function result = calcIntensityPair(p1, p2, fs, micInterval, rho, opts)
% calcIntensityPair  p-p法（2マイク圧力差法）によるペア軸方向音響インテンシティ
%
%   result = calcIntensityPair(p1, p2, fs, micInterval, rho)
%   result = calcIntensityPair(p1, p2, fs, micInterval, rho, opts)
%
%   入力:
%       p1, p2      - 音圧の時系列 [Pa]（マイク1, マイク2, 同じ長さ）。
%                      audioread等の正規化値をそのまま渡す場合は、
%                      呼び出し側でマイク感度[Pa/FS]を掛けてPaに変換すること
%       fs          - サンプリングレート [Hz]
%       micInterval - マイク1-2間の距離 Δr [m]（> 0）
%       rho         - 空気密度 [kg/m^3]（> 0）
%       opts        - 省略可 struct:
%           .nfft         - calcCrossSpectrumへ渡すFFT長（既定 1024）
%           .overlapRatio - calcCrossSpectrumへ渡すオーバーラップ率（既定 0.5）
%           .c            - 音速 [m/s]（省略可）。指定すると既定bandの上限を
%                           min(fs/2, c/(2*micInterval)) に制限する
%                           （下記「上限周波数」参照）。
%                           省略時は上限周波数が検証されないため、
%                           既定bandの上限は fs/2 のままとなる。
%                           上限周波数を有効にしたい場合は opts.c を渡すこと
%           .band         - [fLow fHigh] 積算する周波数帯 [Hz]（fLow<=fHigh)
%                           （既定 [freq(2), min(fs/2, c/(2*micInterval))]
%                           もしくは opts.c 省略時は [freq(2), fs/2]。
%                           DC(0Hz)は方向性が定義できないため既定では除外する）
%                           opts.c が指定され、band(2) が c/(2*micInterval) を
%                           超える場合は警告を出す
%                           （識別子 'calcIntensityPair:bandAboveNull'）
%
%   出力: result struct
%       .freq             - 周波数ベクトル [Hz]（calcCrossSpectrumのfreqそのまま）
%       .intensityPerBin  - 各周波数ビンの軸方向インテンシティ [W/m^2]
%       .intensity        - band内で総和した軸方向インテンシティ [W/m^2]（符号付き）
%       .intensityLevelDb - 10*log10(abs(intensity)/1e-12) [dB re 1e-12 W/m^2]
%                           （intensity==0の場合は -Inf になる）
%       .sign             - sign(intensity)（+1: mic1→mic2方向, -1: 逆方向, 0: ゼロ）
%       .band             - 実際に使用した [fLow fHigh]
%       .crossSpectrum    - calcCrossSpectrum(p1, p2, ...) の生の出力 G12(f)
%
%   物理式・符号の導出:
%       時間規約は e^{+j*omega*t}（進行波の遅延τは位相因子 e^{-j*omega*τ} で
%       表す。MATLAB/Octave の fft も同じ規約に対応する）。
%
%       ピーク振幅フェーザ P1, P2（p(t) = Re{P*e^{j*omega*t}}）による
%       2マイクp-p法（有限差分近似）の粒子速度:
%           u(f) ≈ -1/(j*omega*rho) * (P2(f) - P1(f)) / Δr   （Euler方程式の差分近似）
%       軸方向（mic1→mic2方向を正）の時間平均インテンシティ:
%           I(f) = (1/2) * Re{ P_avg(f) * conj(u(f)) }
%                = -Im{ conj(P1(f)) * P2(f) } / (2 * rho * omega * Δr)   ...(*)
%
%       一方、本コードの calcCrossSpectrum が返す G12(f) は片側パワー表記の
%       平均二乗量（|P|^2/2 相当のスケール）で定義されている。すなわち
%       G12(f) = conj(P1(f))*P2(f) をピーク振幅で書いた場合の (*) 式に対して
%       G12(f) ≈ conj(P1(f))*P2(f) の「半分」のスケールに相当するため、
%       (*) 式の係数 1/2 が G12 のスケールに吸収され、最終的に
%           I(f) = -Im{ G12(f) } / (rho * omega * Δr)
%                = -Im{ G12(f) } / (rho * 2*pi*f * Δr)
%       という、係数2を含まない式になる（本実装はこちらを採用）。
%       G12(f) は conj(X).*Y 規約（MATLAB cpsd との数値上の一致は未検証。
%       calcCrossSpectrum.m のスケーリングの節を参照）。
%
%       符号の直接確認: mic1→mic2方向へ平面波が伝搬する場合、
%       P2 = P1 * exp(-j*k*Δr) （k = omega/c, 遅れて到達）とすると、
%       conj(P1)*P2 = |P1|^2 * exp(-j*k*Δr) なので
%       Im{conj(P1)*P2} = -|P1|^2*sin(k*Δr) < 0 （k*Δr>0の範囲）
%       したがって I = -Im{G12}/(rho*omega*Δr) > 0 となり、
%       「mic1→mic2方向が正」という定義と整合する。
%
%   上限周波数（有限差分近似のバイアスと符号反転）:
%       有限差分近似のバイアス（低周波では1に漸近、高周波で減衰）:
%           I_measured/I_true = sin(k*Δr) / (k*Δr)
%       k*Δr = pi（すなわち f = c/(2*Δr)、半波長がΔrに一致する周波数）で
%       sin(k*Δr)=0 となり推定値がゼロになる。これより高い周波数では
%       sin(k*Δr) が負になるため、推定インテンシティの符号が反転する
%       （物理的な伝搬方向と無関係な人為的な符号反転）。
%       実用上の上限は、バイアスが約 -1 dB（sin(x)/x ≈ 0.89）となる
%       k*Δr ≲ 1.15 を目安とし、f_max ≈ c/(5.5*Δr) 程度に取ることが多い
%       （出典: Fahy, "Sound Intensity", 2nd ed., 1995）。
%       本関数は rho・micInterval を引数で受け取るがcは省略可であり、
%       opts.c を渡した場合のみ既定bandの上限に
%       min(fs/2, c/(2*micInterval)) を用いる。opts.c を渡さない場合、
%       上限周波数は本関数内では検証されないため、呼び出し側で
%       opts.band または opts.c を明示的に指定すること。
%
%   出典:
%       - F.J. Fahy, "Sound Intensity", 2nd ed., E & FN Spon, 1995.
%         （2マイクp-p法によるインテンシティ推定・上限周波数の標準的導出）
%       - ISO 9614-1:1993, "Acoustics -- Determination of sound power levels
%         of noise sources using sound intensity -- Part 1: Measurement at
%         discrete points."
%
%   単位まとめ: p1,p2 [Pa], fs [Hz], micInterval [m], rho [kg/m^3],
%       opts.c [m/s], intensityPerBin/intensity [W/m^2],
%       intensityLevelDb [dB re 1e-12 W/m^2]

    assert(numel(p1) == numel(p2), 'calcIntensityPair: p1とp2の長さが一致しません');
    assert(rho > 0, 'calcIntensityPair: rhoは正の値を指定してください');
    assert(micInterval > 0, 'calcIntensityPair: micIntervalは正の値を指定してください');

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

    hasC = isfield(opts, 'c') && ~isempty(opts.c);
    if hasC
        fNull = opts.c / (2 * micInterval); % kΔr=piとなる周波数（ゼロ点・符号反転点）
        defaultBandHigh = min(fs / 2, fNull);
    else
        fNull = [];
        defaultBandHigh = fs / 2;
    end

    if isfield(opts, 'band') && ~isempty(opts.band)
        band = opts.band;
    else
        if numel(freq) >= 2
            band = [freq(2), defaultBandHigh];
        else
            band = [freq(1), defaultBandHigh];
        end
    end

    assert(numel(band) == 2 && band(1) <= band(2), ...
        'calcIntensityPair: opts.bandは band(1)<=band(2) の[fLow fHigh]で指定してください');

    if hasC && band(2) > fNull
        warning('calcIntensityPair:bandAboveNull', ...
            ['calcIntensityPair: band上限(%.6g Hz)が c/(2*micInterval)=%.6g Hz を超えています。', ...
             'この周波数以上では有限差分近似の符号反転が生じます。'], band(2), fNull);
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
