# Optional strict record checker since Harness 1.0.7; never a standard ready PR/merge prerequisite.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RecordPath,
    [string]$Repository = (Get-Location).Path,
    [Parameter(Mandatory)][string[]]$RequiredAcceptance,
    [Parameter(Mandatory)][string[]]$ScopeFiles,
    [ValidateSet('important','ordinary')][string]$Classification = 'important',
    [string]$RepositoryId,
    [string]$PolicyPath,
    [switch]$Json
)

# Workflow consistency check, not an attestation or a shell/Git access control.
$ErrorActionPreference = 'Stop'
$failures = New-Object 'System.Collections.Generic.List[string]'
$runtimeOutputs = @{}
$runtimeEvents = @{}
$decisionIndices = @{}
function Deny([string]$Message) { $failures.Add($Message) }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function FullPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $script:repo $Path))
}
function Evidence($Ref, [string]$Label) {
    if (-not $Ref -or -not $Ref.path -or $Ref.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
        Deny "$Label evidence reference is missing or invalid"; return $null
    }
    $path = FullPath $Ref.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Deny "$Label evidence file missing: $path"; return $null }
    if ((Hash $path) -cne $Ref.sha256.ToLowerInvariant()) { Deny "$Label evidence hash mismatch"; return $null }
    return $path
}
function Runtime($Actor, [string]$Role, [string]$ExpectedModel) {
    $path = Evidence $Actor.runtime "$Role runtime"
    if (-not $path) { return }
    $events = @(Get-Content -LiteralPath $path -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    if ($Actor.platform -eq 'codex') {
        $meta = @($events | Where-Object { $_.type -eq 'session_meta' })
        $turns = @($events | Where-Object { $_.type -eq 'turn_context' })
        if ($meta.Count -ne 1 -or -not $turns.Count) { Deny "$Role requires native Codex session_meta and turn_context"; return }
        $sessionId = $meta[0].payload.id
        if (-not $sessionId) { $sessionId = $meta[0].payload.session_id }
        if (-not $Actor.id -or $sessionId -cne $Actor.id) { Deny "$Role runtime identity mismatch" }
        foreach ($turn in $turns) {
            if ($turn.payload.model -cne $ExpectedModel -or $turn.payload.effort -cne 'high') { Deny "$Role runtime model/effort is not $ExpectedModel/high" }
            if ($turn.payload.sandbox_policy.type -cne 'read-only') { Deny "$Role runtime permission is not read-only" }
        }
        $script:runtimeOutputs[$Role] = @($events | Where-Object { $_.type -eq 'response_item' -and $_.payload.type -eq 'message' -and $_.payload.role -eq 'assistant' } | ForEach-Object { $_.payload.content | Where-Object { $_.type -eq 'output_text' } | ForEach-Object { $_.text } })
        $script:runtimeEvents[$Role] = $events
    } elseif ($Actor.platform -eq 'claude') {
        $inits = @($events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' })
        $allowed = @('Read','Grep','Glob','WebFetch','WebSearch')
        $child = $false
        if ($inits.Count -eq 1) {
            $init = $inits[0]
            if (-not $Actor.id -or $init.session_id -cne $Actor.id) { Deny "$Role runtime identity mismatch" }
            if (-not @($init.tools).Count -or @($init.tools | Where-Object { $_ -notin $allowed }).Count) { Deny "$Role Claude runtime tools are not a read-only allowlist" }
            $transcriptPath = Evidence $Actor.runtime.transcript "$Role Claude transcript"
            if (-not $transcriptPath) { return }
            $native = @(Get-Content -LiteralPath $transcriptPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
            $actualModel = $init.model
        } elseif ($inits.Count -eq 0) {
            # Native sidechain prompt snapshots expose effective tools, unlike parent init.
            $child = $true
            $native = $events
            $snapshots = @($native | Where-Object { $_.type -eq 'attachment' -and $_.attachment.type -eq 'prompt_snapshot' -and $_.attachment.tools })
            if (-not $snapshots.Count) { Deny "$Role Claude child runtime lacks effective tool snapshot" }
            foreach ($snapshot in $snapshots) {
                $toolNames = @($snapshot.attachment.tools | ForEach-Object { $_.name })
                if ($snapshot.agentId -cne $Actor.id -or -not $toolNames.Count -or @($toolNames | Where-Object { $_ -notin $allowed }).Count) { Deny "$Role Claude child tools/identity are not a read-only allowlist" }
            }
            $actualModel = @($native | Where-Object { $_.type -eq 'assistant' -and $_.message.model } | Select-Object -First 1)[0].message.model
        } else { Deny "$Role Claude runtime has ambiguous init events"; return }
        if ($actualModel -cne $ExpectedModel -and $actualModel -notmatch ('^claude-' + [regex]::Escape($ExpectedModel) + '-')) { Deny "$Role runtime model is not $ExpectedModel" }
        $answers = @($native | Where-Object { $_.type -eq 'assistant' -and $_.message.model })
        if (-not $answers.Count) { Deny "$Role Claude transcript lacks native assistant events" }
        foreach ($answer in $answers) {
            $actualId = if ($child) { $answer.agentId } else { $answer.sessionId }
            if ($actualId -cne $Actor.id -or $answer.effort -cne 'high' -or ($child -and $answer.isSidechain -ne $true)) { Deny "$Role Claude transcript identity/effort mismatch" }
            if ($answer.message.model -cne $actualModel) { Deny "$Role Claude transcript model differs from launch" }
        }
        $script:runtimeOutputs[$Role] = @($answers | ForEach-Object { $_.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text } })
        $script:runtimeEvents[$Role] = $native
    } else { Deny "$Role runtime platform missing or unsupported" }
}
function AssistantTexts($Event) {
    if ($Event.type -eq 'assistant') { return @($Event.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) }
    if ($Event.type -eq 'response_item' -and $Event.payload.type -eq 'message' -and $Event.payload.role -eq 'assistant') { return @($Event.payload.content | Where-Object { $_.type -eq 'output_text' } | ForEach-Object { $_.text }) }
    return @()
}
function NativeResults([string]$Role, [string]$Marker) {
    $found = @()
    $events = @($script:runtimeEvents[$Role])
    for ($eventIndex = 0; $eventIndex -lt $events.Count; $eventIndex++) {
        foreach ($output in @(AssistantTexts $events[$eventIndex])) {
            foreach ($match in [regex]::Matches($output, [regex]::Escape($Marker) + ':\s*(\{[^\r\n]+\})')) {
                $value = $match.Groups[1].Value | ConvertFrom-Json
                if (-not $script:RepositoryId -or $value.repositoryId -ceq $script:RepositoryId) { $found += [pscustomobject]@{Decision=$value;EventIndex=$eventIndex} }
            }
        }
    }
    return $found
}
function NativeDecision([string]$Role, [string]$Marker) {
    $found = @(NativeResults $Role $Marker)
    if ($found.Count -ne 1) { Deny "$Role requires exactly one native $Marker result"; return }
    $decision = $found[0].Decision
    $script:decisionIndices[$Role] = $found[0].EventIndex
    if ($decision.status -cne 'PASS' -or $decision.authorId -cne $script:record.author.id) { Deny "$Role native result is not PASS or author identity differs" }
    if ($Role -eq 'reviewer' -and $script:Classification -eq 'important' -and $decision.plannerId -cne $script:record.planner.id) { Deny 'Native review planner identity differs' }
    if (@(Compare-Object $script:acceptance @($decision.acceptance | Sort-Object -Unique)).Count) { Deny "$Role native result acceptance differs from required scope" }
    if ($decision.target.commit -cne $script:record.target.commit) { Deny "$Role native target commit differs" }
    $expected = @($script:record.target.files | ForEach-Object { $_.path.Replace('\','/') + '=' + $_.sha256.ToLowerInvariant() } | Sort-Object)
    $actual = @($decision.target.files | ForEach-Object { $_.path.Replace('\','/') + '=' + $_.sha256.ToLowerInvariant() } | Sort-Object)
    if (@(Compare-Object $expected $actual).Count) { Deny "$Role native result target files/hash differs" }
}
function IsImage([byte[]]$Bytes) {
    if ($Bytes.Length -lt 12) { return $false }
    $hex = [BitConverter]::ToString($Bytes[0..11])
    if (-not ($hex.StartsWith('89-50-4E-47-0D-0A-1A-0A') -or $hex.StartsWith('FF-D8-FF') -or $hex.StartsWith('47-49-46-38-37-61') -or $hex.StartsWith('47-49-46-38-39-61'))) { return $false }
    # ArgumentList is used only on macOS; Windows PowerShell 5 retains GDI+ below.
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Unix -and (Test-Path -LiteralPath '/System/Library/Frameworks/AppKit.framework')) {
        $temp = Join-Path ([IO.Path]::GetTempPath()) ('inspirei-image-' + [guid]::NewGuid().ToString('N'))
        $process = $null
        try {
            if (-not (Test-Path -LiteralPath '/usr/bin/osascript' -PathType Leaf)) { return $false }
            [IO.File]::WriteAllBytes($temp, $Bytes)
            $helper = 'ObjC.import("AppKit"); function run(argv) { try { var data = $.NSData.dataWithContentsOfFile(argv[0]); var rep = $.NSBitmapImageRep.imageRepWithData(data); if (rep.isNil()) return "invalid"; var raster = rep.TIFFRepresentation; if (raster.isNil() || raster.length <= 0) return "invalid"; return rep.pixelsWide > 0 && rep.pixelsHigh > 0 ? "valid" : "invalid"; } catch (error) { return "invalid"; } }'
            $start = New-Object Diagnostics.ProcessStartInfo
            $start.FileName = '/usr/bin/osascript'
            $start.UseShellExecute = $false
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            foreach ($argument in @('-l','JavaScript','-e',$helper,$temp)) { $start.ArgumentList.Add($argument) }
            $process = New-Object Diagnostics.Process
            $process.StartInfo = $start
            if (-not $process.Start()) { return $false }
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(1000) | Out-Null; return $false }
            # Stream draining is separately bounded, including inherited handles.
            if (-not $stdout.Wait(1000) -or -not $stderr.Wait(1000)) { return $false }
            return $process.ExitCode -eq 0 -and [string]::IsNullOrEmpty($stderr.Result) -and $stdout.Result.TrimEnd("`r", "`n") -ceq 'valid'
        } catch { return $false }
        finally {
            if ($process) {
                try { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(1000) | Out-Null } } catch { }
                $process.Dispose()
            }
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
        }
    }
    $stream = $null
    $decoded = $null
    try {
        Add-Type -AssemblyName System.Drawing
        $stream = New-Object IO.MemoryStream(,$Bytes)
        $decoded = [Drawing.Image]::FromStream($stream)
        return $decoded.Width -gt 0 -and $decoded.Height -gt 0
    } catch { return $false }
    finally { if ($decoded) { $decoded.Dispose() }; if ($stream) { $stream.Dispose() } }
}
function ImageResult($Content) {
    foreach ($item in @($Content)) {
        $encoded = $null
        if ($item.type -in @('input_image','image')) {
            if ($item.source.type -eq 'base64') { $encoded = $item.source.data }
            elseif ($item.image_url -is [string] -and $item.image_url -match '^data:image/[^;]+;base64,(.+)$') { $encoded = $Matches[1] }
            elseif ($item.data -and $item.mimeType -like 'image/*') { $encoded = $item.data }
        }
        if ($encoded -and (IsImage ([Convert]::FromBase64String($encoded)))) { return $true }
    }
    return $false
}
function OriginalImageResult($Content, [string]$ExpectedHash) {
    if ($Content -is [string]) { try { $Content = $Content | ConvertFrom-Json } catch { return $false } }
    if ($Content.isError -eq $true -or $Content.is_error -eq $true) { return $false }
    $images = @($Content | Where-Object { $_.type -in @('input_image','image') })
    if ($images.Count -ne 1) { return $false }
    foreach ($item in @($Content)) {
        if ($item.isError -eq $true -or $item.is_error -eq $true -or ($item.type -eq 'input_text' -and $item.text -match '^Script failed')) { return $false }
    }
    $encoded = $null
    $item = $images[0]
    if ($item.source.type -eq 'base64') { $encoded = $item.source.data }
    elseif ($item.image_url -is [string] -and $item.image_url -match '^data:image/[^;]+;base64,(.+)$') { $encoded = $Matches[1] }
    elseif ($item.data -and $item.mimeType -like 'image/*') { $encoded = $item.data }
    if (-not $encoded) { return $false }
    try {
        $bytes = [Convert]::FromBase64String($encoded)
        if (-not (IsImage $bytes)) { return $false }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
        return $hash -ceq $ExpectedHash
    } catch { return $false }
}
function ViewedImage([string]$ImagePath) {
    $expectedPath = (FullPath $ImagePath).Replace('\','/')
    if (-not (IsImage ([IO.File]::ReadAllBytes((FullPath $ImagePath))))) { return $false }
    # Native call IDs are opaque and case-sensitive across all supported routes.
    $calls = [Collections.Hashtable]::new([StringComparer]::Ordinal)
    $customCalls = [Collections.Hashtable]::new([StringComparer]::Ordinal)
    $expectedHash = Hash (FullPath $ImagePath)
    $events = @($script:runtimeEvents['reviewer'])
    $end = $script:decisionIndices['reviewer']
    if ($null -eq $end) { return $false }
    for ($index = 0; $index -lt $end; $index++) {
        $event = $events[$index]
        if ($event.type -eq 'assistant') {
            foreach ($tool in @($event.message.content | Where-Object { $_.type -eq 'tool_use' -and $_.name -eq 'Read' })) {
                if ($tool.id -and $tool.input.file_path -and (FullPath $tool.input.file_path).Replace('\','/') -ieq $expectedPath) { $calls[$tool.id] = $true }
            }
        }
        if ($event.type -eq 'response_item' -and $event.payload.type -eq 'function_call' -and $event.payload.name -match '(^|\.)view_image$') {
            $argsObject = $event.payload.arguments | ConvertFrom-Json
            if ($event.payload.call_id -and $argsObject.path -and (FullPath $argsObject.path).Replace('\','/') -ieq $expectedPath) { $calls[$event.payload.call_id] = $true }
        }
        if ($event.type -eq 'response_item' -and $event.payload.type -eq 'custom_tool_call' -and $event.payload.name -ceq 'exec') {
            # Recognize syntax, never execute JavaScript. Only whitespace may vary.
            $template = '\A\s*const\s+result\s*=\s*await\s+tools\.view_image\(\s*\{\s*path\s*:\s*("(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*")\s*,\s*detail\s*:\s*"original"\s*\}\s*\)\s*;\s*image\(\s*result\.image_url\s*\)\s*;\s*\z'
            if (-not [string]::IsNullOrWhiteSpace($event.payload.call_id) -and $event.payload.input -cmatch $template) {
                $pathLiteral = $Matches[1]
                try { $customPath = ConvertFrom-Json -InputObject $pathLiteral } catch { continue }
                $id = $event.payload.call_id
                $callCount = @($events | Where-Object { $_.type -eq 'response_item' -and $_.payload.type -in @('custom_tool_call','function_call') -and $_.payload.call_id -ceq $id }).Count
                $resultCount = @($events | Where-Object { $_.type -eq 'response_item' -and $_.payload.type -in @('custom_tool_call_output','function_call_output') -and $_.payload.call_id -ceq $id }).Count
                if ($callCount -eq 1 -and $resultCount -eq 1 -and (FullPath $customPath).Replace('\','/') -ieq $expectedPath) { $customCalls[$id] = $true }
            }
        }
        if ($event.type -eq 'response_item' -and $event.payload.type -eq 'custom_tool_call_output' -and $event.payload.call_id -and $customCalls[$event.payload.call_id]) {
            if (OriginalImageResult $event.payload.output $expectedHash) { return $true }
        }
        if ($event.type -eq 'user') {
            foreach ($result in @($event.message.content | Where-Object { $_.type -eq 'tool_result' })) {
                if ($calls[$result.tool_use_id] -and $result.is_error -ne $true -and (ImageResult $result.content)) { return $true }
            }
        }
        if ($event.type -eq 'response_item' -and $event.payload.type -eq 'function_call_output' -and $calls[$event.payload.call_id]) {
            $content = $event.payload.output
            if ($content -is [string]) {
                try { $content = $content | ConvertFrom-Json } catch { continue }
            }
            if ($content.isError -ne $true -and ((ImageResult $content) -or (ImageResult $content.content))) { return $true }
        }
    }
    return $false
}

try {
    $repo = (Resolve-Path -LiteralPath $Repository).Path
    $record = Get-Content -LiteralPath $RecordPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($record.schemaVersion -ne 1) { Deny 'Unsupported or missing schemaVersion' }
    if ($RepositoryId) {
        if ($record.repositoryId -cne $RepositoryId) { Deny 'Record repository identity differs from caller' }
        $remote = & git -C $repo config --get remote.origin.url 2>$null
        if ($LASTEXITCODE -eq 0 -and $remote) {
            $normalizedRemote = ($remote -replace '^git@([^:]+):', 'https://$1/' -replace '\.git$', '').TrimEnd('/').ToLowerInvariant()
            $normalizedId = ($RepositoryId -replace '^git@([^:]+):', 'https://$1/' -replace '\.git$', '').TrimEnd('/').ToLowerInvariant()
            if ($normalizedRemote -cne $normalizedId) { Deny 'Repository identity does not match origin remote' }
        } elseif ($record.target.commit) { Deny 'Commit repository identity requires origin remote' }
    }
    $policyFiles = @()
    $repoPolicy = Join-Path $repo 'docs/rules/review-policy.json'
    if (Test-Path -LiteralPath $repoPolicy) { $policyFiles += $repoPolicy }
    if ($PolicyPath) { $policyFiles += (FullPath $PolicyPath) }
    $policy = [pscustomobject]@{allowedReviewerModels=@('gpt-6-astra','gpt-6.1-sol','fable','opus');requiredAcceptance=@();requiredValidationIds=@();requireVisual=$false;requireDevice=$false}
    foreach ($policyFile in @($policyFiles | Sort-Object -Unique)) {
        $extra = Get-Content -LiteralPath $policyFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($extra.schemaVersion -ne 1) { Deny 'Unsupported project review policy schema' }
        $policyKeys = @('schemaVersion','classification','allowedReviewerModels','requiredAcceptance','requiredValidationIds','requireVisual','requireDevice')
        if (@($extra.PSObject.Properties.Name | Where-Object { $_ -notin $policyKeys }).Count) { Deny 'Unknown project review policy field' }
        foreach ($key in @('requireVisual','requireDevice')) {
            if ($key -in $extra.PSObject.Properties.Name -and $extra.$key -isnot [bool]) { Deny "Project policy $key must be boolean" }
        }
        if ('allowedReviewerModels' -in $extra.PSObject.Properties.Name -and -not @($extra.allowedReviewerModels | Where-Object { $_ }).Count) { Deny 'Project reviewer model allowlist must not be empty' }
        if ($extra.classification -and $extra.classification -notin @('ordinary','important')) { Deny 'Invalid project classification' }
        if ($extra.classification -eq 'important') { $Classification = 'important' }
        if ($extra.allowedReviewerModels) {
            # Narrowing is supported; a policy cannot authorize a lower common minimum.
            $validModels = @('gpt-6-astra','gpt-6.1-sol','fable','opus')
            if (@($extra.allowedReviewerModels | Where-Object { $_ -notin $validModels }).Count) { Deny 'Project policy contains unsupported reviewer model' }
            $policy.allowedReviewerModels = @($policy.allowedReviewerModels | Where-Object { $_ -in $extra.allowedReviewerModels })
        }
        $policy.requiredAcceptance = @($policy.requiredAcceptance + @($extra.requiredAcceptance) | Where-Object { $_ } | Sort-Object -Unique)
        $policy.requiredValidationIds = @($policy.requiredValidationIds + @($extra.requiredValidationIds) | Where-Object { $_ } | Sort-Object -Unique)
        $policy.requireVisual = $policy.requireVisual -or $extra.requireVisual -eq $true
        $policy.requireDevice = $policy.requireDevice -or $extra.requireDevice -eq $true
    }
    if ($record.classification -notin @('important','ordinary')) { Deny 'Record classification must be explicit' }
    if ($record.classification -eq 'important') { $Classification = 'important' }
    if ($Classification -eq 'important' -and $record.classification -ne 'important') { Deny 'Mandatory important classification cannot be downgraded' }
    $importantReasons = @('estimate','purchase','adoption','design','numerical','signal','units','coordinates','visual','geometry','layout','legal','financial','security','permissions','order','production','repeated-failure')
    $reasons = @($record.reasons)
    if (-not $reasons.Count -or @($reasons | Where-Object { $_ -notin ($importantReasons + @('routine')) }).Count) { Deny 'Classification reasons missing or unsupported' }
    if (@($reasons | Where-Object { $_ -in $importantReasons }).Count) {
        if ($record.classification -ne 'important') { Deny 'Important reason cannot route to ordinary review' }
        $Classification = 'important'
    }
    $acceptance = @($RequiredAcceptance + @($policy.requiredAcceptance) | Where-Object { $_ } | Sort-Object -Unique)
    if (-not $acceptance.Count) { Deny 'Required acceptance scope is empty' }
    $files = @($ScopeFiles | ForEach-Object { $_.Replace('\','/') } | Sort-Object -Unique)
    if (-not $files.Count) { Deny 'Required file scope is empty' }
    $recordFiles = @($record.target.files)
    if ($record.target.kind -notin @('artifact','commit')) { Deny 'Target kind must be artifact or commit' }
    if ($record.target.kind -eq 'commit' -and -not $record.target.commit) { Deny 'Commit target kind requires commit' }
    if ($recordFiles.Count -ne $files.Count -or @(Compare-Object $files @($recordFiles | ForEach-Object { $_.path.Replace('\','/') } | Sort-Object -Unique)).Count) { Deny 'Target file scope does not match required scope' }
    foreach ($file in $recordFiles) {
        $path = FullPath $file.path
        $prefix = $repo.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
        if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { Deny 'Scope file escapes repository'; continue }
        if ($file.sha256 -eq 'absent') {
            if (Test-Path -LiteralPath $path) { Deny "Target file should be absent: $($file.path)" }
        } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf) -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$') { Deny "Target file/hash missing: $($file.path)" }
        elseif ((Hash $path) -cne $file.sha256.ToLowerInvariant()) { Deny "Stale target file: $($file.path)" }
    }
    if ($record.target.commit) {
        $head = & git -C $repo rev-parse HEAD 2>$null
        if ($LASTEXITCODE -ne 0 -or $head -cne $record.target.commit) { Deny 'Target commit does not match HEAD' }
        # Limit dirty checks to accepted files, not unrelated owner work.
        foreach ($file in $files) {
            $dirty = & git -C $repo status --porcelain --untracked-files=all -- $file 2>$null
            if ($LASTEXITCODE -ne 0 -or $dirty) { Deny "Relevant file is dirty for commit review: $file" }
        }
    } elseif ($record.target.kind -ne 'artifact') { Deny 'Target requires a commit or explicit artifact kind with exact file hashes' }
    if (-not $record.author.id -or -not $record.reviewer.id -or $record.author.id -ceq $record.reviewer.id) { Deny 'Reviewer must be independent of author' }
    $reviewerModel = if ($record.reviewer.platform -eq 'codex') { if ($Classification -eq 'important') { 'gpt-6-astra' } else { 'gpt-6.1-sol' } } else { if ($Classification -eq 'important') { 'fable' } else { 'opus' } }
    if ($reviewerModel -notin $policy.allowedReviewerModels) { Deny 'Reviewer does not satisfy stricter project policy' }
    Runtime $record.reviewer 'reviewer' $reviewerModel
    NativeDecision 'reviewer' 'REVIEW_GATE_RESULT'
    if ($Classification -eq 'important') {
        if (-not $record.planner.id -or $record.planner.id -ceq $record.reviewer.id) { Deny 'Senior reviewer must be independent of planner' }
        Runtime $record.planner 'planner' $(if ($record.planner.platform -eq 'codex') { 'gpt-6-astra' } else { 'fable' })
        # Plan approves acceptance and source boundary; it precedes finished artifact hashes.
        $planMatches = @(NativeResults 'planner' 'PLAN_GATE_RESULT')
        if ($planMatches.Count -ne 1) { Deny 'Planner requires exactly one native PLAN_GATE_RESULT' }
        else {
            $planned = $planMatches[0].Decision
            if ($planned.status -cne 'PASS' -or @(Compare-Object $acceptance @($planned.acceptance | Sort-Object -Unique)).Count -or @(Compare-Object $files @($planned.scopeFiles | Sort-Object -Unique)).Count) { Deny 'Native plan does not approve required acceptance/file scope' }
        }
        if ($record.planning.status -cne 'PASS' -or -not (Evidence $record.planning.evidence 'planning')) { Deny 'Important decision requires a confirmed plan and evidence' }
        if (-not (Evidence $record.research.evidence 'research') -or -not $record.research.checkedAt) { Deny 'Important decision requires dated research evidence' }
    }
    if ($record.review.status -cne 'PASS' -or -not (Evidence $record.review.evidence 'review')) { Deny 'Independent review is missing or not PASS' }
    foreach ($check in @($record.validations | Where-Object { $_.mandatory -eq $true })) {
        if ($check.status -cne 'PASS' -or -not (Evidence $check.evidence "mandatory validation $($check.id)")) { Deny "Mandatory validation failed, unknown or lacks evidence: $($check.id)" }
    }
    $reviewed = @($record.review.acceptance | Where-Object { $_.status -ceq 'PASS' } | ForEach-Object { $_.id })
    foreach ($id in $acceptance) {
        if ($id -notin $reviewed) { Deny "Acceptance not independently approved: $id" }
        $checks = @($record.validations | Where-Object { $id -in @($_.acceptance) -and $_.mandatory -eq $true })
        if (-not $checks.Count) { Deny "Mandatory validation missing: $id" }
        foreach ($check in $checks) {
            if ($check.status -cne 'PASS' -or -not (Evidence $check.evidence "validation $($check.id)")) { Deny "Mandatory validation failed, unknown or lacks evidence: $($check.id)" }
        }
    }
    foreach ($id in @($policy.requiredValidationIds | Where-Object { $_ })) {
        $checks = @($record.validations | Where-Object { $_.id -ceq $id -and $_.mandatory -eq $true -and $_.status -ceq 'PASS' })
        if ($checks.Count -ne 1 -or -not (Evidence $checks[0].evidence "project validation $id")) { Deny "Project-required validation missing: $id" }
    }
    if ($record.PSObject.Properties.Name -notcontains 'unverified') { Deny 'Explicit unverified list is required (empty is allowed)' }
    foreach ($item in @($record.unverified)) {
        if (@($item.acceptance | Where-Object { $_ -in $acceptance }).Count) { Deny 'Unverified item overlaps requested completion scope' }
    }
    $needsVisual = $policy.requireVisual -eq $true -or @($reasons | Where-Object { $_ -in @('visual','geometry','layout') }).Count -gt 0
    if ($needsVisual) {
        if ($record.visual.viewedBy -cne $record.reviewer.id -or -not (Evidence $record.visual.image 'visual image') -or -not (Evidence $record.visual.viewingEvidence 'visual viewing')) { Deny 'Visual scope requires image and independent reviewer viewing evidence' }
        elseif (-not (ViewedImage $record.visual.image.path)) { Deny 'Native reviewer runtime has no supported image viewing tool call for the image' }
    }
    if ($policy.requireDevice -eq $true -or $record.claims.device -eq $true) {
        $deviceChecks = @($record.validations | Where-Object { $_.provenance -ceq 'physical-device' -and $_.mandatory -eq $true -and $_.status -ceq 'PASS' })
        if (-not $deviceChecks.Count) { Deny 'Device claim cannot be approved with synthetic/static evidence' }
        foreach ($check in $deviceChecks) { if (-not (Evidence $check.evidence "device $($check.id)")) { Deny 'Physical-device evidence missing' } }
    }
} catch { Deny ("Invalid record or unavailable evidence: " + $_.Exception.Message) }

$result = [pscustomobject]@{ State = $(if ($failures.Count) { 'BLOCKED' } else { 'PASS' }); Classification = $Classification; Failures = @($failures.ToArray()); Record = $RecordPath }
if ($Json) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
if ($failures.Count) { exit 1 }
exit 0
