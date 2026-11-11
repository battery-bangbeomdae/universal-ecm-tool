function parts=effectiveInputs(input)
%EFFECTIVEINPUTS Resolve per-file settings/mappings/labels in one shared place.
if ~isfield(input,'OriginalInputs'),parts={input};return,end
parts=input.OriginalInputs;baseMapping=parts{1}.Mapping;defaults=uecm.defaults();
for k=1:numel(parts)
 item=parts{k};item.Settings=input.Settings;
 if isfield(input,'PerFileSettings')
  overrides=input.PerFileSettings{k};
  for name=string(fieldnames(overrides))'
   if ~isfield(input.Settings,name)||isequaln(input.Settings.(name),defaults.(name)),item.Settings.(name)=overrides.(name);end
  end
 end
 if isfield(input.Settings,'FileOptions')
  options=input.Settings.FileOptions;hit=find(string({options.File})==string(item.File),1);
  if ~isempty(hit),item.Settings.Type=string(options(hit).Type);item.Settings.CurrentSign=string(options(hit).CurrentSign);end
 end
 for f=string(fieldnames(item.Mapping))'
  if isfield(input.Mapping,f)&&input.Mapping.(f)~=baseMapping.(f),item.Mapping.(f)=input.Mapping.(f);end
  if isfield(input.Settings.Mapping,f),item.Mapping.(f)=input.Settings.Mapping.(f);end
 end
 if isfield(input,'ConditionLabels'),item.ConditionLabels=input.ConditionLabels(input.ConditionLabels.source_file==item.File,:);end
 parts{k}=item;
end
end
