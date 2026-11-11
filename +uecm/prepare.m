function p = prepare(input)
%PREPARE Check mapped columns, explicit units, identity and metadata joins.
arguments
    input (1,1) struct
end
if isfield(input,'OriginalInputs')&&numel(input.OriginalInputs)>1
    p=uecm.prepareBatch(input);return
end
o=uecm.withDefaults(input.Settings);T=input.Data;m=input.Mapping;n=height(T);
if ~isfield(m,'calendar'),inferred=uecm.inferMapping(T.Properties.VariableNames);m.calendar=inferred.calendar;end
conversions=struct('Field',{},'SourceColumn',{},'SourceUnit',{},'Factor',{},'OutputUnit',{});
req=struct('Target',{},'Field',{},'Reason',{},'Action',{},'Blocking',{});notes=strings(0,1);
N=table();mapping=fieldnames(m);
for k=1:numel(mapping)
    field=mapping{k};name=m.(field);
    if strlength(name)>0 && ~ismember(name,string(T.Properties.VariableNames))
        add(field,"선택한 열을 찾을 수 없습니다.","열 연결을 다시 골라 주세요.",true);m.(field)="";
    end
end
if n==0,add('data','표에 측정 기록이 없습니다.','열 이름 아래에 실제 측정 기록을 넣어 주세요.',true);end
for f=["source","cell","test","spectrum"]
    if strlength(m.(f))>0&&n>0
        ids=string(T.(m.(f)));
        if all(ismissing(ids)|strlength(strip(ids))==0)
            notes(end+1)="빈 선택 ID 열 "+m.(f)+"은 사용하지 않고 파일 단위 구분을 사용합니다. 여러 셀/시험이면 ID를 채워 주세요.";
            m.(f)="";
        end
    end
end
has=@(f)strlength(m.(f))>0;
isEIS=has('frequency')||has('real')||has('imag')||has('magnitude');
isTime=has('time')||has('current')||has('voltage');kind=o.Type;
if kind=="auto"
    if isEIS && isTime
        kind="ambiguous";add("type","EIS와 시간 신호가 함께 있습니다.","분석 종류에서 EIS 또는 HPPC를 선택해 주세요.",true);
    elseif isEIS,kind="EIS";elseif isTime,kind="HPPC";
    else,kind="unknown";add("type","ECM 식별에 필요한 신호 열을 찾지 못했습니다.","EIS 또는 HPPC 원본 신호를 넣거나 열을 연결해 주세요.",true);end
end
for f=["source","cell","test","spectrum"]
    if has(f),N.(f)=string(T.(m.(f)));else
        [~,stem]=fileparts(input.File);v=stem;
        if f=="cell",v="unassigned";elseif f=="spectrum",v="single";end
        N.(f)=repmat(string(v),n,1);
    end
    if any(ismissing(N.(f))|strlength(N.(f))==0)
        add(f,"측정 식별자에 빈 값이 있습니다.","같은 시험에 같은 식별자를 넣어 주세요.",true);
    end
end
% [G] EIS table WITHOUT a spectrum ID (tidy/template path): split repeated sweeps with the SAME rule as the raw
% reader (uecm.sweepIndex), per source+cell+test. Before 2026-11-09 every row became spectrum "single", so a file
% with 82 sweeps was fitted as one spectrum without any warning (Zhang 2020 hold-out, Type = EIS).
% One sweep -> labels unchanged ("single").
if kind=="EIS" && ~has('spectrum') && has('frequency')
    fr=numeric(T.(m.frequency));
    gk=findgroups(N.source,N.cell,N.test);
    sw=ones(n,1);nsp=0;
    for k=1:max(gk)
        r=find(gk==k);s=uecm.sweepIndex(fr(r));sw(r)=s;nsp=nsp+max(s);
    end
    if any(sw>1)
        N.spectrum="sweep_"+compose("%03d",sw);
        notes(end+1)="스펙트럼 ID 열이 없어 주파수 재시작으로 스펙트럼 "+nsp+"개를 나눴습니다(원시 변환기와 같은 규칙).";
    end
end
% Optional source-verified cell descriptors. Missing values remain blank.
for f=["cell_model","cathode_family","cathode_composition","cell_format"]
    N.(f)=strings(n,1);
    if ismember(f,string(T.Properties.VariableNames))
        values=string(T.(f));values(ismissing(values))="";
        N.(f)=strip(values);
    end
