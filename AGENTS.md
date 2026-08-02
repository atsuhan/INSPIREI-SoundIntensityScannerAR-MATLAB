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

共通Agentは `planner`、`researcher`、`builder`、`reviewer`、`clerk`。専門Agentがある場合は `project.md` の指示に従う。

commitまで行う作業は、差分を積み上げる前に `powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent-harness/Test-GitWriteAccess.ps1` を実行する。

実装依頼では、ユーザーが明示的に止めない限り、利用可能な検証、STATUS更新、commit、push、PR、merge、ローカル同期、今回のマージ済み作業ブランチのローカル・origin削除までを標準完了範囲とする。
