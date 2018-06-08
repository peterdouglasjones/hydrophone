classdef hydrophone < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure                   % Hydropho...
        HPmodel               matlab.ui.container.ButtonGroup    % Hydropho...
        HPmodel0200           matlab.ui.control.RadioButton      % HNP-0200
        HPmodel0400old        matlab.ui.control.RadioButton      % HNP-0400...
        HPmodel0400new        matlab.ui.control.RadioButton      % HNP-0400...
        DCBgain               matlab.ui.container.ButtonGroup    % DC Block...
        gainvalhigh           matlab.ui.control.RadioButton      % High
        gainvallow            matlab.ui.control.RadioButton      % Low
        gainvalnone           matlab.ui.control.RadioButton      % None
        LabelNumericEditField matlab.ui.control.Label            % Frequenc...
        freq_in_mhz_input     matlab.ui.control.NumericEditField % [0 200]
        conversion_type       matlab.ui.container.ButtonGroup   
        PtoV                  matlab.ui.control.RadioButton      % Determin...
        ItoV                  matlab.ui.control.RadioButton      % Determin...
        VtoP                  matlab.ui.control.RadioButton      % Calculat...
        VtoI                  matlab.ui.control.RadioButton      % Calculat...
        execute_button        matlab.ui.control.Button           % Calculate
        input_array_var       matlab.ui.control.EditField       
        Label2                matlab.ui.control.Label            % Input pr...
        CheckBox              matlab.ui.control.CheckBox         % Print ou...
        HPmodel0500           matlab.ui.control.RadioButton      % HNP-0500
        PtoI                  matlab.ui.control.RadioButton      % Convert ...
        ItoP                  matlab.ui.control.RadioButton      % Convert ...
    end

    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

        end

        % execute_button button pushed function
        function execute_buttonButtonPushed(app)
            
            %{
Instructions for code editing: edit as mlapp in matlab "appdesigner". Use mlapp2classdef.m to
convert to .m file after each update. Upload both files to GitHub.
            
Combines previously developed calculations in HydroCalcSN042013Rev2016.m
with lookup tables of calibration factors for the HNP-0200, HNP-0400, or
HNR-0500 hydrophones and AH-2020 DC block and preamp to calculate the
kcalfactor for a specific ultrasound frequency and gain. Uses linear
interpolation of lookup tables to derive approximate calibration factors
for given freq. Uses kcalfactor to convert between peak pressure values 
(one sided, not peak-to-peak, assuming equivalent positive/negative peak 
pressure), intensity values, and oscope voltage readings.
            
Peter Jones, Matthew Adams, Chris Diederich
Version 18.02.01
---------------------------------------------------------------------
%}
%{

to do:
field for output on the gui

%}
            fprintf('\n');
            
            freq_in_mhz = app.freq_in_mhz_input.Value;
            input_array = str2num(app.input_array_var.Value);
            
            %Loads SenslookupHNP0400.txt, SenslookupHNP0200.txt, or
            %SenslookupHNR0500.txt. The text file is 5 tab-delineated columns of
            %values: FREQ_MHZ, SENS_DB, SENS_VPERPA, SENS_V2CM2PERW, and CAP_PF.
            if app.HPmodel0500.Value;
                hpvals = dlmread('SenslookupHNR0500.txt','',1,0);
                hydrophone_model = 'HNR-0500';
            elseif app.HPmodel0400old.Value;
                hpvals = dlmread('SenslookupHNP0400.txt','',1,0);
                hydrophone_model = 'HNP-0400 (old)';
            elseif app.HPmodel0400new.Value;
                hpvals = dlmread('SenslookupHNP0400-1430.txt','',1,0);
                hydrophone_model = 'HNP-0400 (new)';
            elseif app.HPmodel0200.Value;
                hpvals = dlmread('SenslookupHNP0200.txt','',1,0);
                hydrophone_model = 'HNP-0200';
            end
            
            %Ensure query frequency falls within bounds of hydrophone calibration data,
            %if not, set to closest limit frequency.
            if freq_in_mhz < min(hpvals(:,1))
                freq_in_mhz_h = min(hpvals(:,1));
                fprintf(' WARNING: frequency below minimum hydrophone calibration. Using %2.2f MHz.\n', freq_in_mhz_h)
            elseif freq_in_mhz > max(hpvals(:,1))
                freq_in_mhz_h = max(hpvals(:,1));
                fprintf(' WARNING: frequency above maximum hydrophone calibration. Using %2.2f MHz.\n', freq_in_mhz_h)
            else
                freq_in_mhz_h = freq_in_mhz;
            end
            
            %Uses AH2020_senslookup.txt to look up values at freq using interpolation
            %for the DC block and preamp. The text file is 7 tab-delineated columns of
            %values: FREQ_MHZ, GAIN_DBHIGH,	PHASE_DEGHIGH, CAP_PREAMPHIGH, GAIN_DBLOW
            %PHASE_DEGLOW, and CAP_PREAMPLOW.
            pavals = dlmread('SenslookupAH2020.txt','',1,0);
            
            %Ensure query frequency falls within bounds of preamp calibration data,
            %if not, set to closest limit frequency.
            if freq_in_mhz < min(pavals(:,1))
                freq_in_mhz_p = min(pavals(:,1));
                fprintf(' WARNING: frequency below minimum preamp calibration. Using %2.2f MHz.\n', freq_in_mhz_p)
            elseif freq_in_mhz > max(pavals(:,1))
                freq_in_mhz_p = max(pavals(:,1));
                fprintf(' WARNING: frequency above maximum preamp calibration. Using %2.2f MHz.\n', freq_in_mhz_p)
            else
                freq_in_mhz_p = freq_in_mhz;
            end
            
            %Pull CAP_PF and SENS_VPERPA at the frequency specified.
            caphydro = interp1(hpvals(:,1),hpvals(:,5),freq_in_mhz_h,'linear');
            mc = interp1(hpvals(:,1),hpvals(:,3),freq_in_mhz_h,'linear');
            zacoustic=1.5e10; %impedance of water - includes unit correction for cm
            
            %Pull CAP_PREAMP and GAIN_DB for either high, low, or no gain.
            if app.gainvallow.Value;
                gaintext = ['Low'];
                capamp = interp1(pavals(:,1),pavals(:,7),freq_in_mhz_p,'linear');
                gaindB = interp1(pavals(:,1),pavals(:,5),freq_in_mhz_p,'linear');
                gain=10.^(gaindB./20); %converting dB to amplitude
                ml=mc.*gain.*caphydro./(caphydro+capamp);
                kcalfactor=zacoustic.*(ml).^2;
            elseif app.gainvalhigh.Value;
                gaintext = ['High'];
                capamp = interp1(pavals(:,1),pavals(:,4),freq_in_mhz_p,'linear');
                gaindB = interp1(pavals(:,1),pavals(:,2),freq_in_mhz_p,'linear');
                gain=10.^(gaindB./20); %converting dB to amplitude
                ml=mc.*gain.*caphydro./(caphydro+capamp);
                kcalfactor=zacoustic.*(ml).^2;
            elseif app.gainvalnone.Value;
                gaintext = ['No'];
                capamp = interp1(pavals(:,1),pavals(:,4),freq_in_mhz_p,'linear');
                gaindB = interp1(pavals(:,1),pavals(:,2),freq_in_mhz_p,'linear');
                ml = mc;
                kcalfactor = zacoustic.*(mc).^2;
            end
            
            arrayflag = app.CheckBox.Value;
            
            if app.PtoV.Value || app.ItoV.Value || app.VtoP.Value || app.VtoI.Value;
                fprintf('\n');
                fprintf('--------------------------------------------------------------------------\n');
                fprintf(' %s gain calibration values for %s hydrophone at %3.2f MHz\n',gaintext,hydrophone_model,freq_in_mhz);
                fprintf(' Hydrophone capacitance: %.3f pF\n',caphydro);
                fprintf(' MC Hydrophone EOC Sensitivity: %e V/Pa, peak\n',mc);
                fprintf(' ML Calibrated Pressure Sensitivity: %e V/Pa, peak\n',ml);
                fprintf(' Kcalfactor = %e V²cm²/W\n',kcalfactor);
                fprintf('--------------------------------------------------------------------------\n');
            end
            
            if app.PtoV.Value;
                i = 1;
                output_array = [];
                while i <= length(input_array);
                    pressureval = input_array(i);
                    intensityval = ((input_array(i)*1e6).^2)/(10000*2*1500*1000); %convert from pressure to intensity
                    Vpp = 2*sqrt(2)*sqrt(kcalfactor.*intensityval);
                    mVpp = 1000.*Vpp;
                    output_array(i) = mVpp;
                    fprintf('   %6.4g MPa = %.1f mVpp\n',pressureval,mVpp);
                    i = i+1;
                end
                if app.CheckBox.Value;
                    MPa_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
                
            elseif app.ItoV.Value;
                i = 1;
                output_array = [];
                while i <= length(input_array);
                    intensityval = input_array(i);
                    Vpp = 2*sqrt(2)*sqrt(kcalfactor.*intensityval);
                    mVpp = 1000.*Vpp;
                    output_array(i) = mVpp;
                    fprintf('   %6.4g W/cm² = %.1f mVpp\n',intensityval,mVpp);
                    i = i+1;
                end
                if app.CheckBox.Value;
                    Wattspercm2_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
            elseif app.VtoP.Value;
                i = 1;
                output_array = [];
                while i <= length(input_array);
                    mVpp = input_array(i);
                    vpp = mVpp./1000;                %convert mVpp input to Vpp
                    vrms = vpp./2./sqrt(2);          %v=vpp/2 and /sqrt2 for rms
                    Intensity=vrms.^2./kcalfactor; %assumes plane wave conditions, time averaged
                    Pressure = sqrt(Intensity.*(10000*2*1500*1000))./(1e6); %convert to pressure
                    output_array(i) = Pressure;
                    fprintf('   %6.1f mVpp = %.4g MPa\n',mVpp,Pressure);
                    i = i+1;
                end
                if app.CheckBox.Value;
                    mVpp_vs_MPa = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
                
            elseif app.VtoI.Value;
                i = 1;
                output_array = [];
                while i <= length(input_array);
                    mVpp = input_array(i);
                    vpp = mVpp./1000;                %convert mVpp input to Vpp
                    vrms = vpp./2./sqrt(2);          %v=vpp/2 and /sqrt2 for rms
                    Intensity=vrms.^2./kcalfactor;   %assumes plane wave conditions, time averaged
                    output_array(i) = Intensity;
                    fprintf('   %6.1f mVpp = %.4g W/cm²\n',mVpp,Intensity);
                    i = i+1;
                end     
                if app.CheckBox.Value;
                    mVpp_vs_Wattspercm2 = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
            
            elseif app.PtoI.Value;
                fprintf('-------------------------------------------\n');
                fprintf(' Convert Pressures to Intensities\n');
                fprintf('-------------------------------------------\n');
                i = 1;
                output_array = [];
                while i <= length(input_array);
                    pressureval = input_array(i);
                    intensityval = ((input_array(i)*1e6).^2)/(10000*2*1500*1000); %convert from pressure to intensity
                    output_array(i) = intensityval;
                    fprintf('   %6.4g MPa = %.4g W/cm²\n',pressureval,intensityval);
                    i = i+1;
                end
                if app.CheckBox.Value;
                    MPa_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
            elseif app.ItoP.Value;
                fprintf('-------------------------------------------\n');
                fprintf(' Convert Intensities to Pressures\n');
                fprintf('-------------------------------------------\n');
                i = 1;
                output_array = [];
                while i <= length(input_array);
                    intensityval = input_array(i);
                    pressureval = sqrt(intensityval.*(10000*2*1500*1000))./(1e6);
                    output_array(i) = pressureval;
                    fprintf('   %6.4g W/cm² = %.4g MPa\n',intensityval,pressureval);
                    i = i+1;
                end
                if app.CheckBox.Value;
                    MPa_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
            end
            
            
        end

        % HPmodel selection change function
        function HPmodelSelectionChanged(app, event)
            selectedButton1 = app.HPmodel.SelectedObject;
            
            if app.HPmodel0200.Value;
                app.gainvalhigh.Value = 1;
                set(app.gainvalnone,'enable','off');
            elseif app.HPmodel0400old.Value;
                app.gainvalhigh.Value = 1;
                set(app.gainvalnone,'enable','off');
            elseif app.HPmodel0400new.Value;
                app.gainvalhigh.Value = 1;
                set(app.gainvalnone,'enable','off');
            elseif app.HPmodel0500.Value;
                set(app.gainvalnone,'enable','on');
            end
            
        end

        % DCBgain selection change function
        function DCBgainSelectionChanged(app, event)
            selectedButton2 = app.DCBgain.SelectedObject;
            
        end

        % freq_in_mhz_input value changed function
        function freq_in_mhz_inputValueChanged(app)
            value1 = app.freq_in_mhz_input.Value;
            
        end

        % conversion_type selection change function
        function conversion_typeSelectionChanged(app, event)
            selectedButton3 = app.conversion_type.SelectedObject;
            
            if app.PtoV.Value;
                app.Label2.Text = 'Input pressures in MPa, comma-separated:';
            elseif app.ItoV.Value;
                app.Label2.Text = 'Input intensities in W/cm², comma-separated:';
            elseif app.VtoP.Value;
                app.Label2.Text = 'Input voltages in mVpp, comma-separated:';
            elseif app.VtoI.Value;
                app.Label2.Text = 'Input voltages in mVpp, comma-separated:';
            elseif app.PtoI.Value;
                app.Label2.Text = 'Input pressures in MPa, comma-separated:';
            elseif app.ItoP.Value;
                app.Label2.Text = 'Input intensities in W/cm², comma-separated:';
            end
            
        end

        % input_number_var value changed function
        function input_number_varValueChanged(app)
            value2 = app.input_number_var.Value;
            
        end

        % CheckBox value changed function
        function CheckBoxValueChanged(app)
            value = app.CheckBox.Value;
            arrayflag = app.CheckBox.Value;
        end

        % input_array_var value changed function
        function input_array_varValueChanged(app)
            value8 = app.input_array_var.Value;
            