end
if ~has('cell'),notes(end+1)="셀 ID가 없어 파일 단위 자료로 취급합니다. 여러 셀을 합친 파일이면 셀 열을 연결하세요.";end
if kind=="EIS"
    if ~has('frequency'),add("frequency","EIS 주파수가 없습니다.","주파수[Hz] 열을 연결해 주세요.",true);end
    cart=has('real')&&has('imag');polar=has('magnitude')&&has('phase');
    if ~cart && ~polar,add("impedance","임피던스 열이 부족합니다.","실수부·허수부 또는 크기·위상 열을 연결해 주세요.",true);end
    if has('frequency'),N.frequency=convert('frequency',o.FrequencyUnit,"Hz",["MHz","kHz","mHz","Hz"],[1e6,1e3,1e-3,1]);end
    if cart
        N.real=convert('real',o.ImpedanceUnit,"Ohm",["MOhm","kOhm","mOhm","uOhm","Ohm"],[1e6,1e3,.001,1e-6,1]);
        N.imag=convert('imag',o.ImpedanceUnit,"Ohm",["MOhm","kOhm","mOhm","uOhm","Ohm"],[1e6,1e3,.001,1e-6,1]);
        sign=o.ImaginarySign;name=m.imag;
        if sign=="auto"
            info=uecm.columnInfo(name,"imag");sign=info.ImaginarySign;
        end
        if sign=="negative_imaginary",N.imag=-N.imag;notes(end+1)="원본 −Im 열을 부호 변환해 내부의 signed Im으로 사용합니다.";
        elseif sign~="signed_imaginary",add("imag_sign","허수부가 Z″인지 −Z″인지 모릅니다.","허수부 부호를 선택해 주세요.",true);end
        signKnown=ismember(sign,["negative_imaginary","signed_imaginary"]);
    elseif polar
        mag=convert('magnitude',o.ImpedanceUnit,"Ohm",["MOhm","kOhm","mOhm","uOhm","Ohm"],[1e6,1e3,.001,1e-6,1]);
        phase=convert('phase',o.PhaseUnit,"rad",["deg","rad"],[pi/180,1]);
        if o.ImaginarySign=="negative_imaginary"                       % phase written as -theta (capacitive = +)
            phase=-phase;notes(end+1)="위상 열을 −θ 관례로 보고 부호를 바꿔 계산했습니다(허수부 부호 설정).";
        end
        if any(abs(phase)>pi/2+1e-6),notes(end+1)="위상 절댓값이 90°를 넘는 점이 있습니다. 위상 단위(deg/rad)를 확인하세요.";end
        N.real=mag.*cos(phase);N.imag=mag.*sin(phase);
        notes(end+1)="크기·위상에서 계산한 Re/Im입니다. 원본 열과 구분합니다.";
        signKnown=true;
    end
    % [D] Physical check of the imaginary sign. Names (Z'' vs -Z'') can be wrong; a battery spectrum is capacitive
    % (signed Im < 0) over most of 0.1–100 Hz. Checked PER SPECTRUM after the sign is final; blocking, not error().
    if (cart||polar) && has('frequency') && signKnown
        if o.ImagSignCheck=="off"
            notes(end+1)="EIS 허수부 부호 물리 검사를 사용자가 끄셨습니다(ImagSignCheck = off).";
        else
            [bad,skipped,nonpos]=imagSignCheck(N,o.ImagCheckBand_Hz,o.ImagCheckMinPoints);
            if ~isempty(bad)
                add("imag_sign_physics","EIS 허수부 부호 이상 감지: 데이터의 물리적 유효성을 확인하세요.", ...
                    string(o.ImagCheckBand_Hz(1))+"~"+string(o.ImagCheckBand_Hz(2))+" Hz에서 허수부(부호 있는 Im) 음수 비율이 50% 미만인 스펙트럼 "+numel(bad)+"개: "+ ...
                    join(bad(1:min(5,end)),", ")+ifelse(numel(bad)>5," 외",".")+ ...
                    " 원본 열이 Z″인지 −Z″인지 확인해 허수부 부호를 직접 고르세요. 특수 시료라면 ImagSignCheck를 off로 둘 수 있습니다.",true);
            end
            if skipped>0,notes(end+1)="검사 대역의 점이 부족해 허수부 부호 검사를 생략한 스펙트럼: "+skipped+"개.";end
            if nonpos>0,notes(end+1)="실수부가 0 이하인 점이 "+nonpos+"개 있습니다. 단위·열 연결을 확인해 주세요.";end
        end
    end
    if ismember('imag',N.Properties.VariableNames)&&any(N.imag>0)
        notes(end+1)="부호 변환 후 Im(Z)>0인 "+nnz(N.imag>0)+"점은 EIS 피팅에서 제외합니다.";
    end
