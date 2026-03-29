function quat = eulerToQuat(eulerAngles)
% eulerToQuat  オイラー角 [roll, pitch, yaw] をクォータニオン [w, x, y, z] に変換
%
%   quat = eulerToQuat(eulerAngles)
%
%   入力:
%       eulerAngles - [roll, pitch, yaw] 度単位
%
%   出力:
%       quat - [w, x, y, z] クォータニオン
%
%   回転順序: ZYX（yaw→pitch→roll）、Unity準拠

    roll  = eulerAngles(1) * pi / 180;
    pitch = eulerAngles(2) * pi / 180;
    yaw   = eulerAngles(3) * pi / 180;

    cy = cos(yaw * 0.5);
    sy = sin(yaw * 0.5);
    cp = cos(pitch * 0.5);
    sp = sin(pitch * 0.5);
    cr = cos(roll * 0.5);
    sr = sin(roll * 0.5);

    quat = [
        cr * cp * cy + sr * sp * sy, ...  % w
        sr * cp * cy - cr * sp * sy, ...  % x
        cr * sp * cy + sr * cp * sy, ...  % y
        cr * cp * sy - sr * sp * cy       % z
    ];
end
