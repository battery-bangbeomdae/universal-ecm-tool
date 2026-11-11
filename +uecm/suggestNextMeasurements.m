function [Next, Redundant, Info] = suggestNextMeasurements(results, opts)
%SUGGESTNEXTMEASUREMENTS Where to measure next (and what can be skipped) from the parameters already estimated.
%   [Next,Redundant] = uecm.suggestNextMeasurements(bundle)            % bundle from uecm.analyze, or its Results table
%   [Next,Redundant] = uecm.suggestNextMeasurements(bundle, struct('Parameters',["R0_Ohm","R1_Ohm"],'Top',5))
% Purpose (dry-lab support for wet-lab planning): an HPPC/EIS campaign usually uses a fixed SOC grid. Parameters
% change slowly in the middle SOC range and fast near the ends, so a fixed grid spends cells and days where little
% changes and under-samples where it matters. From the measured points of each cell x temperature series this
% function reports
%   Next      : SOC values between two measured points where a parameter changes the most (midpoint, rounded to
%               SOCStep). Score = largest relative change of any selected parameter across the gap.
%   Redundant : interior points that linear interpolation of their two neighbours already predicts within
%               RedundantTol for EVERY selected parameter -> candidates to skip in the NEXT similar campaign.
% Nothing is extrapolated and no values are changed; this is a ranked suggestion for the researcher to judge.
arguments
    results
    opts (1,1) struct = struct()
end
if isstruct(results)&&isfield(results,'Results'),results=results.Results;end
if ~istable(results),error('uecm:NextMeasurements','analyze 결과(bundle) 또는 결과 표를 넣어 주세요.');end
d=struct('Parameters',strings(0,1),'Top',5,'SOCStep',5,'MinGap',10,'RedundantTol',0.02,'MinPoints',3);
for n=string(fieldnames(d))',if ~isfield(opts,n),opts.(n)=d.(n);end,end
Next=table();Redundant=table();Info=struct('Parameters',strings(0,1),'Series',0,'Notes',strings(0,1));
if isempty(results)||~ismember('soc_pct',results.Properties.VariableNames)
    Info.Notes(end+1)="SOC가 있는 결과가 없어 제안할 수 없습니다.";return
end
P=string(opts.Parameters);
if isempty(P)
    cand=["R0_Ohm","R1_Ohm","R2_Ohm","tau1_s","Rs_Ohm","Rct_Ohm"];
    P=cand(ismember(cand,results.Properties.VariableNames));
    P=P(arrayfun(@(p)nnz(isfinite(results.(p)))>=opts.MinPoints,P));
end
if isempty(P),Info.Notes(end+1)="SOC별로 비교할 수 있는 저항·시간상수 값이 부족합니다.";return,end
Info.Parameters=P;
R=results(isfinite(results.soc_pct),:);
if ismember('fit_status',R.Properties.VariableNames),R=R(R.fit_status~="failed",:);end
cellId=strings(height(R),1);if ismember('cell_id',R.Properties.VariableNames),cellId=string(R.cell_id);end
tempC=nan(height(R),1);if ismember('temperature_C',R.Properties.VariableNames),tempC=round(R.temperature_C);end   % 1 degC bins: 24.9 and 25.1 are one chamber setpoint (fix 2026-11-10)
tempC(isnan(tempC))=-9999;   % findgroups drops NaN keys; unknown temperature is its own series
dom=strings(height(R),1);if ismember('domain',R.Properties.VariableNames),dom=string(R.domain);end
% Dataset key (fix 2026-11-10). EIS usually stores ONE SOC point per file, so a per-file key leaves every series with
% one SOC and no suggestion is ever made. source_id is a dataset label only when one id spans several files; the raw
% converter sets source_id = file name, and then the input folder stands in for the dataset (sources still never mix).
ds=strings(height(R),1);hasSrc=ismember('source_id',R.Properties.VariableNames);
if hasSrc,ds=string(R.source_id);ds(ismissing(ds))="";end
if ismember('source_file',R.Properties.VariableNames)&&height(R)>0
    fileKey=string(R.source_file);fileKey(ismissing(fileKey))="";
    perFile=true;
    if hasSrc&&any(ds~="")
        [~,~,gi]=unique(ds);perFile=all(splitapply(@(v)numel(unique(v)),fileKey,gi)<=1);
    end
    if perFile&&numel(unique(fileKey))>1,ds="folder="+regexprep(fileKey,"[\\/][^\\/]*$","");end
