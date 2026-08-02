# Project Rules — INSPIREI SoundIntensityScannerAR MATLAB

このファイルはこのrepoが所有し、親ハーネス更新では上書きしません。

## Product Contracts

- 音響インテンシティ計測のMATLAB解析、fixture、数値検証を担う。
- Unity側へ移植する数式、単位、座標系、符号、周波数帯、正規化を明示する。
- WAV、CSV、計測fixtureのスキーマとチャンネル順を一方的に変更しない。
- `projects/*/data/` の再計測困難な一次データを上書き・削除しない。
- 実験コードと製品契約に使う実装を区別する。
- 既存規約に合わせ、関数名と変数名はlowerCamelCaseを使用する。

## Verification

- 実在するMATLABチェック、Tests、代表fixtureを実行する。
- Aerospace Toolboxなど対象コードの依存Toolboxと呼び出し側projectの引数整合を確認し、一時検証スクリプトやログを残さない。
- Unity側とのパリティと実機計測が未確認なら分けて記録する。

## Specialists

- 数値・音響レビューはprofessor/reviewer、論文・Toolbox・公式実装の調査はresearcherを使用する。
