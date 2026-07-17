# SISAR MATLAB解析ツール群

複数の計測点のwav(4ch)/bytes/CSV/textファイルを読み込み、音響インテンシティを計算・可視化するMATLABツール群。
将来的にMATLAB App Designer でGUIアプリ化する予定。

## Tech Stack
- MATLAB（Live Script .mlx、App Designer .mlapp 含む）
- Aerospace Toolbox（quatrotate, quatmultiply）
- 関連リポジトリ: INSPIREI-SoundIntensityScannerAR-Unity

## Commands
- 初回: プロジェクトルートで `run('startup.m')` を実行（パス設定）
- 解析: projects/{計測名}/runAnalysis.m を実行
- 例: projects/example/runAnalysis.m を実行

## Architecture
@docs/architecture.md

## Quality
@docs/quality.md

## Coding Rules
- 共通関数は functions/ に置く。1関数1ファイル。ファイル名=関数名
- 関数名・変数名はlowerCamelCase（例: loadBytes, applyRotation, calcIntensity, dataFolder）
- 定数は UPPER_SNAKE_CASE（例: SAMPLE_RATE, MIC_INTERVAL）
- コメントは「なぜ」を書く。物理量の導出元には文献・規格番号を明記
- モック・ダミーデータでのごまかし禁止

## Data Format
- .bytes: double精度バイナリ。4ch×sampleLength + 7メタデータ（posX,Y,Z, rotW,X,Y,Z）
- .wav: 4chマルチチャンネル音声ファイル
- Setting.txt: 測定条件（サンプルレート、サンプル長、マイク間隔、気温、気圧）
- CSV: スカラー場（PosX,Y,Z,Value）/ ベクトル場（+NormVecX,Y,Z）

## Git Workflow
- ブランチを切って作業する（feature/xxx, fix/xxx）
- IMPORTANT: コミットメッセージは日本語で書く。きりのいいところで頻繁にコミット
- PRは日本語で作成し、変更の目的と影響範囲を明記する

## Development Style
- 機能単位の縦割りで段階的に動くものを作る
- 完了条件は「実際に動くこと」
- IMPORTANT: 物理量・単位・座標系・信号処理に触るタスクは professor（音響工学の教授）の審査を通過しないと完了しない

## タスク運用
- タスク管理: `MILESTONES.md`（リポ直下・正本）／ 自走ループ: `PROMPT.md`（1ループ1タスク）
- milestones.json は廃止済み（2026-07-17。git 履歴には残る）

## 開発チーム（実体エージェント）

`planner → builder → reviewer` を順に回し、雑務は `clerk` に切り出す。professor は招集制（read-only）:

| 役割 | エージェント | model |
|---|---|---|
| Planner（計画・理論検証・タスク分解・**受け入れ条件の定義**。実装しない） | `planner` | **fable** |
| Builder（実装・仮実装禁止・自己checkcode/試走・**検証結果を添えて完了報告**） | `builder` | **sonnet**（難所はopus） |
| Reviewer（挙動検証・レビュー。物理の合否は代行しない） | `reviewer` | **fable** |
| Professor（音響工学の教授。物理的正当性の最終審査・招集制） | `professor` | **fable** |
| Clerk（雑務: 整理・変換・転記。内容判断なし） | `clerk` | **sonnet** |

## モデル方針（全リポジトリ共通）
- **難しい作業（計画・確認・デザイン）= Fable**（`planner` / `reviewer` / `professor`）／**実装 = Sonnet 既定・難所は Opus**（`builder` を `model=opus` で起用）／**雑務 = Sonnet**（`clerk`）

## メモリ方針
- **二層方式**: claude-mem（自動・ローカル）＋ `docs/decisions/decisions.md`（ADR＝git同期される正本）
- **後々効く決定・前提・禁止事項は `docs/decisions/decisions.md` に追記する**（追記専用。既存エントリは書き換えず、覆ったら新エントリ＋旧に差し替え行）。claude-mem はセッション内リコール用

## Project-Specific Notes
- 座標系: Unity左手系。可視化時にZ軸を反転する
- クォータニオン: オイラー角→クォータニオン変換で3D回転を適用（Aerospace Toolbox使用）
- 各プロジェクトの data/ は .gitignore で除外（大容量バイナリ）
- archives/ に旧コード（InoueIntensity, SISAR_old等）を保管。gitで追跡しない
