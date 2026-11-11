function input=combineInputs(parts,settings)
%COMBINEINPUTS Preserve existing batch representation and individual import decisions.
files=string(cellfun(@(p)p.File,parts,'UniformOutput',false));
files=files(:);
input=parts{1};tables=cell(size(parts));columns=strings(1,0);
for k=1:numel(parts)
    columns=union(columns,string(parts{k}.Data.Properties.VariableNames),'stable');
end
numericColumns=true(size(columns));categoricalColumns=true(size(columns));
for k=1:numel(parts)
    raw=parts{k}.Data;
    for j=1:numel(columns)
        name=columns(j);
        if ismember(name,string(raw.Properties.VariableNames))
            numericColumns(j)=numericColumns(j)&&isnumeric(raw.(name));
            categoricalColumns(j)=categoricalColumns(j)&&iscategorical(raw.(name));
        end
    end
end
for k=1:numel(parts)
    raw=parts{k}.Data;T=table();
    for j=1:numel(columns)
        name=columns(j);present=ismember(name,string(raw.Properties.VariableNames));
        if numericColumns(j)
            if present,T.(name)=double(raw.(name));else,T.(name)=nan(height(raw),1);end
        elseif categoricalColumns(j)
            if present,T.(name)=raw.(name);else,T.(name)=categorical(repmat(string(missing),height(raw),1));end
        else
            if present,T.(name)=string(raw.(name));else,T.(name)=repmat(string(missing),height(raw),1);end
        end
    end
    T.uecm_input_file=repmat(categorical(files(k)),height(T),1);
    T.uecm_input_row=(1:height(T))';
    tables{k}=T;
end
input.Data=vertcat(tables{:});
input.Files=files;input.OriginalInputs=parts;
defaults=uecm.defaults();suggested=cell(size(parts));
for k=1:numel(parts)
    override=struct();names=fieldnames(parts{k}.Settings);
    for j=1:numel(names)
        name=names{j};
        if isfield(defaults,name)&&~isequaln(parts{k}.Settings.(name),defaults.(name))
            override.(name)=parts{k}.Settings.(name);
        end
    end
    suggested{k}=override;
end
input.Settings=settings;input.PerFileSettings=suggested;
if numel(parts)==1,input.Settings=parts{1}.Settings;end
end
