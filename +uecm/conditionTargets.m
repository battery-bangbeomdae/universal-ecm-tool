function targets=conditionTargets(input,p)
%CONDITIONTARGETS One optional label target per spectrum or candidate HPPC pulse.
arguments
    input (1,1) struct
    p (1,1) struct = struct()
end
if isempty(fieldnames(p)),p=uecm.prepare(input);end
prepared={p};
if isfield(p,'FilePrepared'),prepared=p.FilePrepared;end
rows={};
for part=1:numel(prepared)
    q=prepared{part};T=q.Data;
    if ~ismember('calendar',T.Properties.VariableNames),T.calendar=nan(height(T),1);T.calendar_source=strings(height(T),1);end
    if q.Blocked||isempty(T),continue,end
    group=findgroups(T.source,T.cell,T.test,T.spectrum);
    byGroup=accumarray(group,(1:height(T))',[],@(idx){sort(idx)});
    [~,order]=sort(cellfun(@(idx)idx(1),byGroup));byGroup=byGroup(order);
    for k=1:numel(byGroup)
        idx=byGroup{k};G=T(idx,:);windows=[1,height(G)];scope="스펙트럼";
        if q.Type=="HPPC"
            scope="후보 펄스 시작 조건";
            active=abs(G.current)>max(.02*max(abs(G.current)),1e-8);
            starts=find(diff([false;active])==1);ends=find(diff([active;false])==-1);
            windows=zeros(0,2);
            for h=1:numel(starts)
                first=starts(h);last=ends(h);previous=0;if h>1,previous=ends(h-1);end
                after=height(G);if h<numel(starts),after=starts(h+1)-1;end
                if first-previous<6||last-first<5||after-last<5,continue,end
                windows(end+1,:)=[first,after]; %#ok<AGROW>
            end
            if isempty(windows),windows=[1,height(G)];scope="시험 구간 · 펄스 미확인";end
        end
        for w=1:size(windows,1)
            first=windows(w,1);last=windows(w,2);
            r=struct('source_file',q.Input.File,'source_id',G.source(first),'cell_id',G.cell(first), ...
                'test_id',G.test(first),'spectrum_id',G.spectrum(first),'row_start',idx(first),'row_end',idx(last), ...
                'scope',scope,'soc_pct',G.soc(first),'soh_pct',G.soh(first),'temperature_C',G.temperature(first), ...
                'cycle_number',G.cycle(first),'initial_capacity_Ah',G.initial_capacity(first), ...
                'current_capacity_Ah',G.current_capacity(first),'calendar_days',G.calendar(first));
            for name=["soc","soh","temperature","cycle","initial_capacity","current_capacity","calendar"]
                r.(name+"_source")=G.(name+"_source")(first);
            end
            rows{end+1,1}=r; %#ok<AGROW>
        end
    end
end
targets=table();
if ~isempty(rows),targets=struct2table(vertcat(rows{:}));end
end
