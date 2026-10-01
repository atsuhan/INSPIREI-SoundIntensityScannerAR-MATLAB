[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$gate = Join-Path $PSScriptRoot 'Test-ReviewGate.ps1'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('inspirei-review-gate-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
function SaveJson($Value, [string]$Path) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false))) }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Ref([string]$Path) { @{path=$Path;sha256=(Sha $Path)} }
function NativeLog([string]$Path, [string]$Id, [string]$Model, [string]$Text) {
    $events = @(
        @{type='session_meta';payload=@{id=$Id;originator='codex_exec';cli_version='0.159.3'}},
        @{type='turn_context';payload=@{model=$Model;effort='high';sandbox_policy=@{type='read-only'}}},
        @{type='response_item';payload=@{type='message';role='assistant';content=@(@{type='output_text';text=$Text})}}
    )
    [IO.File]::WriteAllLines($Path, @($events | ForEach-Object { $_ | ConvertTo-Json -Depth 20 -Compress }), (New-Object Text.UTF8Encoding($false)))
}
function Fixture([string]$Reason = 'design', [string]$Class = 'important') {
    [IO.File]::WriteAllText((Join-Path $sandbox 'product.txt'), 'reviewed product')
    [IO.File]::WriteAllText((Join-Path $sandbox 'validation.log'), 'actual test output')
    [IO.File]::WriteAllText((Join-Path $sandbox 'research.log'), 'dated primary-source research')
    $target = @{kind='artifact'; files=@(@{path='product.txt';sha256=(Sha (Join-Path $sandbox 'product.txt'))})}
    $decision = @{status='PASS';authorId='author-1';plannerId='planner-1';acceptance=@('A-1');target=$target}
    $reviewLog = Join-Path $sandbox 'reviewer.jsonl'
    $plannerLog = Join-Path $sandbox 'planner.jsonl'
    $model = if ($Class -eq 'ordinary') { 'gpt-6.1-sol' } else { 'gpt-6-astra' }
    NativeLog $reviewLog 'reviewer-1' $model ('REVIEW_GATE_RESULT: ' + ($decision | ConvertTo-Json -Depth 12 -Compress))
    NativeLog $plannerLog 'planner-1' 'gpt-6-astra' ('PLAN_GATE_RESULT: ' + (@{status='PASS';acceptance=@('A-1');scopeFiles=@('product.txt')} | ConvertTo-Json -Compress))
    return @{
        schemaVersion=1; classification=$Class; reasons=@($Reason); target=$target;
        author=@{id='author-1'};reviewer=@{id='reviewer-1';platform='codex';runtime=(Ref $reviewLog)};
        planner=@{id='planner-1';platform='codex';runtime=(Ref $plannerLog)};
        research=@{checkedAt='2026-10-01';evidence=(Ref (Join-Path $sandbox 'research.log'))};
        planning=@{status='PASS';evidence=(Ref $plannerLog)};
        review=@{status='PASS';evidence=(Ref $reviewLog);acceptance=@(@{id='A-1';status='PASS'})};
        validations=@(@{id='test-1';acceptance=@('A-1');mandatory=$true;status='PASS';provenance='static';evidence=(Ref (Join-Path $sandbox 'validation.log'))});
        unverified=@();claims=@{device=$false}
    }
}
$passed = 0
$failed = 0
function Case([string]$Name, [bool]$ShouldPass, [scriptblock]$Mutation, [string]$Reason = 'design', [string]$Class = 'important', [string]$RequestedClass = 'important', [scriptblock]$Policy = {}, [string[]]$ExtraArgs = @()) {
    $policyFile = Join-Path $sandbox 'docs/rules/review-policy.json'
    if (Test-Path -LiteralPath $policyFile) { Remove-Item -LiteralPath $policyFile }
    $record = Fixture $Reason $Class
    & $Mutation $record
    & $Policy $policyFile
    $recordPath = Join-Path $sandbox 'record.json'
    SaveJson $record $recordPath
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $gate -RecordPath $recordPath -Repository $sandbox -RequiredAcceptance A-1 -ScopeFiles product.txt -Classification $RequestedClass -Json @ExtraArgs 2>&1
    $code = $LASTEXITCODE
    if (($code -eq 0) -eq $ShouldPass) { $script:passed++; Write-Output "PASS $Name (exit=$code)" }
    else { $script:failed++; Write-Output "FAIL $Name (exit=$code expected pass=$ShouldPass)"; $output | Write-Output }
}
try {
    Case 'important native Astra planner and independent reviewer' $true {}
    Case 'routine implementation routes to Sol reviewer' $true {} 'routine' 'ordinary' 'ordinary'
    foreach ($reason in @('estimate','purchase','adoption','design','numerical','signal','units','coordinates','legal','financial','security','permissions','order','production','repeated-failure')) {
        Case "important route $reason rejects ordinary declaration" $false {} $reason 'ordinary' 'ordinary'
    }
    Case 'unknown classification defaults mandatory' $false { param($r) $r.classification=$null }
    Case 'ordinary cannot weaken mandatory invocation' $false {} 'routine' 'ordinary'
    Case 'model alias/self assertion cannot replace native model' $false { param($r)
        NativeLog $r.reviewer.runtime.path 'reviewer-1' 'gpt-6.1-sol' 'I am Astra/high; PASS'
        $r.reviewer.runtime=Ref $r.reviewer.runtime.path
    }
    Case 'unrelated native smoke log cannot approve target' $false { param($r)
        NativeLog $r.reviewer.runtime.path 'reviewer-1' 'gpt-6-astra' 'PASS'
        $r.reviewer.runtime=Ref $r.reviewer.runtime.path
    }
    Case 'missing runtime file' $false { param($r) $r.reviewer.runtime.path=Join-Path $sandbox 'missing.jsonl' }
    Case 'runtime hash tampering' $false { param($r) $r.reviewer.runtime.sha256='0' * 64 }
    Case 'wrong native effort' $false { param($r)
        $path=$r.reviewer.runtime.path
        [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path).Replace('"effort":"high"','"effort":"medium"')))
        $r.reviewer.runtime=Ref $path
    }
    Case 'reviewer native write permission rejected' $false { param($r)
        $path=$r.reviewer.runtime.path
        [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path).Replace('read-only','danger-full-access')))
        $r.reviewer.runtime=Ref $path
    }
    Case 'native review target mismatch' $false { param($r)
        $path=$r.reviewer.runtime.path
        [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path).Replace('author-1','other-author')))
        $r.reviewer.runtime=Ref $path
    }
    Case 'self review' $false { param($r) $r.author.id='reviewer-1' }
    Case 'planner reviews own plan' $false { param($r) $r.planner.id='reviewer-1' }
    Case 'stale artifact hash' $false { param($r) [IO.File]::WriteAllText((Join-Path $sandbox 'product.txt'), 'changed after approval') }
    Case 'stale commit' $false { param($r) $r.target.commit='0' * 40 }
    Case 'scope narrowing' $false { param($r) $r.target.files=@() }
    Case 'scope escape' $false { param($r) $r.target.files[0].path='../outside.txt' }
    Case 'acceptance partially reviewed' $false { param($r) $r.review.acceptance=@() }
    Case 'mandatory test failure cannot use CI waiver' $false { param($r) $r.validations[0].status='FAIL' }
    Case 'mandatory test unknown' $false { param($r) $r.validations[0].status='UNKNOWN' }
    Case 'mandatory test omitted' $false { param($r) $r.validations=@() }
    Case 'unverified completion scope' $false { param($r) $r.unverified=@(@{acceptance=@('A-1');reason='not run'}) }
    Case 'explicit unverified field required' $false { param($r) $r.Remove('unverified') }
    foreach ($reason in @('visual','geometry','layout')) { Case "$reason requires actual viewing evidence" $false {} $reason }
    Case 'visual evidence without native viewing rejected' $false { param($r)
        $r.visual=@{viewedBy=$r.reviewer.id;image=(Ref (Join-Path $sandbox 'product.txt'));viewingEvidence=(Ref $r.reviewer.runtime.path)}
    } 'visual'
    $visualFixture = { param($r)
        $path=$r.reviewer.runtime.path
        $png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZ1kAAAAASUVORK5CYII='
        $imagePath=Join-Path $sandbox 'image.png'
        [IO.File]::WriteAllBytes($imagePath, [Convert]::FromBase64String($png))
        $call=@{type='response_item';payload=@{type='function_call';call_id='view-1';name='view_image';arguments=(@{path=$imagePath} | ConvertTo-Json -Compress)}}
        $result=@{type='response_item';payload=@{type='function_call_output';call_id='view-1';output=@(@{type='input_image';image_url=('data:image/png;base64,'+$png)})}}
        $events=@(Get-Content -LiteralPath $path)
        $newEvents=@($events[0..1]) + @(($call | ConvertTo-Json -Depth 10 -Compress),($result | ConvertTo-Json -Depth 10 -Compress)) + @($events[2])
        [IO.File]::WriteAllLines($path, $newEvents)
        $r.reviewer.runtime=Ref $path
        $r.review.evidence=Ref $path
        $r.visual=@{viewedBy=$r.reviewer.id;image=(Ref $imagePath);viewingEvidence=(Ref $path)}
    }
    Case 'visual native successful viewing before PASS accepted' $true $visualFixture 'visual'
    Case 'visual tool error rejected' $false { param($r)
        & $visualFixture $r
        $path=$r.reviewer.runtime.path
        $events=@(Get-Content -LiteralPath $path | ForEach-Object { $_ | ConvertFrom-Json })
        $events[3].payload.output=@{isError=$true;content=@(@{type='input_image';image_url=('data:image/png;base64,'+[Convert]::ToBase64String([IO.File]::ReadAllBytes($r.visual.image.path)))})}
        [IO.File]::WriteAllLines($path, @($events | ForEach-Object { $_ | ConvertTo-Json -Depth 20 -Compress }))
        $r.reviewer.runtime=Ref $path; $r.review.evidence=Ref $path; $r.visual.viewingEvidence=Ref $path
    } 'visual'
    Case 'visual missing successful tool result rejected' $false { param($r)
        & $visualFixture $r
        $path=$r.reviewer.runtime.path
        [IO.File]::WriteAllLines($path, @(Get-Content -LiteralPath $path | Where-Object { $_ -notmatch 'function_call_output' }))
        $r.reviewer.runtime=Ref $path; $r.review.evidence=Ref $path; $r.visual.viewingEvidence=Ref $path
    } 'visual'
    Case 'visual result after PASS rejected' $false { param($r)
        & $visualFixture $r
        $path=$r.reviewer.runtime.path
        $events=@(Get-Content -LiteralPath $path)
        [IO.File]::WriteAllLines($path, @($events[0],$events[1],$events[2],$events[4],$events[3]))
        $r.reviewer.runtime=Ref $path; $r.review.evidence=Ref $path; $r.visual.viewingEvidence=Ref $path
    } 'visual'
    Case 'visual text file is not an image' $false { param($r)
        & $visualFixture $r
        [IO.File]::WriteAllText($r.visual.image.path,'not an image')
        $r.visual.image=Ref $r.visual.image.path
    } 'visual'
    Case 'synthetic evidence cannot establish device claim' $false { param($r) $r.claims.device=$true; $r.validations[0].provenance='synthetic' }
    Case 'physical device claim with raw evidence' $true { param($r) $r.claims.device=$true; $r.validations[0].provenance='physical-device' }
    Case 'stricter project acceptance enforced' $false {} 'design' 'important' 'important' { param($path)
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        SaveJson @{schemaVersion=1;requiredAcceptance=@('DEVICE-1')} $path
    }
    Case 'stricter project model enforced' $false {} 'design' 'important' 'important' { param($path)
        SaveJson @{schemaVersion=1;allowedReviewerModels=@('fable')} $path
    }
    Case 'project policy cannot weaken important category' $false {} 'routine' 'ordinary' 'ordinary' { param($path)
        SaveJson @{schemaVersion=1;classification='important'} $path
    }
    Case -Name 'caller custom policy cannot replace stricter repo policy' -ShouldPass $false -Mutation {} -Policy { param($path)
        SaveJson @{schemaVersion=1;requireDevice=$true} $path
        SaveJson @{schemaVersion=1} (Join-Path $sandbox 'caller-policy.json')
    } -ExtraArgs @('-PolicyPath',(Join-Path $sandbox 'caller-policy.json'))
    Case 'unrelated dirty artifact does not block exact scope' $true { param($r) [IO.File]::WriteAllText((Join-Path $sandbox 'owner-work.txt'), 'unrelated') }
    $claudeFixture = { param($r)
        $initPath = Join-Path $sandbox 'claude-init.jsonl'
        $nativePath = Join-Path $sandbox 'claude-native.jsonl'
        $decision = @{status='PASS';authorId=$r.author.id;plannerId=$r.planner.id;acceptance=@('A-1');target=$r.target}
        SaveJson @{type='system';subtype='init';session_id='claude-reviewer-1';model='claude-fable-5-1';tools=@('Read','Grep','Glob')} $initPath
        # Real persisted transcript is JSONL with message.model and top-level effort/sessionId.
        SaveJson @{type='assistant';sessionId='claude-reviewer-1';effort='high';message=@{model='claude-fable-5-1';content=@(@{type='text';text=('REVIEW_GATE_RESULT: ' + ($decision | ConvertTo-Json -Depth 12 -Compress))})}} $nativePath
        # SaveJson's pretty JSON must be one event per line for native JSONL.
        foreach ($path in @($initPath,$nativePath)) {
            $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 20 -Compress))
        }
        $r.reviewer=@{id='claude-reviewer-1';platform='claude';runtime=(Ref $initPath)}
        $r.reviewer.runtime.transcript=Ref $nativePath
        $r.review.evidence=Ref $nativePath
    }
    Case 'Claude native init plus high effort transcript' $true $claudeFixture
    Case 'Claude effort absent cannot be inferred from agent definition' $false { param($r)
        & $claudeFixture $r
        $path=$r.reviewer.runtime.transcript.path
        [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path).Replace('"effort":"high",','')))
        $r.reviewer.runtime.transcript=Ref $path
    }
    Case 'Claude Bash or delegation tools rejected' $false { param($r)
        & $claudeFixture $r
        $path=$r.reviewer.runtime.path
        $init=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $init.tools=@('Read','Bash','Task')
        [IO.File]::WriteAllText($path, ($init | ConvertTo-Json -Compress))
        $r.reviewer.runtime.sha256=Sha $path
    }
    $claudeChildFixture = { param($r)
        $path=Join-Path $sandbox 'claude-child.jsonl'
        $decision=@{status='PASS';authorId=$r.author.id;plannerId=$r.planner.id;acceptance=@('A-1');target=$r.target}
        $events=@(
            @{type='attachment';agentId='child-reviewer-1';sessionId='shared-parent-session';attachment=@{type='prompt_snapshot';tools=@(@{name='Read'},@{name='Grep'},@{name='Glob'})}},
            @{type='assistant';agentId='child-reviewer-1';sessionId='shared-parent-session';isSidechain=$true;effort='high';message=@{model='claude-fable-5-1';content=@(@{type='text';text=('REVIEW_GATE_RESULT: ' + ($decision | ConvertTo-Json -Depth 12 -Compress))})}}
        )
        [IO.File]::WriteAllLines($path, @($events | ForEach-Object { $_ | ConvertTo-Json -Depth 20 -Compress }))
        $r.reviewer=@{id='child-reviewer-1';platform='claude';runtime=(Ref $path)}
        $r.review.evidence=Ref $path
    }
    Case 'Claude child effective tools and agent identity' $true $claudeChildFixture
    Case 'Claude child parent session ID is not actor identity' $false { param($r)
        & $claudeChildFixture $r
        $r.reviewer.id='shared-parent-session'
    }
    Case 'Claude child effective tool snapshot absent' $false { param($r)
        & $claudeChildFixture $r
        $path=$r.reviewer.runtime.path
        $events=Get-Content -LiteralPath $path | Where-Object { $_ -notmatch 'prompt_snapshot' }
        [IO.File]::WriteAllLines($path, @($events))
        $r.reviewer.runtime=Ref $path
    }
    Case 'Claude child effective write tools rejected' $false { param($r)
        & $claudeChildFixture $r
        $path=$r.reviewer.runtime.path
        [IO.File]::WriteAllText($path, ([IO.File]::ReadAllText($path).Replace('"name":"Glob"','"name":"Write"')))
        $r.reviewer.runtime=Ref $path
    }
    $batchFixture = { param($r)
        $r.repositoryId='https://example.test/repo-1'
        $decisions=@()
        $plans=@()
        foreach ($id in @('https://example.test/repo-1','https://example.test/repo-2')) {
            $decisions += 'REVIEW_GATE_RESULT: ' + (@{status='PASS';repositoryId=$id;authorId=$r.author.id;plannerId=$r.planner.id;acceptance=@('A-1');target=$r.target} | ConvertTo-Json -Depth 15 -Compress)
            $plans += 'PLAN_GATE_RESULT: ' + (@{status='PASS';repositoryId=$id;acceptance=@('A-1');scopeFiles=@('product.txt')} | ConvertTo-Json -Compress)
        }
        NativeLog $r.reviewer.runtime.path 'reviewer-1' 'gpt-6-astra' ($decisions -join "`n")
        NativeLog $r.planner.runtime.path 'planner-1' 'gpt-6-astra' ($plans -join "`n")
        $r.reviewer.runtime=Ref $r.reviewer.runtime.path; $r.review.evidence=$r.reviewer.runtime
        $r.planner.runtime=Ref $r.planner.runtime.path; $r.planning.evidence=$r.planner.runtime
    }
    Case -Name 'batch native decisions select exactly one repository' -ShouldPass $true -Mutation $batchFixture -ExtraArgs @('-RepositoryId','https://example.test/repo-1')
    Case -Name 'batch cannot use decision of other repository' -ShouldPass $false -Mutation $batchFixture -ExtraArgs @('-RepositoryId','https://example.test/repo-3')
    Case -Name 'multiple native decisions need explicit repository selector' -ShouldPass $false -Mutation $batchFixture
    Write-Output "Scenarios: $passed passed, $failed failed"
} finally {
    # Delete only the exact generated temp directory after checking its absolute location.
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath($sandbox)
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^inspirei-review-gate-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
if ($failed) { exit 1 }
