function fig = plotVectorField(data, vecX, vecY, vecZ, values, titleStr)
% plotVectorField  音響インテンシティのベクトル場を3Dプロット
%
%   fig = plot_vector_field(data, vecX, vecY, vecZ, values)
%   fig = plot_vector_field(data, vecX, vecY, vecZ, values, titleStr)
%
%   入力:
%       data     - 構造体配列（posX/Y/Zフィールドを使用）
%       vecX/Y/Z - ベクトル成分 [1 x N]
%       values   - スカラー値 [1 x N]（色付け用、dB値など）
%       titleStr - タイトル文字列（省略時は自動生成）
%
%   出力:
%       fig - figureハンドル

    n = length(data);
    posX = [data.posX];
    posY = [data.posY];
    posZ = -[data.posZ];  % Z軸反転（左手系→右手系）

    if nargin < 6 || isempty(titleStr)
        titleStr = sprintf('Sound Intensity Vector Field (%d points)', n);
    end

    fig = figure;
    quiver3(posX, posY, posZ, vecX, vecY, -vecZ, 'LineWidth', 1.5);
    hold on;
    scatter3(posX, posY, posZ, 40, values, 'filled');
    hold off;

    xlabel('X [m]');
    ylabel('Y [m]');
    zlabel('Z [m]');
    set(gca, 'ZDir', 'reverse');
    title(titleStr);
    colorbar;
    grid on;
    axis equal;

    fprintf('plotVectorField: %d 点をプロット\n', n);
end
