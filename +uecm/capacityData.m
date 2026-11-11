function [initial,current]=capacityData(T)
%CAPACITYDATA Read explicitly identified measured capacities, normalized to Ah.
initial=nan(height(T),1);current=initial;
names=string(T.Properties.VariableNames);
for j=1:numel(names)
    name=names(j);key=lower(regexprep(name,'[^a-zA-Z0-9]',''));
    target="";
    if any(startsWith(key,["initialcapacity","baselinecapacity","qinitial"])),target="initial";
    elseif any(startsWith(key,["currentcapacity","measuredcapacity","qcurrent"])),target="current";end
    if target=="",continue,end
    token=regexp(char(name),'(mAh|Ah)[\]\)\s]*$','tokens','once');
    if isempty(token),continue,end
    values=T.(name);if isnumeric(values),values=double(values);else,values=str2double(string(values));end
    unit=uecm.unitDefinition(string(token{1}),"capacity");
    values=values*unit.Factor;values(~isfinite(values)|values<=0)=NaN;
    if target=="initial",initial=values;else,current=values;end
end
end
