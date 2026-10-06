<!-- BEGIN INSPIREI AGENT HARNESS -->
# INSPIREI-SoundIntensityScannerAR-MATLAB Agent Entry Point

作業開始前に、次を順番に読むこと。

1. `docs/rules/common.md`
2. `docs/rules/project.md`
3. `docs/index.md`
4. 現在の作業に関係する文書だけ

全docsを一括で読み込まない。人間向けの現在地は `STATUS.md`、Agentの作業台帳は `docs/roadmap/MILESTONES.md` とする。

ルールの優先順位:

1. 安全、秘密情報、破壊防止
2. `docs/rules/project.md` の製品固有契約
3. `docs/rules/common.md` のMUST
4. 共通DEFAULTと個別の作業指示

共通Agentは `planner`、`researcher`、`builder`、`reviewer`、`senior-reviewer`、`clerk`。専門Agentがある場合は `project.md` の指示に従う。

チームを積極的に使うことをDEFAULTとする。メインチャットはSol／Opus級を想定し、親は仕事の分解、所有境界、依存調整、統合、ユーザー説明を担う。非自明・複数領域の仕事は調査・設計・実装・レビュー・専門判断をAgentへ積極委譲し、独立タスクを並列に進める。競合するScene／Prefab等は単独ownerに割り当て、親が検証結果と未検証範囲を統合する。難所では上位モデルへの相談を任意に選び、小さな単純変更は親が処理してよい。重複調査や無益な人数増を避け、モデル・人数不足だけで作業やマージを保留しない。個人のモデル設定は変更しない。詳細は `docs/rules/common.md` のAgent運用に従う。

commitまで行う作業は、差分を積み上げる前に `powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-GitWriteAccess.ps1` を実行する。

実装依頼では、ユーザーが明示的に止めない限り、利用可能な検証、STATUS更新、commit、push、PR、merge、ローカル同期、今回のマージ済み作業ブランチのローカル・origin削除までを標準完了範囲とする。

通常の差分レビューと変更に応じた検証を行う。上位モデル、planner、senior-reviewer、専門Agent、厳密な証跡照合は難度・リスクに応じて任意に選ぶ。二重検収、特定モデル・high effort、実効read-onlyやnativeログ・画像閲覧証跡・成果物hashの機械照合、Test-ReviewGate成功は判断確定・完了・ready PR化・mergeの必須条件ではなく、その未成立だけで保留しない。秘密保護、破壊的操作の権限確認、既存変更の保全、製品固有契約、未検証をPASSにしない規則は維持する。

人間宛のメール・メッセージ・公開コメント・通知は、送信前に宛先/公開範囲・全文・添付等を提示し、プレビュー後のユーザー本人の明示承認を各送信ごとに待つ。包括指示・過去承認・自動承認・reviewer承認で代替しない。変更や再送は再承認。draft PRも公開/通知であり対象。詳細は `docs/rules/common.md` の「人間への送信前確認」に従う。
<!-- END INSPIREI AGENT HARNESS -->
