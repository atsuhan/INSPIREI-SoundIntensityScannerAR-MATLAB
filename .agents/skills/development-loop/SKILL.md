---
name: development-loop
description: Milestoneから関連作業を選び、調査、計画、実装、検証、STATUS更新、PRマージまで自律的に進める。自走、ループ、残タスクを進める依頼で使用する。
---

# Development Loop

人間宛のメール・メッセージ・公開コメント・通知は、送信前に宛先/公開範囲・全文・添付等を提示し、プレビュー後のユーザー本人の明示承認を各送信ごとに待つ。包括指示・過去承認・自動承認・reviewer承認で代替しない。変更や再送は再承認。draft PRも公開/通知であり対象。詳細は `docs/rules/common.md` の「人間への送信前確認」に従う。

公開・通知の承認がない間はローカル準備で止める。自走や保存用draft PRの規定は送信承認を免除しない。

1. `git status`、`STATUS.md`、`docs/roadmap/MILESTONES.md` を確認する。commitまで行う依頼では、実装前に `powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-GitWriteAccess.ps1` を実行する。
2. 依存関係と変更領域が近い項目を、説明・検証・ロールバック可能な作業バッチへまとめる。親は担当範囲、所有境界、依存関係、固有契約、受入条件、禁止事項を定め、チームを積極的に使う。独立タスクは並列に進め、Scene／Prefab等の競合する成果物は単独ownerに割り当てる。
3. 非自明・複数領域の仕事では設計と受入条件をplanner、調査をresearcher、領域固有の判断を専門Agentへ積極的に委譲する。最新性や外部仕様が関係すれば現在の事実を調査する。親は結果を固有契約と照合し、採否を根拠とリスクに応じて判断する。
4. 実装と利用可能な検証をbuilderへ積極的に委譲し、検証証拠を生のまま返してもらう。他者の変更を戻さないよう伝える。
5. 固有契約、diff、回帰、検証結果の確認をreviewerへ積極的に委譲する。親は指摘、修正、検証結果、未検証範囲を統合する。難所・高リスクでは上位モデルやsenior-reviewerへ任意に相談する。
6. 実装できる範囲は作り切る。別AI、実機、外部権限が必要な調整だけ、具体的な後続項目にする。
7. MilestoneとSTATUSを更新する。未検証を完了扱いしない。
8. 関連変更を意図的にstageし、commit、push、ready PR、merge、ローカル同期、今回のマージ済み作業ブランチのローカル・origin削除まで行う。
9. 次の着手可能な作業バッチがあり、ユーザーが継続を求めている場合は続ける。

同一エラーを繰り返すだけのループを避け、原因・試行・次の仮説を残す。
Git write preflightが失敗した場合は差分を増やさず、Codexのproject Permission Profile、OS read-only属性／ACL、`index.lock` の順に切り分ける。`index.lock` はactiveなGitプロセスがなくstaleと確認できた場合だけ除去する。

チーム運用はDEFAULTとし、メインチャットはSol／Opus級を想定する。親は分解・依存調整・統合・ユーザー説明に集中する。小さく単純な変更は親が処理してよく、重複調査や無益な人数増は避ける。モデルやAgent数の不足だけで作業やマージを保留せず、通常レビューと変更に応じた検証を行う。個人のモデル設定は変更しない。

## レビューと検証

通常の差分レビューと変更に応じた検証を行う。上位モデル、planner、senior-reviewer、専門Agent、厳密な証跡照合は難度・リスクに応じて任意に選ぶ。二重検収、特定モデル・high effort、実効read-onlyやnativeログ・画像閲覧証跡・成果物hashの機械照合、Test-ReviewGate成功は判断確定・完了・ready PR化・mergeの必須条件ではなく、その未成立だけで保留しない。秘密保護、破壊的操作の権限確認、既存変更の保全、製品固有契約、未検証をPASSにしない規則は維持する。
