
%% POWER QUALITY DISTURBANCE DETECTION AND CLASSIFICATION
% MATLAB Online project
% Manual fault: Voltage Swell
% Start: 0.090 s
% Duration: 0.050 s
% Increase: 50%

clear;
clc;
close all;

%% 1. SYSTEM PARAMETERS
fs = 10000;                  % Sampling frequency (Hz)
f0 = 50;                      % Supply frequency (Hz)
nominalRMS = 230;             % Nominal RMS voltage (V)
Vpeak = sqrt(2)*nominalRMS;
simulationTime = 0.200;       % Total simulation time (s)

t = (0:1/fs:simulationTime-1/fs)';
vNormal = Vpeak*sin(2*pi*f0*t);
v = vNormal;

%% 2. MANUAL FAULT SETTINGS
faultType = 'Voltage Swell';
faultStart = 0.090;           % Start at 90 ms
faultDuration = 0.050;        % Duration: 50 ms
severityPercent = 50;         % Voltage increase: 50%
faultEnd = faultStart + faultDuration;

if faultStart < 0 || faultDuration <= 0 || ...
        faultEnd > simulationTime
    error('Fault timing must be within the simulation duration.');
end

event = t >= faultStart & t < faultEnd;

%% 3. INJECT THE FAULT
switch faultType

    case 'Voltage Swell'
        v(event) = (1 + severityPercent/100)*vNormal(event);

    case 'Voltage Sag'
        v(event) = (1 - severityPercent/100)*vNormal(event);

    case 'Interruption'
        v(event) = 0;

    case 'Harmonics'
        v(event) = Vpeak*( ...
            sin(2*pi*f0*t(event)) + ...
            0.15*sin(2*pi*5*f0*t(event)) + ...
            0.08*sin(2*pi*7*f0*t(event)));

    case 'Flicker'
        v(event) = Vpeak*( ...
            1 + 0.10*sin(2*pi*8*t(event))).* ...
            sin(2*pi*f0*t(event));

    case 'Transient'
        transientEnd = min(faultStart + 0.020, faultEnd);
        transient = t >= faultStart & t < transientEnd;
        tau = t(transient) - faultStart;

        v(transient) = vNormal(transient) + ...
            0.7*Vpeak.*exp(-tau/0.004).* ...
            sin(2*pi*1000*tau);

    otherwise
        error('Unknown fault type: %s', faultType);
end

%% 4. PREPARE INPUT FOR SIMULINK
% From Workspace block reads the variable simInput.
simInput = timeseries(v, t);

% Explicitly place it in the base workspace for Simulink.
assignin('base', 'simInput', simInput);

%% 5. AUTOMATIC CLASSIFICATION
% The classifier receives voltage samples only, not faultType,
% faultStart, faultEnd or severityPercent.

[detectedFault, features] = ...
    classify_power_quality(t, v, fs, nominalRMS, f0);

%% 6. PRINT RESULTS
fprintf('\n');
fprintf('====================================================\n');
fprintf(' POWER QUALITY DISTURBANCE DETECTION RESULTS\n');
fprintf('====================================================\n');

fprintf('Configured fault       : %s\n', faultType);
fprintf('Automatically detected : %s\n', detectedFault);

fprintf('\n--- Fault injection settings ---\n');
fprintf('Start time              : %.3f s\n', faultStart);
fprintf('End time                : %.3f s\n', faultEnd);
fprintf('Duration                : %.3f s\n', faultDuration);
fprintf('Voltage increase        : %.1f %%\n', severityPercent);

fprintf('\n--- Signal analysis ---\n');
fprintf('Nominal voltage         : %.2f V RMS\n', nominalRMS);
fprintf('Overall RMS voltage     : %.2f V RMS\n', features.OverallRMS);
fprintf('Detected event RMS      : %.2f V RMS\n', features.EventRMS);
fprintf('Event RMS ratio         : %.3f\n', features.RMSRatio);
fprintf('Estimated THD           : %.2f %%\n', 100*features.THD);
fprintf('RMS variation           : %.2f %%\n', ...
    100*features.RMSVariation);
fprintf('High-frequency energy   : %.4f\n', ...
    features.HighFrequencyRatio);

if isnan(features.DetectedStart)
    fprintf('Estimated event start   : Not detected\n');
    fprintf('Estimated event end     : Not detected\n');
