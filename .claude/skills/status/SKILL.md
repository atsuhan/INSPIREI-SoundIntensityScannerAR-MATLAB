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

## レビューと検証

通常の差分レビューと変更に応じた検証を行う。上位モデル、planner、senior-reviewer、専門Agent、厳密な証跡照合は難度・リスクに応じて任意に選ぶ。二重検収、特定モデル・high effort、実効read-onlyやnativeログ・画像閲覧証跡・成果物hashの機械照合、Test-ReviewGate成功は判断確定・完了・ready PR化・mergeの必須条件ではなく、その未成立だけで保留しない。秘密保護、破壊的操作の権限確認、既存変更の保全、製品固有契約、未検証をPASSにしない規則は維持する。
