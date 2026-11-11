function C=conditionCoverage(p)
%CONDITIONCOVERAGE Report unlinked conditions, never assert absence in source.
parts={p};if isfield(p,'FilePrepared'),parts=p.FilePrepared;end
fields=["soc","soh","temperature","cycle","calendar","initial_capacity","current_capacity"];
external=["soc_pct","soh_pct","temperature_C","cycle_number","calendar_days","initial_capacity_Ah","current_capacity_Ah"];
labels=["SOC [%]","SOH [%]","온도 [C]","사이클 수","열화 경과일 [day]","초기 실측 용량 [Ah]","현재 실측 용량 [Ah]"];
patterns=["soc|state.?of.?charge|충전상태","soh|state.?of.?health|건강","temp|온도", ...
    "cycle|사이클","calendar|aging|ageing|storage|elapsed|date|day|경과|날짜", ...
    "capacity|initial|baseline|용량","capacity|current|measured|용량"];
rows={};
for k=1:numel(parts)
 q=parts{k};T=q.Data;input=q.Input;names=string(input.Data.Properties.VariableNames);
 if ~isempty(input.Metadata),names=[names,string(input.Metadata.Properties.VariableNames)];end
 if isfield(input,'RawReport')&&isfield(input.RawReport,'ObservedColumns'),names=[names,reshape(string(input.RawReport.ObservedColumns),1,[])];end
 names=unique(names,'stable');
 if height(T)>0
  groups=findgroups(T.source,T.cell,T.test,T.spectrum);assigned=isfinite(groups);
  if any(assigned),total=accumarray(groups(assigned),1);else,total=zeros(0,1);end
 else,groups=[];assigned=false(0,1);total=zeros(0,1);end
 for j=1:numel(fields)
  values=nan(height(T),1);if ismember(fields(j),string(T.Properties.VariableNames)),values=T.(fields(j));end
  known=zeros(size(total));if any(assigned),known=accumarray(groups(assigned),double(isfinite(values(assigned))),size(total));end
  complete=sum(known==total);partial=sum(known>0&known<total);missing=sum(known==0);
  status="모두 연결";action="";
  if isempty(total),status="측정 구간 미확인";action="먼저 신호·단위·식별자 진단을 해결하세요.";
  elseif missing>0||partial>0
   status="일부 미연결";if missing==numel(total),status="전체 미연결";end
   action="원본·README/논문을 확인하고 열 연결·조건표·직접 입력으로 보충하거나 LLM 가공 후 재입력하세요. 미확인은 공란으로 유지합니다.";
  end
  suspect=names(~cellfun('isempty',regexpi(cellstr(names),patterns(j),'once')));
  rows{end+1,1}=struct('input_file',string(input.File),'measurement_type',q.Type,'field',external(j),'label',labels(j), ...
   'measurement_groups',numel(total),'complete_groups',complete,'partial_groups',partial,'missing_groups',missing, ...
   'known_rows',nnz(isfinite(values)),'total_rows',height(T),'unassigned_id_rows',nnz(~assigned),'status',status,'signal_blocked',q.Blocked, ...
   'possible_source_columns',join(suspect,"; "),'action',action); %#ok<AGROW>
 end
end
C=struct2table(vertcat(rows{:}));
end
