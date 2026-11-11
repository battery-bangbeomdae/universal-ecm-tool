function info=unitDefinition(symbol,quantity)
%UNITDEFINITION Quantity-aware, case-sensitive conversion into analysis units.
arguments
    symbol (1,1) string
    quantity (1,1) string = ""
end
persistent catalog
if isempty(catalog)
    root=fileparts(fileparts(mfilename('fullpath')));
    catalog=readtable(fullfile(root,'config','unit_catalog.csv'),'TextType','string');
end
u=strip(symbol);u=replace(u,["µ","μ","Ω","Ω","°C","℃"],["u","u","Ohm","Ohm","C","C"]);
aliases=["sec","s";"ss.xxx","s";"hr","h";"a","A";"ma","mA";"ua","uA"; ...
    "v","V";"mv","mV";"uv","uV";"hz","Hz";"khz","kHz";"ohm","Ohm"; ...
    "mohm","mOhm";"uohm","uOhm";"kohm","kOhm";"degc","C";"degC","C";"c","C";"k","K"; ...
    "°","deg";"%","percent";"ah","Ah";"mah","mAh";"as","As"];
hit=find(aliases(:,1)==u,1);if ~isempty(hit),u=aliases(hit,2);end
matches=catalog.unit==u;
if quantity~="",matches=matches&catalog.quantity==quantity;end
hit=find(matches,1);
info=struct('Known',~isempty(hit),'Unit',u,'Quantity',quantity, ...
    'TargetUnit',"",'Factor',NaN,'Offset',NaN);
if isempty(hit),return,end
info.Quantity=catalog.quantity(hit);info.TargetUnit=catalog.target_unit(hit);
info.Factor=catalog.factor(hit);info.Offset=catalog.offset(hit);
end