elseif kind=="HPPC"
    if has('time'),N.time=convert('time',o.TimeUnit,"s",["ms","s","min","h"],[.001,1,60,3600]);
    elseif isfinite(o.SampleInterval_s)&&o.SampleInterval_s>0
        N.time=(0:n-1)'*o.SampleInterval_s;notes(end+1)="사용자가 확인한 일정 샘플링 간격으로 시간축을 구성했습니다.";
    else,add("time","시간축이 없습니다.","시간[s] 열 또는 확인된 일정 샘플링 간격[s]을 넣어 주세요.",true);end
    statusRebuilt=false;
    if has('current')
        N.current=convert('current',o.CurrentUnit,"A",["uA","mA","A"],[1e-6,.001,1]);
        % [J] UNSIGNED current (all >= 0) + instrument status column with BOTH charge and discharge codes:
        % rebuild the sign row by row (C -> +|I|, D -> -|I|, R -> value kept) in the CHARGE-POSITIVE convention.
        % A signed file (any negative current) is never touched.
        if isfield(m,'status') && strlength(m.status)>0 && all(N.current(isfinite(N.current))>=0)
            [cls,unknown]=statusClass(T.(m.status));
            if any(cls=="C") && any(cls=="D")
                if ~isempty(unknown)
                    add("current_status","상태 열에 충전·방전·휴지로 해석할 수 없는 코드가 있습니다: "+join(unknown(1:min(8,end)),", "), ...
                        "장비 설명서에서 코드 의미를 확인하고 해당 행을 정리하거나 전류 부호를 직접 지정해 주세요.",true);
                else
                    sgn=ones(n,1);sgn(cls=="D")=-1;N.current=N.current.*sgn;statusRebuilt=true;
                    nr=nnz(cls=="R"&abs(N.current)>0);
                    notes(end+1)="무부호 전류를 상태 열("+m.status+")로 복원: 충전 "+nnz(cls=="C")+"행 +, 방전 "+nnz(cls=="D")+"행 −, 휴지 "+nnz(cls=="R")+"행 값 유지"+ ...
                        ifelse(nr>0,"(휴지인데 전류가 0이 아닌 행 "+nr+"개)","")+".";
                end
            end
        end
    else,add("current","같은 시간의 전류 기록이 없습니다.","전류[A] 열을 추가해 주세요.",true);end
    if has('voltage'),N.voltage=convert('voltage',o.VoltageUnit,"V",["uV","mV","V"],[1e-6,.001,1]);
    else,add("voltage","단자 전압 기록이 없습니다.","전압[V] 열을 추가해 주세요.",true);end
    sign=string(o.CurrentSign);
    if statusRebuilt
        % [J] rebuilt current is charge-positive; cross-check with the pulse-onset physics (inferPulseSign)
        if ~ismember(sign,["unknown","charge_positive"])
            notes(end+1)="무부호 전류라 설정한 전류 부호("+sign+") 대신 상태 열로 부호를 복원했습니다.";
        end
        sign="charge_positive";
        if all(ismember({'time','current','voltage'},N.Properties.VariableNames))
            chk=inferPulseSign(N);
            if chk=="discharge_positive"
                add("current_status_physics","상태 열로 복원한 전류 부호가 펄스 시작 전압 변화와 반대입니다.", ...
                    "상태 코드의 의미(C/D)가 장비 설명과 같은지 확인해 주세요.",true);
            elseif chk=="charge_positive",notes(end+1)="복원한 전류 부호가 펄스 시작 전압 변화와 일치합니다.";
            else,notes(end+1)="복원한 전류 부호를 펄스 전압 변화로 교차 확인하지 못했습니다(판정 근거 부족).";end
        end
    elseif sign=="unknown"&&all(ismember({'time','current','voltage'},N.Properties.VariableNames))
        sign=inferPulseSign(N);
        if sign=="charge_positive",notes(end+1)="펄스 시작 전압 변화로 충전 양수 전류를 자동 판별했습니다.";
        elseif sign=="discharge_positive",notes(end+1)="펄스 시작 전압 변화로 방전 양수 전류를 자동 판별했습니다.";end
    end
    if sign=="charge_positive"&&ismember('current',N.Properties.VariableNames)
        N.current=-N.current;
        notes(end+1)="원본 충전 양수 전류를 내부 방전 양수 전류로 변환합니다.";
    elseif sign~="discharge_positive"&&sign~="charge_positive"
        add("current_sign","펄스 전류 부호를 자동 판별할 근거가 부족하거나 서로 충돌합니다.","원본 규약에 따라 전류 부호를 골라 주세요.",true);
    end
