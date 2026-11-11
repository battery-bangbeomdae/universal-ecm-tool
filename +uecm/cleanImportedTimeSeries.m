function [T,notes]=cleanImportedTimeSeries(T,settings)
%CLEANIMPORTEDTIMESERIES Apply explicit raw-profile time policies per experiment.
notes=strings(0,1);m=uecm.inferMapping(T.Properties.VariableNames);
if any(strlength([m.time,m.current,m.voltage])==0),return,end
idColumns=strings(1,0);
for field=["source","cell","test"]
    if strlength(m.(field))>0,idColumns(end+1)=m.(field);end
end
if isempty(idColumns),group=ones(height(T),1);else,group=findgroups(T(:,cellstr(idColumns)));end
keep=true(height(T),1);
for k=unique(group(isfinite(group)))'
    rows=find(group==k);
    screen=uecm.screenTimeSeries(double(T.(m.time)(rows)),double(T.(m.current)(rows)), ...
        double(T.(m.voltage)(rows)),settings);
    notes(end+1)=screen.Message;
    if ~screen.Blocking,keep(rows)=screen.Keep;end
end
T=T(keep,:);
end
