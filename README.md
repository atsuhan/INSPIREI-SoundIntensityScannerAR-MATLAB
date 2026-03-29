# INSPIREI-SoundIntensityScannerAR-MATLAB

SISAR（Sound Intensity Scanner AR）の MATLAB 解析ツール群。

## 概要

SISARで取得した計測データの後処理・解析・CSV変換を行う。

## ファイル構成

| ファイル | 用途 |
|---------|------|
| `MeasuredPointEditor.m` | 計測点データの編集・加工 |
| `VectorFieldCsvConverter.mlx` | ベクトル場データの CSV 変換 |
| `VectorFieldCsvViewer.mlx` | ベクトル場データの可視化 |

## 計測データ

`*.bytes` ファイル（Unityからエクスポートされた計測点バイナリ）は `.gitignore` で除外。
ローカルに保持し、必要に応じて共有。

## 関連リポジトリ

- [INSPIREI-SoundIntensityScannerAR-Unity](https://github.com/atsuhan/INSPIREI-SoundIntensityScannerAR-Unity) — XRアプリケーション
