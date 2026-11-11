function note=mapConditionNotice(R,x,y)
%MAPCONDITIONNOTICE Explain duplicate XY values and remaining variable conditions.
note="";if isempty(R),return,end
coordinates=R.(x);
if y~="none"&&ismember(y,string(R.Properties.VariableNames)),coordinates=[coordinates,R.(y)];end
[~,~,g]=unique(coordinates,'rows');counts=accumarray(g,1);duplicates=sum(counts-1);
fields=["soc_pct","soh_pct","temperature_C","cycle_number","calendar_days"];varies=strings(0,1);fields=[fields,string(R.Properties.VariableNames(startsWith(string(R.Properties.VariableNames),"custom_")))];
for f=fields
 if ismember(f,[x,y])||~ismember(f,string(R.Properties.VariableNames)),continue,end
 v=R.(f);v=v(isfinite(v));if numel(unique(v))>1,varies(end+1)=f+" "+numel(unique(v))+"수준";end %#ok<AGROW>
end
if duplicates>0,note="동일 선택 축 좌표에 추가 "+duplicates+"점이 있습니다. 평균내지 않았습니다. ‘나머지 조건 한정’으로 범위를 좁히세요.";end
if ~isempty(varies),note=note+" 축 외 변동: "+join(varies,", ")+".";end
end
