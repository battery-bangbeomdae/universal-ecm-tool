function p=prepareBatch(input)
%PREPAREBATCH Normalize each original file before combining semantic signals.
parts=uecm.effectiveInputs(input);prepared=cell(size(parts));
for k=1:numel(parts),prepared{k}=uecm.prepare(parts{k});end
[prepared,axisDefs,axisCategories]=uecm.harmonizeConditionAxes(prepared);
p=prepared{1};p.Input=input;p.Data=table();p.Requests=p.Requests([],:);
p.Notes=strings(0,1);p.Conversions=p.Conversions([]);
types=strings(numel(parts),1);names=strings(1,0);
for k=1:numel(parts)
    q=prepared{k};types(k)=q.Type;
    names=union(names,string(q.Data.Properties.VariableNames),'stable');
end
tables=cell(size(parts));
for k=1:numel(parts)
    q=prepared{k};T=q.Data;
    for name=names
        if ~ismember(name,string(T.Properties.VariableNames)),T.(name)=nan(height(T),1);end
    end
    tables{k}=T(:,cellstr(names));
    p.Requests=[p.Requests;q.Requests];
    p.Notes=[p.Notes;parts{k}.File;q.Notes(:)];
    p.Conversions=[p.Conversions,q.Conversions];
end
p.Data=vertcat(tables{:});
p.FilePrepared=prepared;p.CustomAxes=axisDefs;p.AxisCategories=axisCategories;
p.Blocked=all(cellfun(@(q)q.Blocked,prepared));
if numel(unique(types))>1,p.Type="mixed";end
p.AxisCoverage=uecm.conditionCoverage(p);
p.Notes(end+1)="파일별 분석: "+sum(~cellfun(@(q)q.Blocked,prepared))+" / "+numel(parts)+"개 준비됨. 보류 파일은 진단을 확인하세요.";
p.Notes(end+1)="각 원본 파일의 열 이름·단위·허수부 부호를 개별 해석했습니다. 미리보기의 빈칸은 다른 파일에만 있는 열입니다.";
end
