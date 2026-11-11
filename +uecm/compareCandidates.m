function selected = compareCandidates(candidates)
%COMPARECANDIDATES Separate SAME-DATA training error winner from recommendation.
arguments
    candidates cell
end
n=numel(candidates);rows=cell(n,1);
reference=candidates{1};
for k=1:n
    c=candidates{k};
    if ~isequaln(c.Measured,reference.Measured)||~isequaln(c.SourceIndices,reference.SourceIndices)
        error('uecm:UnfairComparison','후보가 같은 측정 행을 사용하지 않아 오차를 비교하지 않습니다.');
    end
    e=c.Predicted-c.Measured;
    rows{k}=struct('Model',c.ModelName,'NParameters',c.NParameters,'NPoints',numel(e), ...
        'RMSE',sqrt(mean(abs(e).^2)),'MAE',mean(abs(e)),'MaxAbsError',max(abs(e)), ...
        'ErrorUnit',c.ErrorUnit,'BIC',c.BIC,'Status',c.Status,'Condition',c.Condition, ...
        'Converged',c.ExitFlag>0,'Recommended',false,'LowestTrainingError',false, ...
        'ValidationRMSE',NaN,'ValidationStatus',"not_provided");
end
scores=struct2table(vertcat(rows{:}));[~,best]=min(scores.RMSE);
% Only distinguish errors beyond floating-point noise at the scale of the response.
tolerance=max(sqrt(mean(abs(reference.Measured).^2))*1e-10,1e-14);
winners=abs(scores.RMSE-scores.RMSE(best))<=tolerance;scores.LowestTrainingError=winners;
valid=find(scores.Status=="candidate"&scores.Converged);
if isempty(valid),valid=find(scores.Converged);end
if isempty(valid),valid=(1:n)';end
[~,j]=min(scores.BIC(valid));pick=valid(j);
selectionReason="BIC·수렴·품질 기준";
if string(reference.Domain)=="EIS" && ismember(scores.Model(pick),["2RC","2CPE","2RC+W","2CPE+W"])
    [tailSupported,tailSigma,tailUpper]=uecm.warburgTailEvidence(reference.Frequency,reference.Measured);
    if tailSupported
        simpler=valid(ismember(scores.Model(valid),["1RC+W","CPE+W"]) & scores.Status(valid)=="candidate");
        for index=simpler(:)'
            sigma=candidates{index}.Parameters.Warburg_sigma_Ohm_s_mhalf;
            if ~(sigma>=tailSigma/2 && sigma<=2*tailSigma),simpler(simpler==index)=[];end
        end
        if ~isempty(simpler)
            [bic,index]=min(scores.BIC(simpler));
            % Require strong additional evidence for a second relaxation.
            params=candidates{pick}.Parameters;
            overlapsTail=~endsWith(scores.Model(pick),"+W") && isfield(params,'tau2_s') ...
                && isfinite(params.tau2_s) && params.tau2_s>0 ...
                && 1/(2*pi*params.tau2_s)<=tailUpper;
            if overlapsTail
                pick=simpler(index);
                selectionReason="느린 가지의 특성 주파수가 확산 꼬리와 겹침";
            elseif bic-scores.BIC(pick)<6
                pick=simpler(index);
                selectionReason="저주파 확산 근거 확인 · 두 번째 완화의 BIC 개선 6 미만";
            end
        end
    end
end
scores.Recommended(pick)=true;
summary="같은 "+height(reference.Measured)+"개 측정점: ";
for k=1:n,summary=summary+scores.Model(k)+" RMSE="+compose('%.5g',scores.RMSE(k))+" "+scores.ErrorUnit(k)+"; ";end
summary=summary+"학습 오차 최소: "+join(scores.Model(winners)," / ")+". ";
summary=summary+"현재 권장: "+scores.Model(pick)+" ("+selectionReason+"). ";
if scores.Status(pick)~="candidate",summary=summary+"모든 후보가 검토 대상이라 권장은 잠정입니다. ";end
summary=summary+"독립 검증 자료 없음: 새 시험의 예측오차 우열은 확인하지 못했습니다.";
selected=candidates{pick};selected.Alternatives=candidates;selected.CandidateScores=scores;
selected.RecommendedIndex=pick;selected.ComparisonSummary=summary;selected.TrainingWinner=join(scores.Model(winners)," / ");
end