else
    fprintf('Estimated event start   : %.3f s\n', ...
        features.DetectedStart);
    fprintf('Estimated event end     : %.3f s\n', ...
        features.DetectedEnd);
end

if strcmp(detectedFault, faultType)
    fprintf('\nClassification result: MATCH\n');
else
    fprintf('\nClassification result: MISMATCH\n');
    fprintf('Inspect the feature values and classification rules.\n');
end

%% 7. PLOT THE VOLTAGE WAVEFORM
figure('Name', 'Power Quality Voltage Waveform');

plot(t, vNormal, '--k', 'LineWidth', 0.9);
hold on;
plot(t, v, 'b', 'LineWidth', 1.2);

xline(faultStart, '--r', 'Injected start');
xline(faultEnd, '--m', 'Injected end');

grid on;
xlabel('Time (seconds)');
ylabel('Voltage (V)');
title(['Injected: ', faultType, ...
       ' | Detected: ', detectedFault]);

legend('Normal reference', 'Faulted voltage', ...
       'Injected start', 'Injected end', ...
       'Location', 'best');

%% 8. PLOT HALF-CYCLE RMS
figure('Name', 'RMS Voltage Analysis');

plot(features.RMSTime, features.RMSByHalfCycle, ...
    '-o', 'LineWidth', 1.2);
hold on;

yline(nominalRMS, '--k', 'Nominal RMS');
yline(1.10*nominalRMS, ':r', 'Swell threshold');
yline(0.90*nominalRMS, ':m', 'Sag threshold');

grid on;
xlabel('Time (seconds)');
ylabel('RMS voltage (V)');
title('Half-Cycle RMS Voltage Analysis');

legend('Measured RMS', 'Nominal RMS', ...
       'Swell threshold', 'Sag threshold', ...
       'Location', 'best');

%% 9. PLOT FFT SPECTRUM
figure('Name', 'Voltage FFT Spectrum');

plot(features.Frequency, features.Spectrum, ...
    'LineWidth', 1.1);

xlim([0 1000]);
grid on;
xlabel('Frequency (Hz)');
ylabel('Amplitude (V peak, approximate)');
title('Voltage Frequency Spectrum');

%% 10. CREATE AND SAVE RESULTS TABLE
Parameter = {
    'Configured fault';
    'Detected fault';
    'Nominal RMS voltage (V)';
    'Overall RMS voltage (V)';
    'Event RMS voltage (V)';
    'Event RMS ratio';
    'Estimated THD (%)';
    'RMS variation (%)';
    'High-frequency energy ratio';
    'Injected start time (s)';
    'Injected end time (s)';
    'Injected duration (s)';
    'Voltage increase (%)'
};

Value = {
    faultType;
    detectedFault;
    nominalRMS;
    features.OverallRMS;
    features.EventRMS;
    features.RMSRatio;
    100*features.THD;
    100*features.RMSVariation;
    features.HighFrequencyRatio;
    faultStart;
    faultEnd;
    faultDuration;
    severityPercent
};

Results = table(Parameter, Value);

fprintf('\n--- Results table ---\n');
disp(Results);

writetable(Results, 'PowerQualityResults.csv');

save('PowerQualityResults.mat', ...
    'Results', 'features', 'faultType', 'detectedFault', ...
    't', 'v', 'vNormal', 'fs', 'f0', 'nominalRMS', ...
    'faultStart', 'faultDuration', 'severityPercent');

fprintf('\nSaved PowerQualityResults.csv\n');
fprintf('Saved PowerQualityResults.mat\n');

%% 11. RUN SIMULINK MODEL IF IT EXISTS
modelName = 'PowerQualityDetection';
modelFile = [modelName, '.slx'];

if isfile(modelFile)
    try
        load_system(modelName);

        set_param(modelName, ...
            'StopTime', num2str(simulationTime));

        open_system(modelName);

        % Open the Scope if the block is named Scope.
        try
            open_system([modelName, '/Scope']);
        catch
            fprintf('Open the Scope block manually if needed.\n');
        end

        % Run Simulink using simInput in the base workspace.
        sim(modelName);

        fprintf('Simulink simulation completed successfully.\n');

    catch ME
        warning('MATLAB analysis completed, but Simulink failed: %s', ...
            ME.message);
    end
else
    fprintf('\nSimulink model not found: %s\n', modelFile);
    fprintf('MATLAB analysis and plots are complete.\n');
    fprintf('Create the Simulink model using the instructions provided.\n');
end
