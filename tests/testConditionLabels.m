function tests=testConditionLabels
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
end
function testLabelsDoNotOverwriteOriginalAndCapacitiesDeriveSOH(t)
o=uecm.defaults();o.Circuit="RC";
input=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'),o);
input.Data.soh_pct=nan(height(input.Data),1);input.Mapping.soh="soh_pct";
targets=uecm.conditionTargets(input);
label=makeLabels(targets(1,:));label.soc_pct=1;label.cycle_number=42;
label.initial_capacity_Ah=5;label.current_capacity_Ah=4;
input.ConditionLabels=label;p=uecm.prepare(input);
idx=label.row_start;
verifyEqual(t,p.Data.soc(idx),targets.soc_pct(1));
verifyEqual(t,p.Data.soc_source(idx),"source_data");
verifyEqual(t,p.Data.soh(idx),80);verifyEqual(t,p.Data.soh_source(idx),"capacity_ratio");
verifyEqual(t,p.Data.cycle(idx),42);verifyEqual(t,p.Data.cycle_source(idx),"manual");
verifyTrue(t,isnan(p.Data.current_capacity(end)));
b=uecm.analyze(input);first=b.Results(b.Results.spectrum_id==label.spectrum_id,:);
verifyEqual(t,first.initial_capacity_Ah,5);verifyEqual(t,first.current_capacity_Ah,4);
verifyEqual(t,first.soh_pct,80);verifyEqual(t,first.soh_source,"capacity_ratio");
end
function testPerPulseSOCIsOptionalAndScoped(t)
input=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_hppc_practice.csv'));
input.Data.soc_pct(:)=NaN;
targets=uecm.conditionTargets(input);verifyGreaterThanOrEqual(t,height(targets),2);
label=makeLabels(targets(1,:));label.soc_pct=55;
input.ConditionLabels=label;p=uecm.prepare(input);
verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.soc(label.row_start),55);
verifyTrue(t,isnan(p.Data.soc(targets.row_start(2))));
input.ConditionLabels=label([],:);p=uecm.prepare(input);
verifyFalse(t,p.Blocked);verifyTrue(t,all(isnan(p.Data.soc)));
end
function testExplicitCapacityColumnsAreNormalized(t)
input=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
input.Data.initial_capacity_mAh=repmat(5000,height(input.Data),1);
input.Data.current_capacity_Ah=repmat(4,height(input.Data),1);
input.Data.soh_pct=nan(height(input.Data),1);input.Mapping.soh="soh_pct";
p=uecm.prepare(input);
verifyEqual(t,p.Data.initial_capacity,repmat(5,height(input.Data),1));
verifyEqual(t,p.Data.soh,repmat(80,height(input.Data),1));
end
function testBatchLabelsReachTheirOwnFile(t)
files=[string(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv')); ...
    string(fullfile(t.TestData.Root,'examples','REAL_D014_hppc_one_pulse.csv'))];
o=uecm.defaults();o.CurrentSign="charge_positive";
input=uecm.readInputs(files,o);targets=uecm.conditionTargets(input);
row=find(targets.source_file==files(2),1);label=makeLabels(targets(row,:));label.cycle_number=123;
input.ConditionLabels=label;p=uecm.prepare(input);
verifyEqual(t,p.FilePrepared{2}.Data.cycle(label.row_start),123);
verifyFalse(t,any(p.FilePrepared{1}.Data.cycle==123));
end
function labels=makeLabels(target)
names=["source_file","source_id","cell_id","test_id","spectrum_id","row_start","row_end", ...
    "soc_pct","soh_pct","temperature_C","cycle_number","initial_capacity_Ah","current_capacity_Ah"];
labels=target(:,names);
for field=names(8:end),labels.(field)=NaN;end
end
function testConditionTableCallbackStoresAndClearsValues(t)
input=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
app=launch_universal_ecm();c=onCleanup(@()delete(app.view));
app.viewModel.acceptInput(input);app.viewModel.diagnose();
button=findall(findall(groot,'Tag','InputInformationWindow'),'Text','조건 다시 확인');feval(button.ButtonPushedFcn,button,[]);
grid=findall(findall(groot,'Tag','InputInformationWindow'),'Tag','MeasurementConditions');
feval(grid.CellEditCallback,grid,struct('Indices',[1,10],'NewData',5));
feval(grid.CellEditCallback,grid,struct('Indices',[1,11],'NewData',4));
verifyEqual(t,grid.Data.soh_pct(1),80);
verifyEqual(t,grid.Data.soh_source(1),"capacity_ratio");
soc=grid.Data.soc_pct(1);
feval(grid.CellEditCallback,grid,struct('Indices',[1,6],'NewData',1));
verifyEqual(t,grid.Data.soc_pct(1),soc);
feval(grid.CellEditCallback,grid,struct('Indices',[1,11],'NewData',NaN));
verifyTrue(t,isnan(grid.Data.soh_pct(1)));
end
