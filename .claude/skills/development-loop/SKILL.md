---
name: development-loop
description: Milestoneから関連作業を選び、調査、計画、実装、検証、STATUS更新、PRマージまで自律的に進める。自走、ループ、残タスクを進める依頼で使用する。
---

# Development Loop

1. `git status`、`STATUS.md`、`docs/roadmap/MILESTONES.md` を確認する。
2. 依存関係と変更領域が近い項目を、説明・検証・ロールバック可能な作業バッチへまとめる。
3. 受入条件が曖昧ならplannerで確定する。最新性や外部仕様が関係すればresearcherを使う。
4. builderが実装し、利用可能な検証を行う。
5. reviewerが固有契約、diff、回帰、検証証拠を独立確認する。
6. 実装できる範囲は作り切る。別AI、実機、外部権限が必要な調整だけ、具体的な後続項目にする。
7. MilestoneとSTATUSを更新する。未検証を完了扱いしない。
8. 関連変更を意図的にstageし、commit、push、ready PR、merge、ローカル同期、今回のマージ済み作業ブランチのローカル・origin削除まで行う。
9. 次の着手可能な作業バッチがあり、ユーザーが継続を求めている場合は続ける。

同一エラーを繰り返すだけのループを避け、原因・試行・次の仮説を残す。
