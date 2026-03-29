function data = applyRotation(data, eulerAngles)
% applyRotation  全計測点にオイラー角ベースの回転を適用
%
%   data = apply_rotation(data, eulerAngles)
%
%   入力:
%       data        - 構造体配列（load_bytesの出力）
%       eulerAngles - [roll, pitch, yaw] 度単位
%
%   出力:
%       data - 座標と回転が更新された構造体配列
%
%   クォータニオン回転をAerospace Toolboxのquatrotate/quatmultiplyで計算。
%   位置とクォータニオン姿勢の両方を回転する。

    if all(eulerAngles == 0)
        return;
    end

    quat = eulerToQuat(eulerAngles);

    for i = 1:length(data)
        % 位置を回転
        pos = [data(i).posX, data(i).posY, data(i).posZ];
        pos_rotated = quatrotate(quat, pos);
        data(i).posX = pos_rotated(1);
        data(i).posY = pos_rotated(2);
        data(i).posZ = pos_rotated(3);

        % クォータニオン姿勢も回転
        quat_orig = [data(i).rotW, data(i).rotX, data(i).rotY, data(i).rotZ];
        quat_new = quatmultiply(quat, quat_orig);
        data(i).rotW = quat_new(1);
        data(i).rotX = quat_new(2);
        data(i).rotY = quat_new(3);
        data(i).rotZ = quat_new(4);
    end

    fprintf('applyRotation: euler=[%g, %g, %g]° を%d点に適用\n', ...
        eulerAngles(1), eulerAngles(2), eulerAngles(3), length(data));
end
