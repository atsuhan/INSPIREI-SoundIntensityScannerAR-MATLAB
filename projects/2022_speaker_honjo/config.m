function cfg = config()
% config  2022年本庄スピーカ計測のパラメータ設定
%
%   cfg = config()

    thisDir = fileparts(mfilename('fullpath'));

    % データフォルダ（このプロジェクト内のdata/）
    cfg.dataFolder = fullfile(thisDir, 'data');

    % 座標変換（この計測では変換なし）
    cfg.translateXYZ = [0, 0, 0];
    cfg.eulerAngles = [0, 0, 0];

    % フィルタリング（全通過）
    cfg.filterCondition = @(x,y,z) true;
end
