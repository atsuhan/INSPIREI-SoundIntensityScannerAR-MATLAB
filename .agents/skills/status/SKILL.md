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

## 必須レビューゲート

作業入口と範囲変更時に `docs/rules/common.md` の重要判断を分類する。見積・購入構成・採用・設計・数値・視覚・法務財務・セキュリティ権限・発注本番・反復失敗は、上位plannerと別のsenior-reviewerによる独立検収が必須。親の自信や専門Agentの判断で省略しない。

ready化・merge前に `tools/agent-harness/Test-ReviewGate.ps1` で対象revision/hash・モデル実行根拠・独立性・受入範囲を検査する。未実施・不合格・モデル不明では完了チェック、判断確定、ready化、mergeを保留し、保存用commit/push/draft PRまでとする。通常CIの既知失敗を許容する既定は、このゲートを免除しない。詳細は `docs/rules/common.md` と `tools/agent-harness/review-gate.md` に従う。
