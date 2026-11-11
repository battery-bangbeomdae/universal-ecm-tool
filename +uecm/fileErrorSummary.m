function [scores,overall]=fileErrorSummary(bundle,file)
%FILEERRORSUMMARY Actual same-data residual RMSE; pool by fitted point count.
scores=table();overall=struct('RMSE',NaN,'ErrorUnit',"",'NPoints',0,'NData',0);
rows={};squared=0;
if ~isfield(bundle,'Fits'),return,end
for k=1:numel(bundle.Fits)
    f=bundle.Fits{k};if string(f.SourceFile)~=string(file),continue,end
    overall.NData=overall.NData+1;local=overall.NData;
    e=f.Measured-f.Predicted;squared=squared+sum(abs(e).^2);overall.NPoints=overall.NPoints+numel(e);
    overall.ErrorUnit=f.ErrorUnit;cc=uecm.candidatesOf(f);
    for j=1:numel(cc)
        c=cc{j};e=c.Measured-c.Predicted;
        rows{end+1,1}=struct('data_number',local,'fit_index',k,'fit_id',bundle.Results.fit_id(k), ...
            'test_id',bundle.Results.test_id(k),'spectrum_id',bundle.Results.spectrum_id(k), ...
            'model',c.ModelName,'rmse',sqrt(mean(abs(e).^2)),'error_unit',c.ErrorUnit, ...
            'mae',mean(abs(e)),'max_abs_error',max(abs(e)), ...
            'n_points',numel(e),'recommended',c.ModelName==f.ModelName,'status',c.Status);
    end
end
if ~isempty(rows),scores=struct2table(vertcat(rows{:}));end
if overall.NPoints>0,overall.RMSE=sqrt(squared/overall.NPoints);end
end
