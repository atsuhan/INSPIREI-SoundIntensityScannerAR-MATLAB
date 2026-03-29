function filtered = filterPoints(data, condition)
% filterPoints  条件関数で計測点をフィルタリング
%
%   filtered = filter_points(data, condition)
%
%   入力:
%       data      - 構造体配列（load_bytesの出力）
%       condition - フィルタ関数ハンドル @(posX, posY, posZ) -> logical
%                   例: @(x,y,z) y > 0
%                   例: @(x,y,z) y > 0 && z < 1.0
%                   例: @(x,y,z) true  （全通過）
%
%   出力:
%       filtered - 条件を満たす計測点のみの構造体配列

    mask = false(1, length(data));
    for i = 1:length(data)
        mask(i) = condition(data(i).posX, data(i).posY, data(i).posZ);
    end

    filtered = data(mask);

    fprintf('filterPoints: %d/%d 点が条件を通過\n', sum(mask), length(data));
end
