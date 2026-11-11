function [days,unit,factor]=calendarData(T,column)
%CALENDARDATA Explicit experiment ageing time, never signal time or RPT index.
arguments
    T table
    column (1,1) string
end
days=nan(height(T),1);unit="unknown";factor=NaN;
if column==""||~ismember(column,string(T.Properties.VariableNames)),return,end
info=uecm.columnInfo(column,"calendar");unit=info.Unit;
units=["d","h","week","s"];factors=[1,1/24,7,1/86400];j=find(units==unit,1);
if isempty(j),return,end
values=T.(column);if isnumeric(values),values=double(values);else,values=str2double(string(values));end
factor=factors(j);days=values*factor;days(~isfinite(days)|days<0)=NaN;
end
