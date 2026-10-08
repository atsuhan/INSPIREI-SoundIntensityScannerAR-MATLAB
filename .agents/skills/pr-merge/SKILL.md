---
name: pr-merge
description: 作業を意図的にcommitし、push、ready PR作成、マージ、ローカル同期、マージ済みブランチのローカル・remote削除まで完了する。公開、PR、マージ、仕上げの依頼で使用する。
---

# PR and Merge

人間宛のメール・チャット・SMS・投稿・他者のPR/Issueへのコメント・招待・共有通知・外部repo/サービスへの連絡は、送信前に宛先/公開範囲・全文・添付等を提示し、プレビュー後のユーザー本人の明示承認を各送信ごとに待つ。包括指示・過去承認・自動承認・reviewer承認で代替しない。変更や再送は再承認。ユーザー自身のINSPIREI repoで依頼された作業のcommit・push・PR作成/本文更新・merge・同期・マージ済みブランチ削除は標準の完了範囲であり、送信ごとの承認を要求しない。詳細は `docs/rules/common.md` の「人間への送信前確認」に従う。

ユーザー自身のINSPIREI repoでは、依頼された作業のpush・PR・mergeを標準完了範囲として進める。他者へ届く通知（他者PRへのコメント、外部repo、メール・チャット等）は承認まで行わない。

1. `git status` とdiffを確認し、対象外のユーザー変更を含めない。続けて `powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-GitWriteAccess.ps1` を実行し、commit前ではなく作業バッチの入口でGit書込み可否を確定する。
2. 利用可能な検証を実行し、PASS、FAIL、未実行、未検証を記録する。
3. 関連作業を説明・検証・ロールバック可能なPRへまとめる。
4. ready PRを作成し、目的、変更、影響、検証、未検証、後続項目を書く。
5. 一人開発の既定としてPRをマージする。ユーザー自身のINSPIREI repoでは送信ごとの承認を待たず進める。CI失敗は自動停止条件ではないが、状態を隠さない。
6. PRがMERGEDであることと、削除対象が今回の作業ブランチであることを確認する。
7. ローカルを既定ブランチへ戻し、`pull --ff-only` で最新化する。
8. マージ済み作業ブランチを `git branch -d <branch>` と `git push origin --delete <branch>` でローカル・originの両方から削除する。hosting側ですでにremote削除済みなら、その事実を確認する。
9. squash／rebase mergeのため `-d` が拒否した場合だけ、PRのMERGED状態と対象branchの一致を再確認してからローカルの `-D` を許可する。
10. `git fetch origin --prune` 後、`git branch --list <branch>` と `git branch -r --list origin/<branch>` がどちらも空であることを確認する。
11. 未マージ、保護対象、共有中、別作業、所有者不明のブランチは削除しない。
12. 秘密情報、復旧困難な変更、発注、課金、本番操作が含まれる場合は停止して確認する。

`index.lock: Permission denied` の場合、Codex標準の `workspace-write` が `.git` を保護している可能性を先に確認する。trusted projectのPermission Profileでもpreflightが失敗するときだけ、OS属性・ACL・stale lockを調べる。lockはactiveなGitプロセスがなくstaleと確認できた場合だけ除去する。

## レビューと検証

通常の差分レビューと変更に応じた検証を行う。上位モデル、planner、senior-reviewer、専門Agent、厳密な証跡照合は難度・リスクに応じて任意に選ぶ。二重検収、特定モデル・high effort、実効read-onlyやnativeログ・画像閲覧証跡・成果物hashの機械照合、Test-ReviewGate成功は判断確定・完了・ready PR化・mergeの必須条件ではなく、その未成立だけで保留しない。秘密保護、破壊的操作の権限確認、既存変更の保全、製品固有契約、未検証をPASSにしない規則は維持する。
