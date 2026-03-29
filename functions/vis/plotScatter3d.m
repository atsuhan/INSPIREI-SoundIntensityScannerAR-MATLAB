function fig = plotScatter3d(data, colorValues, titleStr)
% plotScatter3d  計測点の3Dスキャッタープロット
%
%   fig = plot_scatter3d(data)
%   fig = plot_scatter3d(data, colorValues)
%   fig = plot_scatter3d(data, colorValues, titleStr)
%
%   入力:
%       data        - 構造体配列（posX/Y/Zフィールドを使用）
%       colorValues - 各点の色に使う値ベクトル [1 x N]
%                     省略時はインデックス番号で着色
%       titleStr    - タイトル文字列（省略時は自動生成）
%
%   出力:
%       fig - figureハンドル
%
%   可視化時にZ軸を反転（Unity左手系→MATLAB右手系の変換）

    n = length(data);
    posX = [data.posX];
    posY = [data.posY];
    posZ = -[data.posZ];  % Z軸反転（左手系→右手系）

    if nargin < 2 || isempty(colorValues)
        colorValues = [data.idx];
    end

    if nargin < 3 || isempty(titleStr)
        titleStr = sprintf('MeasurePoint Positions (%d points)', n);
    end

    fig = figure;
    scatter3(posX, posY, posZ, 100, colorValues, 'filled');
    xlabel('X Position');
    ylabel('Y Position');
    zlabel('Z Position');
    set(gca, 'ZDir', 'reverse');
    title(titleStr);
    colorbar;
    grid on;
    axis equal;

    fprintf('plotScatter3d: %d 点をプロット\n', n);
end