elseif kind=="dynamic"
    add("dynamic","일반 운전 시계열 자동 식별은 v0.1에서 지원하지 않습니다.","휴지·펄스·회복 구간이 있는 시험을 넣어 주세요. 원자료는 보존합니다.",true);
end
if isfield(input,'RawReport')
    rr=input.RawReport;
    notes=[notes(:);"원본 변환: "+rr.Profile;rr.Hints(:)];
    if isfield(rr,'Applied')&&~isempty(rr.Applied),notes=[notes;"원본 형식에 맞춰 자동 적용한 설정: "+rr.Applied(:)];end   % visible in the app, not only in methods_summary
    for message=rr.Requests(:)'
        add("raw_import",message,"원본 열·단위와 변환 기록을 확인하세요.",false);
    end
end
for f=["soc","temperature","soh","cycle"]
    if has(f),N.(f)=numeric(T.(m.(f)));else,N.(f)=nan(n,1);end
end
[N.initial_capacity,N.current_capacity]=uecm.capacityData(T);
[N.calendar,calendarUnit,calendarFactor]=uecm.calendarData(T,m.calendar);
if any(isfinite(N.calendar))
    conversions(end+1)=struct('Field',"calendar",'SourceColumn',m.calendar,'SourceUnit',calendarUnit,'Factor',calendarFactor,'OutputUnit',"day");
end
if has('calendar')&&calendarUnit=="unknown"
    add("calendar","열화 경과 시간의 단위가 명시되지 않았습니다.","calendar_days 등 단위가 있는 열 또는 직접 입력 조건을 사용하세요.",false);
end
% Join only on explicit, shared identifiers; never on row number.
if ~isempty(input.Metadata)
    M=input.Metadata;mm=uecm.inferMapping(M.Properties.VariableNames);ids=["source","cell","test","spectrum"];
    common=ids(arrayfun(@(f)has(f)&&strlength(mm.(f))>0,ids));
    if ~any(ismember(common,["spectrum","test"]))
        add("metadata_key","조건표를 같은 시험에 연결할 식별자가 없습니다.","시험 ID 또는 스펙트럼 ID 열을 두 표에 넣어 주세요.",true);
    else
        key=makeKey(N,common);MT=table();
        for f=common,MT.(f)=string(M.(mm.(f)));end
        mk=makeKey(MT,common);
        if numel(unique(mk))~=numel(mk)
            add("metadata_duplicate","조건표의 연결 키가 중복됩니다.","측정마다 조건표 한 줄만 연결되도록 ID를 확인해 주세요.",true);
        else
            [found,loc]=ismember(key,mk);
            if any(~found),notes(end+1)="조건표에 연결되지 않은 측정 행: "+sum(~found)+"개. 해당 조건은 결측으로 남깁니다.";end
            [initialCapacity,currentCapacity]=uecm.capacityData(M);
            capacityValues={initialCapacity,currentCapacity};capacityNames=["initial_capacity","current_capacity"];
            for j=1:2
                f=capacityNames(j);joined=nan(n,1);values=capacityValues{j};joined(found)=values(loc(found));
                conflict=isfinite(N.(f))&isfinite(joined)&abs(N.(f)-joined)>1e-7;
                if any(conflict),add(f,"원본과 조건표의 실측 용량이 충돌합니다.","셀·시험과 용량 기준을 확인하세요.",true);end
                use=~isfinite(N.(f));N.(f)(use)=joined(use);
            end
            for f=["cell_model","cathode_family","cathode_composition","cell_format"]
                if ~ismember(f,string(M.Properties.VariableNames)),continue,end
                v=string(M.(f));v(ismissing(v))="";v=strip(v);
                joined=strings(n,1);joined(found)=v(loc(found));
                known=strlength(N.(f))>0; hasLabel=strlength(joined)>0;
                if any(known&hasLabel&N.(f)~=joined)
                    add(f,"원본과 조건표의 셀 정보가 충돌합니다.","같은 셀·시험인지 확인해 주세요.",true);
                end
                N.(f)(~known)=joined(~known);
            end
            for f=["soc","temperature","soh","cycle","calendar"]
                if strlength(mm.(f))==0,continue,end
                if f=="calendar"
                    [vals,u,factor]=uecm.calendarData(M,mm.(f));
                    if u=="unknown",add("calendar","조건표의 열화 경과 시간 단위를 모릅니다.","calendar_days 등 단위가 있는 열을 사용하세요.",false);end
                    if any(isfinite(vals))
                        conversions(end+1)=struct('Field',"calendar",'SourceColumn',"metadata:"+mm.(f),'SourceUnit',u,'Factor',factor,'OutputUnit',"day");
                    end
                else,vals=numeric(M.(mm.(f)));end
                joined=nan(n,1);joined(found)=vals(loc(found));
                conflict=isfinite(N.(f))&isfinite(joined)&abs(N.(f)-joined)>1e-7;
                if any(conflict),add(f,"원본과 조건표 값이 충돌합니다.","같은 셀·시험·조건인지 확인해 주세요.",true);end
                use=isnan(N.(f));N.(f)(use)=joined(use);
                if ~has(f),m.(f)=mm.(f);end
            end
        end
    end
