function value=validateConditionValue(field,value)
%VALIDATECONDITIONVALUE Optional labels use canonical units; NaN means omitted.
if isempty(value),value=NaN;end
if ~isnumeric(value)||~isscalar(value)||isinf(value)
    error('uecm:ConditionValue','숫자를 입력하거나 빈칸으로 두세요.');
end
if isnan(value),return,end
if field=="soc_pct"&&(value<0||value>100)
    error('uecm:ConditionValue','SOC는 0~100% 범위로 입력하세요.');
elseif field=="soh_pct"&&value<0
    error('uecm:ConditionValue','SOH는 0 이상의 백분율로 입력하세요. 초기 실측 기준보다 용량이 높으면 100%를 넘을 수 있습니다.');
elseif field=="calendar_days"&&value<0
    error('uecm:ConditionValue','열화 경과일은 0 이상의 일수로 입력하세요.');
elseif field=="cycle_number"&&(value<0||value~=floor(value))
    error('uecm:ConditionValue','사이클 수는 0 이상의 정수로 입력하세요.');
elseif endsWith(field,"capacity_Ah")&&value<=0
    error('uecm:ConditionValue','실측 용량은 0보다 큰 Ah 값으로 입력하세요.');
elseif field=="temperature_C"&&value< -273.15
    error('uecm:ConditionValue','온도는 −273.15°C 이상으로 입력하세요.');
end
end
