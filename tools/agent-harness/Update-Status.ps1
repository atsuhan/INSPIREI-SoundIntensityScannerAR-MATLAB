[CmdletBinding()]
param(
    [string]$Repository = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath $Repository).Path
$milestonePath = Join-Path $repositoryPath 'docs\roadmap\MILESTONES.md'
$statusPath = Join-Path $repositoryPath 'STATUS.md'
$projectName = Split-Path $repositoryPath -Leaf

if (-not (Test-Path -LiteralPath $milestonePath)) {
    throw "Milestone file not found: $milestonePath"
}

$lines = @(Get-Content -LiteralPath $milestonePath -Encoding UTF8)
$tasks = @()
$sections = @()
$currentSection = $null

foreach ($line in $lines) {
    if ($line -match '^##\s+(.+)$') {
        $title = $Matches[1].Trim()
        if ($title -notmatch '^(Backlog|運用ルール|書式規約|アーカイブ)') {
            $currentSection = [PSCustomObject]@{
                Title = $title
                Complete = 0
                Remaining = 0
            }
            $sections += $currentSection
        } else {
            $currentSection = $null
        }
        continue
    }

    if ($line -match '^\s*-\s+\[(?<done>[ xX])\]\s+(?<text>.+)$') {
        $doneMark = $Matches['done']
        $text = $Matches['text'].Trim()
        $isDone = $doneMark -match '[xX]'
        $tasks += [PSCustomObject]@{
            Done = $isDone
            Text = $text
            Section = if ($currentSection) { $currentSection.Title } else { 'Backlog' }
        }
        if ($currentSection) {
            if ($isDone) { $currentSection.Complete++ } else { $currentSection.Remaining++ }
        }
    }
}

$complete = @($tasks | Where-Object Done)
$remaining = @($tasks | Where-Object { -not $_.Done })
$activeSections = @($sections | Where-Object { $_.Remaining -gt 0 -or $_.Complete -gt 0 })
$now = Get-Date -Format 'yyyy-MM-dd HH:mm zzz'

$output = [System.Collections.Generic.List[string]]::new()
$output.Add("# $projectName Status")
$output.Add('')
$output.Add('<!-- generated-by: tools/agent-harness/Update-Status.ps1 -->')
$output.Add('')
$output.Add("最終更新: $now")
$output.Add('')
$output.Add('## 現在の状況')
$output.Add('')
$output.Add("- 完了チェック: $($complete.Count)")
$output.Add("- 未完了チェック: $($remaining.Count)")
$output.Add("- 記載マイルストーン: $($activeSections.Count)")
$output.Add('')
$output.Add('## マイルストーン')
$output.Add('')
if ($activeSections.Count -eq 0) {
    $output.Add('Milestoneのチェック項目はまだ登録されていません。')
} else {
    $output.Add('| マイルストーン | 状態 | 完了 | 残り |')
    $output.Add('|---|---|---:|---:|')
    foreach ($section in $activeSections | Select-Object -First 12) {
        $state = if ($section.Remaining -eq 0 -and $section.Complete -gt 0) { '完了' } elseif ($section.Complete -gt 0) { '作業中' } else { '未着手' }
        $safeTitle = $section.Title -replace '\|', '\|'
        $output.Add("| $safeTitle | $state | $($section.Complete) | $($section.Remaining) |")
    }
}
$output.Add('')
$output.Add('## 次に着手可能')
$output.Add('')
if ($remaining.Count -eq 0) {
    $output.Add('- 現在のMilestoneに未完了チェックはありません。')
} else {
    foreach ($task in $remaining | Select-Object -First 10) {
        $output.Add("- $($task.Text) — $($task.Section)")
    }
}
$output.Add('')
$output.Add('## 最近完了')
$output.Add('')
if ($complete.Count -eq 0) {
    $output.Add('- 完了チェックはまだありません。')
} else {
    foreach ($task in $complete | Select-Object -Last 8) {
        $output.Add("- $($task.Text) — $($task.Section)")
    }
}
$output.Add('')
$output.Add('## 読み方')
$output.Add('')
$output.Add('- このファイルは人間向けの自動生成サマリーです。')
$output.Add('- 作業状態の正本は `docs/roadmap/MILESTONES.md`、Git、PR、検証結果です。')
$output.Add('- 実装済みと検証済みを区別する必要がある場合は、Milestone本文の証拠と注記を確認します。')

$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines($statusPath, $output, $utf8)
Write-Output "Updated $statusPath"
