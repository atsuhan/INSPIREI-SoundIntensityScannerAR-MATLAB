[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$gate = Join-Path $PSScriptRoot 'Test-ReviewGate.ps1'
# Use the current engine on Windows PowerShell and cross-platform PowerShell.
$powerShellExecutable = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
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
    # Expected corrupt-image fixtures may emit native decoder warnings on stderr.
    # Evaluate the checker exit code rather than aborting this test runner on stderr.
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $gate -RecordPath $recordPath -Repository $sandbox -RequiredAcceptance A-1 -ScopeFiles product.txt -Classification $RequestedClass -Json @ExtraArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
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
        # The former positive PNG had an invalid IDAT CRC; this 1x1 fixture has valid chunks.
        $png='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pFzSMdNv5pqZfdJoaa0MkU2VNcoN4J/SNoWT4gtFZ0FgQXXBq1mpsw4V6haKC9uKnIsWFz0qDi/eMRufzZ3dUmJdsqCkcw5rzta5yNwZc1vm2c4rm9c1P2L+rgWaC3IX/FjKKF1Z+sfCtIXNZRZl88sefhHxxZ5yWrm0/OYi/0VbvsS/FH55cfHYxesXv6vgVfxQyaisqny7hLvkh688vlr31fulWUsvLvNetnk5cbl4+Y0VQSt2rdRdWbzy4aqJqxpW01dXrP5jzfQ156vGVW1Zq7lWsbZjXcy6xvV265evf7tBsKG9ekL1vo3mGxdvfLmJt+nq5uDN9VsstlRuefO18OtbWyO2NtQ41FRtI24r2PbL9tTtrTuYO+pqzWora//cKd7ZsStx15k6n7q63ea7l+1B9yj29OydsvfyN6HfNNa71W/dZ7Svcj/Yr9j/+EDmgRsHow+2HGIeqv/W/tuNh/UPVzQgDUUNfUcERzoa0xuvNEU1tTT7Nx/+zv27nUetj1YfMzy27Ljm8bLj708Un+g/KTnZeyr71MOW6S13T086ff1MwpmLZ6PPnvs+/PvTrazWE+cCzh0973e+6QfmD0cueF9oaPNqO/yj14+HL3pfbLjkc6nxsu/l5ivjrxy/GnT11LXQa99fZ1+/0B7bfuVGyo1bN6fc7LjFu9V9W3T72Z2COwN358OLfcV9nftVD8wf1Pxr9L/2dXh3HOsM7Wz7Kemnuw+5D5/8LPv5bVfZL9Rfqh5ZParr9uw+2hPec/nx5MddTyRPBnrLf9X9deNTp6ff/hb8W1vfpL6uZ9Jn739f8tz0+c4/xv3R0h/f/+BF3ouBlxWvTF/tes183fom7c2jgVlvSW/X/Tn6z+Z30e/uvc97//7fCQ/4Yk7kYoUAAAA4ZVhJZk1NACoAAAAIAAGHaQAEAAAAAQAAABoAAAAAAAKgAgAEAAAAAQAAAAGgAwAEAAAAAQAAAAEAAAAA2uq/xAAAAZlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDYuMC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MjwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4yPC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CuW954sAAAALSURBVAgdY2BgAAAAAwABT0gKrwAAAABJRU5ErkJggg=='
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
    # These synthetic logs exercise parser rejection; they are not formal reviews.
    function VisualEvents($r) { @(Get-Content -LiteralPath $r.reviewer.runtime.path | ForEach-Object { $_ | ConvertFrom-Json }) }
    function SetVisualEvents($r, $events) {
        $path = $r.reviewer.runtime.path
        [IO.File]::WriteAllLines($path, @($events | ForEach-Object { $_ | ConvertTo-Json -Depth 30 -Compress }))
        $r.reviewer.runtime=Ref $path; $r.review.evidence=Ref $path; $r.visual.viewingEvidence=Ref $path
    }
    $formatImages = @{
        PNG='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pFzSMdNv5pqZfdJoaa0MkU2VNcoN4J/SNoWT4gtFZ0FgQXXBq1mpsw4V6haKC9uKnIsWFz0qDi/eMRufzZ3dUmJdsqCkcw5rzta5yNwZc1vm2c4rm9c1P2L+rgWaC3IX/FjKKF1Z+sfCtIXNZRZl88sefhHxxZ5yWrm0/OYi/0VbvsS/FH55cfHYxesXv6vgVfxQyaisqny7hLvkh688vlr31fulWUsvLvNetnk5cbl4+Y0VQSt2rdRdWbzy4aqJqxpW01dXrP5jzfQ156vGVW1Zq7lWsbZjXcy6xvV265evf7tBsKG9ekL1vo3mGxdvfLmJt+nq5uDN9VsstlRuefO18OtbWyO2NtQ41FRtI24r2PbL9tTtrTuYO+pqzWora//cKd7ZsStx15k6n7q63ea7l+1B9yj29OydsvfyN6HfNNa71W/dZ7Svcj/Yr9j/+EDmgRsHow+2HGIeqv/W/tuNh/UPVzQgDUUNfUcERzoa0xuvNEU1tTT7Nx/+zv27nUetj1YfMzy27Ljm8bLj708Un+g/KTnZeyr71MOW6S13T086ff1MwpmLZ6PPnvs+/PvTrazWE+cCzh0973e+6QfmD0cueF9oaPNqO/yj14+HL3pfbLjkc6nxsu/l5ivjrxy/GnT11LXQa99fZ1+/0B7bfuVGyo1bN6fc7LjFu9V9W3T72Z2COwN358OLfcV9nftVD8wf1Pxr9L/2dXh3HOsM7Wz7Kemnuw+5D5/8LPv5bVfZL9Rfqh5ZParr9uw+2hPec/nx5MddTyRPBnrLf9X9deNTp6ff/hb8W1vfpL6uZ9Jn739f8tz0+c4/xv3R0h/f/+BF3ouBlxWvTF/tes183fom7c2jgVlvSW/X/Tn6z+Z30e/uvc97//7fCQ/4Yk7kYoUAAAA4ZVhJZk1NACoAAAAIAAGHaQAEAAAAAQAAABoAAAAAAAKgAgAEAAAAAQAAAAGgAwAEAAAAAQAAAAEAAAAA2uq/xAAAAZlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDYuMC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MjwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4yPC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CuW954sAAAALSURBVAgdY2BgAAAAAwABT0gKrwAAAABJRU5ErkJggg=='
        JPEG='/9j/4AAQSkZJRgABAQAASABIAAD/4QBARXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAAqADAAQAAAABAAAAAgAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/+IRrElDQ19QUk9GSUxFAAEBAAARnGFwcGwCAAAAbW50ckdSQVlYWVogB9wACAAXAA8ALgAPYWNzcEFQUEwAAAAAbm9uZQAAAAAAAAAAAAAAAAAAAAAAAPbWAAEAAAAA0y1hcHBsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFZGVzYwAAAMAAAAB5ZHNjbQAAATwAAAgaY3BydAAACVgAAAAjd3RwdAAACXwAAAAUa1RSQwAACZAAAAgMZGVzYwAAAAAAAAAfR2VuZXJpYyBHcmF5IEdhbW1hIDIuMiBQcm9maWxlAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAG1sdWMAAAAAAAAAHwAAAAxza1NLAAAALgAAAYRkYURLAAAAOgAAAbJjYUVTAAAAOAAAAex2aVZOAAAAQAAAAiRwdEJSAAAASgAAAmR1a1VBAAAALAAAAq5mckZVAAAAPgAAAtpodUhVAAAANAAAAxh6aFRXAAAAGgAAA0xrb0tSAAAAIgAAA2ZuYk5PAAAAOgAAA4hjc0NaAAAAKAAAA8JoZUlMAAAAJAAAA+pyb1JPAAAAKgAABA5kZURFAAAATgAABDhpdElUAAAATgAABIZzdlNFAAAAOAAABNR6aENOAAAAGgAABQxqYUpQAAAAJgAABSZlbEdSAAAAKgAABUxwdFBPAAAAUgAABXZubE5MAAAAQAAABchlc0VTAAAATAAABgh0aFRIAAAAMgAABlR0clRSAAAAJAAABoZmaUZJAAAARgAABqpockhSAAAAPgAABvBwbFBMAAAASgAABy5hckVHAAAALAAAB3hydVJVAAAAOgAAB6RlblVTAAAAPAAAB94AVgFhAGUAbwBiAGUAYwBuAOEAIABzAGkAdgDhACAAZwBhAG0AYQAgADIALAAyAEcAZQBuAGUAcgBpAHMAawAgAGcAcgDlACAAMgAsADIAIABnAGEAbQBtAGEALQBwAHIAbwBmAGkAbABHAGEAbQBtAGEAIABkAGUAIABnAHIAaQBzAG8AcwAgAGcAZQBuAOgAcgBpAGMAYQAgADIALgAyAEMepQB1ACAAaADsAG4AaAAgAE0A4AB1ACAAeADhAG0AIABDAGgAdQBuAGcAIABHAGEAbQBtAGEAIAAyAC4AMgBQAGUAcgBmAGkAbAAgAEcAZQBuAOkAcgBpAGMAbwAgAGQAYQAgAEcAYQBtAGEAIABkAGUAIABDAGkAbgB6AGEAcwAgADIALAAyBBcEMAQzBDAEOwRMBD0EMAAgAEcAcgBhAHkALQQzBDAEPAQwACAAMgAuADIAUAByAG8AZgBpAGwAIABnAOkAbgDpAHIAaQBxAHUAZQAgAGcAcgBpAHMAIABnAGEAbQBtAGEAIAAyACwAMgDBAGwAdABhAGwA4QBuAG8AcwAgAHMAegD8AHIAawBlACAAZwBhAG0AbQBhACAAMgAuADKQGnUocHCWjlFJXqYAMgAuADKCcl9pY8+P8Md8vBgAINaMwMkAIKwQucgAIAAyAC4AMgAg1QS4XNMMx3wARwBlAG4AZQByAGkAcwBrACAAZwByAOUAIABnAGEAbQBtAGEAIAAyACwAMgAtAHAAcgBvAGYAaQBsAE8AYgBlAGMAbgDhACABYQBlAGQA4QAgAGcAYQBtAGEAIAAyAC4AMgXSBdAF3gXUACAF0AXkBdUF6AAgBdsF3AXcBdkAIAAyAC4AMgBHAGEAbQBhACAAZwByAGkAIABnAGUAbgBlAHIAaQBjAQMAIAAyACwAMgBBAGwAbABnAGUAbQBlAGkAbgBlAHMAIABHAHIAYQB1AHMAdAB1AGYAZQBuAC0AUAByAG8AZgBpAGwAIABHAGEAbQBtAGEAIAAyACwAMgBQAHIAbwBmAGkAbABvACAAZwByAGkAZwBpAG8AIABnAGUAbgBlAHIAaQBjAG8AIABkAGUAbABsAGEAIABnAGEAbQBtAGEAIAAyACwAMgBHAGUAbgBlAHIAaQBzAGsAIABnAHIA5QAgADIALAAyACAAZwBhAG0AbQBhAHAAcgBvAGYAaQBsZm6QGnBwXqZ8+2VwADIALgAyY8+P8GWHTvZOAIIsMLAw7DCkMKww8zDeACAAMgAuADIAIDDXMO0w1TChMKQw6wOTA7UDvQO5A7oDzAAgA5MDugPBA7kAIAOTA6wDvAO8A7EAIAAyAC4AMgBQAGUAcgBmAGkAbAAgAGcAZQBuAOkAcgBpAGMAbwAgAGQAZQAgAGMAaQBuAHoAZQBuAHQAbwBzACAAZABhACAARwBhAG0AbQBhACAAMgAsADIAQQBsAGcAZQBtAGUAZQBuACAAZwByAGkAagBzACAAZwBhAG0AbQBhACAAMgAsADIALQBwAHIAbwBmAGkAZQBsAFAAZQByAGYAaQBsACAAZwBlAG4A6QByAGkAYwBvACAAZABlACAAZwBhAG0AbQBhACAAZABlACAAZwByAGkAcwBlAHMAIAAyACwAMg4jDjEOBw4qDjUOQQ4BDiEOIQ4yDkAOAQ4jDiIOTA4XDjEOSA4nDkQOGwAgADIALgAyAEcAZQBuAGUAbAAgAEcAcgBpACAARwBhAG0AYQAgADIALAAyAFkAbABlAGkAbgBlAG4AIABoAGEAcgBtAGEAYQBuACAAZwBhAG0AbQBhACAAMgAsADIAIAAtAHAAcgBvAGYAaQBpAGwAaQBHAGUAbgBlAHIAaQENAGsAaQAgAEcAcgBhAHkAIABHAGEAbQBtAGEAIAAyAC4AMgAgAHAAcgBvAGYAaQBsAFUAbgBpAHcAZQByAHMAYQBsAG4AeQAgAHAAcgBvAGYAaQBsACAAcwB6AGEAcgBvAVsAYwBpACAAZwBhAG0AbQBhACAAMgAsADIGOgYnBkUGJwAgADIALgAyACAGRAZIBkYAIAYxBkUGJwYvBkoAIAY5BicGRQQeBDEESQQwBE8AIARBBDUEQAQwBE8AIAQzBDAEPAQ8BDAAIAAyACwAMgAtBD8EQAQ+BEQEOAQ7BEwARwBlAG4AZQByAGkAYwAgAEcAcgBhAHkAIABHAGEAbQBtAGEAIAAyAC4AMgAgAFAAcgBvAGYAaQBsAGUAAHRleHQAAAAAQ29weXJpZ2h0IEFwcGxlIEluYy4sIDIwMTIAAFhZWiAAAAAAAADzUQABAAAAARbMY3VydgAAAAAAAAQAAAAABQAKAA8AFAAZAB4AIwAoAC0AMgA3ADsAQABFAEoATwBUAFkAXgBjAGgAbQByAHcAfACBAIYAiwCQAJUAmgCfAKQAqQCuALIAtwC8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'
        GIF='R0lGODdhAQABAIAAAAAAAAAAACH5BAkAAAAALAAAAAABAAEAAAICRAEAOw=='
    }
    foreach ($format in @('PNG','JPEG','GIF')) {
        Case "legacy valid $format file and tool image decode" $true { param($r)
            & $visualFixture $r
            $bytes = [Convert]::FromBase64String($formatImages[$format])
            [IO.File]::WriteAllBytes($r.visual.image.path, $bytes); $r.visual.image=Ref $r.visual.image.path
            $events=VisualEvents $r
            $events[3].payload.output[0].image_url='data:image/'+$format.ToLowerInvariant()+';base64,'+$formatImages[$format]
            SetVisualEvents $r $events
        } 'visual'
        foreach ($location in @('file','result')) {
            Case "$format signature-valid corrupt $location rejected" $false { param($r)
                & $visualFixture $r
                $source=[Convert]::FromBase64String($formatImages[$format])
                $corrupt=New-Object byte[] 32
                [Array]::Copy($source, $corrupt, 12)
                if ($location -eq 'file') {
                    [IO.File]::WriteAllBytes($r.visual.image.path,$corrupt); $r.visual.image=Ref $r.visual.image.path
                } else {
                    $events=VisualEvents $r
                    $events[3].payload.output[0].image_url='data:image/png;base64,'+[Convert]::ToBase64String($corrupt)
                    SetVisualEvents $r $events
                }
            } 'visual'
        }
    }
    $customFixture = { param($r)
        & $visualFixture $r
        $events=VisualEvents $r
        $pathLiteral=ConvertTo-Json -InputObject $r.visual.image.path -Compress
        $events[2].payload=@{type='custom_tool_call';call_id='custom-view-1';name='exec';input=('const result = await tools.view_image({path:'+$pathLiteral+',detail:"original"}); image(result.image_url);')}
        $events[3].payload.type='custom_tool_call_output'; $events[3].payload.call_id='custom-view-1'
        SetVisualEvents $r $events
    }
    Case 'custom exact single original image template accepted' $true $customFixture 'visual'
    Case 'custom native image array with completion text accepted' $true { param($r)
        & $customFixture $r; $events=VisualEvents $r
        $events[3].payload.output=@(@{type='input_text';text="Script completed`nWall time 0.0 seconds`nOutput:"}) + @($events[3].payload.output)
        SetVisualEvents $r $events
    } 'visual'
    Case 'custom whitespace-only template variation accepted' $true { param($r)
        & $customFixture $r; $events=VisualEvents $r
        $events[2].payload.input="`n const  result = await tools.view_image( { path : "+(ConvertTo-Json -InputObject $r.visual.image.path -Compress)+" , detail : `"original`" } ) ;`n image( result.image_url ) ; `n"
        SetVisualEvents $r $events
    } 'visual'
    foreach ($variant in @('comment','conditional','batch','extra','path-expression','extra-argument','wrong-detail','wrong-name','wrong-path','no-id','duplicate-call','duplicate-result','wrong-id','no-result','wrong-output-type','error','script-error','late','bad-base64','corrupt-image','wrong-valid-image','multiple-images','result-before-call','whitespace-id','cross-format-call','result-after-marker-duplicate')) {
        Case "custom $variant rejected" $false { param($r)
            & $customFixture $r; $events=VisualEvents $r
            switch ($variant) {
                'comment' { $events[2].payload.input='/* comment */ '+$events[2].payload.input }
                'conditional' { $events[2].payload.input='if (true) { '+$events[2].payload.input+' }' }
                'batch' { $events[2].payload.input='const results = await Promise.all([tools.view_image({path:"'+$r.visual.image.path+'"})]); image(results[0].image_url);' }
                'extra' { $events[2].payload.input+=' text("extra");' }
                'path-expression' { $events[2].payload.input=$events[2].payload.input.Replace('path:','path:"" + ') }
                'extra-argument' { $events[2].payload.input=$events[2].payload.input.Replace('detail:"original"','detail:"original",unused:true') }
                'wrong-detail' { $events[2].payload.input=$events[2].payload.input.Replace('"original"','"high"') }
                'wrong-name' { $events[2].payload.name='exec_command' }
                'wrong-path' { $events[2].payload.input=$events[2].payload.input.Replace('image.png','another.png') }
                'no-id' { $events[2].payload.call_id='' }
                'duplicate-call' { $events=@($events[0],$events[1],$events[2],$events[2],$events[3],$events[4]) }
                'duplicate-result' { $events=@($events[0],$events[1],$events[2],$events[3],$events[3],$events[4]) }
                'wrong-id' { $events[3].payload.call_id='wrong-id' }
                'no-result' { $events=@($events[0],$events[1],$events[2],$events[4]) }
                'wrong-output-type' { $events[3].payload.type='function_call_output' }
                'error' { $events[3].payload.output=@{isError=$true;content=$events[3].payload.output} }
                'script-error' { $events[3].payload.output=@(@{type='input_text';text='Script failed: error'}) + @($events[3].payload.output) }
                'late' { $events=@($events[0],$events[1],$events[2],$events[4],$events[3]) }
                'bad-base64' { $events[3].payload.output[0].image_url='data:image/png;base64,not-base64!' }
                'corrupt-image' { $events[3].payload.output[0].image_url='data:image/png;base64,'+[Convert]::ToBase64String([byte[]]@(137,80,78,71,13,10,26,10,0,0,0,0,0,0,0,0)) }
                'wrong-valid-image' { $events[3].payload.output[0].image_url='data:image/png;base64,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' }
                'multiple-images' { $events[3].payload.output=@($events[3].payload.output[0],$events[3].payload.output[0]) }
                'result-before-call' { $events=@($events[0],$events[1],$events[3],$events[2],$events[4]) }
                'whitespace-id' { $events[2].payload.call_id=' '; $events[3].payload.call_id=' ' }
                'cross-format-call' {
                    $duplicate=@{type='response_item';payload=@{type='function_call';name='unrelated';call_id='custom-view-1';arguments='{}'}}
                    $events=@($events[0],$events[1],$events[2],$duplicate,$events[3],$events[4])
                }
                'result-after-marker-duplicate' { $events=@($events[0],$events[1],$events[2],$events[3],$events[4],$events[3]) }

            }
            SetVisualEvents $r $events
        } 'visual'
    }
    foreach ($actualResult in @('late','error')) {
        Case "custom case-binding mismatched success plus exact $actualResult rejected" $false { param($r)
            & $customFixture $r; $events=VisualEvents $r
            $events[2].payload.call_id='view-A'
            $events[3].payload.call_id='view-a'
            $exact=$events[3] | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
            $exact.payload.call_id='view-A'
            if ($actualResult -eq 'error') {
                $exact.payload.output=@{isError=$true;content=$exact.payload.output}
                $events=@($events[0],$events[1],$events[2],$events[3],$exact,$events[4])
            } else { $events=@($events[0],$events[1],$events[2],$events[3],$events[4],$exact) }
            SetVisualEvents $r $events
        } 'visual'
    }
    foreach ($route in @('custom','legacy')) {
        Case "$route case-binding case-distinct IDs remain independent" $true { param($r)
            if ($route -eq 'custom') { & $customFixture $r } else { & $visualFixture $r }
            $events=VisualEvents $r
            $events[2].payload.call_id='view-A'; $events[3].payload.call_id='view-A'
            $secondCall=$events[2] | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
            $secondResult=$events[3] | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
            $secondCall.payload.call_id='view-a'; $secondResult.payload.call_id='view-a'
            $events[3].payload.output=@{isError=$true;content=$events[3].payload.output}
            SetVisualEvents $r @($events[0],$events[1],$events[2],$events[3],$secondCall,$secondResult,$events[4])
        } 'visual'
    }
    Case 'legacy case-binding uppercase variation wrong ID rejected' $false { param($r)
        & $visualFixture $r; $events=VisualEvents $r
        $events[2].payload.call_id='view-A'; $events[3].payload.call_id='view-a'
        SetVisualEvents $r $events
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
    $claudeVisualFixture = { param($r)
        & $visualFixture $r; $image=Ref $r.visual.image.path
        & $claudeFixture $r
        $path=$r.reviewer.runtime.transcript.path
        $decision=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $call=@{type='assistant';sessionId=$r.reviewer.id;effort='high';message=@{model='claude-fable-5-1';content=@(@{type='tool_use';id='view-A';name='Read';input=@{file_path=$image.path}})}}
        $result=@{type='user';message=@{content=@(@{type='tool_result';tool_use_id='view-A';content=@(@{type='image';source=@{type='base64';data=[Convert]::ToBase64String([IO.File]::ReadAllBytes($image.path))}})})}}
        [IO.File]::WriteAllLines($path,@($call,$result,$decision | ForEach-Object { $_ | ConvertTo-Json -Depth 30 -Compress }))
        $r.reviewer.runtime.transcript=Ref $path; $r.review.evidence=Ref $path
        $r.visual=@{viewedBy=$r.reviewer.id;image=$image;viewingEvidence=(Ref $path)}
    }
    function SetClaudeVisualEvents($r,$events) {
        $path=$r.reviewer.runtime.transcript.path
        [IO.File]::WriteAllLines($path,@($events | ForEach-Object { $_ | ConvertTo-Json -Depth 30 -Compress }))
        $r.reviewer.runtime.transcript=Ref $path; $r.review.evidence=Ref $path; $r.visual.viewingEvidence=Ref $path
    }
    Case 'Claude case-binding uppercase variation wrong ID rejected' $false { param($r)
        & $claudeVisualFixture $r
        $events=@(Get-Content -LiteralPath $r.reviewer.runtime.transcript.path | ForEach-Object { $_ | ConvertFrom-Json })
        $events[1].message.content[0].tool_use_id='view-a'
        SetClaudeVisualEvents $r $events
    } 'visual'
    Case 'Claude case-binding case-distinct IDs remain independent' $true { param($r)
        & $claudeVisualFixture $r
        $events=@(Get-Content -LiteralPath $r.reviewer.runtime.transcript.path | ForEach-Object { $_ | ConvertFrom-Json })
        $secondCall=$events[0] | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
        $secondResult=$events[1] | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json
        $secondCall.message.content[0].id='view-a'; $secondResult.message.content[0].tool_use_id='view-a'
        $events[1].message.content[0] | Add-Member -NotePropertyName is_error -NotePropertyValue $true
        SetClaudeVisualEvents $r @($events[0],$events[1],$secondCall,$secondResult,$events[2])
    } 'visual'
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
