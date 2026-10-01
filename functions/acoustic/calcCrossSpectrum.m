function [gxy, freq] = calcCrossSpectrum(x, y, fs, nfft, overlapRatio)
% calcCrossSpectrum  Welch法によるクロススペクトル推定（片側・パワー表記）
%
%   [gxy, freq] = calcCrossSpectrum(x, y, fs, nfft, overlapRatio)
%
%   Signal Processing Toolbox（cpsd, pwelch, hann等）に依存せず、
%   周期Hann窓を自前生成してWelch平均を行う。
%
%   入力:
%       x, y         - 実数の列/行ベクトル（同じ長さ）
%       fs           - サンプリングレート [Hz]
%       nfft         - セグメント長（省略時 1024）。
%                      信号長Nがnfftより短い場合は nfft = N - mod(N,2)
%                      （偶数に切り下げて1セグメントとする）
%       overlapRatio - セグメント重複率 0以上1未満（省略時 0.5）
%
%   出力:
%       gxy  - 片側クロススペクトル [nfft/2+1 x 1]（複素数, パワー表記）
%              gxy(k) = mean_seg(conj(X_k).*Y_k) * 2 / (nfft*sum(w.^2))
%              （DCとNyquistは x1。他は x2）
%       freq - 周波数ベクトル [Hz]（0 から fs/2、長さ nfft/2+1）
%
%   規約:
%       - conj(X).*Y 規約（G(f) = conj(X(f)).*Y(f) の平均）。
%         MATLAB cpsd との数値上の一致は未検証（下記スケーリングの節を参照）。
%       - パワー表記（Hz密度ではないスペクトル）。
%         x==y のとき sum(real(gxx)) ≈ mean(x.^2)（Parseval, 窓補正込み）
%       - 窓: 周期Hann w = 0.5*(1-cos(2*pi*(0:nfft-1)/nfft))（自前生成、Toolbox非依存）
%       - 各セグメントは窓を掛ける前に平均値を除去する（x_seg - mean(x_seg)）。
%         Hann窓の主ローブがDC成分から低域ビンへ漏れ込み、
%         低域の Im{G12}（＝低域インテンシティ推定）にバイアスを与えるのを防ぐため
%       - Welch平均: 50%（既定）オーバーラップでセグメント分割し、
%         conj(X_k).*Y_k をセグメント間で平均した後にスケーリングする
%
%   スケーリングの根拠・MATLABとの関係（未検証）:
%       本関数の gxy は「ビン当たりパワー」（PSD × Δf、Δf=fs/nfft）に相当する
%       表記であり、Hz密度（PSD, 単位 [単位^2/Hz]）ではない。
%       MATLAB の cpsd(x, y, w, noverlap, nfft, fs)（既定オプション 'psd'）が
%       返す値は PSD [単位^2/Hz] であるため、本関数の gxy は
%       おおよそ cpsd(...) * fs/nfft に相当するはず（MATLAB未導入のため未検証）。
%       cpsd の 'power' オプション（Δf補正済みのバンド幅補正パワー）とは
%       スケーリングの定義が異なる可能性があるため、明示的に区別する。
%
%   出典:
%       - P. Welch, "The use of fast Fourier transform for the estimation of
%         power spectra: A method based on time averaging over short,
%         modified periodograms", IEEE Trans. Audio Electroacoust.,
%         vol. 15, no. 2, pp. 70-73, 1967.
%       - J.S. Bendat and A.G. Piersol, "Random Data: Analysis and
%         Measurement Procedures", 4th ed., Wiley, 2010, Ch. 11
%         （Welch平均・窓補正・クロススペクトル推定の標準的定式化）。

    if nargin < 4 || isempty(nfft)
        nfft = 1024;
    end
    if nargin < 5 || isempty(overlapRatio)
        overlapRatio = 0.5;
    end

    x = x(:);
    y = y(:);
    assert(numel(x) == numel(y), 'calcCrossSpectrum: xとyの長さが一致しません');
    assert(overlapRatio >= 0 && overlapRatio < 1, ...
        'calcCrossSpectrum: overlapRatioは[0,1)の範囲で指定してください');

    n = numel(x);
    if n < nfft
        nfft = n - mod(n, 2); % 偶数に切り下げ（Nyquistビンの取り扱いを一貫させるため）
    end
    assert(nfft >= 2, 'calcCrossSpectrum: 信号が短すぎます（nfft>=2が必要）');

    % 周期Hann窓（自前生成）
    w = 0.5 * (1 - cos(2 * pi * (0:nfft - 1)' / nfft));
    sumW2 = sum(w .^ 2);

    step = max(1, round(nfft * (1 - overlapRatio)));
    starts = 1:step:(n - nfft + 1);
    if isempty(starts)
        starts = 1;
    end
    nSeg = numel(starts);

    nHalf = floor(nfft / 2);
    nFreqBins = nHalf + 1;

    segAccum = zeros(nfft, 1);
    for i = 1:nSeg
        idx = starts(i):(starts(i) + nfft - 1);
        xSeg = x(idx) - mean(x(idx));
        ySeg = y(idx) - mean(y(idx));
        xw = xSeg .* w;
        yw = ySeg .* w;
        xSpec = fft(xw, nfft);
        ySpec = fft(yw, nfft);
        segAccum = segAccum + conj(xSpec) .* ySpec;
    end
    segAvg = segAccum / nSeg;

    % 片側スケーリング（DC, Nyquistは x1、それ以外は x2）
    scale = 2 / (nfft * sumW2);
    gxy = segAvg(1:nFreqBins) * scale;
    gxy(1) = gxy(1) / 2;
    if mod(nfft, 2) == 0
        gxy(end) = gxy(end) / 2;
    end

    freq = (0:nFreqBins - 1)' * (fs / nfft);
end
