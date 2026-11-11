function bundle=analyzeBatch(input,sendProgress,prepared)
%ANALYZEBATCH Dispatch every file independently; retain global provenance rows.
arguments
    input (1,1) struct
    sendProgress (1,1) function_handle = @(~)[]
    prepared (1,1) struct = struct()
end
p=uecm.analysisPrepared(input,prepared);
bundle=struct('Prepared',p,'Fits',{{}},'Results',table(),'Version',"0.5.0-merged",'ComputationSchema',"uecm-v7-diffusion-1", ...
    'Timestamp',string(datetime('now','TimeZone','Asia/Seoul')),'Status',"needs_input");
bundle.CustomAxes=p.CustomAxes;bundle.AxisCategories=p.AxisCategories;
fits={};rows={};offset=0;requests=p.Requests([],:);
for k=1:numel(p.FilePrepared)
    q=p.FilePrepared{k};
    sendProgress(struct('Index',k,'Total',numel(p.FilePrepared), ...
        'Message',"파일 "+k+" / "+numel(p.FilePrepared)+" · "+q.Type+" · "+q.Input.File));
    if q.Blocked
        requests=[requests;q.Requests];
    else
        try
            child=uecm.analyze(q.Input,@(data)sendProgress(struct('Index',k,'Total',numel(p.FilePrepared), ...
                'Message',"파일 "+k+" / "+numel(p.FilePrepared)+" · "+q.Type+" · "+string(data.Message))),q);
            bundle.Prepared.Notes=[bundle.Prepared.Notes;child.Prepared.Notes(:)];
            requests=[requests;child.Prepared.Requests];
            for j=1:numel(child.Fits)
                f=child.Fits{j};f.SourceRows=f.SourceRows+offset;
                identity=table2struct(child.Results(j,:));
                identity.fit_id="fit_"+string(numel(fits)+1);
                identity.source_file=q.Input.File;f.Identity=identity;
                if isfield(f,'Alternatives')
                    for a=1:numel(f.Alternatives)
                        c=f.Alternatives{a};c.SourceRows=c.SourceRows+offset;
                        c.Identity=uecm.candidateRow(identity,c);f.Alternatives{a}=c;
                    end
                end
                fits{end+1,1}=f;rows{end+1,1}=identity;
            end
        catch ex
            request=table(q.Input.File,"file",string(ex.message), ...
                "이 파일의 입력 설정을 확인하세요. 다른 파일은 계속 처리합니다.",true, ...
                'VariableNames',{'Target','Field','Reason','Action','Blocking'});
            requests=[requests;request];
        end
    end
    offset=offset+height(q.Input.Data);
end
bundle.Prepared.Requests=requests;bundle.Fits=fits;
if ~isempty(rows)
    bundle.Results=struct2table(vertcat(rows{:}));bundle.Status="candidate";
    if any(requests.Blocking),bundle.Status="partial";end
end
for a=1:numel(bundle.CustomAxes)
 field=bundle.CustomAxes(a).Field;known=0;
 if ismember(field,string(bundle.Results.Properties.VariableNames)),known=nnz(isfinite(bundle.Results.(field)));end
 bundle.CustomAxes(a).LinkedCount=known;bundle.CustomAxes(a).MissingCount=height(bundle.Results)-known;
end
end
