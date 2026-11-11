function label=axisValueLabel(bundle,field,value)
%AXISVALUELABEL Decode imported categorical values for labels and exports.
label=string(compose('%.5g',value));
if ~isfield(bundle,'AxisCategories'),return,end
j=find(string({bundle.AxisCategories.Field})==string(field),1);
if isempty(j),return,end
values=bundle.AxisCategories(j).Values;ok=isfinite(value)&value>=1&value<=numel(values)&value==fix(value);
label(ok)=values(value(ok));label(~isfinite(value))="미연결";
end
