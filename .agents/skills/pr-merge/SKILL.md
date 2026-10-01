---
name: pr-merge
description: 作業を意図的にcommitし、push、ready PR作成、マージ、ローカル同期、マージ済みブランチのローカル・remote削除まで完了する。公開、PR、マージ、仕上げの依頼で使用する。
---

# PR and Merge

1. `git status` とdiffを確認し、対象外のユーザー変更を含めない。続けて `powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-GitWriteAccess.ps1` を実行し、commit前ではなく作業バッチの入口でGit書込み可否を確定する。
2. 利用可能な検証を実行し、PASS、FAIL、未実行、未検証を記録する。
3. 関連作業を説明・検証・ロールバック可能なPRへまとめる。
4. ready PRを作成し、目的、変更、影響、検証、未検証、後続項目を書く。
5. 一人開発の既定としてPRをマージする。CI失敗は自動停止条件ではないが、状態を隠さない。
6. PRがMERGEDであることと、削除対象が今回の作業ブランチであることを確認する。
7. ローカルを既定ブランチへ戻し、`pull --ff-only` で最新化する。
8. マージ済み作業ブランチを `git branch -d <branch>` と `git push origin --delete <branch>` でローカル・originの両方から削除する。hosting側ですでにremote削除済みなら、その事実を確認する。
9. squash／rebase mergeのため `-d` が拒否した場合だけ、PRのMERGED状態と対象branchの一致を再確認してからローカルの `-D` を許可する。
10. `git fetch origin --prune` 後、`git branch --list <branch>` と `git branch -r --list origin/<branch>` がどちらも空であることを確認する。
11. 未マージ、保護対象、共有中、別作業、所有者不明のブランチは削除しない。
12. 秘密情報、復旧困難な変更、発注、課金、本番操作が含まれる場合は停止して確認する。

`index.lock: Permission denied` の場合、Codex標準の `workspace-write` が `.git` を保護している可能性を先に確認する。trusted projectのPermission Profileでもpreflightが失敗するときだけ、OS属性・ACL・stale lockを調べる。lockはactiveなGitプロセスがなくstaleと確認できた場合だけ除去する。

## 必須レビューゲート

作業入口と範囲変更時に `docs/rules/common.md` の重要判断を分類する。見積・購入構成・採用・設計・数値・視覚・法務財務・セキュリティ権限・発注本番・反復失敗は、上位plannerと別のsenior-reviewerによる独立検収が必須。親の自信や専門Agentの判断で省略しない。

ready化・merge前に `tools/agent-harness/Test-ReviewGate.ps1` で対象revision/hash・モデル実行根拠・独立性・受入範囲を検査する。未実施・不合格・モデル不明では完了チェック、判断確定、ready化、mergeを保留し、保存用commit/push/draft PRまでとする。通常CIの既知失敗を許容する既定は、このゲートを免除しない。詳細は `docs/rules/common.md` と `tools/agent-harness/review-gate.md` に従う。
