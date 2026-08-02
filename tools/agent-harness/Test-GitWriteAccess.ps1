[CmdletBinding()]
param(
    [string]$Repository = (Get-Location).Path,
    [switch]$RepairReadOnly,
    [ValidateSet('Table', 'Json')]
    [string]$Format = 'Table'
)

$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath $Repository).Path
$gitDirectory = (& git -C $repositoryPath rev-parse --absolute-git-dir 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $gitDirectory) {
    throw "Not a Git repository: $repositoryPath"
}
$gitDirectory = $gitDirectory.Trim()

$gitItem = Get-Item -LiteralPath $gitDirectory -Force
$indexPath = Join-Path $gitDirectory 'index'
$lockPath = Join-Path $gitDirectory 'index.lock'

if ($RepairReadOnly) {
    if ($gitItem.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
        $gitItem.Attributes = $gitItem.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
        $gitItem = Get-Item -LiteralPath $gitDirectory -Force
    }
    if (Test-Path -LiteralPath $indexPath) {
        $indexItem = Get-Item -LiteralPath $indexPath -Force
        if ($indexItem.IsReadOnly) {
            $indexItem.IsReadOnly = $false
        }
    }
}

$directoryReadOnly = [bool]($gitItem.Attributes -band [System.IO.FileAttributes]::ReadOnly)
$indexReadOnly = if (Test-Path -LiteralPath $indexPath) {
    [bool](Get-Item -LiteralPath $indexPath -Force).IsReadOnly
} else {
    $false
}
$lockExists = Test-Path -LiteralPath $lockPath
$lockAgeMinutes = if ($lockExists) {
    [math]::Round(((Get-Date) - (Get-Item -LiteralPath $lockPath -Force).LastWriteTime).TotalMinutes, 1)
} else {
    $null
}

$probePath = Join-Path $gitDirectory ('.codex-write-probe-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
$writeProbe = 'PASS'
$detail = ''
try {
    $stream = [System.IO.FileStream]::new(
        $probePath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $stream.WriteByte(0)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
} catch {
    $writeProbe = 'FAIL'
    $detail = $_.Exception.Message
} finally {
    if (Test-Path -LiteralPath $probePath) {
        [System.IO.File]::Delete($probePath)
    }
}

$state = if ($lockExists) {
    'BLOCKED_INDEX_LOCK'
} elseif ($indexReadOnly) {
    'BLOCKED_READ_ONLY_ATTRIBUTE'
} elseif ($writeProbe -ne 'PASS') {
    'BLOCKED_SANDBOX_OR_ACL'
} else {
    'READY'
}

$result = [pscustomobject]@{
    Repository = $repositoryPath
    GitDirectory = $gitDirectory
    State = $state
    WriteProbe = $writeProbe
    DirectoryReadOnly = $directoryReadOnly
    IndexReadOnly = $indexReadOnly
    IndexLock = $lockExists
    IndexLockAgeMinutes = $lockAgeMinutes
    Detail = $detail
}

if ($Format -eq 'Json') {
    $result | ConvertTo-Json -Depth 3
} else {
    $result | Format-List
}

if ($state -ne 'READY') {
    Write-Error 'Git metadata is not writable. In Codex workspace-write, .git is protected by design. Use the trusted project permission profile or Full access; if the probe still fails, repair the OS read-only attribute or ACL. Never remove index.lock until no Git process is active and the lock is confirmed stale.'
    exit 1
}
