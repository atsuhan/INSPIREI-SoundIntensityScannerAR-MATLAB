function data = applyTranslation(data, translateXYZ)
% applyTranslation  全計測点に平行移動を適用
%
%   data = apply_translation(data, translateXYZ)
%
%   入力:
%       data         - 構造体配列（load_bytesの出力）
%       translateXYZ - [dx, dy, dz] 移動量
%
%   出力:
%       data - 座標が更新された構造体配列

    if all(translateXYZ == 0)
        return;
    end

    for i = 1:length(data)
        data(i).posX = data(i).posX + translateXYZ(1);
        data(i).posY = data(i).posY + translateXYZ(2);
        data(i).posZ = data(i).posZ + translateXYZ(3);
    end

    fprintf('applyTranslation: [%g, %g, %g] を%d点に適用\n', ...
        translateXYZ(1), translateXYZ(2), translateXYZ(3), length(data));
end
