function [parts,defs,categories]=harmonizeConditionAxes(parts)
%HARMONIZECONDITIONAXES Share category codes and additional schemas across files.
defs=struct('Field',{},'Label',{},'Unit',{},'Source',{},'Column',{},'Keys',{},'LinkedCount',{},'MissingCount',{});categories=struct('Field',{},'Values',{});
for k=1:numel(parts)
 if ~isfield(parts{k},'CustomAxes'),continue,end
 for a=parts{k}.CustomAxes
  if isempty(defs)||~ismember(a.Field,string({defs.Field})),if isempty(defs),defs=a;else,defs(end+1)=a;end;end
 end
end
for a=defs
 values=strings(0,1);isCategory=false;
 for k=1:numel(parts)
  p=parts{k};if ~isfield(p,'AxisCategories'),continue,end
  j=find(string({p.AxisCategories.Field})==a.Field,1);
  if ~isempty(j),values=[values;p.AxisCategories(j).Values(:)];isCategory=true;end
 end
 if isCategory
  % Mixed numeric/text files use the displayed original values as categories.
  for k=1:numel(parts)
   p=parts{k};if ~ismember(a.Field,string(p.Data.Properties.VariableNames)),continue,end
   j=find(string({p.AxisCategories.Field})==a.Field,1);
   if isempty(j),v=p.Data.(a.Field);values=[values;string(v(isfinite(v)))];end
  end
  values=unique(values,'sorted');categories(end+1)=struct('Field',a.Field,'Values',values);
 end
 for k=1:numel(parts)
  p=parts{k};v=nan(height(p.Data),1);
  if ismember(a.Field,string(p.Data.Properties.VariableNames))
   v=p.Data.(a.Field);
   if isCategory
    j=find(string({p.AxisCategories.Field})==a.Field,1);ok=isfinite(v);s=strings(size(v));
    if isempty(j),s(ok)=string(v(ok));else,s(ok)=p.AxisCategories(j).Values(v(ok));end
    [~,code]=ismember(s,values);v=double(code);v(~ok)=NaN;
   end
  end
  p.Data.(a.Field)=v;parts{k}=p;
 end
end
for j=1:numel(defs)
 f=defs(j).Field;linked=0;missingCount=0;
 for k=1:numel(parts),v=parts{k}.Data.(f);linked=linked+nnz(isfinite(v));missingCount=missingCount+nnz(~isfinite(v));end
 defs(j).LinkedCount=linked;defs(j).MissingCount=missingCount;
 if ismember(f,string({categories.Field})),defs(j).Label=defs(j).Column+" (범주)";end
end
for k=1:numel(parts),parts{k}.CustomAxes=defs;parts{k}.AxisCategories=categories;end
end
