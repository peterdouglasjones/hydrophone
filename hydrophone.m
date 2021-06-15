classdef hydrophone < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        HPmodel                matlab.ui.container.ButtonGroup
        HPmodelHNP0200_1043    matlab.ui.control.RadioButton
        HPmodelHNP0400_1308    matlab.ui.control.RadioButton
        HPmodelHNP0400_1430    matlab.ui.control.RadioButton
        HPmodelHNR0500_1862    matlab.ui.control.RadioButton
        HPmodelHNA0400_1296    matlab.ui.control.RadioButton
        DCBgain                matlab.ui.container.ButtonGroup
        gainvalhigh            matlab.ui.control.RadioButton
        gainvallow             matlab.ui.control.RadioButton
        gainvalnone            matlab.ui.control.RadioButton
        LabelNumericEditField  matlab.ui.control.Label
        freq_in_mhz_input      matlab.ui.control.NumericEditField
        conversion_type        matlab.ui.container.ButtonGroup
        PtoV                   matlab.ui.control.RadioButton
        ItoV                   matlab.ui.control.RadioButton
        VtoP                   matlab.ui.control.RadioButton
        VtoI                   matlab.ui.control.RadioButton
        PtoI                   matlab.ui.control.RadioButton
        ItoP                   matlab.ui.control.RadioButton
        execute_button         matlab.ui.control.Button
        input_array_var        matlab.ui.control.EditField
        Label2                 matlab.ui.control.Label
        ArrayCheckBox          matlab.ui.control.CheckBox
        UITable                matlab.ui.control.Table
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
         
        end

        % Button pushed function: execute_button
        function execute_buttonButtonPushed(app, event)
            
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
Version date 21.05.26
---------------------------------------------------------------------
%}
%{

to do:
field for output on the gui

%}
            fprintf('\n');
            
            freq_in_mhz = app.freq_in_mhz_input.Value;
            input_array = str2num(app.input_array_var.Value);
            
            %Loads SenslookupHNP0400-1308.txt, SenslookupHNP0200-1043.txt, or
            %SenslookupHNR0500-1862.txt. The text file is 5 tab-delineated columns of
            %values: FREQ_MHZ, SENS_DB, SENS_VPERPA, SENS_V2CM2PERW, and CAP_PF.
            %Lookup tables must be in same folder as the program.
            if app.HPmodelHNR0500_1862.Value;
                hpvals = dlmread('SenslookupHNR0500-1862.txt','',1,0);
                hydrophone_model = 'HNR-0500';
            elseif app.HPmodelHNP0400_1308.Value;
                hpvals = dlmread('SenslookupHNP0400-1308.txt','',1,0);
                hydrophone_model = 'HNP-0400 (old)';
            elseif app.HPmodelHNP0400_1430.Value;
                hpvals = dlmread('SenslookupHNP0400-1430.txt','',1,0);
                hydrophone_model = 'HNP-0400 (new)';
            elseif app.HPmodelHNP0200_1043.Value;
                hpvals = dlmread('SenslookupHNP0200-1043.txt','',1,0);
                hydrophone_model = 'HNP-0200';
            elseif app.HPmodelHNA0400_1296.Value;
                hpvals = dlmread('SenslookupHNA0400-1296.txt','',1,0);
                hydrophone_model = 'HNA-0400';
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
            
            arrayflag = app.ArrayCheckBox.Value;
            
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
            
            output_array = zeros(1,length(input_array));
            output_table1 = strings(1,length(input_array));
            output_table2 = strings(1,length(input_array));
            sigdigscounter = zeros(1,length(input_array));
            
            for t = 1:length(input_array);
                sigdigscounter(t) = numel(num2str(input_array(t)));
            end
            sigdigsnum = max(sigdigscounter);
            
            if app.PtoV.Value;
                app.UITable.ColumnName = {'Pressure (MPa)'; 'Scope reading (mVpp)'};
                i = 1;
                while i <= length(input_array);
                    pressureval = input_array(i);
                    intensityval = ((input_array(i)*1e6).^2)/(10000*2*1500*1000); %convert from pressure to intensity
                    Vpp = 2*sqrt(2)*sqrt(kcalfactor.*intensityval);
                    mVpp = 1000.*Vpp;
                    output_array(i) = mVpp;
                    fprintf('   %6.4g MPa = %.1f mVpp\n',pressureval,mVpp);
                    output_table1(i) = num2str(input_array(i),'%6.4g');
                    output_table2(i) = num2str(output_array(i),'%.1f');
                    i = i+1;
                end
                
                if app.ArrayCheckBox.Value;
                    MPa_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
                
            elseif app.ItoV.Value;
                app.UITable.ColumnName = {'Intensity (W/cm²)'; 'Scope reading (mVpp)'};
                i = 1;
                while i <= length(input_array);
                    intensityval = input_array(i);
                    Vpp = 2*sqrt(2)*sqrt(kcalfactor.*intensityval);
                    mVpp = 1000.*Vpp;
                    output_array(i) = mVpp;
                    fprintf('   %6.4g W/cm² = %.1f mVpp\n',intensityval,mVpp);
                    output_table1(i) = num2str(input_array(i),'%6.4g');
                    output_table2(i) = num2str(output_array(i),'%.1f');
                    i = i+1;
                end
                if app.ArrayCheckBox.Value;
                    Wattspercm2_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
            elseif app.VtoP.Value;
                app.UITable.ColumnName = {'Scope reading (mVpp)'; 'Pressure (MPa)'};
                i = 1;
                while i <= length(input_array);
                    mVpp = input_array(i);
                    vpp = mVpp./1000;                %convert mVpp input to Vpp
                    vrms = vpp./2./sqrt(2);          %v=vpp/2 and /sqrt2 for rms
                    Intensity=vrms.^2./kcalfactor; %assumes plane wave conditions, time averaged
                    Pressure = sqrt(Intensity.*(10000*2*1500*1000))./(1e6); %convert to pressure
                    output_array(i) = Pressure;
                    fprintf('   %6.1f mVpp = %.4g MPa\n',mVpp,Pressure);
                    output_table1(i) = num2str(input_array(i),'%6.1f');
                    output_table2(i) = num2str(output_array(i),'%.4g');
                    i = i+1;
                end
                if app.ArrayCheckBox.Value;
                    mVpp_vs_MPa = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
                
            elseif app.VtoI.Value;
                app.UITable.ColumnName = {'Scope reading (mVpp)'; 'Intensity (W/cm²)'};
                i = 1;
                while i <= length(input_array);
                    mVpp = input_array(i);
                    vpp = mVpp./1000;                %convert mVpp input to Vpp
                    vrms = vpp./2./sqrt(2);          %v=vpp/2 and /sqrt2 for rms
                    Intensity=vrms.^2./kcalfactor;   %assumes plane wave conditions, time averaged
                    output_array(i) = Intensity;
                    fprintf('   %6.1f mVpp = %.4g W/cm²\n',mVpp,Intensity);
                    output_table1(i) = num2str(input_array(i),'%6.1f');
                    output_table2(i) = num2str(output_array(i),'%.4g');
                    i = i+1;
                end     
                if app.ArrayCheckBox.Value;
                    mVpp_vs_Wattspercm2 = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
            
            elseif app.PtoI.Value;
                app.UITable.ColumnName = {'Pressure (MPa)'; 'Intensity (W/cm²)'};
                fprintf('-------------------------------------------\n');
                fprintf(' Convert Pressures to Intensities\n');
                fprintf('-------------------------------------------\n');
                i = 1;
                while i <= length(input_array);
                    pressureval = input_array(i);
                    intensityval = ((input_array(i)*1e6).^2)/(10000*2*1500*1000); %convert from pressure to intensity
                    output_array(i) = intensityval;
                    fprintf('   %6.4g MPa = %.4g W/cm²\n',pressureval,intensityval);
                    output_table1(i) = num2str(input_array(i),'%6.4g');
                    output_table2(i) = num2str(output_array(i),'%.4g');
                    i = i+1;
                end
                if app.ArrayCheckBox.Value;
                    MPa_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
            elseif app.ItoP.Value;
                app.UITable.ColumnName = {'Intensity (W/cm²)'; 'Pressure (MPa)'};
                fprintf('-------------------------------------------\n');
                fprintf(' Convert Intensities to Pressures\n');
                fprintf('-------------------------------------------\n');
                i = 1;
                while i <= length(input_array);
                    intensityval = input_array(i);
                    pressureval = sqrt(intensityval.*(10000*2*1500*1000))./(1e6);
                    output_array(i) = pressureval;
                    fprintf('   %6.4g W/cm² = %.4g MPa\n',intensityval,pressureval);
                    output_table1(i) = num2str(input_array(i),'%6.4g');
                    output_table2(i) = num2str(output_array(i),'%.4g');
                    i = i+1;
                end
                if app.ArrayCheckBox.Value;
                    MPa_vs_mVpp = [transpose(input_array),transpose(output_array)]
                end
                fprintf('\n');
                
            end
            app.UITable.Data = [transpose(output_table1),transpose(output_table2)];
            
            
        end

        % Selection changed function: HPmodel
        function HPmodelSelectionChanged(app, event)
            selectedButton1 = app.HPmodel.SelectedObject;
            
            if app.HPmodelHNP0200_1043.Value;
                app.gainvalhigh.Value = 1;
                set(app.gainvalnone,'enable','off');
            elseif app.HPmodelHNP0400_1308.Value;
                app.gainvalhigh.Value = 1;
                set(app.gainvalnone,'enable','off');
            elseif app.HPmodelHNP0400_1430.Value;
                app.gainvalhigh.Value = 1;
                set(app.gainvalnone,'enable','off');
            elseif app.HPmodelHNR0500_1862.Value;
                set(app.gainvalnone,'enable','on');
            elseif app.HPmodelHNA0400_1296.Value;
                set(app.gainvalnone,'enable','off');
                
            end
            
        end

        % Selection changed function: DCBgain
        function DCBgainSelectionChanged(app, event)
            selectedButton2 = app.DCBgain.SelectedObject;
            
        end

        % Value changed function: freq_in_mhz_input
        function freq_in_mhz_inputValueChanged(app, event)
            value1 = app.freq_in_mhz_input.Value;
            
        end

        % Selection changed function: conversion_type
        function conversion_typeSelectionChanged(app, event)
            selectedButton3 = app.conversion_type.SelectedObject;
            
            if app.PtoV.Value;
                app.Label2.Text = 'Input pressures in MPa, space-separated:';
            elseif app.ItoV.Value;
                app.Label2.Text = 'Input intensities in W/cm², space-separated:';
            elseif app.VtoP.Value;
                app.Label2.Text = 'Input voltages in mVpp, space-separated:';
            elseif app.VtoI.Value;
                app.Label2.Text = 'Input voltages in mVpp, space-separated:';
            elseif app.PtoI.Value;
                app.Label2.Text = 'Input pressures in MPa, space-separated:';
            elseif app.ItoP.Value;
                app.Label2.Text = 'Input intensities in W/cm², space-separated:';
            end
            
        end

        % Callback function
        function input_number_varValueChanged(app, event)
            value2 = app.input_number_var.Value;
            
        end

        % Value changed function: ArrayCheckBox
        function ArrayCheckBoxValueChanged(app, event)
            value = app.ArrayCheckBox.Value;
            arrayflag = app.ArrayCheckBox.Value;
        end

        % Value changed function: input_array_var
        function input_array_varValueChanged(app, event)
            value8 = app.input_array_var.Value;
            