end
for f=["soc","soh"]
    col=N.(f);if ~any(isfinite(col)),continue,end
    if f=="soc",unit=o.SOCUnit;else,unit=o.SOHUnit;end
    name=lower(m.(f));
    if unit=="auto"
        info=uecm.columnInfo(string(m.(f)),f);
        if ismember(info.Unit,["percent","fraction"]),unit=info.Unit;
        else,add(f,"상태 값이 %인지 0~1 비율인지 모릅니다.","상태 단위를 % 또는 fraction으로 골라 주세요.",false);col(:)=NaN;end
    end
    if unit=="fraction",col=100*col;end
    upper=100;if f=="soh",upper=Inf;end % measured capacity can recover above its initial reference
    % Coulomb-counted SOC overshoots by a few 0.01 %p (100.14 %). Within SOCTolerance_pct of a bound: clip + note;
    % only values beyond the tolerance become NaN (restored from v2_raw, 2026-11-09).
    tol=o.SOCTolerance_pct;near=(col<0&col>=-tol)|(col>upper&col<=upper+tol);
    if any(near),notes(end+1)=f+" 값 "+sum(near)+"개가 경계를 "+tol+"%p 이내로 벗어나 경계값으로 맞췄습니다.";col(near)=min(max(col(near),0),upper);end
    invalid=col<0|col>upper;
    if any(invalid)
        add(f,"상태 값 중 0~100% 범위를 벗어난 행이 있습니다.","단위와 산정 기준을 확인해 주세요. 유효한 다른 행은 유지합니다.",false);
        col(invalid)=NaN;
    end
    if f=="soh"&&any(col>100+1e-8)
        add("soh_reference","초기 실측 용량 기준으로 SOH가 100%를 넘는 값이 있습니다.","초기 기준·용량 시험 조건을 확인하세요. 값을 절삭하거나 임의로 삭제하지 않고 유지합니다.",false);
    end
    N.(f)=col;
end
if any(isfinite(N.temperature))
    u=o.TemperatureUnit;name=lower(m.temperature);
    if u=="auto"
        info=uecm.columnInfo(string(m.temperature),"temperature");u=info.Unit;
    end
    if u=="K",N.temperature=N.temperature-273.15;
    elseif u~="C",N.temperature(:)=NaN;add("temperature","온도 단위를 모릅니다.","섭씨 C 또는 켈빈 K를 골라 주세요.",false);end
end
if kind=="HPPC" && all(isnan(N.soc)) && isfinite(o.InitialSOC_pct) && isfinite(o.Capacity_Ah) && o.Capacity_Ah>0 ...
        && ismember('time',N.Properties.VariableNames)&&ismember('current',N.Properties.VariableNames)
    if numel(unique(N.test))==1&&numel(unique(N.cell))==1&&all(diff(N.time)>0)
        N.soc=o.InitialSOC_pct-100*cumtrapz(N.time,N.current)/(3600*o.Capacity_Ah);
        notes(end+1)="SOC는 사용자 초기 SOC·용량으로 전류 적분한 계산값입니다. 효율=1 가정.";
    else,add("soc","초기 SOC 적산은 한 셀의 연속 시험에서만 지원합니다.","시험을 나누거나 펄스별 SOC 조건표를 넣어 주세요.",false);end
