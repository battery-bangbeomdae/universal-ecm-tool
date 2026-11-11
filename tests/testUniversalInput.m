classdef testUniversalInput < matlab.unittest.TestCase
    properties (TestParameter)
        HeaderStyle = {'bracket','prime','korean','polar'}
        FileFormat = {'comma','semicolon','tab','xlsx'}
        FrequencyUnit = {'Hz','kHz','mHz','MHz'}
        TimeUnit = {'s','ms','min','h'}
        ImpedanceUnit = {'Ohm','mOhm','uOhm','kOhm','MOhm'}
        ElectricalScale = {'SI','milli','micro'}
    end
    properties
        Root
        Folder
        EIS
        HPPC
    end
    methods (TestMethodSetup)
        function realMeasurementFixtures(testCase)
            testCase.Root=string(fileparts(fileparts(mfilename('fullpath'))));addpath(testCase.Root);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder=string(fixture.Folder);
            input=uecm.readInput(fullfile(testCase.Root,'examples','REAL_D010_eis_12spectra.csv'));
            prepared=uecm.prepare(input);key=prepared.Data.spectrum(1);
            testCase.EIS=prepared.Data(prepared.Data.spectrum==key,:);
            options=uecm.defaults();options.CurrentSign="charge_positive";
            prepared=uecm.prepare(uecm.readInput(fullfile(testCase.Root,'examples','REAL_D014_hppc_one_pulse.csv'),options));
            testCase.HPPC=prepared.Data;
        end
    end
    methods (Test)
        function commonHeaderFormsRetainComplexImpedance(testCase,HeaderStyle)
            tableData=testCase.eisTable(HeaderStyle);
            file=fullfile(testCase.Folder,'headers.csv');writetable(tableData,file,'Encoding','UTF-8');
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.real,testCase.EIS.real,'AbsTol',1e-12);
            testCase.verifyEqual(prepared.Data.imag,testCase.EIS.imag,'AbsTol',1e-12);
        end
        function commonFileFormatsRetainRows(testCase,FileFormat)
            data=testCase.eisTable('bracket');file=testCase.writeFormat(data,FileFormat);
            input=uecm.readInput(file);prepared=uecm.prepare(input);
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(height(input.Data),height(data));
            testCase.verifyEqual(prepared.Data.frequency,testCase.EIS.frequency,'RelTol',1e-12);
        end
        function frequencyPrefixesRemainDistinct(testCase,FrequencyUnit)
            factors=struct('Hz',1,'kHz',1e3,'mHz',1e-3,'MHz',1e6);
            data=table(testCase.EIS.frequency/factors.(FrequencyUnit),testCase.EIS.real,testCase.EIS.imag, ...
                'VariableNames',["Freq ["+FrequencyUnit+"]","z_real_ohm","z_imag_ohm"]);
            file=fullfile(testCase.Folder,'si.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.frequency,testCase.EIS.frequency,'RelTol',1e-12);
        end
        function timeAndElectricalUnitsAreConverted(testCase,TimeUnit)
            factors=struct('s',1,'ms',.001,'min',60,'h',3600);
            data=table(testCase.HPPC.time/factors.(TimeUnit),testCase.HPPC.current*1000,testCase.HPPC.voltage*1000, ...
                'VariableNames',["Time ["+TimeUnit+"]","Current [mA]","Voltage [mV]"]);
            file=fullfile(testCase.Folder,'pulse.csv');writetable(data,file);
            options=uecm.defaults();options.CurrentSign="discharge_positive";
            prepared=uecm.prepare(uecm.readInput(file,options));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.time,testCase.HPPC.time,'AbsTol',1e-8);
            testCase.verifyEqual(prepared.Data.current,testCase.HPPC.current,'AbsTol',1e-12);
            testCase.verifyEqual(prepared.Data.voltage,testCase.HPPC.voltage,'AbsTol',1e-12);
        end
        function impedancePrefixesRemainDistinct(testCase,ImpedanceUnit)
            factors=struct('Ohm',1,'mOhm',.001,'uOhm',1e-6,'kOhm',1e3,'MOhm',1e6);
            data=table(testCase.EIS.frequency,testCase.EIS.real/factors.(ImpedanceUnit),testCase.EIS.imag/factors.(ImpedanceUnit), ...
                'VariableNames',["Frequency [Hz]","Re(Z) ["+ImpedanceUnit+"]","Im(Z) ["+ImpedanceUnit+"]"]);
            file=fullfile(testCase.Folder,'impedance_units.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.real,testCase.EIS.real,'AbsTol',1e-12);
            testCase.verifyEqual(prepared.Data.imag,testCase.EIS.imag,'AbsTol',1e-12);
        end
        function electricalPrefixesRemainDistinct(testCase,ElectricalScale)
            current=struct('SI',"A",'milli',"mA",'micro',"uA");
            voltage=struct('SI',"V",'milli',"mV",'micro',"uV");
            factors=struct('SI',1,'milli',.001,'micro',1e-6);
            data=table(testCase.HPPC.time,testCase.HPPC.current/factors.(ElectricalScale),testCase.HPPC.voltage/factors.(ElectricalScale), ...
                'VariableNames',["Test Time (s)","I ["+current.(ElectricalScale)+"]","U ["+voltage.(ElectricalScale)+"]"]);
            file=fullfile(testCase.Folder,'electrical_units.csv');writetable(data,file);
            options=uecm.defaults();options.CurrentSign="discharge_positive";
            prepared=uecm.prepare(uecm.readInput(file,options));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.current,testCase.HPPC.current,'AbsTol',1e-12);
            testCase.verifyEqual(prepared.Data.voltage,testCase.HPPC.voltage,'AbsTol',1e-12);
        end
        function percentFractionAndKelvinAreExplicit(testCase)
            data=testCase.eisTable('bracket');
            data.("SOC [fraction]")=testCase.EIS.soc/100;
            data.("Temperature [K]")=testCase.EIS.temperature+273.15;
            file=fullfile(testCase.Folder,'conditions.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.soc,testCase.EIS.soc,'AbsTol',1e-12);
            testCase.verifyEqual(prepared.Data.temperature,testCase.EIS.temperature,'AbsTol',1e-12);
        end
        function decimalCommaNeedsExplicitSelection(testCase)
            data=testCase.eisTable('bracket');file=fullfile(testCase.Folder,'decimal.csv');
            writetable(data,file,'Delimiter',';');text=fileread(file);writelines(replace(string(text),".",","),file);
            options=uecm.defaults();options.DecimalSeparator=",";
            prepared=uecm.prepare(uecm.readInput(file,options));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.real,testCase.EIS.real,'AbsTol',1e-12);
        end
        function spreadsheetSheetSelectionAndConditionJoin(testCase)
            data=testCase.eisTable('bracket');data.("Sweep ID")=testCase.EIS.spectrum;
            conditions=table(testCase.EIS.spectrum(1),testCase.EIS.soc(1), ...
                'VariableNames',["spectrum_id","SOC [%]"]);
            file=fullfile(testCase.Folder,'book.xlsx');
            writetable(data,file,'Sheet','signals');writetable(conditions,file,'Sheet','conditions');
            automatic=uecm.readInput(file);
            testCase.verifyEqual(height(automatic.Data),height(data));
            testCase.verifyEqual(unique(string(automatic.Data.raw_sheet)),"signals");
            options=uecm.defaults();options.Sheet="signals";options.MetadataSheet="conditions";
            prepared=uecm.prepare(uecm.readInput(file,options,file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.soc,testCase.EIS.soc);
        end
        function duplicateMeaningsAreNotChosenAutomatically(testCase)
            data=testCase.eisTable('bracket');data.("Real [Ohm]")=testCase.EIS.real;
            file=fullfile(testCase.Folder,'duplicate.csv');writetable(data,file);
            input=uecm.readInput(file);prepared=uecm.prepare(input);
            testCase.verifyEqual(input.Mapping.real,"");
            testCase.verifyTrue(prepared.Blocked);
        end
        function missingUnitsRemainRequests(testCase)
            data=table(testCase.EIS.frequency,testCase.EIS.real,testCase.EIS.imag,'VariableNames',{'Freq','Re(Z)','Im(Z)'});
            file=fullfile(testCase.Folder,'unknown.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyTrue(prepared.Blocked);
            testCase.verifyTrue(any(prepared.Requests.Field=="frequency_unit"));
        end
        function blankOptionalIDsUseExplicitFileGrouping(testCase)
            data=testCase.eisTable('bracket');data.cell_id=strings(height(data),1);data.test_id=strings(height(data),1);
            file=fullfile(testCase.Folder,'blank_ids.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyTrue(all(prepared.Data.cell=="unassigned"));
            testCase.verifyEqual(numel(unique(prepared.Data.test)),1);
        end
        function partialBlankIDsAreRejected(testCase)
            data=testCase.eisTable('bracket');data.cell_id=testCase.EIS.cell;data.cell_id(1)="";
            file=fullfile(testCase.Folder,'partial_ids.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyTrue(prepared.Blocked);
            testCase.verifyTrue(any(prepared.Requests.Field=="cell"));
        end
        function harmlessUnitSpellingVariantsAreRecognized(testCase)
            data=table(testCase.EIS.frequency,testCase.EIS.real,testCase.EIS.imag,testCase.EIS.temperature, ...
                'VariableNames',["Frequency [HZ]","Re(Z) [OHMS]","Im(Z) [OHMS]","Temperature (Celsius)"]);
            file=fullfile(testCase.Folder,'spelling.csv');writetable(data,file);
            prepared=uecm.prepare(uecm.readInput(file));
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(prepared.Data.real,testCase.EIS.real,'AbsTol',1e-12);
            testCase.verifyEqual(prepared.Data.temperature,testCase.EIS.temperature,'AbsTol',1e-12);
        end
        function ambiguousExplicitCurrentUnitIsRejected(testCase)
            data=table(testCase.HPPC.time,testCase.HPPC.current,testCase.HPPC.voltage, ...
                'VariableNames',{'time_s','current_A','voltage_V'});
            file=fullfile(testCase.Folder,'bad_unit.csv');writetable(data,file);
            options=uecm.defaults();options.CurrentSign="discharge_positive";options.CurrentUnit="MA";
            prepared=uecm.prepare(uecm.readInput(file,options));
            testCase.verifyTrue(prepared.Blocked);
            testCase.verifyTrue(any(prepared.Requests.Field=="current_unit"));
        end
        function ambiguousSIPrefixIsNotGuessed(testCase)
            info=uecm.columnInfo("Freq [mhz]","frequency");
            testCase.verifyEqual(info.Unit,"unknown");
        end
    end
    methods (Access=private)
        function T=eisTable(testCase,style)
            f=testCase.EIS.frequency;re=testCase.EIS.real;im=testCase.EIS.imag;
            switch string(style)
                case "bracket"
                    T=table(f/1000,re*1000,-im*1000,'VariableNames',["Freq [kHz]","Re(Z) [mΩ]","-Im(Z) [mΩ]"]);
                case "prime"
                    T=table(f,re,im,'VariableNames',["f/Hz","Z' (Ohm)","Z'' (Ohm)"]);
                case "korean"
                    T=table(f,re,im,'VariableNames',["주파수 [Hz]","실수부 [Ω]","허수부 [Ω]"]);
                otherwise
                    T=table(f,abs(complex(re,im))*1000,angle(complex(re,im)), ...
                        'VariableNames',["Frequency (Hz)","|Z| (mOhm)","Phase (rad)"]);
            end
        end
        function file=writeFormat(testCase,data,format)
            switch string(format)
                case "comma",file=fullfile(testCase.Folder,'comma.csv');writetable(data,file);
                case "semicolon",file=fullfile(testCase.Folder,'semicolon.csv');writetable(data,file,'Delimiter',';');
                case "tab",file=fullfile(testCase.Folder,'tab.txt');writetable(data,file,'Delimiter','tab');
                otherwise,file=fullfile(testCase.Folder,'single.xlsx');writetable(data,file,'Sheet','measurements');
            end
        end
    end
end
