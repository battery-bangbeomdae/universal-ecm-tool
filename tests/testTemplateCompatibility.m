classdef testTemplateCompatibility < matlab.unittest.TestCase
    properties (TestParameter)
        BlankTemplate = {'EIS/EIS_signed_Im_template.csv','EIS/EIS_negative_Im_template.csv', ...
            'EIS/EIS_magnitude_phase_template.csv','HPPC/HPPC_template.csv'}
    end
    properties
        Root
    end
    methods (TestMethodSetup)
        function locateApp(testCase)
            testCase.Root=string(fileparts(fileparts(mfilename('fullpath'))));
            addpath(testCase.Root);
        end
    end
    methods (Test)
        function blankTemplatesRequestMeasurements(testCase,BlankTemplate)
            input=uecm.readInput(fullfile(testCase.Root,'templates',BlankTemplate));
            prepared=uecm.prepare(input);
            testCase.verifyTrue(prepared.Blocked);
            testCase.verifyTrue(any(prepared.Requests.Blocking));
        end
        function commaCSVRetainsColonRichIDsAndJoinsConditions(testCase)
            folder=fullfile(testCase.Root,'tests','fixtures_jwl_template_inputs');
            input=uecm.readInput(fullfile(folder,'Molicel_P42A_Independent_EIS_signals.csv'),uecm.defaults(), ...
                fullfile(folder,'Molicel_P42A_Independent_EIS_conditions.csv'));
            prepared=uecm.prepare(input);
            testCase.verifyEqual(input.Mapping.frequency,"frequency_hz");
            testCase.verifyEqual(height(input.Data),14638);
            testCase.verifyEqual(prepared.Type,"EIS");
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyEqual(numel(unique(prepared.Data.spectrum)),240);
        end
        function reportedTemperatureCenterIsNumericAndUncertaintyRetained(testCase)
            folder=fullfile(testCase.Root,'tests','fixtures_jwl_template_inputs');
            input=uecm.readInput(fullfile(folder,'D011_NMC532_pouch64Ah_EIS_signals.csv'),uecm.defaults(), ...
                fullfile(folder,'D011_NMC532_pouch64Ah_EIS_conditions.csv'));
            prepared=uecm.prepare(input);
            testCase.verifyFalse(prepared.Blocked);
            testCase.verifyTrue(all(isfinite(prepared.Data.temperature)));
            testCase.verifyEqual(prepared.Data.temperature(1),1.48,'AbsTol',1e-12);
            testCase.verifyTrue(ismember('temperature_source_text',input.Metadata.Properties.VariableNames));
            testCase.verifyTrue(ismember('temperature_reported_uncertainty_C',input.Metadata.Properties.VariableNames));
        end
        function rowShapedNotesDoNotBreakHPPCScreenRefresh(testCase)
            o=uecm.defaults();o.CurrentSign="discharge_positive";o.MaxGroups=1;
            input=uecm.readInput(fullfile(testCase.Root,'examples','SYNTHETIC_hppc_practice.csv'),o);
            bundle=uecm.analyze(input);bundle.Prepared.Notes=["first note","second note"];
            app=launch_universal_ecm();testCase.addTeardown(@()delete(app.view));
            app.view.UIFigure.Visible='off';app.viewModel.acceptInput(input);
            testCase.verifyWarningFree(@()app.viewModel.acceptFit(bundle));
            choices=findall(app.view.UIFigure,'Tag','ZAxisChoice');
            testCase.verifyTrue(ismember('R0_Ohm',choices.Items));
        end
        function mainMapHasRotationWithoutGraphMode(testCase)
            app=launch_universal_ecm();testCase.addTeardown(@()delete(app.view));
            app.view.UIFigure.WindowState='normal';app.view.UIFigure.Position=[60,60,1450,880];drawnow;pause(.3);drawnow;
            dimension=findall(app.view.UIFigure,'Tag','PlotDimension');
            rotation=findall(app.view.UIFigure,'Tag','RotateMap');
            testCase.verifyEmpty(dimension);
            testCase.verifyGreaterThanOrEqual(rotation.Position(4),20);
        end
        function rejectedPulseDoesNotSilentlyReturnEmpty(testCase)
            time=(0:19)';current=[zeros(5,1);ones(2,1);zeros(13,1)];
            voltage=4-.01*current;
            testCase.verifyError(@()uecm.fitHPPC(time,current,voltage), 'uecm:PulseCoverage');
        end
    end
end
