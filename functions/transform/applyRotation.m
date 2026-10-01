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

    % Aerospace Toolbox の確認
    hasAerospaceToolbox = true;
    try
        % ダミー呼び出しで確認
        quatrotate([1 0 0 0], [1 0 0]);
        hasAerospaceToolbox = true;
    catch
        hasAerospaceToolbox = false;
        warning('applyRotation: Aerospace Toolbox がありません。簡易実装を使用します。');
    end

    for i = 1:length(data)
        % 位置を回転
        pos = [data(i).posX, data(i).posY, data(i).posZ];
        
        if hasAerospaceToolbox
            pos_rotated = quatrotate(quat, pos);
        else
            % 簡易実装：Rodriguesの回転公式
            pos_rotated = applyRotationQuatSimple(quat, pos);
        end
        
        data(i).posX = pos_rotated(1);
        data(i).posY = pos_rotated(2);
        data(i).posZ = pos_rotated(3);

        % クォータニオン姿勢も回転
        quat_orig = [data(i).rotW, data(i).rotX, data(i).rotY, data(i).rotZ];
        
        if hasAerospaceToolbox
            quat_new = quatmultiply(quat, quat_orig);
        else
            % 簡易実装：クォータニオン乗算
            quat_new = applyQuatMultiplySimple(quat, quat_orig);
        end
        
        data(i).rotW = quat_new(1);
        data(i).rotX = quat_new(2);
        data(i).rotY = quat_new(3);
        data(i).rotZ = quat_new(4);
    end

    fprintf('applyRotation: euler=[%g, %g, %g]° を%d点に適用\n', ...
        eulerAngles(1), eulerAngles(2), eulerAngles(3), length(data));
end

%% ヘルパー関数

function result = applyRotationQuatSimple(quat, pos)
% クォータニオンによる位置ベクトル回転（簡易実装）
% Rodriguesの回転公式を使用

    % クォータニオン正規化
    quat = quat / norm(quat);
    w = quat(1); x = quat(2); y = quat(3); z = quat(4);

    % 回転行列に変換して適用（標準的な方法）
    R = [
        1 - 2*(y^2 + z^2),     2*(x*y - w*z),     2*(x*z + w*y);
            2*(x*y + w*z), 1 - 2*(x^2 + z^2),     2*(y*z - w*x);
            2*(x*z - w*y),     2*(y*z + w*x), 1 - 2*(x^2 + y^2)
    ];

    result = (R * pos')';
end

function result = applyQuatMultiplySimple(q1, q2)
% クォータニオン乗算（簡易実装）
% result = q1 * q2

    w1 = q1(1); x1 = q1(2); y1 = q1(3); z1 = q1(4);
    w2 = q2(1); x2 = q2(2); y2 = q2(3); z2 = q2(4);

    result = [
        w1*w2 - x1*x2 - y1*y2 - z1*z2;
        w1*x2 + x1*w2 + y1*z2 - z1*y2;
        w1*y2 - x1*z2 + y1*w2 + z1*x2;
        w1*z2 + x1*y2 - y1*x2 + z1*w2
    ];
end

