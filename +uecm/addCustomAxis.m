function [bundle,report]=addCustomAxis(bundle,M,column,label,unit,keys,source)
%ADDCUSTOMAXIS Join explicit numeric experimental metadata to fitted measurements.
arguments
 bundle (1,1) struct
 M table
 column (1,1) string
 label (1,1) string
 unit (1,1) string
 keys string
 source (1,1) string = "user table"
end
if ~isfield(bundle,'Results')||isempty(bundle.Results),error('uecm:CustomAxis','먼저 피팅 결과를 생성하세요.');end
R=bundle.Results;keys=keys(:)';
allowed=["fit_id","measurement_id","source_id","source_file","cell_id","test_id","spectrum_id"];
if isempty(keys)||~all(ismember(keys,allowed))||~all(ismember(keys,string(R.Properties.VariableNames)))||~all(ismember(keys,string(M.Properties.VariableNames)))
 error('uecm:CustomAxis','양쪽 표에 존재하는 측정 식별 키를 선택하세요.');end
if ~ismember(column,string(M.Properties.VariableNames))||ismember(column,keys)||strlength(strtrim(label))==0
 error('uecm:CustomAxis','조건 값 열과 표시 이름을 확인하세요.');end
A=strings(height(R),numel(keys));B=strings(height(M),numel(keys));
for k=1:numel(keys)
 A(:,k)=string(R.(keys(k)));B(:,k)=string(M.(keys(k)));
 if any(ismissing(B(:,k))|strlength(strtrim(B(:,k)))==0),error('uecm:CustomAxis','조건표의 식별 키에 빈 값이 있습니다.');end
end
% Multi-column string rows avoid delimiter collisions in path/test identifiers.
if height(unique(B,'rows'))~=height(M),error('uecm:CustomAxis','선택한 키가 조건표에서 중복됩니다. 더 세부적인 키를 추가하세요.');end
v=M.(column);
if isnumeric(v),v=double(v);else
 s=string(v);v=str2double(s);bad=~ismissing(s)&strlength(strtrim(s))>0&isnan(v);
 if any(bad),error('uecm:CustomAxis','조건 값에 숫자가 아닌 값이 있습니다. 숫자 또는 빈칸만 사용하세요.');end
end
if ~isvector(v)||numel(v)~=height(M)||any(isinf(v)),error('uecm:CustomAxis','유한 숫자 또는 빈 값만 허용합니다.');end
[matched,j]=ismember(A,B,'rows');matched=matched&~any(ismissing(A)|strlength(strtrim(A))==0,2);
values=nan(height(R),1);values(matched)=v(j(matched));
if ~any(isfinite(values)),error('uecm:CustomAxis','유효한 숫자가 연결된 측정이 없습니다. 선택한 키와 값을 확인하세요.');end
field=string(matlab.lang.makeValidName("custom_"+column));
if ismember(field,string(R.Properties.VariableNames)),error('uecm:CustomAxis','이미 등록된 변수입니다. 중복 등록 대신 새 세션 또는 다른 열 이름을 사용하세요.');end
R.(field)=values;bundle.Results=R;
entry=struct('Field',field,'Label',strtrim(label),'Unit',strtrim(unit),'Source',source,'Column',column,'Keys',keys, ...
 'LinkedCount',sum(isfinite(values)),'MissingCount',sum(~isfinite(values)));
if ~isfield(bundle,'CustomAxes')||isempty(bundle.CustomAxes),bundle.CustomAxes=entry;else,bundle.CustomAxes(end+1)=entry;end
report=label+": "+sum(isfinite(values))+" / "+height(R)+"개 연결 · 미연결/빈 값 "+sum(~isfinite(values))+"개 · 조건표 미사용 행 "+sum(~ismember(B,A,'rows'))+"개. 단위 변환·피팅 재계산 없음.";
end
