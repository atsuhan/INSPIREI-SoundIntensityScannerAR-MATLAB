---
name: status
description: MilestoneとGitの証拠から、人間向けSTATUS.mdを生成・更新する。進捗、現在地、残タスク、次にやることを尋ねられたときに使用する。
---

# Status

1. `docs/roadmap/MILESTONES.md`、Git状態、最近のPRを確認する。
2. 実装済み、検証済み、未検証、ブロック中を区別する。
3. `tools/agent-harness/Update-Status.ps1` があれば実行する。
4. STATUSには現在の重点、作業中、次に着手可能、確認待ち、最近完了を短く表示する。
5. 根拠のない進捗率を使用しない。
6. STATUSは人間向け表示であり、作業状態の正本はMilestoneとGitとする。