end
if kind=="HPPC"&&all(isnan(N.soc))&&o.SOCMethod=="auto_anchor" ...
        &&all(ismember({'time','current','voltage'},N.Properties.VariableNames)) ...
        &&~any(~isfinite(N.current))&&~(isfinite(o.InitialSOC_pct)&&isfinite(o.Capacity_Ah))
    group=findgroups(N.source,N.cell,N.test);
    for k=unique(group(isfinite(group)))'
        rows=find(group==k);
        anchor=uecm.socFromAnchors(N.time(rows),-N.current(rows),N.voltage(rows),o);
        if anchor.Found,N.soc(rows)=anchor.SOC;end
        notes(end+1)=anchor.Message;
    end
end
N=uecm.applyConditionLabels(N,input);
if all(isnan(N.soc)),add("soc","SOC 정보가 없어 SOC축은 사용할 수 없습니다.","SOC[%] 조건표 또는 초기 SOC·용량을 추가하면 다시 확인합니다.",false);end
if all(isnan(N.temperature)),add("temperature","온도 정보가 없어 온도축은 사용할 수 없습니다.","시험 온도[C] 조건표를 추가하거나 다른 축을 골라 주세요.",false);end
if input.Synthetic,notes(end+1)="SYNTHETIC: 가상 연습 자료입니다. 실제 실험 측정값이 아닙니다.";end
if isempty(req),requests=table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),false(0,1),'VariableNames',{'Target','Field','Reason','Action','Blocking'});
else,requests=struct2table(req);end
p=struct('Data',N,'Requests',requests,'Notes',notes(:),'Type',kind,'Input',input,'Conversions',conversions,'Blocked',any(requests.Blocking));
% Magnitude sanity (warnings only, never blocking): a header unit that is wrong by 10^3 passes every other check.
if p.Type=="EIS"&&ismember('real',p.Data.Properties.VariableNames)&&any(isfinite(p.Data.real))
    mr=median(p.Data.real(isfinite(p.Data.real)));
    if mr<1e-4||mr>10,p.Notes(end+1)="실수부 중앙값 "+string(mr)+" Ω: 원통형 셀의 일반 범위(0.1 mΩ~10 Ω) 밖입니다. 임피던스 단위(mΩ/Ω)를 확인하세요.";end
end
if ismember('temperature',p.Data.Properties.VariableNames)&&any(p.Data.temperature<-40|p.Data.temperature>90)
    p.Notes(end+1)="온도 값이 −40~90 °C 밖에 있습니다. 온도 단위(K/°C)나 열 연결을 확인하세요.";
end
if p.Type=="HPPC"&&ismember('current',p.Data.Properties.VariableNames)&&isfinite(o.Capacity_Ah)&&o.Capacity_Ah>0 ...
        &&max(abs(p.Data.current))/o.Capacity_Ah>20
    p.Notes(end+1)="최대 전류가 용량 대비 20C를 넘습니다. 전류 단위(mA/A)를 확인하세요.";
end
[p.Data,p.CustomAxes,p.AxisCategories]=uecm.importConditionAxes(p.Data,input);
if ~isempty(p.CustomAxes),p.Notes(end+1)="추가 조건 열 "+numel(p.CustomAxes)+"개 자동 등록. 문자 범주는 axis_categories.json의 코드표로 구분하며 미연결 값은 채우지 않습니다.";end
p.AxisCoverage=uecm.conditionCoverage(p);
    function add(field,reason,action,blocking)
        req(end+1)=struct('Target',input.File,'Field',string(field),'Reason',string(reason),'Action',string(action),'Blocking',blocking);
    end
    function v=convert(field,unit,canonical,unitNames,multipliers)
        raw=numeric(T.(m.(field)));selected=string(unit);
        if any(~isfinite(raw))
            add(field+"_values","숫자로 읽을 수 없거나 비어 있는 필수 측정값이 있습니다: "+m.(field), ...
                "빈 행·숫자 표기·소수점 구분자를 확인하세요. 단위 문자는 열 이름에 두고 숫자 칸은 측정값만 넣으세요.",true);
        end
        if selected=="auto"
            info=uecm.columnInfo(string(m.(field)),string(field));
        else
            info=uecm.columnInfo("quantity ["+selected+"]",string(field));
        end
        selected=info.Unit;match=find(selected==unitNames,1);
        if isempty(match)
            add(field+"_unit","확인된 단위가 없습니다: "+m.(field),canonical+" 등 원본 단위를 골라 주세요.",true);v=nan(size(raw));
        else
            v=raw*multipliers(match);
            conversions(end+1)=struct('Field',string(field),'SourceColumn',string(m.(field)), ...
                'SourceUnit',string(unitNames(match)),'Factor',multipliers(match),'OutputUnit',string(canonical));
        end
    end
