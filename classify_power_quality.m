
function [label, features] = classify_power_quality(t, v, fs, nominalRMS, f0)
% CLASSIFY_POWER_QUALITY
% Automatic classification of simulated power-quality disturbances.
%
% Inputs:
%   t          - time vector (seconds)
%   v          - voltage samples (volts)
%   fs         - sampling frequency (Hz)
%   nominalRMS - nominal RMS voltage (V)
%   f0         - nominal supply frequency (Hz)
%
% Outputs:
%   label      - detected disturbance label
%   features   - measured features and diagnostic data
%
% This function is not provided with the injected fault name or timing.

    %% Validate inputs
    t = t(:);
    v = v(:);

    if numel(t) ~= numel(v)
        error('Time and voltage vectors must have equal lengths.');
    end

    if numel(v) < 100
        error('Not enough samples to analyze the waveform.');
    end

    if fs <= 0 || nominalRMS <= 0 || f0 <= 0
        error('fs, nominalRMS and f0 must be positive.');
    end

    %% 1. Half-cycle RMS analysis
    samplesPerHalfCycle = round(fs / (2*f0));
    numberOfWindows = floor(numel(v) / samplesPerHalfCycle);

    rmsValues = zeros(numberOfWindows, 1);
    rmsTimes = zeros(numberOfWindows, 1);
    windowStart = zeros(numberOfWindows, 1);
    windowEnd = zeros(numberOfWindows, 1);

    for k = 1:numberOfWindows
        firstIndex = (k-1)*samplesPerHalfCycle + 1;
        lastIndex = k*samplesPerHalfCycle;

        segment = v(firstIndex:lastIndex);

        rmsValues(k) = sqrt(mean(segment.^2));
        rmsTimes(k) = mean(t(firstIndex:lastIndex));
        windowStart(k) = t(firstIndex);
        windowEnd(k) = t(lastIndex) + 1/fs;
    end

    rmsRatioByWindow = rmsValues / nominalRMS;

    % Demonstration thresholds: 90% and 110% of nominal voltage.
    abnormal = rmsRatioByWindow < 0.90 | ...
               rmsRatioByWindow > 1.10;

    if any(abnormal)
        abnormalIndices = find(abnormal);

        % Median of abnormal RMS windows
        eventRMS = median(rmsValues(abnormal));
        eventRatio = eventRMS / nominalRMS;

        firstAbnormal = abnormalIndices(1);
        lastAbnormal = abnormalIndices(end);

        detectedStart = windowStart(firstAbnormal);
        detectedEnd = windowEnd(lastAbnormal);
    else
        eventRMS = sqrt(mean(v.^2));
        eventRatio = eventRMS / nominalRMS;

        detectedStart = NaN;
        detectedEnd = NaN;
    end

    %% 2. Overall RMS and variation
    overallRMS = sqrt(mean(v.^2));

    if mean(rmsValues) > eps
        rmsVariation = std(rmsValues) / mean(rmsValues);
    else
        rmsVariation = 0;
    end

    %% 3. FFT analysis
    N = numel(v);
    signal = v - mean(v);

    X = fft(signal);
    positiveCount = floor(N/2) + 1;

    Xpositive = X(1:positiveCount);
    frequency = (0:positiveCount-1)' * fs/N;
    amplitude = abs(Xpositive) * 2/N;

    % Correct DC and Nyquist amplitudes
    amplitude(1) = amplitude(1)/2;

    if rem(N,2) == 0
        amplitude(end) = amplitude(end)/2;
    end

    %% 4. Estimate total harmonic distortion
    fundamentalIndex = round(f0*N/fs) + 1;

    if fundamentalIndex > numel(amplitude)
        error('Insufficient sampling rate for the selected frequency.');
    end

    fundamentalAmplitude = amplitude(fundamentalIndex);
    harmonicPower = 0;

    maxHarmonic = min(40, floor((fs/2)/f0));

    for h = 2:maxHarmonic
        index = round(h*f0*N/fs) + 1;

        if index <= numel(amplitude)
            harmonicPower = harmonicPower + amplitude(index)^2;
        end
    end

    THD = sqrt(harmonicPower) / max(fundamentalAmplitude, eps);

    %% 5. High-frequency energy ratio
    totalEnergy = sum(abs(Xpositive).^2);
    highFrequencyMask = frequency >= 500;

    highFrequencyEnergy = sum( ...
        abs(Xpositive(highFrequencyMask)).^2);

    highFrequencyRatio = ...
        highFrequencyEnergy / max(totalEnergy, eps);

    %% 6. Automatic classification
    % Prioritize large RMS changes so that a voltage swell is not
    % incorrectly labelled as a transient because of its edges.
    %
    % These are educational demonstration rules, not universal
    % power-quality standards.

    if eventRatio < 0.10
        label = 'Interruption';

    elseif eventRatio < 0.90
        label = 'Voltage Sag';

    elseif eventRatio > 1.10
        label = 'Voltage Swell';

    elseif highFrequencyRatio > 0.08
        label = 'Transient';

    elseif THD > 0.05
        label = 'Harmonics';

    elseif rmsVariation > 0.025
        label = 'Flicker';

    else
        label = 'Normal';
    end

    %% 7. Return all features
    features.OverallRMS = overallRMS;
    features.EventRMS = eventRMS;
    features.RMSRatio = eventRatio;
    features.THD = THD;
    features.RMSVariation = rmsVariation;
    features.HighFrequencyRatio = highFrequencyRatio;

    features.DetectedStart = detectedStart;
    features.DetectedEnd = detectedEnd;

    features.RMSTime = rmsTimes;
    features.RMSByHalfCycle = rmsValues;
    features.RMSRatioByWindow = rmsRatioByWindow;

    features.Frequency = frequency;
    features.Spectrum = amplitude;
end
