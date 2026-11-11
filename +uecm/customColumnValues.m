function [values,categories,kind]=customColumnValues(raw)
%CUSTOMCOLUMNVALUES Explicitly selected numeric or categorical CSV column.
categories=strings(0,1);kind="숫자";
if isnumeric(raw)||islogical(raw)
 values=double(raw);if any(isinf(values)),error('uecm:CustomAxis','무한대 값은 변수로 추가할 수 없습니다.');end
else
 s=strip(string(raw));blank=ismissing(s)|strlength(s)==0|lower(s)=="nan";
 values=nan(size(s));parsed=str2double(s(~blank));
 if all(isfinite(parsed)),values(~blank)=parsed;
 elseif any(isinf(parsed)),error('uecm:CustomAxis','무한대 값은 변수로 추가할 수 없습니다.');
 else
  kind="범주";[categories,~,codes]=unique(s(~blank),'sorted');values(~blank)=double(codes);
 end
end
if ~isvector(values)&&~isempty(values),error('uecm:CustomAxis','한 열에 한 값인 데이터만 추가할 수 있습니다.');end
values=values(:);
end
