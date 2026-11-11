function f = fitEIS(freq,re,im,settings)
%FITEIS Fit RC branches with optional series semi-infinite Warburg diffusion.
arguments
    freq (:,1) double
    re (:,1) double
    im (:,1) double
    settings (1,1) struct = uecm.defaults()
end
if any(~isfinite([freq;re;im]))||any(freq<=0),error('uecm:EISValues','주파수·임피던스의 결측/유효 범위를 확인해 주세요.');end
% Internal imaginary values are signed Im(Z), regardless of import convention.
settings=uecm.withDefaults(settings);report=uecm.screenEIS(freq,re,im,settings);
keep=find(im<=0&~report.StatisticalOutlier&~report.UnstableRepeat);
if numel(unique(freq(keep)))<10
    error('uecm:EISPoints','Im(Z)>0 제외 후 서로 다른 EIS 주파수점이 10개 이상 필요합니다.');
end
[freq,order]=sort(freq(keep),'descend');order=keep(order);
z=complex(re(order),im(order));w=2*pi*freq;
scale=max(sqrt(mean(abs(z).^2)),eps);rs=max(min(real(z)),scale*1e-4);
rp=max(max(real(z))-rs,scale*.2);[~,pk]=max(-imag(z));tau=1/w(pk);
types=uecm.eisFitTypes(settings);
diffusion=(1-1i)./sqrt(w);
fits=cell(0,1);
[tailSupported,tailSigma]=uecm.warburgTailEvidence(freq,z);
for kind=types
    base=erase(kind,"+W");
    withCPE=base=="CPE";twoCPE=base=="2CPE";
    if base=="RC"||withCPE
        lo=log([scale*1e-7,scale*1e-7,1/max(w)/1e3]);hi=log([scale*1e3,scale*1e3,1/min(w)*1e3]);
        starts=[log([rs,rp,tau]);log([rs,rp,tau/10]);log([rs,rp,tau*10])];
        predict=@(x)exp(x(1))+exp(x(2))./(1+1i*w*exp(x(3)));
    elseif base=="2RC"||twoCPE
        lo=log([scale*1e-7,scale*1e-7,1/max(w)/1e3,scale*1e-7,1/max(w)/1e3]);
        hi=log([scale*1e3,scale*1e3,1/min(w)*1e3,scale*1e3,1/min(w)*1e3]);
        starts=log([rs,rp*.3,tau/10,rp*.7,tau*10;rs,rp*.7,tau/10,rp*.3,tau*10; ...
            rs,rp*.5,tau/3,rp*.5,tau*3;rs,rp*.5,tau/30,rp*.5,tau*30]);
        if ~isempty(fits)&&isfinite(fits{1}.Parameters.Rct_Ohm)
            a=fits{1}.Parameters;starts(end+1,:)=log([a.Rs_Ohm,a.Rct_Ohm/2,a.tau_s,a.Rct_Ohm/2,a.tau_s]);
        end
        predict=@(x)exp(x(1))+exp(x(2))./(1+1i*w*exp(x(3)))+exp(x(4))./(1+1i*w*exp(x(5)));
    else,error('uecm:Circuit','지원하지 않는 EIS 회로입니다.');end
    if withCPE
        lo=[lo,.35];hi=[hi,1];
        starts=[starts,repmat(.85,size(starts,1),1);starts,repmat(.6,size(starts,1),1)];
        predict=@(x)exp(x(1))+exp(x(2))./(1+(1i*w*exp(x(3))).^x(4));
    end
    if twoCPE
        lo=[lo,.35,.35];hi=[hi,1,1];
        nStarts=size(starts,1);
        starts=[starts,repmat([.85,.85],nStarts,1);starts,repmat([.7,.9],nStarts,1);starts,repmat([.9,.7],nStarts,1)];
        predict=@(x)exp(x(1))+exp(x(2))./(1+(1i*w*exp(x(3))).^x(6)) ...
            +exp(x(4))./(1+(1i*w*exp(x(5))).^x(7));
    end
    withWarburg=endsWith(kind,"+W");
    if withWarburg
        nRC=numel(lo);rcPredict=predict;
        sigmaMin=scale*sqrt(min(w))*1e-9;
        sigmaMax=scale*sqrt(max(w))*1e3;
        sigma0=max(-imag(z(end))*sqrt(w(end)),sigmaMin*10);
        starts=[starts,repmat(log(sigma0),size(starts,1),1); ...
            starts,repmat(log(sigma0/10),size(starts,1),1)];
        if tailSupported && (base=="RC"||withCPE)
            corrected=z-tailSigma*diffusion;
            [~,peak]=max(-imag(corrected));
            seed=log([max(min(real(corrected)),scale*1e-4), ...
                max(range(real(corrected)),scale*.01),1/w(peak)]);
            if withCPE,seed=[seed,.8];end
            starts(end+1,:)=[seed,log(tailSigma)];
        end
        lo=[lo,log(sigmaMin)];hi=[hi,log(sigmaMax)];
        predict=@(x)rcPredict(x(1:nRC))+exp(x(end))*diffusion;
    end
    residual=@(x)[real(predict(x)-z);imag(predict(x)-z)]/scale;
    sol=uecm.solveFit(residual,starts,lo,hi);zh=predict(sol.x);n=2*numel(z);k=numel(sol.x);
    p=exp(sol.x(1:3));params=struct('Rs_Ohm',p(1),'Rct_Ohm',NaN,'Cdl_F',NaN,'Ceff_F',NaN, ...
        'Warburg_sigma_Ohm_s_mhalf',NaN,'CPE_Q',NaN,'CPE_alpha',NaN,'L_H',NaN,'R1_Ohm',NaN,'C1_F',NaN,'R2_Ohm',NaN,'C2_F',NaN, ...
        'tau_s',NaN,'tau1_s',NaN,'tau2_s',NaN);
    if withCPE
        alpha=sol.x(4);
        params.Rct_Ohm=p(2);params.CPE_alpha=alpha;params.CPE_Q=p(3)^alpha/p(2);
        params.Ceff_F=p(3)/p(2);params.tau_s=p(3);
        circuit="Rs + (Rct || CPE)";model="CPE";taus=p(3);
    elseif base=="RC"
        params.Rct_Ohm=p(2);params.Cdl_F=p(3)/p(2);params.tau_s=p(3);
        circuit="Rs + (Rct || Cdl)";model="1RC";taus=p(3);
    else
        p=exp(sol.x);[taus,ix]=sort([p(3),p(5)]);R=[p(2),p(4)];R=R(ix);
        params.R1_Ohm=R(1);params.R2_Ohm=R(2);
        params.tau1_s=taus(1);params.tau2_s=taus(2);
        if twoCPE
            alpha=sol.x(5+ix);Q=taus.^alpha./R;
            params.CPE1_Q=Q(1);params.CPE2_Q=Q(2);
            params.CPE1_alpha=alpha(1);params.CPE2_alpha=alpha(2);
            params.Ceff1_F=taus(1)/R(1);params.Ceff2_F=taus(2)/R(2);
            circuit="Rs + (R1 || CPE1) + (R2 || CPE2)";model="2CPE";
        else
            params.C1_F=taus(1)/R(1);params.C2_F=taus(2)/R(2);
            circuit="Rs + (R1 || C1) + (R2 || C2)";model="2RC";
        end
    end
    if withWarburg
        params.Warburg_sigma_Ohm_s_mhalf=exp(sol.x(end));
        circuit=circuit+" + W";model=model+"+W";
    end
    status="candidate";why="학습 EIS 후보 피팅. 독립 검증 전입니다.";
    if sol.exitflag<=0||sol.boundary||sol.condition>1e8||sol.rmse>settings.EISRelativeErrorLimit
        status="review";why="수렴·경계·식별성 또는 잔차 검토 필요. "+why;end
    if nnz(report.StatisticalOutlier)>0,why=why+" 통계 이상점 "+nnz(report.StatisticalOutlier)+"개 제외.";end
    if nnz(report.UnstableRepeat)>0,why=why+" 불안정 반복 주파수 구간 "+nnz(report.UnstableRepeat)+"점 제외.";end
    if strlength(report.Properties.UserData.Warning)>0,status="review";why=why+" "+report.Properties.UserData.Warning;end
    corners=1./(2*pi*taus);
    if any(corners<min(freq)*3|corners>max(freq)/3)
        status="review";why="반원 양쪽 측정 대역이 충분하지 않습니다. "+why;end
    if (base=="2RC"||twoCPE)&&taus(2)/taus(1)<3
        status="review";why="두 시정수가 가까워 RC 가지를 구분하기 어렵습니다. "+why;end
    a=struct('Parameters',params,'Circuit',circuit,'Candidate',kind,'ModelName',model,'NParameters',k, ...
        'BIC',n*log(max(sum(sol.residual.^2)/n,1e-20))+k*log(n),'Status',status,'Reason',why, ...
        'RMSE',sqrt(mean(abs(zh-z).^2)),'RelativeError',sol.rmse,'ErrorUnit',"Ohm", ...
        'Solver',sol.solver,'ExitFlag',sol.exitflag,'Condition',sol.condition,'Boundary',sol.boundary, ...
        'History',sol.History,'StartSummary',sol.StartSummary,'BestStart',sol.BestStart, ...
        'Frequency',freq,'Measured',z,'Predicted',zh,'Domain',"EIS",'Time',[],'Current',[], ...
        'Baseline',NaN,'FitPoints',numel(freq),'SourceIndices',order,'ExcludedPositiveImaginary',nnz(report.PositiveImaginary),'ExcludedOutlierCount',nnz(report.StatisticalOutlier),'ExcludedRepeatCount',nnz(report.UnstableRepeat),'PreprocessingVersion',2,'Preprocessing',report);
    if withWarburg
        % The preceding fit used the same circuit family and measured points.
        baseline=fits{end};
        if a.ExitFlag>0&&a.RMSE<baseline.RMSE&&a.BIC<baseline.BIC ...
                &&(baseline.Status=="review"||a.Status~="review")
            fits{end}=a;
        end
    else
        fits{end+1,1}=a; %#ok<AGROW>
    end
end
f=uecm.compareCandidates(fits);
f.EvaluatedModels=types;
end
