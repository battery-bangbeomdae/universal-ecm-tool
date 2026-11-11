function N=applyConditionLabels(N,input)
%APPLYCONDITIONLABELS Keep supplied data, fill optional measurement labels and capacity SOH.
[originalInitial,originalCurrent]=uecm.capacityData(input.Data);
if ~ismember('initial_capacity',N.Properties.VariableNames)
    N.initial_capacity=originalInitial;N.current_capacity=originalCurrent;
end
names=["soc","soh","temperature","cycle","initial_capacity","current_capacity","calendar"];
map=uecm.inferMapping(input.Data.Properties.VariableNames);
if ~isempty(input.Metadata),metadataMapping=uecm.inferMapping(input.Metadata.Properties.VariableNames);end
for name=names
    source=strings(height(N),1);known=isfinite(N.(name));
    source(known)="source_data";
    if ismember(name,["soc","soh","temperature","cycle","calendar"])
        original=false(height(N),1);
        if isfield(input.Mapping,name),column=input.Mapping.(name);else,column=map.(name);end
        if strlength(column)>0&&ismember(column,string(input.Data.Properties.VariableNames))
            original=isfinite(str2double(string(input.Data.(column))));
        end
        source(known&~original)="calculated";
        if ~isempty(input.Metadata)
            m=metadataMapping;
            if strlength(m.(name))>0,source(known&~original)="metadata";end
        end
    end
    if name=="initial_capacity",source(known&~isfinite(originalInitial))="metadata";end
    if name=="current_capacity",source(known&~isfinite(originalCurrent))="metadata";end
    N.(name+"_source")=source;
end
if isfield(input,'ConditionLabels')&&~isempty(input.ConditionLabels)
    labels=input.ConditionLabels;
    external=["soc_pct","soh_pct","temperature_C","cycle_number","initial_capacity_Ah","current_capacity_Ah","calendar_days"];
    for k=1:height(labels)
        if labels.source_file(k)~=input.File,continue,end
        selected=(1:height(N))'>=labels.row_start(k)&(1:height(N))'<=labels.row_end(k);
        for id=["source","cell","test","spectrum"]
            selected=selected&N.(id)==labels.(id+"_id")(k);
        end
        for j=1:numel(names)
            if ~ismember(external(j),string(labels.Properties.VariableNames)),continue,end
            name=names(j);value=uecm.validateConditionValue(external(j),labels.(external(j))(k));
            if ~isfinite(value),continue,end
            available=~isfinite(N.(name))|N.(name+"_source")=="calculated";
            use=selected&available;
            N.(name)(use)=value;N.(name+"_source")(use)="manual";
        end
    end
end
use=~isfinite(N.soh)&isfinite(N.initial_capacity)&N.initial_capacity>0 ...
    &isfinite(N.current_capacity)&N.current_capacity>0;
N.soh(use)=100*N.current_capacity(use)./N.initial_capacity(use);
N.soh_source(use)="capacity_ratio";
end