end
function v=numeric(x)
if isnumeric(x),v=double(x);else,v=str2double(string(x));end
v=v(:);
end
function [bad,skipped,nonpos]=imagSignCheck(N,band,minPts)
% [D] per spectrum (source+cell+test+spectrum): share of signed Im < 0 inside band; bad = labels with share < 0.5
bad=strings(0,1);skipped=0;nonpos=nnz(isfinite(N.real)&N.real<=0);
g=findgroups(string(N.source),string(N.cell),string(N.test),string(N.spectrum));
if isempty(g)||all(isnan(g)),return,end
for k=1:max(g)
    rows=g==k;
    r=rows&N.frequency>=band(1)&N.frequency<=band(2)&isfinite(N.imag);
    if nnz(r)<minPts,skipped=skipped+1;continue,end
    share=mean(N.imag(r)<0);
    if share<0.5
        f=find(rows,1);
        bad(end+1)=string(N.spectrum(f))+"("+round(100*share)+"%)"; %#ok<AGROW>
    end
end
end
function [cls,unknown]=statusClass(x)
% [J] status text -> "C" charge | "D" discharge | "R" rest | "?" unknown. Discharge is tested first
% ('DCHG' contains 'CHG'). Covers Maccor C/D/R and common words (Charge, CC_DChg, Rest, Pause, OCV).
s=upper(strtrim(string(x)));s(ismissing(s))="";cls=repmat("?",numel(s),1);
isD=s=="D"|contains(s,["DCH","DISCH","DISCHARGE"]);
isC=~isD&(s=="C"|contains(s,["CHG","CHA","CHARGE"]));
isR=~isD&~isC&(s=="R"|contains(s,["REST","PAU","OCV"]));
cls(isD)="D";cls(isC)="C";cls(isR)="R";
unknown=unique(s(cls=="?"));unknown(unknown=="")="(빈칸)";unknown=unique(unknown);
end
function out=ifelse(c,a,b)
if c,out=a;else,out=b;end
end
function key=makeKey(T,fields)
key=repmat("",height(T),1);
for f=fields,key=key+string(T.(f))+char(31);end
end


function convention=inferPulseSign(T)
% Compare the voltage step at each isolated pulse onset with the current step.
convention="unknown";
group=findgroups(T.source,T.cell,T.test,T.spectrum);
rows=find(isfinite(group));
if isempty(rows),return,end
byGroup=accumarray(group(rows),rows,[],@(idx){sort(idx)});
votes=zeros(0,1);
for k=1:numel(byGroup)
    g=T(byGroup{k},:);i=g.current;v=g.voltage;
    if any(~isfinite([g.time;i;v]))||any(diff(g.time)<=0),continue,end
    active=abs(i)>max(.02*max(abs(i)),1e-8);
    starts=find(diff([false;active])==1);
    for j=starts(:)'
        if j<6||j+4>numel(i)||any(active(j-5:j-1))||~all(active(j:j+4)),continue,end
        before=v(j-5:j-1);after=v(j:j+4);
        deltaV=median(after)-median(before);
        deltaI=median(i(j:j+4))-median(i(j-5:j-1));
        noise=median(abs(before-median(before)));
        if abs(deltaV)>max(.0005,6*noise)&&abs(deltaI)>1e-8
            votes(end+1,1)=sign(deltaI*deltaV); %#ok<AGROW>
        end
    end
end
if isempty(votes),return,end
if all(votes>0),convention="charge_positive";
elseif all(votes<0),convention="discharge_positive";end
end
