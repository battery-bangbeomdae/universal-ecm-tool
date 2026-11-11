function result=queryConditionComparison(data,o)
%QUERYCONDITIONCOMPARISON Explicit filters; never infer missing conditions or average replicates.
arguments
 data (1,1) struct
 o (1,1) struct
end
T=data.Measurements;result=struct('Table',T,'DefaultSelection',false(height(T),1),'Message',"표시할 측정이 없습니다.",'Warnings',strings(0,1));
if isempty(T),return,end
keep=true(height(T),1);
for pair={"Domain","domain";"SourceFile","source_file";"Model","cell_model";"CellKey","cell_key"}'
 name=pair{1};field=pair{2};if isfield(o,name)&&string(o.(name))~="*",keep=keep&T.(field)==string(o.(name));end
end
if isfield(o,'Direction')&&string(o.Direction)~="*",keep=keep&(T.domain~="HPPC"|T.pulse_direction==string(o.Direction));end
variable=string(o.Variable);fields=["soc_pct","soh_pct","temperature_C","cycle_number","calendar_days","pulse_amplitude_A","pulse_duration_s"];
if isfield(data,'CustomAxes')&&~isempty(data.CustomAxes),fields=[fields,string({data.CustomAxes.Field})];end
fixedNames=strings(0,1);allow=isfield(o,'AllowTolerance')&&o.AllowTolerance;
for field=fields
 if field==variable||(isfield(o,'Domain')&&string(o.Domain)=="EIS"&&startsWith(field,"pulse_")),continue,end
 if isfield(o,'Fixed')&&isfield(o.Fixed,field)&&isfinite(o.Fixed.(field))
  tol=0;if allow&&isfield(o,'Tolerance')&&isfield(o.Tolerance,field),tol=o.Tolerance.(field);end
  if ~isfinite(tol)||tol<0,error('uecm:ConditionTolerance','허용 범위는 0 이상이어야 합니다.');end
  target=o.Fixed.(field);keep=keep&isfinite(T.(field))&abs(T.(field)-target)<=tol+1e-7;
  fixedNames(end+1)=field+"="+target+" ±"+tol; %#ok<AGROW>
 end
end
if variable~="cell_id",keep=keep&isfinite(T.(variable));end
T=T(keep,:);result.Table=T;
if isempty(T),result.Message="정확히 일치하는 자료가 없습니다. 조건의 미연결 여부를 확인하거나, 직접 ±허용 범위를 켜세요.";return,end
warnings=strings(0,1);
for field=fields
 if field==variable||(isfield(o,'Domain')&&string(o.Domain)=="EIS"&&startsWith(field,"pulse_")),continue,end
 if ~isfield(o.Fixed,field)||~isfinite(o.Fixed.(field))
  vals=T.(field);missingCount=nnz(~isfinite(vals));vals=vals(isfinite(vals));
  if startsWith(field,"custom_")&&missingCount>0&&~isempty(vals),warnings(end+1)=field+" 일부 미연결 ("+missingCount+"개)";end
  if isempty(vals),warnings(end+1)=field+" 미기록/미연결";
  elseif numel(unique(vals))>1,warnings(end+1)=field+" 미고정 ("+min(vals)+"–"+max(vals)+")";end %#ok<AGROW>
 end
end
if numel(unique(T.cell_key))>1&&variable~="cell_id",warnings(end+1)="여러 물리 셀의 차이가 함께 포함됩니다.";end
if numel(unique(T.cell_model))>1,warnings(end+1)="서로 다른 셀 모델이 포함됩니다.";end
if any(T.temperature_max_C-T.temperature_min_C>1e-6),warnings(end+1)="구간 내 실제 온도 변동이 있습니다(표의 최소/최대 참조).";end
result.Warnings=warnings;
if variable=="cell_id",T=sortrows(T,"cell_key");else,T=sortrows(T,variable);end
result.Table=T;
if variable=="cell_id",[~,order]=sort(T.cell_key);key=T.cell_key;
else,[~,order]=sort(T.(variable));key=string(T.(variable));end
[~,first]=unique(key(order),'stable');pick=order(first);
if numel(pick)>6,pick=pick(unique(round(linspace(1,numel(pick),6))));end
selected=false(height(T),1);selected(pick)=true;result.DefaultSelection=selected;
result.Message=height(T)+"개 후보 · 대표 "+nnz(selected)+"개 선택(같은 값의 첫 시행). 표에서 다른 시행/전체를 선택할 수 있습니다.";
if ~isempty(fixedNames),result.Message=result.Message+" 고정: "+join(fixedNames,", ")+".";end
if isfield(data,'CustomConditionNote')&&strlength(data.CustomConditionNote)>0,result.Message=result.Message+" "+data.CustomConditionNote;end
if ~isempty(warnings),result.Message=result.Message+" 주의: "+join(warnings," / ");end
end
