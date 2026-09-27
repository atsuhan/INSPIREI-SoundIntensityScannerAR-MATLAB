function result = calcIntensityPair(p1, p2, fs, micInterval, rho, opts)
% calcIntensityPair  p-p法（2マイク圧力差法）によるペア軸方向音響インテンシティ
%
%   result = calcIntensityPair(p1, p2, fs, micInterval, rho)
%   result = calcIntensityPair(p1, p2, fs, micInterval, rho, opts)
%
%   入力:
%       p1, p2      - 音圧の時系列 [Pa]（マイク1, マイク2）。
%                      audioread等の正規化値をそのまま渡す場合は、
%                      呼び出し側でマイク感度[Pa/FS]を掛けてPaに変換すること
%       fs          - サンプリングレート [Hz]
%       micInterval - マイク1-2間の距離 Δr [m]
%       rho         - 空気密度 [kg/m^3]
%       opts        - 省略可 struct:
%           .nfft         - calcCrossSpectrumへ渡すFFT長（既定 1024）
%           .overlapRatio - calcCrossSpectrumへ渡すオーバーラップ率（既定 0.5）
%           .band         - [fLow fHigh] 積算する周波数帯 [Hz]
%                           （既定 [freq(2), fs/2]。DC(0Hz)は方向性が
%                           定義できないため既定では除外する）
%
%   出力: result struct
%       .freq             - 周波数ベクトル [Hz]（calcCrossSpectrumのfreqそのまま）
%       .intensityPerBin  - 各周波数ビンの軸方向インテンシティ [W/m^2]
%       .intensity        - band内で総和した軸方向インテンシティ [W/m^2]（符号付き）
%       .intensityLevelDb - 10*log10(abs(intensity)/1e-12) [dB re 1e-12 W/m^2]
%       .sign             - sign(intensity)（+1: mic1→mic2方向, -1: 逆方向, 0: ゼロ）
%       .band             - 実際に使用した [fLow fHigh]
%       .crossSpectrum    - calcCrossSpectrum(p1, p2, ...) の生の出力 G12(f)
%
%   物理式・符号の導出:
%       2マイクp-p法（有限差分近似）による粒子速度:
%           u(f) ≈ -1/(j*omega*rho) * (P2(f) - P1(f)) / Δr   （Euler方程式の差分近似）
%       軸方向（mic1→mic2方向を正）のインテンシティ:
%           I(f) = (1/2) * Re{ P_avg(f) * conj(u(f)) }
%                = -Im{ conj(P1(f)) * P2(f) } / (rho * omega * Δr)
%                = -Im{ G12(f) } / (rho * 2*pi*f * Δr)
%       ここで G12(f) = conj(P1(f)) * P2(f) （本コードの calcCrossSpectrum の
%       出力規約と同一。MATLAB cpsd(p1,p2) と同じ規約）。
%
%       符号の直接確認: mic1→mic2方向へ平面波が伝搬する場合、
%       P2 = P1 * exp(-j*k*Δr) （k = omega/c, 遅れて到達）とすると、
%       conj(P1)*P2 = |P1|^2 * exp(-j*k*Δr) なので
%       Im{conj(P1)*P2} = -|P1|^2*sin(k*Δr) < 0 （k*Δr>0の範囲）
%       したがって I = -Im{G12}/(rho*omega*Δr) > 0 となり、
%       「mic1→mic2方向が正」という定義と整合する。
%
%       有限差分近似のバイアス（低周波では1に漸近、高周波で減衰）:
%           I_measured/I_true = sin(k*Δr) / (k*Δr)
%       この近似が破綻し始める上限周波数の目安は f <= c/(2*Δr)
%       （半波長がΔrに一致する周波数; ユーザー側でband上限として指定する。
%       本関数はΔrやcをハードコードしないため既定bandの上限は fs/2 とする）
%
%   出典:
%       - F.J. Fahy, "Sound Intensity", 2nd ed., E & FN Spon, 1995.
%         （2マイクp-p法によるインテンシティ推定の標準的導出）
%       - ISO 9614-1:1993, "Acoustics -- Determination of sound power levels
%         of noise sources using sound intensity -- Part 1: Measurement at
%         discrete points."
%
%   単位まとめ: p1,p2 [Pa], fs [Hz], micInterval [m], rho [kg/m^3],
%       intensityPerBin/intensity [W/m^2], intensityLevelDb [dB re 1e-12 W/m^2]

    if nargin < 6 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'nfft')
        opts.nfft = 1024;
    end
    if ~isfield(opts, 'overlapRatio')
        opts.overlapRatio = 0.5;
    end

    [g12, freq] = calcCrossSpectrum(p1, p2, fs, opts.nfft, opts.overlapRatio);

    omega = 2 * pi * freq;
    intensityPerBin = zeros(size(freq));
    nonZero = omega ~= 0;
    intensityPerBin(nonZero) = -imag(g12(nonZero)) ./ (rho * omega(nonZero) * micInterval);
    % DC(0Hz)は方向性が定義できないため0とする

    if isfield(opts, 'band') && ~isempty(opts.band)
        band = opts.band;
    else
        if numel(freq) >= 2
            band = [freq(2), fs / 2];
        else
            band = [freq(1), fs / 2];
        end
    end

    inBand = freq >= band(1) & freq <= band(2);
    intensity = sum(intensityPerBin(inBand));

    result = struct();
    result.freq = freq;
    result.intensityPerBin = intensityPerBin;
    result.intensity = intensity;
    result.intensityLevelDb = 10 * log10(abs(intensity) / 1e-12);
    result.sign = sign(intensity);
    result.band = band;
    result.crossSpectrum = g12;
end
