---
name: development-loop
description: Milestoneから関連作業を選び、調査、計画、実装、検証、STATUS更新、PRマージまで自律的に進める。自走、ループ、残タスクを進める依頼で使用する。
---

# Development Loop

1. `git status`、`STATUS.md`、`docs/roadmap/MILESTONES.md` を確認する。commitまで行う依頼では、実装前に `powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-GitWriteAccess.ps1` を実行する。
2. 依存関係と変更領域が近い項目を、説明・検証・ロールバック可能な作業バッチへまとめる。
3. 受入条件が曖昧ならplannerで確定する。最新性や外部仕様が関係すればresearcherで事実を集め、重要な採否は上位plannerが確定する。
4. builderが実装し、利用可能な検証を行い、検証証拠を生のまま返す。
5. reviewerが固有契約、diff、回帰、検証証拠を独立確認し、PASSを判定する。3D・視覚、数値・信号処理、発注・本番ゲートはsenior-reviewerで独立確認する。
6. 実装できる範囲は作り切る。別AI、実機、外部権限が必要な調整だけ、具体的な後続項目にする。
7. MilestoneとSTATUSを更新する。未検証を完了扱いしない。
8. 関連変更を意図的にstageし、commit、push、ready PR、merge、ローカル同期、今回のマージ済み作業ブランチのローカル・origin削除まで行う。
9. 次の着手可能な作業バッチがあり、ユーザーが継続を求めている場合は続ける。

同一エラーを繰り返すだけのループを避け、原因・試行・次の仮説を残す。
Git write preflightが失敗した場合は差分を増やさず、Codexのproject Permission Profile、OS read-only属性／ACL、`index.lock` の順に切り分ける。`index.lock` はactiveなGitプロセスがなくstaleと確認できた場合だけ除去する。

## 必須レビューゲート

作業入口と範囲変更時に `docs/rules/common.md` の重要判断を分類する。見積・購入構成・採用・設計・数値・視覚・法務財務・セキュリティ権限・発注本番・反復失敗は、上位plannerと別のsenior-reviewerによる独立検収が必須。親の自信や専門Agentの判断で省略しない。

ready化・merge前に `tools/agent-harness/Test-ReviewGate.ps1` で対象revision/hash・モデル実行根拠・独立性・受入範囲を検査する。未実施・不合格・モデル不明では完了チェック、判断確定、ready化、mergeを保留し、保存用commit/push/draft PRまでとする。通常CIの既知失敗を許容する既定は、このゲートを免除しない。詳細は `docs/rules/common.md` と `tools/agent-harness/review-gate.md` に従う。
