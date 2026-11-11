function fits = fitHPPC(time,current,voltage,settings)
%FITHPPC Fit BOTH 1RC and 2RC to identical local pulse/recovery windows.
arguments
    time (:,1) double
    current (:,1) double
    voltage (:,1) double
    settings (1,1) struct = uecm.defaults()
end
if numel(time)~=numel(current)||numel(time)~=numel(voltage)||numel(time)<15
    error('uecm:TimeSeries','시간·전류·전압 길이가 같고 15점 이상이어야 합니다.');end
if any(~isfinite([time;current;voltage]))||any(diff(time)<=0)
    error('uecm:TimeOrder','시간·전류·전압의 결측과 시간 역전/중복을 확인해 주세요. 자동 정렬하지 않습니다.');end
% Rest threshold. The v0.2 rule (2 % of the largest current) treats a 0.3 A recharge as rest when the file has a
% 36 A pulse (Samsung 30T). Default: min(2 % of max, 0.05 A); settings.RestCurrent_A overrides.
threshold=min(max(abs(current))*.02,0.05);
if isfield(settings,'RestCurrent_A')&&isfinite(settings.RestCurrent_A)&&settings.RestCurrent_A>0,threshold=settings.RestCurrent_A;end
threshold=max(threshold,1e-8);active=abs(current)>threshold;
% Runs shorter than 5 samples OR shorter than 0.1 s cannot be fitted as pulses; treat them as rest so a current
% glitch at a pulse end does not cut the following relaxation window. Wuppertal cell tester: 1-sample +-0.05 A
% (MCU1) and an 8-sample (8 ms at 1 kHz) +0.051 A blip after the 50 % SOC charge pulse (MCU6) - a count-only rule
% dropped that pulse.
runStart=find(diff([false;active])==1);runEnd=find(diff([active;false])==-1);hadRuns=~isempty(runStart);
for q=find((runEnd-runStart)<4|(time(runEnd)-time(runStart))<0.1)',active(runStart(q):runEnd(q))=false;end
maxDuration=Inf;
if isfield(settings,'MaxPulseDuration_s')&&isfinite(settings.MaxPulseDuration_s)&&settings.MaxPulseDuration_s>0,maxDuration=settings.MaxPulseDuration_s;end
starts=find(diff([false;active])==1);ends=find(diff([active;false])==-1);fits=cell(0,1);
if isempty(starts)&&hadRuns,error('uecm:PulseCoverage','전류가 흐른 구간은 있지만 모두 5샘플·0.1초보다 짧아 펄스로 피팅할 수 없습니다. 기록 간격을 줄이거나 펄스를 길게 측정해 주세요.');end
if isempty(starts),error('uecm:NoPulse','전류 펄스가 없습니다. 시간·전류·전압이 담긴 펄스 시험을 넣어 주세요.');end
for h=1:numel(starts)
    first=starts(h);last=ends(h);previousEnd=0;if h>1,previousEnd=ends(h-1);end
    before=(previousEnd+1):(first-1);afterEnd=numel(time);if h<numel(starts),afterEnd=starts(h+1)-1;end
    if numel(before)<5||last-first<5||afterEnd-last<5,continue,end
    if time(last)-time(first)>maxDuration,continue,end   % e.g. CC recharge / SOC-step discharges between HPPC pulses
    % Constant-current check on the plateau: >=90 % of pulse samples within +-5 % of the median. A cell tester's
    % ~10 ms rise and fall (Wuppertal, 1 kHz logging) made the v0.2 rule std<5 % reject every real pulse; the fit
    % itself always uses the MEASURED current, so ramps are modelled, not ignored.
    amp=median(current(first:last));if mean(abs(current(first:last)-amp)<=.05*abs(amp))<.9,continue,end
    idx=(first:afterEnd)';t=time(idx)-time(first);i=current(idx);v=voltage(idx);
    baseRows=before(max(1,end-9):end);base=median(voltage(baseRows));dt=median(diff(time));
    duration=time(last)-time(first);relax=time(afterEnd)-time(last);preDuration=time(first)-time(before(1));
    r0=max((base-v(1))/amp,1e-5);r1=max((v(1)-v(last-first+1))/amp,1e-5);
    tau=max(duration/2,dt*3);scale=max(abs(amp)*(r0+r1),.001);candidates=cell(0,1);one=[];
    for branches=1:2
        if branches==1
            lo=log([1e-7,1e-7,dt*.2]);hi=log([100,100,max(duration+relax,dt)*100]);
            initials=log([r0,r1,tau;r0,r1,tau/4;r0,r1,tau*4]);
            predict=@(x)uecm.simulatePulse(t,i,base,exp(x(1)),exp(x(2)),exp(x(3)));
        else
            lo=log([1e-7,1e-7,dt*.2,1e-7,dt*.2]);hi=log([100,100,max(duration+relax,dt)*100,100,max(duration+relax,dt)*100]);
            initials=log([one(1),one(2)*.3,one(3)/8,one(2)*.7,one(3)*4; ...
                one(1),one(2)*.7,one(3)/8,one(2)*.3,one(3)*4; ...
                one(1),one(2)*.5,one(3)/3,one(2)*.5,one(3)*3; ...
                one(1),one(2)*.5,one(3)/20,one(2)*.5,one(3)*10; ...
                one(1),one(2)*.5,one(3),one(2)*.5,one(3)]);
            predict=@(x)uecm.simulatePulse(t,i,base,exp(x(1)),exp(x([2,4])),exp(x([3,5])));
        end
        sol=uecm.solveFit(@(x)(predict(x)-v)/scale,initials,lo,hi);p=exp(sol.x);vh=predict(sol.x);
        if branches==1,one=p;taus=p(3);resist=p(2);
        else,[taus,j]=sort(p([3,5]));resist=p([2,4]);resist=resist(j);end
        rmse=sqrt(mean((vh-v).^2));status="candidate";
        why="국소 일정 기준전압·초기 분극 0 가정. OCV-SOC/독립 전압 검증 미완료.";
        if sol.exitflag<=0||sol.condition>1e8||sol.boundary||rmse>settings.PulseErrorLimit_V
            status="review";why="수렴·식별성·잔차 검토 필요. "+why;end
        if any(taus<3*dt|taus>min(duration,relax)/2)||preDuration<3*max(taus)
            status="review";why="시정수 대비 샘플링/펄스/휴지 구간이 부족할 수 있습니다. "+why;end
        if branches==2&&taus(2)/taus(1)<3
            status="review";why="두 시정수가 가까워 두 RC 가지를 구분하기 어렵습니다. "+why;end
        if abs(median(voltage(max(last+1,afterEnd-4):afterEnd))-base)>.01
            status="review";why="기준전압 차이가 커 OCV 변화/휴지 부족을 확인하세요. "+why;end
        params=struct('R0_Ohm',p(1),'R1_Ohm',resist(1),'C1_F',taus(1)/resist(1), ...
            'R2_Ohm',NaN,'C2_F',NaN,'tau_s',NaN,'tau1_s',taus(1),'tau2_s',NaN);
        if branches==1,params.tau_s=taus(1);circuit="OCV - R0 - (R1 || C1)";
        else,params.R2_Ohm=resist(2);params.C2_F=taus(2)/resist(2);params.tau2_s=taus(2);circuit="OCV - R0 - (R1 || C1) - (R2 || C2)";end
        model=string(branches)+"RC";n=numel(v);k=numel(p);
        a=struct('Parameters',params,'Circuit',circuit,'Candidate',"HPPC_"+model,'ModelName',model,'NParameters',k, ...
            'BIC',n*log(max(sum(sol.residual.^2)/n,1e-20))+k*log(n),'Status',status,'Reason',why, ...
            'RMSE',rmse,'RelativeError',rmse/scale,'ErrorUnit',"V",'Solver',sol.solver, ...
            'ExitFlag',sol.exitflag,'Condition',sol.condition,'Boundary',sol.boundary, ...
            'History',sol.History,'StartSummary',sol.StartSummary,'BestStart',sol.BestStart, ...
            'Frequency',[],'Measured',v,'Predicted',vh,'Domain',"HPPC",'Time',t,'Current',i, ...
            'Baseline',base,'FitPoints',numel(idx),'SourceIndices',idx,'PulseStart',first,'PulseEnd',last);
        candidates{end+1,1}=a; %#ok<AGROW>
    end
    fits{end+1,1}=uecm.compareCandidates(candidates); %#ok<AGROW>
end
if isempty(fits),error('uecm:PulseCoverage','펄스 전 휴지·일정 전류·펄스 후 회복 구간이 충분한 기록이 필요합니다. 일반 운전 시계열 자동 식별은 미지원입니다.');end
end
