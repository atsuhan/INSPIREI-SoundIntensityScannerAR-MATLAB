<!-- BEGIN INSPIREI AGENT HARNESS -->
@docs/rules/common.md
@docs/rules/project.md

# Claude Code

- 作業の入口と優先順位は `AGENTS.md` に従う。
- 必要な文書だけ `docs/index.md` から選ぶ。
- 共通ワークフローは `.claude/skills/`、専門Agentは `.claude/agents/` を使用する。
- 書き込みAgentへ委譲するときは、対象範囲、固有契約、受入条件、禁止事項を明示する。
- ExploreまたはPlan Agentの結果は、親Agentが固有契約と照合してから採用する。

チームを積極的に使うことをDEFAULTとする。親は仕事の分解、所有境界、依存調整、統合、ユーザー説明を担う。非自明・複数領域の仕事は調査・設計・実装・レビュー・専門判断をAgentへ積極委譲し、独立タスクを並列に進める。競合するScene／Prefab等は単独ownerに割り当て、親が検証結果と未検証範囲を統合する。モデルは作業種別で選ぶ: 設計と、基板・機構・UI・シーン・Webデザイン・DSP/検出アルゴリズム・顧客向け成果物など視覚・空間・デザイン判断に品質が依存する作業は上位モデル（Claude Fable／Codex Astra）の `planner`→`craft-builder`→`senior-reviewer` で最後まで行い、機械的で仕様確定・自動検証可能な作業は通常の `builder` でよい。builderは同一ゲート2回連続失敗・仕様外の設計判断・見積の約2倍超過・レビューの品質指摘でエスカレーションを自己申告し、親はcraft-builderに修正または引き継ぎさせる。重複調査や無益な人数増を避け、モデル・人数不足だけで作業やマージを保留しない。個人のモデル設定は変更しない。詳細は `docs/rules/common.md` のAgent運用に従う。

通常の差分レビューと変更に応じた検証を行う。上位モデル、planner、senior-reviewer、専門Agent、厳密な証跡照合は難度・リスクに応じて任意に選ぶ。二重検収、特定モデル・high effort、実効read-onlyやnativeログ・画像閲覧証跡・成果物hashの機械照合、Test-ReviewGate成功は判断確定・完了・ready PR化・mergeの必須条件ではなく、その未成立だけで保留しない。秘密保護、破壊的操作の権限確認、既存変更の保全、製品固有契約、未検証をPASSにしない規則は維持する。

人間宛のメール・チャット・SMS・投稿・他者のPR/Issueへのコメント・招待・共有通知・外部repo/サービスへの連絡は、送信前に宛先/公開範囲・全文・添付等を提示し、プレビュー後のユーザー本人の明示承認を各送信ごとに待つ。包括指示・過去承認・自動承認・reviewer承認で代替しない。変更や再送は再承認。ユーザー自身のINSPIREI repoで依頼された作業のcommit・push・PR作成/本文更新・merge・同期・マージ済みブランチ削除は標準の完了範囲であり、送信ごとの承認を要求しない。詳細は `docs/rules/common.md` の「人間への送信前確認」に従う。
<!-- END INSPIREI AGENT HARNESS -->