%             currChar = get(handles.UIFigure,'CurrentCharacter');
%             if isequal(currChar,char(13)) %char(13) == enter key
%                 fprinf('k');
%             end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [101 101 356 697];
            app.UIFigure.Name = 'Hydrophone V/P/I Conversions v1.2';

            % Create HPmodel
            app.HPmodel = uibuttongroup(app.UIFigure);
            app.HPmodel.SelectionChangedFcn = createCallbackFcn(app, @HPmodelSelectionChanged, true);
            app.HPmodel.Title = 'Hydrophone model';
            app.HPmodel.Position = [47 531 136 145];

            % Create HPmodelHNP0200_1043
            app.HPmodelHNP0200_1043 = uiradiobutton(app.HPmodel);
            app.HPmodelHNP0200_1043.Text = 'HNP-0200 [1043]';
            app.HPmodelHNP0200_1043.Position = [11 95 115 22];

            % Create HPmodelHNP0400_1308
            app.HPmodelHNP0400_1308 = uiradiobutton(app.HPmodel);
            app.HPmodelHNP0400_1308.Text = 'HNP-0400 [1308]';
            app.HPmodelHNP0400_1308.Position = [11 73 115 22];

            % Create HPmodelHNP0400_1430
            app.HPmodelHNP0400_1430 = uiradiobutton(app.HPmodel);
            app.HPmodelHNP0400_1430.Text = 'HNP-0400 [1430]';
            app.HPmodelHNP0400_1430.Position = [11 51 115 22];

            % Create HPmodelHNR0500_1862
            app.HPmodelHNR0500_1862 = uiradiobutton(app.HPmodel);
            app.HPmodelHNR0500_1862.Text = 'HNR-0500 [1862]';
            app.HPmodelHNR0500_1862.Position = [11 29 115 22];

            % Create HPmodelHNA0400_1296
            app.HPmodelHNA0400_1296 = uiradiobutton(app.HPmodel);
            app.HPmodelHNA0400_1296.Text = 'HNA-0400 [1296]';
            app.HPmodelHNA0400_1296.Position = [11 6 115 22];
            app.HPmodelHNA0400_1296.Value = true;

            % Create DCBgain
            app.DCBgain = uibuttongroup(app.UIFigure);
            app.DCBgain.SelectionChangedFcn = createCallbackFcn(app, @DCBgainSelectionChanged, true);
            app.DCBgain.Title = 'DC Block Gain';
            app.DCBgain.Position = [193 558 123 106];

            % Create gainvalhigh
            app.gainvalhigh = uiradiobutton(app.DCBgain);
            app.gainvalhigh.Text = 'High';
            app.gainvalhigh.Position = [11 60 45 16];
            app.gainvalhigh.Value = true;

            % Create gainvallow
            app.gainvallow = uiradiobutton(app.DCBgain);
            app.gainvallow.Text = 'Low';
            app.gainvallow.Position = [11 38 42 16];

            % Create gainvalnone
            app.gainvalnone = uiradiobutton(app.DCBgain);
            app.gainvalnone.Enable = 'off';
            app.gainvalnone.Text = 'None';
            app.gainvalnone.Position = [11 16 49 16];

            % Create LabelNumericEditField
            app.LabelNumericEditField = uilabel(app.UIFigure);
            app.LabelNumericEditField.HorizontalAlignment = 'right';
            app.LabelNumericEditField.VerticalAlignment = 'top';
            app.LabelNumericEditField.Position = [77 501 94 15];
            app.LabelNumericEditField.Text = 'Frequency (MHz)';

            % Create freq_in_mhz_input
            app.freq_in_mhz_input = uieditfield(app.UIFigure, 'numeric');
            app.freq_in_mhz_input.Limits = [0 200];
            app.freq_in_mhz_input.ValueDisplayFormat = '%.2f';
            app.freq_in_mhz_input.ValueChangedFcn = createCallbackFcn(app, @freq_in_mhz_inputValueChanged, true);
            app.freq_in_mhz_input.Position = [186 497 100 22];
            app.freq_in_mhz_input.Value = 1;

            % Create conversion_type
            app.conversion_type = uibuttongroup(app.UIFigure);
            app.conversion_type.SelectionChangedFcn = createCallbackFcn(app, @conversion_typeSelectionChanged, true);
            app.conversion_type.BorderType = 'none';
            app.conversion_type.Position = [33 344 301 150];

            % Create PtoV
            app.PtoV = uiradiobutton(app.conversion_type);
            app.PtoV.Text = 'Determine voltages for desired peak pressures';
            app.PtoV.Position = [11 124 273 16];
            app.PtoV.Value = true;

            % Create ItoV
            app.ItoV = uiradiobutton(app.conversion_type);
            app.ItoV.Text = 'Determine voltages for desired intensities';
            app.ItoV.Position = [11 102 301.109375 16];

            % Create VtoP
            app.VtoP = uiradiobutton(app.conversion_type);
            app.VtoP.Text = 'Calculate peak pressures from voltage readings';
            app.VtoP.Position = [11 80 279 16];

            % Create VtoI
            app.VtoI = uiradiobutton(app.conversion_type);
            app.VtoI.Text = 'Calculate intensities from voltage readings';
            app.VtoI.Position = [11 57 301.453125 16];

            % Create PtoI
            app.PtoI = uiradiobutton(app.conversion_type);
            app.PtoI.Text = 'Convert pressures to intensities';
            app.PtoI.Position = [11 34 190 16];

            % Create ItoP
            app.ItoP = uiradiobutton(app.conversion_type);
            app.ItoP.Text = 'Convert intensities to pressures';
            app.ItoP.Position = [11 12 190 16];

            % Create execute_button
            app.execute_button = uibutton(app.UIFigure, 'push');
            app.execute_button.ButtonPushedFcn = createCallbackFcn(app, @execute_buttonButtonPushed, true);
            app.execute_button.BackgroundColor = [0.8 0.8 0.8];
            app.execute_button.Position = [132 215 100 22];
            app.execute_button.Text = 'Calculate';

            % Create input_array_var
            app.input_array_var = uieditfield(app.UIFigure, 'text');
            app.input_array_var.ValueChangedFcn = createCallbackFcn(app, @input_array_varValueChanged, true);
            app.input_array_var.Position = [43 285 273 22];

            % Create Label2
            app.Label2 = uilabel(app.UIFigure);
            app.Label2.HorizontalAlignment = 'center';
            app.Label2.VerticalAlignment = 'top';
            app.Label2.Position = [53 301 255 22];
            app.Label2.Text = 'Input pressures in MPa, space-separated:';

            % Create ArrayCheckBox
            app.ArrayCheckBox = uicheckbox(app.UIFigure);
            app.ArrayCheckBox.ValueChangedFcn = createCallbackFcn(app, @ArrayCheckBoxValueChanged, true);
            app.ArrayCheckBox.Text = 'Print output array for copy/paste';
            app.ArrayCheckBox.FontSize = 9;
            app.ArrayCheckBox.Position = [108 265 154 16];

            % Create UITable
            app.UITable = uitable(app.UIFigure);
            app.UITable.ColumnName = {'Input'; 'Output'};
            app.UITable.RowName = {};
            app.UITable.Position = [33 24 301 162];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = hydrophone

            % Create UIFigure and components
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