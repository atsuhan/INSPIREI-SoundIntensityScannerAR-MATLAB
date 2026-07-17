# 意思決定ログ（ADR）— INSPIREI-SoundIntensityScannerAR-MATLAB

> **このファイルが判断の正本**（git 同期され、両PC・全エージェントが参照する）。
> claude-mem はセッション内リコール用 — 後々効く決定はここに書く（二層方式）。
>
> **追記専用ルール:** 既存エントリは書き換えない。決定が覆ったら**新しいエントリを足し**、
> 旧エントリの末尾に `- **差し替え:** YYYY-MM-DD の決定で更新` を1行付けて辿れるようにする。
>
> フォーマット:
> ```
> ### YYYY-MM-DD: [判断の要約]  ［状態: ✅反映済 / ⏳要確認 / ❌却下］
> - **前提:** / **決定:** / **却下案:** / **根拠:** / **反映先:**
> ```

---

### 2026-07-17: 基盤環境を標準チーム構成へ移行（milestones.json・旧looper 廃止） ［状態: ✅反映済］
- **前提:** 本リポは旧世代の自走環境（milestones.json ＋ looper/prompts の Planner→Builder→Verifier→Professor）のままで、全リポ共通の基盤環境（MILESTONES.md v2・コア4エージェント・PROMPT.md）から取り残されていた。井上の指示 2026-07-17「sisarmatlabもやっといて。otomiruのmatlabも参考にしながら、エージェントやルール決めを」
- **決定:** ① INSPIREI-OTOMIRU-MATLAB を雛形にコア4体（planner=fable / builder=sonnet / reviewer=fable / clerk=sonnet）を `.claude/agents/` に設置 ② SISAR 固有文化の **professor（音響工学の教授・招集制・fable）** を5体目として維持 — 物理量・単位・座標系・信号処理に触るタスクは professor 審査を通過しないと完了しない（旧 looper/prompts/professor.md の審査基準を継承）③ milestones.json を MILESTONES.md（書式規約v2）へ移行 — 旧M1は完了アーカイブ、旧M2/M3/M4 は P1/P2/P3 として引き継ぎ ④ 自走ループの掟は PROMPT.md（4本柱＋professor条項）⑤ json前提の `.claude/commands/gen-milestones.md` と `looper/` は廃止（`plan.md` は汎用なので存置）
- **却下案:** 旧 Verifier の名称維持（全リポ共通の reviewer に統一。挙動検証=reviewer / 物理審査=professor と役割を分離）／professor の廃止（自社完結開発で研究品質を担保する仕組みは SISAR の強み。残す）
- **根拠:** 実運用で回っている OTOMIRU-MATLAB 形が MATLAB リポの標準。SISAR は理論検証の比重が高く、旧環境の professor 審査は品質ゲートとして機能していたため標準構成に組み込んで継承する
- **反映先:** `.claude/agents/{planner,builder,reviewer,professor,clerk}.md`／`MILESTONES.md`（新設・書式規約v2）／`PROMPT.md`（新設）／`CLAUDE.md`（チーム・タスク運用・メモリ方針の節を刷新）／`docs/decisions/decisions.md`（本ファイル新設）／削除: `milestones.json`・`looper/`・`.claude/commands/gen-milestones.md`
