function data=attachCustomComparison(data,bundle,links)
%ATTACHCUSTOMCOMPARISON Share registered conditions by exact trace/pulse identity.
arguments
 data (1,1) struct
 bundle (1,1) struct
 links (1,1) struct = struct()
end
% Remove a previous attachment when a fit/input is cleared or replaced.
T=data.Measurements;old=string(T.Properties.VariableNames);keep=strings(0,1);if isfield(data,'ImportedAxes')&&~isempty(data.ImportedAxes),keep=string({data.ImportedAxes.Field});end
T(:,old(startsWith(old,"custom_")&~ismember(old,keep)))=[];
data.CustomAxes=struct([]);if isfield(data,'ImportedAxes'),data.CustomAxes=data.ImportedAxes;end;data.CustomConditionNote="";data.Measurements=T;
if isempty(T)||~isfield(bundle,'CustomAxes')||isempty(bundle.CustomAxes)||~isfield(bundle,'Results'),return,end
R=bundle.Results;data.CustomAxes=bundle.CustomAxes;if isfield(bundle,'AxisCategories'),data.AxisCategories=bundle.AxisCategories;end
for a=bundle.CustomAxes,if ~ismember(a.Field,string(T.Properties.VariableNames)),T.(a.Field)=nan(height(T),1);end;end
data.Measurements=T;
if isempty(fieldnames(links)),[matched,j]=uecm.comparisonFitLinks(T,bundle);else,matched=links.Matched;j=links.Index;end
counts=zeros(numel(bundle.CustomAxes),1);
for k=1:numel(bundle.CustomAxes)
 f=bundle.CustomAxes(k).Field;v=T.(f);
 if ismember(f,string(R.Properties.VariableNames)),v(matched)=R.(f)(j(matched));end
 T.(f)=v;counts(k)=nnz(isfinite(v));
end
data.Measurements=T;
data.CustomConditionNote="추가 변수: 피팅 측정/펄스와 정확히 대응한 값만 연결. "+sum(~matched)+"개 구간은 결과와 미대응/중복 대응. 변수별 유효 연결 "+join(string(counts'),"/")+"개.";
end
