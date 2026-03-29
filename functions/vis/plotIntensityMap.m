function fig = plotIntensityMap(data, values, titleStr)
% plotIntensityMap  音響インテンシティのスカラーマップを3Dプロット
%
%   fig = plot_intensity_map(data, values)
%   fig = plot_intensity_map(data, values, titleStr)
%
%   入力:
%       data     - 構造体配列（posX/Y/Zフィールドを使用）
%       values   - 各計測点のスカラー値 [1 x N]（dB値など）
%       titleStr - タイトル文字列（省略時は自動生成）
%
%   出力:
%       fig - figureハンドル

    n = length(data);
    posX = [data.posX];
    posY = [data.posY];
    posZ = -[data.posZ];  % Z軸反転（左手系→右手系）

    if nargin < 3 || isempty(titleStr)
        titleStr = sprintf('Sound Intensity Level [dB] (%d points)', n);
    end

    fig = figure;
    scatter3(posX, posY, posZ, 80, values, 'filled');
    xlabel('X [m]');
    ylabel('Y [m]');
    zlabel('Z [m]');
    set(gca, 'ZDir', 'reverse');
    title(titleStr);
    cb = colorbar;
    cb.Label.String = 'Intensity Level [dB]';
    grid on;
    axis equal;
    colormap(jet);

    fprintf('plotIntensityMap: %d 点をプロット\n', n);
end
