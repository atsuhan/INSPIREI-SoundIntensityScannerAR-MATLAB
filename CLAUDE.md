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
- ralph-loop: Planner → Builder → Verifier → Professor の順で進める
- IMPORTANT: Professor（音響工学の教授）の審査を通過しないとマイルストーンは完了しない

## Project-Specific Notes
- 座標系: Unity左手系。可視化時にZ軸を反転する
- クォータニオン: オイラー角→クォータニオン変換で3D回転を適用（Aerospace Toolbox使用）
- 各プロジェクトの data/ は .gitignore で除外（大容量バイナリ）
- archives/ に旧コード（InoueIntensity, SISAR_old等）を保管。gitで追跡しない
