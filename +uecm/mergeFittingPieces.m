function bundle=mergeFittingPieces(p,pieces)
%MERGEFITTINGPIECES Rebase file-local fits and current axis/category identities.
bundle=struct('Prepared',p,'Fits',{{}},'Results',table(),'Version',"0.5.0-merged",'ComputationSchema',"uecm-v7-diffusion-1",'Timestamp',string(datetime('now','TimeZone','Asia/Seoul')),'Status',"needs_input");
bundle.CustomAxes=p.CustomAxes;bundle.AxisCategories=p.AxisCategories;
parts={p};if isfield(p,'FilePrepared'),parts=p.FilePrepared;end
rows={};offset=0;requests=p.Requests;
for k=1:numel(parts)
 q=parts{k};piece=pieces{k};
 if ~isempty(piece)
  requests=[requests;piece.Prepared.Requests]; %#ok<AGROW>
  for j=1:height(piece.Results)
   f=piece.Fits{j};identity=table2struct(piece.Results(j,:));identity.fit_id="fit_"+(numel(rows)+1);identity.source_file=string(q.Input.File);
   start=f.SourceRows(1);group=q.Data.source==identity.source_id&q.Data.cell==identity.cell_id&q.Data.test==identity.test_id&q.Data.spectrum==identity.spectrum_id;
   if q.Type=="HPPC"&&isfield(f,'PulseStart'),indices=find(group);start=indices(f.PulseStart);end
   % Replace cached condition labels with the current curated table, including missing values.
   for field=["soc","soh","temperature","cycle","calendar","initial_capacity","current_capacity"]
    target=field;switch field
     case "soc",target="soc_pct";case "soh",target="soh_pct";case "temperature",target="temperature_C";
     case "cycle",target="cycle_number";case "calendar",target="calendar_days";
     case "initial_capacity",target="initial_capacity_Ah";case "current_capacity",target="current_capacity_Ah";
    end
    identity.(target)=q.Data.(field)(start);
    sourceField=field+"_source";if ismember(sourceField,string(q.Data.Properties.VariableNames)),identity.(sourceField)=q.Data.(sourceField)(start);end
   end
   for field=["cell_model","cathode_family","cathode_composition","cell_format"]
    identity.(field)=q.Data.(field)(start);
   end
   for a=q.CustomAxes
    values=q.Data.(a.Field);v=values(start);
    if q.Type=="EIS",subset=values(group);if any(~isfinite(subset))||numel(unique(subset(isfinite(subset))))>1,v=NaN;end,end
    identity.(a.Field)=v;
   end
   f.SourceRows=f.SourceRows+offset;f.SourceFile=string(q.Input.File);f.Identity=identity;
   if isfield(f,'Alternatives')
    for a=1:numel(f.Alternatives)
     c=f.Alternatives{a};c.SourceRows=c.SourceRows+offset;c.SourceFile=f.SourceFile;c.Identity=uecm.candidateRow(identity,c);f.Alternatives{a}=c;
    end
   end
   bundle.Fits{end+1,1}=f;rows{end+1,1}=identity; %#ok<AGROW>
  end
  if isfield(piece,'CustomAxes')
   for a=piece.CustomAxes
    if ~ismember(a.Field,string({bundle.CustomAxes.Field})),bundle.CustomAxes(end+1)=a;end
   end
  end
 end
 offset=offset+height(q.Input.Data);
end
if ~isempty(rows)
 names=strings(0,1);for k=1:numel(rows),names=union(names,string(fieldnames(rows{k})),'stable');end
 for k=1:numel(rows),for f=names',if ~isfield(rows{k},f),rows{k}.(f)=NaN;end,end;rows{k}=orderfields(rows{k},cellstr(names));end
 bundle.Results=struct2table(vertcat(rows{:}));bundle.Status="candidate";
 if any(cellfun(@isempty,pieces))||any(requests.Blocking),bundle.Status="partial";end
end
bundle.Prepared.Requests=unique(requests,'rows','stable');
for k=1:numel(bundle.CustomAxes)
 f=bundle.CustomAxes(k).Field;n=0;if ismember(f,string(bundle.Results.Properties.VariableNames)),n=nnz(isfinite(bundle.Results.(f)));end
 bundle.CustomAxes(k).LinkedCount=n;bundle.CustomAxes(k).MissingCount=height(bundle.Results)-n;
end
end
