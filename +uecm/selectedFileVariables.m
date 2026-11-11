function result=selectedFileVariables(bundle,file,revision)
%SELECTEDFILEVARIABLES Read already-loaded columns using proven fit/group links.
% No file dialog, disk read, averaging, inferred axis values, or cache writes.
arguments
    bundle struct
    file (1,1) string
    revision double = 0
end
if ~isfield(bundle,'Prepared')||~isfield(bundle,'Results')||isempty(bundle.Results)
 error('uecm:SelectedVariables','먼저 선택 파일의 피팅을 실행하세요.');
end
parts={bundle.Prepared};if isfield(bundle.Prepared,'FilePrepared'),parts=bundle.Prepared.FilePrepared;end
q=[];offset=0;
for k=1:numel(parts)
 if string(parts{k}.Input.File)==file,q=parts{k};break,end
 offset=offset+height(parts{k}.Input.Data);
end
if isempty(q),error('uecm:SelectedVariables','현재 선택 파일의 읽기 내역을 찾을 수 없습니다. 파일을 다시 선택하세요.');end
R=bundle.Results;indices=find(string(R.source_file)==file);
if isempty(indices),error('uecm:SelectedVariables','현재 선택 파일의 피팅 결과가 없습니다. 이 파일을 먼저 피팅하세요.');end
if height(q.Data)~=height(q.Input.Data),error('uecm:SelectedVariables','원본 행과 정규화 행의 연결을 확인할 수 없습니다.');end
preview=q.Input.Data;
% Include only actually linked sidecar columns, decoding harmonized categories.
if isfield(q,'CustomAxes')
 for a=q.CustomAxes
  col=string(a.Column);if ismember(col,string(preview.Properties.VariableNames))||~ismember(a.Field,string(q.Data.Properties.VariableNames)),continue,end
  values=q.Data.(a.Field);if ~any(isfinite(values)),continue,end
  category=[];if isfield(q,'AxisCategories'),category=find(string({q.AxisCategories.Field})==a.Field,1);end
  if ~isempty(category)
   labels=string(q.AxisCategories(category).Values);decoded=strings(height(q.Data),1);decoded(:)=missing;
   ok=isfinite(values)&values==fix(values)&values>=1&values<=numel(labels);decoded(ok)=labels(values(ok));values=decoded;
  end
  preview.(col)=values;
 end
end
% Resolve EIS groups once. All rows in a spectrum count, including excluded points.
identity=[q.Data.source,q.Data.cell,q.Data.test,q.Data.spectrum];
[uniqueIDs,~,group]=unique(identity,'rows');groupRows=accumarray(group,(1:height(q.Data))',[],@(v){v});
[linked,where]=ismember([R.source_id(indices),R.cell_id(indices),R.test_id(indices),R.spectrum_id(indices)],uniqueIDs,'rows');
if ~all(linked),error('uecm:SelectedVariables','피팅 결과와 원본 측정 식별자가 일치하지 않습니다. 다시 피팅하세요.');end
rows=cell(numel(indices),1);
for k=1:numel(indices)
 if q.Type=="EIS",rows{k}=groupRows{where(k)};
 else
  local=bundle.Fits{indices(k)}.SourceRows(:)-offset;
  if isempty(local)||any(local<1|local>height(q.Data)|local~=fix(local))||any(group(local)~=where(k))
   error('uecm:SelectedVariables','HPPC 피팅 구간의 원본 행 연결을 확인할 수 없습니다.');
  end
  rows{k}=local;
 end
end
M=table(R.fit_id(indices),'VariableNames',{'fit_id'});names=string(preview.Properties.VariableNames);
conflicts=zeros(size(names));
for n=1:numel(names)
 col=names(n);if col=="fit_id",continue,end
 raw=preview.(col);numeric=isnumeric(raw)||islogical(raw);
 if numeric,values=nan(numel(indices),1);else,raw=string(raw);values=strings(numel(indices),1);values(:)=missing;end
 if size(raw,2)~=1,conflicts(n)=numel(indices);M.(col)=values;continue,end
 for k=1:numel(indices)
  v=raw(rows{k});
  if numeric
   if all(isfinite(v))&&all(v==v(1)),values(k)=double(v(1));
   elseif any(isfinite(v)),conflicts(n)=conflicts(n)+1;end
  else
   blank=ismissing(v)|strlength(strip(v))==0|lower(strip(v))=="nan";
   if ~any(blank)&&all(v==v(1)),values(k)=v(1);
   elseif ~all(blank),conflicts(n)=conflicts(n)+1;end
  end
 end
 M.(col)=values;
end
info=uecm.variableColumnInfo(M);
for n=find(conflicts>0)
 j=find(info.column==names(n),1);
 info.reason(j)="측정 구간 안에서 값이 변하거나 일부 값이 비어 "+conflicts(n)+"건은 연결하지 않았습니다. 평균값은 만들지 않습니다.";
end
[~,name,extension]=fileparts(file);total=height(preview);
context=struct('Preview',preview(1:min(200,total),:),'TotalRows',total,'SelectedFile',file,'JoinKeys',"fit_id", ...
 'Description',"현재 선택 파일: "+name+extension+" · "+numel(indices)+"개 피팅과 연결 · 원본 열 미리보기");
result=struct('File',file,'Table',M,'ColumnInfo',info,'Context',context,'Revision',revision);
end
