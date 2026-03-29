%% runAnalysis - サンプルデータの基本解析フロー
%
%  bytesファイルの読み込み→座標変換→フィルタリング→3Dプロットの基本フロー
%
%  使い方:
%    1. プロジェクトルートで startup.m を実行
%    2. data/ フォルダに計測データを配置
%    3. このスクリプトを実行

clear; clc;

%% 設定読み込み
cfg = config();

%% データ読み込み
setting = loadSetting(cfg.dataFolder);
data = loadBytes(cfg.dataFolder);

%% 座標変換
data = applyTranslation(data, cfg.translateXYZ);
data = applyRotation(data, cfg.eulerAngles);

%% フィルタリング
data = filterPoints(data, cfg.filterCondition);

%% 3Dプロット
plotScatter3d(data);
