function cfg = config()
% config  2022年インプレッサエンジン計測のパラメータ設定
%
%   cfg = config()

    thisDir = fileparts(mfilename('fullpath'));

    % データフォルダ（このプロジェクト内のdata/）
    cfg.dataFolder = fullfile(thisDir, 'data');

    % 座標変換
    cfg.translateXYZ = [0, 0.85, 0.8];
    cfg.eulerAngles = [8, 0, 0];

    % フィルタリング
    cfg.filterCondition = @(x,y,z) y > 0;
end
