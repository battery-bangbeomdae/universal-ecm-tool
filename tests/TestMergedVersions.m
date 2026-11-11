classdef TestMergedVersions < matlab.unittest.TestCase
    properties
        Root
        Temp
    end
    methods(TestMethodSetup)
        function setupPaths(t)
            t.Root=string(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(t.Root));
            f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());t.Temp=string(f.Folder);
        end
    end
    methods(Test)
        function hppcMaximumDurationInvalidatesCache(t)
            [i,b]=hppc(t.Root);q=uecm.prepare(i);
            t.verifyTrue(uecm.fitPieceMatches(b,q));
            q.Input.Settings.MaxPulseDuration_s=1;
            t.verifyFalse(uecm.fitPieceMatches(b,q));
        end
        function restThresholdInvalidatesCache(t)
            [i,b]=hppc(t.Root);q=uecm.prepare(i);q.Input.Settings.RestCurrent_A=.001;
            t.verifyFalse(uecm.fitPieceMatches(b,q));
        end
        function parentEngineCacheRequiresRecalculation(t)
            [i,b]=hppc(t.Root);q=uecm.prepare(i);b=rmfield(b,'ComputationSchema');
            t.verifyFalse(uecm.fitPieceMatches(b,q));
        end
        function eisKeepsKKAndScreening(t)
            o=uecm.defaults();o.Circuit="RC";
            i=uecm.readInput(fullfile(t.Root,'examples','SYNTHETIC_2RC_eis_practice.csv'),o);b=uecm.analyze(i);
            t.verifyNotEmpty(b.Results);t.verifyTrue(isfield(b.Fits{1},'Preprocessing'));
            t.verifyTrue(isfield(b.Fits{1},'KK'));t.verifyEqual(b.Results.kk_status,"pass");
            t.verifyEqual(b.ComputationSchema,"uecm-v7-diffusion-1");
            folder=uecm.exportBundle(b,t.Temp);
            t.verifyTrue(isfile(fullfile(folder,'methods_summary_ko.md')));
            t.verifyTrue(isfile(fullfile(folder,'fit_0001_eis_preprocessing.csv')));
        end
        function nextMeasurementsDoNotMixSources(t)
            R=suggestionRows();R.source_id=["sourceA";"sourceB"];
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEmpty(N);
        end
        function nextMeasurementsDoNotMixCircuits(t)
            R=suggestionRows();R.model=["1RC";"2RC"];
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEmpty(N);
        end
        function matchedSeriesStillSuggests(t)
            R=suggestionRows();R.source_id=["sourceA";"sourceA"];
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEqual(N.suggest_soc_pct,50);
        end
        function separateFilesSameSeriesStillSuggest(t)
            % EIS: one file per SOC point. Different files of one source/cell/temperature must stay one series.
            R=suggestionRows();R.source_id=["sourceA";"sourceA"];R.source_file=["a_10SOC.csv";"a_90SOC.csv"];
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEqual(N.suggest_soc_pct,50);
        end
        function rawFileNameIdsShareFolderSeries(t)
            % Raw converter: source_id = file name. Same folder = one campaign -> one series.
            R=suggestionRows();R.source_id=["a_10SOC";"a_90SOC"];R.source_file=fullfile("C:","data","cellA",["a_10SOC.csv";"a_90SOC.csv"]);
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEqual(N.suggest_soc_pct,50);
        end
        function rawFileNameIdsInOtherFoldersDoNotMix(t)
            R=suggestionRows();R.source_id=["a_10SOC";"b_90SOC"];R.source_file=[fullfile("C:","data","campaignA","a_10SOC.csv");fullfile("C:","data","campaignB","b_90SOC.csv")];
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEmpty(N);
        end
        function nearbyTemperaturesShareSeries(t)
            R=suggestionRows();R.temperature_C=[24.9;25.1];
            N=uecm.suggestNextMeasurements(R,struct('Parameters',"Rs_Ohm"));t.verifyEqual(N.suggest_soc_pct,50);
        end
        function absentSOCRemainsUnlinked(t)
            o=uecm.defaults();o.CurrentSign="charge_positive";o.SOCMethod="none";
            i=uecm.readInput(fullfile(t.Root,'examples','REAL_D014_hppc_one_pulse.csv'),o);p=uecm.prepare(i);
            t.verifyTrue(all(isnan(p.Data.soc)));t.verifyTrue(any(p.AxisCoverage.known_rows==0));
        end
        function converterCannotOverwriteExistingOutput(t)
            file=fullfile(t.Temp,'existing.csv');writelines("KEEP ORIGINAL",file);
            t.verifyError(@()uecm.convertRawFolder(fullfile(t.Root,'tests','fixtures_raw'),file,"*.dta"),'uecm:OutputExists');
            t.verifyEqual(strtrim(string(fileread(file))),"KEEP ORIGINAL");
        end
    end
end
function [i,b]=hppc(root)
o=uecm.defaults();o.Type="HPPC";o.CurrentSign="charge_positive";
i=uecm.readInput(fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv'),o);b=uecm.analyze(i);
end
function R=suggestionRows()
R=table(["cellA";"cellA"],[25;25],["EIS";"EIS"],[10;90],[.1;.2], ...
 'VariableNames',{'cell_id','temperature_C','domain','soc_pct','Rs_Ohm'});
end
