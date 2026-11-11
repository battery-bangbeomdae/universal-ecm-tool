function p=analysisPrepared(input,prepared)
%ANALYSISPREPARED Reuse only a diagnosis made from exactly the same input/settings.
arguments
 input (1,1) struct
 prepared (1,1) struct = struct()
end
if isempty(fieldnames(prepared)),p=uecm.prepare(input);return,end
if ~isfield(prepared,'Input')||~isequaln(prepared.Input,input)
 error('uecm:PreparedInputMismatch','입력 또는 설정이 바뀌었습니다. 자료 확인을 다시 실행하세요.');
end
p=prepared;
if ~isfield(p,'CustomAxes'),[p.Data,p.CustomAxes,p.AxisCategories]=uecm.importConditionAxes(p.Data,input);end
end