%             currChar = get(handles.UIFigure,'CurrentCharacter');
%             if isequal(currChar,char(13)) %char(13) == enter key
%                 fprinf('k');
%             end
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure;
            app.UIFigure.Position = [100 100 359 520];
            app.UIFigure.Name = 'Hydrophone V/P/I Conversions v1.1';
            setAutoResize(app, app.UIFigure, true)

            % Create HPmodel
            app.HPmodel = uibuttongroup(app.UIFigure);
            app.HPmodel.SelectionChangedFcn = createCallbackFcn(app, @HPmodelSelectionChanged, true);
            app.HPmodel.BorderType = 'line';
            app.HPmodel.Title = 'Hydrophone model';
            app.HPmodel.FontName = 'Helvetica';
            app.HPmodel.FontUnits = 'pixels';
            app.HPmodel.FontSize = 12;
            app.HPmodel.Units = 'pixels';
            app.HPmodel.Position = [46 368 136 130];

            % Create HPmodel0200
            app.HPmodel0200 = uiradiobutton(app.HPmodel);
            app.HPmodel0200.Text = 'HNP-0200';
            app.HPmodel0200.Position = [10 83 77 16];

            % Create HPmodel0400old
            app.HPmodel0400old = uiradiobutton(app.HPmodel);
            app.HPmodel0400old.Value = true;
            app.HPmodel0400old.Text = 'HNP-0400 (old)';
            app.HPmodel0400old.Position = [10 61 105 16];

            % Create HPmodel0400new
            app.HPmodel0400new = uiradiobutton(app.HPmodel);
            app.HPmodel0400new.Text = 'HNP-0400 (new)';
            app.HPmodel0400new.Position = [10 39 111 16];

            % Create HPmodel0500
            app.HPmodel0500 = uiradiobutton(app.HPmodel);
            app.HPmodel0500.Text = 'HNP-0500';
            app.HPmodel0500.Position = [10 16 77 16];

            % Create DCBgain
            app.DCBgain = uibuttongroup(app.UIFigure);
            app.DCBgain.SelectionChangedFcn = createCallbackFcn(app, @DCBgainSelectionChanged, true);
            app.DCBgain.BorderType = 'line';
            app.DCBgain.Title = 'DC Block Gain';
            app.DCBgain.FontName = 'Helvetica';
            app.DCBgain.FontUnits = 'pixels';
            app.DCBgain.FontSize = 12;
            app.DCBgain.Units = 'pixels';
            app.DCBgain.Position = [192 380 123 106];

            % Create gainvalhigh
            app.gainvalhigh = uiradiobutton(app.DCBgain);
            app.gainvalhigh.Value = true;
            app.gainvalhigh.Text = 'High';
            app.gainvalhigh.Position = [10 59 45 16];

            % Create gainvallow
            app.gainvallow = uiradiobutton(app.DCBgain);
            app.gainvallow.Text = 'Low';
            app.gainvallow.Position = [10 37 42 16];

            % Create gainvalnone
            app.gainvalnone = uiradiobutton(app.DCBgain);
            app.gainvalnone.Enable = 'off';
            app.gainvalnone.Text = 'None';
            app.gainvalnone.Position = [10 15 49 16];

            % Create LabelNumericEditField
            app.LabelNumericEditField = uilabel(app.UIFigure);
            app.LabelNumericEditField.HorizontalAlignment = 'right';
            app.LabelNumericEditField.Position = [76 323 94 15];
            app.LabelNumericEditField.Text = 'Frequency (MHz)';

            % Create freq_in_mhz_input
            app.freq_in_mhz_input = uieditfield(app.UIFigure, 'numeric');
            app.freq_in_mhz_input.ValueChangedFcn = createCallbackFcn(app, @freq_in_mhz_inputValueChanged);
            app.freq_in_mhz_input.Limits = [0 200];
            app.freq_in_mhz_input.Position = [185 319 100 22];
            app.freq_in_mhz_input.Value = 1;

            % Create conversion_type
            app.conversion_type = uibuttongroup(app.UIFigure);
            app.conversion_type.SelectionChangedFcn = createCallbackFcn(app, @conversion_typeSelectionChanged, true);
            app.conversion_type.BorderType = 'none';
            app.conversion_type.FontName = 'Helvetica';
            app.conversion_type.FontUnits = 'pixels';
            app.conversion_type.FontSize = 12;
            app.conversion_type.Units = 'pixels';
            app.conversion_type.Position = [32 166 301 150];

            % Create PtoV
            app.PtoV = uiradiobutton(app.conversion_type);
            app.PtoV.Value = true;
            app.PtoV.Text = 'Determine voltages for desired peak pressures';
            app.PtoV.Position = [10 123 273 16];

            % Create ItoV
            app.ItoV = uiradiobutton(app.conversion_type);
            app.ItoV.Text = 'Determine voltages for desired intensities';
            app.ItoV.Position = [10 101 301.109375 16];

            % Create VtoP
            app.VtoP = uiradiobutton(app.conversion_type);
            app.VtoP.Text = 'Calculate peak pressures from voltage readings';
            app.VtoP.Position = [10 79 279 16];

            % Create VtoI
            app.VtoI = uiradiobutton(app.conversion_type);
            app.VtoI.Text = 'Calculate intensities from voltage readings';
            app.VtoI.Position = [10 56 301.453125 16];

            % Create PtoI
            app.PtoI = uiradiobutton(app.conversion_type);
            app.PtoI.Text = 'Convert pressures to intensities';
            app.PtoI.Position = [10 33 190 16];

            % Create ItoP
            app.ItoP = uiradiobutton(app.conversion_type);
            app.ItoP.Text = 'Convert intensities to pressures';
            app.ItoP.Position = [10 11 190 16];

            % Create execute_button
            app.execute_button = uibutton(app.UIFigure, 'push');
            app.execute_button.ButtonPushedFcn = createCallbackFcn(app, @execute_buttonButtonPushed);
            app.execute_button.Position = [131 37 100 22];
            app.execute_button.Text = 'Calculate';

            % Create input_array_var
            app.input_array_var = uieditfield(app.UIFigure, 'text');
            app.input_array_var.ValueChangedFcn = createCallbackFcn(app, @input_array_varValueChanged);
            app.input_array_var.Position = [42.03125 107 273 22];

            % Create Label2
            app.Label2 = uilabel(app.UIFigure);
            app.Label2.HorizontalAlignment = 'center';
            app.Label2.Position = [52 130 255 15];
            app.Label2.Text = 'Input pressures in MPa, comma-separated:';

            % Create CheckBox
            app.CheckBox = uicheckbox(app.UIFigure);
            app.CheckBox.ValueChangedFcn = createCallbackFcn(app, @CheckBoxValueChanged);
            app.CheckBox.Text = 'Print output array for copy/paste';
            app.CheckBox.FontSize = 9;
            app.CheckBox.Position = [107 87 154 16];
        end
    end

    methods (Access = public)

        % Construct app
        function app = hydrophone()

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end