end
extraKey=char(31)+"dataset="+ds;
for field=["model","circuit","soh_pct","cycle_number","calendar_days","processing_route","route"]
    if ismember(field,string(R.Properties.VariableNames)),values=string(R.(field));values(ismissing(values))="<unlinked>";extraKey=extraKey+char(31)+field+"="+values;end
end
[g,gc,gt,gd,gx]=findgroups(cellId,tempC,dom,extraKey);
nx=cell(0,1);rd=cell(0,1);
for k=1:max([g;0])
    S=R(g==k,:);[soc,~,j]=unique(S.soc_pct);
    if numel(soc)<2,continue,end
    Y=nan(numel(soc),numel(P));
    for q=1:numel(P),Y(:,q)=accumarray(j,S.(P(q)),[],@(v)mean(v(isfinite(v))));end   % repeats averaged
    good=all(isfinite(Y),2);soc=soc(good);Y=Y(good,:);
    if numel(soc)<2,continue,end
    Info.Series=Info.Series+1;scale=median(abs(Y),1);scale(scale==0)=1;Yn=Y./scale;
    label=gc(k)+" | "+tlabel(gt(k))+" | "+gd(k)+replace(gx(k),char(31)," | ");
    for i=1:numel(soc)-1                                           % gaps
        gap=soc(i+1)-soc(i);if gap<opts.MinGap,continue,end
        [s,qmax]=max(abs(Yn(i+1,:)-Yn(i,:)));
        mid=opts.SOCStep*round((soc(i)+soc(i+1))/2/opts.SOCStep);
        if mid<=soc(i)||mid>=soc(i+1),mid=(soc(i)+soc(i+1))/2;end
        nx{end+1,1}={label,gc(k),gt(k),gd(k),mid,soc(i),soc(i+1),s,P(qmax), ...
            sprintf("%s가 SOC %.4g→%.4g%%에서 %.0f%% 변합니다. 중간 SOC %.4g%% 측정을 권장합니다.",P(qmax),soc(i),soc(i+1),100*s,mid)}; %#ok<AGROW>
    end
    if numel(soc)>=opts.MinPoints                                  % interior points predicted by neighbours
        for i=2:numel(soc)-1
            a=(soc(i)-soc(i-1))/(soc(i+1)-soc(i-1));pred=(1-a)*Yn(i-1,:)+a*Yn(i+1,:);
            e=max(abs(Yn(i,:)-pred)./max(abs(Yn(i,:)),eps));
            if e<=opts.RedundantTol
                rd{end+1,1}={label,gc(k),gt(k),gd(k),soc(i),e, ...
                    sprintf("이웃 SOC %.4g·%.4g%% 값의 선형 보간이 모든 선택 변수를 %.1f%% 이내로 예측합니다. 다음 유사 시험에서 생략 후보입니다.",soc(i-1),soc(i+1),100*e)}; %#ok<AGROW>
            end
        end
    end
end
vn={'series','cell_id','temperature_C','domain','suggest_soc_pct','between_low_pct','between_high_pct','score','driver','reason'};
if ~isempty(nx)
    Next=cell2table(vertcat(nx{:}),'VariableNames',vn);Next=sortrows(Next,'score','descend');
    Next=Next(1:min(opts.Top,height(Next)),:);Next.temperature_C(Next.temperature_C==-9999)=NaN;
end
if ~isempty(rd)
    Redundant=cell2table(vertcat(rd{:}),'VariableNames',{'series','cell_id','temperature_C','domain','soc_pct','max_rel_interp_error','reason'});
    Redundant.temperature_C(Redundant.temperature_C==-9999)=NaN;
end
if Info.Series==0,Info.Notes(end+1)="SOC가 2개 이상인 셀·온도 묶음이 없어 제안할 수 없습니다.";end
end
function s=tlabel(t)
if isnan(t)||t==-9999,s="온도 미상";else,s=string(t)+" °C";end
end
