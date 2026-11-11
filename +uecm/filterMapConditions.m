function [keep,message]=filterMapConditions(R,filters,axisFields)
%FILTERMAPCONDITIONS Restrict unused condition ranges; no averaging or implicit filling.
arguments
 R table
 filters (1,1) struct = struct()
 axisFields string = strings(0,1)
end
keep=true(height(R),1);notes=strings(0,1);
if isfield(filters,'Numeric')
 C=filters.Numeric;
 for k=1:height(C)
  f=string(C.field(k));if ~C.enabled(k)||ismember(f,axisFields),continue,end
  lo=C.minimum(k);hi=C.maximum(k);
  if isnan(lo)||isnan(hi)||lo>hi,error('uecm:MapFilter','조건 범위의 최소/최대를 확인하세요.');end
  if ~ismember(f,string(R.Properties.VariableNames)),keep(:)=false;else,keep=keep&isfinite(R.(f))&R.(f)>=lo-1e-7&R.(f)<=hi+1e-7;end
  notes(end+1)=f+"="+lo+"–"+hi; %#ok<AGROW>
 end
end
for f=["source_id","cell_model","cell_id","domain"]
 if isfield(filters,f)&&strlength(string(filters.(f)))>0&&string(filters.(f))~="*"
  if ~ismember(f,string(R.Properties.VariableNames)),keep(:)=false;else,keep=keep&string(R.(f))==string(filters.(f));end
  notes(end+1)=f+"="+string(filters.(f)); %#ok<AGROW>
 end
end
message="추가 조건 제한 없음";if ~isempty(notes),message="조건 한정: "+join(notes,", ");end
end
