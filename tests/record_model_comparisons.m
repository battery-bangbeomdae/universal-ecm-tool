% Record same-data scores; generated tables are ESTIMATES, never measurements.
comparisonAppRoot=fileparts(fileparts(mfilename('fullpath')));addpath(comparisonAppRoot);
filesV02=["REAL_D010_eis_12spectra.csv","REAL_D014_hppc_one_pulse.csv", ...
    "SYNTHETIC_2RC_hppc_practice.csv","SYNTHETIC_2RC_eis_practice.csv","SYNTHETIC_hppc_practice.csv"];
recordsV02={};
for fileV02=filesV02
    optionsV02=uecm.defaults();
    if startsWith(fileV02,"SYNTHETIC"),optionsV02.MaxGroups=1;optionsV02.CurrentSign="discharge_positive";end
    if contains(fileV02,'D014'),optionsV02.CurrentSign="charge_positive";end
    inputV02=uecm.readInput(fullfile(comparisonAppRoot,'examples',fileV02),optionsV02);
    bundleV02=uecm.analyze(inputV02);
    if isempty(bundleV02.Fits),disp(bundleV02.Prepared.Requests);error('Comparison recording failed');end
    for jV02=1:numel(bundleV02.Fits)
        fV02=bundleV02.Fits{jV02};scoreV02=fV02.CandidateScores;
        scoreV02.Example=repmat(fileV02,height(scoreV02),1);scoreV02.Measurement=repmat(string(jV02),height(scoreV02),1);
        scoreV02.Synthetic=repmat(inputV02.Synthetic,height(scoreV02),1);
        scoreV02.SourceID=repmat(fV02.Identity.source_id,height(scoreV02),1);scoreV02.CellID=repmat(fV02.Identity.cell_id,height(scoreV02),1);
        scoreV02.TestID=repmat(fV02.Identity.test_id,height(scoreV02),1);scoreV02.SpectrumID=repmat(fV02.Identity.spectrum_id,height(scoreV02),1);
        scoreV02.InputRows=repmat(height(inputV02.Data),height(scoreV02),1);recordsV02{end+1}=scoreV02;
    end
end
allV02=vertcat(recordsV02{:});writetable(allV02,fullfile(comparisonAppRoot,'docs','model_comparison_examples_v02.csv'),'Encoding','UTF-8');
disp(allV02(:,{'Example','Measurement','Model','RMSE','ErrorUnit','Recommended','Status'}));
