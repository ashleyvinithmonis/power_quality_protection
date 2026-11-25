
function PowerQualityApp
% POWER QUALITY MONITOR WITH AUTOMATIC FAULT DETECTION
% Save as PowerQualityApp.m
% Run: PowerQualityApp
%
% Hardware-free demonstration. Voltage and current are simulated.
% The fault selector injects a disturbance; the detector classifies
% the measured signal independently of the selected fault name.

    %% Simulation settings
    fs = 5000;
    fNom = 50;
    vNom = 230;
    loadR = 46;                 % Simulated resistive load: 5 A nominal
    dt = 0.05;
    nTick = round(fs*dt);
    displaySeconds = 2;

    simTime = 0;
    running = false;
    activeStimulus = 'Normal';
    stimulusStart = -1;
    stimulusEnd = -1;
    severity = 50;
    faultDuration = 0.5;

    detectedFault = 'Normal';
    previousDetectedFault = 'Normal';
    history = {};

    tBuffer = [];
    vBuffer = [];
    iBuffer = [];
    rmsTime = [];
    vRmsBuffer = [];
    iRmsBuffer = [];
    freqBuffer = [];

    %% Main window
    fig = uifigure( ...
        'Name','Automatic Power Quality Fault Detection', ...
        'Position',[40 40 1380 850], ...
        'Color',[0.96 0.97 0.98]);

    fig.CloseRequestFcn = @closeApp;

    main = uigridlayout(fig,[1 2]);
    main.ColumnWidth = {300,'1x'};
    main.Padding = [10 10 10 10];
    main.ColumnSpacing = 10;

    %% Left control panel
    control = uipanel(main,'Title','Controls and Measurements');
    control.Layout.Column = 1;

    cg = uigridlayout(control,[19 1]);
    cg.RowHeight = {25,30,22,30,22,30,40,40,25,25,25,25,25,25,25,'1x',25,25,25};
    cg.Padding = [10 8 10 8];
    cg.RowSpacing = 4;

    uilabel(cg,'Text','Test disturbance (injection only)', ...
        'FontWeight','bold');

    faultDrop = uidropdown(cg, ...
        'Items',{'Voltage Sag','Voltage Swell','Interruption', ...
                 'Harmonics','Flicker','Transient', ...
                 'Frequency Deviation'}, ...
        'Value','Voltage Sag');

    uilabel(cg,'Text','Fault severity (%)','FontWeight','bold');

    severitySlider = uislider(cg, ...
        'Limits',[10 90],'Value',50, ...
        'MajorTicks',[10 30 50 70 90]);
    severitySlider.ValueChangedFcn = @updateSettings;

    severityLabel = uilabel(cg,'Text','Severity: 50%');

    uilabel(cg,'Text','Fault duration (s)','FontWeight','bold');

    durationSlider = uislider(cg, ...
        'Limits',[0.1 3],'Value',0.5, ...
        'MajorTicks',[0.1 1 2 3]);
    durationSlider.ValueChangedFcn = @updateSettings;

    durationLabel = uilabel(cg,'Text','Duration: 0.50 s');

    injectButton = uibutton(cg,'push', ...
        'Text','INJECT TEST FAULT', ...
        'BackgroundColor',[0.85 0.25 0.20], ...
        'FontColor',[1 1 1], ...
        'FontWeight','bold', ...
        'ButtonPushedFcn',@injectFault);

    startButton = uibutton(cg,'push', ...
        'Text','START LIVE MONITORING', ...
        'BackgroundColor',[0.15 0.55 0.30], ...
        'FontColor',[1 1 1], ...
        'ButtonPushedFcn',@startSimulation);

    stopButton = uibutton(cg,'push', ...
        'Text','STOP MONITORING', ...
        'ButtonPushedFcn',@stopSimulation);

    uilabel(cg,'Text','LIVE MEASUREMENTS', ...
        'FontWeight','bold');

    voltageLabel = uilabel(cg,'Text','Voltage RMS: -- V');
    currentLabel = uilabel(cg,'Text','Current RMS: -- A');
    frequencyLabel = uilabel(cg,'Text','Frequency: -- Hz');
    thdLabel = uilabel(cg,'Text','Voltage THD: -- %');

    uilabel(cg,'Text','AUTOMATIC DETECTOR', ...
        'FontWeight','bold');

    faultLabel = uilabel(cg, ...
        'Text','Detected fault: Normal', ...
        'FontWeight','bold', ...
        'FontColor',[0.10 0.45 0.20]);

    previousLabel = uilabel(cg,'Text','Previous fault: None');

    statusLabel = uilabel(cg,'Text','Status: Stopped');

    %% Right-side plots and history
    right = uigridlayout(main,[4 1]);
    right.Layout.Column = 2;
    right.RowHeight = {'3x','3x','2x','2x'};
    right.RowSpacing = 8;
    right.Padding = [0 0 0 0];

    % Voltage plot
    p1 = uipanel(right,'Title','Live Voltage Waveform');
    axV = uiaxes(p1,'Position',[55 35 930 140]);
    axV.XGrid = 'on';
    axV.YGrid = 'on';
    axV.XLabel.String = 'Time (s)';
    axV.YLabel.String = 'Voltage (V)';
    axV.Title.String = 'Measured Voltage';
    axV.YLim = [-550 550];
    lineV = plot(axV,nan,nan,'b','LineWidth',1.2);

    % Current plot
    p2 = uipanel(right,'Title','Live Load Current');
    axI = uiaxes(p2,'Position',[55 35 930 140]);
    axI.XGrid = 'on';
    axI.YGrid = 'on';
    axI.XLabel.String = 'Time (s)';
    axI.YLabel.String = 'Current (A)';
    axI.Title.String = 'Measured Load Current';
    axI.YLim = [-15 15];
    lineI = plot(axI,nan,nan,'Color',[0.1 0.55 0.2],'LineWidth',1.2);

    % RMS and frequency trends
    p3 = uipanel(right,'Title','Live RMS and Frequency Trends');
    axR = uiaxes(p3,'Position',[55 35 450 125]);
    axR.XGrid = 'on';
    axR.YGrid = 'on';
    axR.XLabel.String = 'Time (s)';
    axR.YLabel.String = 'RMS';
    hold(axR,'on');
    lineVRms = plot(axR,nan,nan,'r','LineWidth',1.3);
    lineIRms = plot(axR,nan,nan,'g','LineWidth',1.3);
    legend(axR,{'Voltage RMS (V)','Current RMS (A)'}, ...
        'Location','northwest');
    hold(axR,'off');

    axF = uiaxes(p3,'Position',[560 35 420 125]);
    axF.XGrid = 'on';
    axF.YGrid = 'on';
    axF.XLabel.String = 'Time (s)';
    axF.YLabel.String = 'Frequency (Hz)';
    axF.YLim = [40 60];
    lineF = plot(axF,nan,nan,'m','LineWidth',1.3);

    % Detection history
    p4 = uipanel(right,'Title','Automatic Fault Detection History');
    historyList = uilistbox(p4,'Position',[10 10 970 125], ...
        'Items',{'No faults detected yet'});

    %% Timer
    simTimer = timer( ...
        'ExecutionMode','fixedSpacing', ...
        'Period',dt, ...
        'BusyMode','drop', ...
        'TimerFcn',@simulationTick);

    updateSettings();

    %% Callbacks
    function updateSettings(~,~)
        severity = severitySlider.Value;
        faultDuration = durationSlider.Value;
        severityLabel.Text = sprintf('Severity: %.0f%%',severity);
        durationLabel.Text = sprintf('Duration: %.2f s',faultDuration);
    end

    function startSimulation(~,~)
        if running
            return;
        end

        running = true;
        statusLabel.Text = 'Status: Monitoring';
        startButton.Enable = 'off';
        stopButton.Enable = 'on';

        try
            start(simTimer);
        catch ME
            running = false;
            startButton.Enable = 'on';
            statusLabel.Text = ['Timer error: ' ME.message];
        end
    end

    function stopSimulation(~,~)
        running = false;

        if isvalid(simTimer) && strcmp(simTimer.Running,'on')
            stop(simTimer);
        end

        startButton.Enable = 'on';
        statusLabel.Text = 'Status: Stopped';
    end

    function injectFault(~,~)
        if ~running
            uialert(fig, ...
                'Start live monitoring before injecting a fault.', ...
                'Monitoring is stopped');
            return;
        end

        updateSettings();

        activeStimulus = faultDrop.Value;
        stimulusStart = simTime;
        stimulusEnd = simTime + faultDuration;

        addHistory(sprintf( ...
            '%.3f s | TEST DISTURBANCE INJECTED: %s', ...
            simTime,activeStimulus));

        statusLabel.Text = ['Status: Injected ' activeStimulus];
    end

    %% Continuous simulation
    function simulationTick(~,~)
        if ~running || ~isvalid(fig)
            return;
        end

        t = simTime + (0:nTick-1)/fs;
        v = zeros(size(t));

        for n = 1:numel(t)
            v(n) = makeVoltage(t(n));
        end

        % Simulated resistive load current.
        % In this demonstration, current follows voltage / load resistance.
        i = v/loadR;

        simTime = simTime + nTick/fs;

        tBuffer = [tBuffer t];
        vBuffer = [vBuffer v];
        iBuffer = [iBuffer i];

        keep = tBuffer >= max(0,simTime-displaySeconds);
        tBuffer = tBuffer(keep);
        vBuffer = vBuffer(keep);
        iBuffer = iBuffer(keep);

        % Update voltage and current waveforms
        lineV.XData = tBuffer;
        lineV.YData = vBuffer;
        lineI.XData = tBuffer;
        lineI.YData = iBuffer;

        xleft = max(0,simTime-displaySeconds);
        xright = max(displaySeconds,simTime);
        axV.XLim = [xleft xright];
        axI.XLim = [xleft xright];

        % One-cycle RMS measurements: 20 ms at 50 Hz.
        oneCycle = round(fs/fNom);
        count = min(oneCycle,numel(vBuffer));

        vRecent = vBuffer(end-count+1:end);
        iRecent = iBuffer(end-count+1:end);

        measuredVRMS = sqrt(mean(vRecent.^2));
        measuredIRMS = sqrt(mean(iRecent.^2));

        % Estimate frequency using positive-going zero crossings.
        % Use a longer buffer for improved stability.
        frequency = estimateFrequency(tBuffer,vBuffer);

        % Estimate THD from the latest 0.2 seconds.
        thd = estimateTHD(vBuffer,fs,fNom);

        % RMS trends
        rmsTime(end+1) = simTime;
        vRmsBuffer(end+1) = measuredVRMS;
        iRmsBuffer(end+1) = measuredIRMS;
        freqBuffer(end+1) = frequency;

        rmsKeep = rmsTime >= max(0,simTime-displaySeconds);
        lineVRms.XData = rmsTime(rmsKeep);
        lineVRms.YData = vRmsBuffer(rmsKeep);
        lineIRms.XData = rmsTime(rmsKeep);
        lineIRms.YData = iRmsBuffer(rmsKeep);
        lineF.XData = rmsTime(rmsKeep);
        lineF.YData = freqBuffer(rmsKeep);

        axR.XLim = [xleft xright];
        axF.XLim = [xleft xright];

        % Update live measurement labels
        voltageLabel.Text = sprintf('Voltage RMS: %.2f V',measuredVRMS);
        currentLabel.Text = sprintf('Current RMS: %.3f A',measuredIRMS);
        frequencyLabel.Text = sprintf('Frequency: %.2f Hz',frequency);
        thdLabel.Text = sprintf('Voltage THD: %.2f %%',100*thd);

        % Automatic detection uses measured signal features.
        % It does NOT use the selected dropdown value.
        newDetection = classifyMeasuredSignal( ...
            vBuffer,measuredVRMS,frequency,thd,fs,vNom,fNom);

        if ~strcmp(newDetection,detectedFault)
            previousDetectedFault = detectedFault;
            detectedFault = newDetection;

            if ~strcmp(detectedFault,'Normal')
                addHistory(sprintf( ...
                    '%.3f s | DETECTED: %s | V_RMS %.1f V | I_RMS %.2f A | f %.2f Hz', ...
                    simTime,detectedFault,measuredVRMS, ...
                    measuredIRMS,frequency));
                faultLabel.FontColor = [0.85 0.15 0.10];
            else
                addHistory(sprintf( ...
                    '%.3f s | Fault cleared; signal returned to normal', ...
                    simTime));
                faultLabel.FontColor = [0.10 0.45 0.20];
            end

            previousLabel.Text = ['Previous fault: ' previousDetectedFault];
            faultLabel.Text = ['Detected fault: ' detectedFault];
        end

        % Export data to MATLAB base workspace for inspection.
        assignin('base','liveTime',tBuffer(:));
        assignin('base','liveVoltage',vBuffer(:));
        assignin('base','liveCurrent',iBuffer(:));
        assignin('base','liveVoltageRMS',measuredVRMS);
        assignin('base','liveCurrentRMS',measuredIRMS);
        assignin('base','liveFrequencyHz',frequency);
        assignin('base','liveTHD',thd);
        assignin('base','liveDetectedFault',detectedFault);

        % End stimulus after its duration.
        if simTime >= stimulusEnd
            activeStimulus = 'Normal';
        end

        drawnow limitrate;
    end

    %% Fault stimulus generator
    function v = makeVoltage(t)
        phase = 2*pi*fNom*t;
        peak = vNom*sqrt(2);

        if t < stimulusStart || t >= stimulusEnd
            v = peak*sin(phase);
            return;
        end

        s = severity/100;
        elapsed = t-stimulusStart;

        switch activeStimulus
            case 'Voltage Sag'
                v = peak*(1-s)*sin(phase);

            case 'Voltage Swell'
                v = peak*(1+s)*sin(phase);

            case 'Interruption'
                v = peak*max(0,1-s)*sin(phase);

            case 'Harmonics'
                v = peak*(sin(phase) ...
                    + 0.40*s*sin(5*phase) ...
                    + 0.08*s*sin(7*phase));

            case 'Flicker'
                modulation = 1+0.30*s*sin(2*pi*8*t);
                v = peak*modulation*sin(phase);

            case 'Transient'
                transient = peak*0.8*s* ...
                    exp(-elapsed/0.015)*sin(2*pi*700*elapsed);
                v = peak*sin(phase)+transient;

            case 'Frequency Deviation'
                % Severity 10-90% gives approximately +/-0.3 to +/-2.7 Hz.
                direction = 1;
                if mod(round(simTime*10),2) == 1
                    direction = -1;
                end
                faultFreq = fNom + direction*(3*s);
                v = peak*sin(2*pi*faultFreq*t);

            otherwise
                v = peak*sin(phase);
        end
    end

    %% Frequency estimation from positive-going zero crossings
    function f = estimateFrequency(t,v)
        f = fNom;

        if numel(v) < round(0.25*fs)
            return;
        end

        % Use the last 0.3 s, if available.
        n = min(numel(v),round(0.3*fs));
        vv = v(end-n+1:end);
        tt = t(end-n+1:end);

        crossings = find(vv(1:end-1) <= 0 & vv(2:end) > 0);

        if numel(crossings) < 2
            return;
        end

        crossTimes = zeros(size(crossings));

        for q = 1:numel(crossings)
            k = crossings(q);
            dv = vv(k+1)-vv(k);

            if abs(dv) > eps
                crossTimes(q) = tt(k) + ...
                    (0-vv(k))*(tt(k+1)-tt(k))/dv;
            else
                crossTimes(q) = tt(k);
            end
        end

        periods = diff(crossTimes);
        periods = periods(periods > 0.005 & periods < 0.05);

        if ~isempty(periods)
            f = 1/median(periods);
        end
    end

    %% Total harmonic distortion estimate
    function thd = estimateTHD(v,Fs,baseFrequency)
        thd = 0;

        % A 0.2-second window gives 5 Hz FFT resolution at 5 kHz.
        N = min(numel(v),round(0.2*Fs));

        if N < round(0.1*Fs)
            return;
        end

        x = v(end-N+1:end);
        x = x-mean(x);

        % Manual Hann window avoids extra toolbox dependencies.
        win = 0.5-0.5*cos(2*pi*(0:N-1)/(N-1));
        xw = x.*win;

        X = abs(fft(xw));
        X = X(1:floor(N/2)+1);
        fAxis = (0:floor(N/2))*Fs/N;

        [~,fundIndex] = min(abs(fAxis-baseFrequency));
        fundamental = X(fundIndex);

        if fundamental < 1e-8
            return;
        end

        harmonicPower = 0;
        for h = 2:10
            target = h*baseFrequency;
            [~,idx] = min(abs(fAxis-target));
            if idx <= numel(X)
                harmonicPower = harmonicPower + X(idx)^2;
            end
        end

        thd = sqrt(harmonicPower)/fundamental;
    end

    %% Independent automatic fault classifier
    function result = classifyMeasuredSignal(v,vrms,f,thd,Fs,Vnom,Fnom)
        result = 'Normal';

        % Recent peak and RMS features.
        peakNominal = Vnom*sqrt(2);
        nCycle = min(numel(v),round(Fs/Fnom));
        recent = v(end-nCycle+1:end);
        peakMeasured = max(abs(recent));
        rmsRatio = vrms/Vnom;

        % Detect brief abnormal peaks without confusing sustained swell.
        if peakMeasured > 1.30*peakNominal && ...
                rmsRatio >= 0.80 && rmsRatio <= 1.20
            result = 'Transient';
            return;
        end

        % RMS thresholds
        if rmsRatio < 0.10
            result = 'Interruption';
            return;
        elseif rmsRatio < 0.90
            result = 'Voltage Sag';
            return;
        elseif rmsRatio > 1.10
            result = 'Voltage Swell';
            return;
        end

        % Frequency fault
        if f < Fnom-0.5
            result = 'Under-Frequency';
            return;
        elseif f > Fnom+0.5
            result = 'Over-Frequency';
            return;
        end

        % Distortion threshold
        if thd > 0.05
            result = 'Harmonics';
            return;
        end

        % Flicker: inspect cycle-to-cycle RMS variation.
        if numel(v) >= round(0.25*Fs)
            cycles = floor(numel(v)/round(Fs/Fnom));
            if cycles >= 5
                cycN = round(Fs/Fnom);
                cycleRMS = zeros(1,cycles);

                for c = 1:cycles
                    idx1 = numel(v)-cycles*cycN+(c-1)*cycN+1;
                    idx2 = idx1+cycN-1;
                    if idx1 >= 1 && idx2 <= numel(v)
                        segment = v(idx1:idx2);
                        cycleRMS(c) = sqrt(mean(segment.^2));
                    end
                end

                cycleRMS = cycleRMS(cycleRMS > 0);
                if numel(cycleRMS) >= 5
                    variation = std(cycleRMS)/max(mean(cycleRMS),eps);
                    if variation > 0.06
                        result = 'Voltage Flicker';
                        return;
                    end
                end
            end
        end
    end

    %% History
    function addHistory(message)
        history{end+1} = message;

        % Most recent event appears first.
        historyList.Items = flip(history);
        historyList.Value = historyList.Items{1};
    end

    %% Cleanup
    function closeApp(~,~)
        running = false;

        try
            if isvalid(simTimer)
                if strcmp(simTimer.Running,'on')
                    stop(simTimer);
                end
                delete(simTimer);
            end
        catch
        end

        delete(fig);
    end
end
