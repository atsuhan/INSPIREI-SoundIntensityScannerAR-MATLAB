---
name: pr-merge
description: 作業を意図的にcommitし、push、ready PR作成、マージ、ローカル同期、マージ済みブランチのローカル・remote削除まで完了する。公開、PR、マージ、仕上げの依頼で使用する。
---

# PR and Merge

1. `git status` とdiffを確認し、対象外のユーザー変更を含めない。
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
