function [T, report] = readRaw(file, settings)
%READRAW Read an instrument/raw export WITHOUT changing measured values and return the tool's canonical table.
% Supported (rule-based, deterministic; no AI):
%   .mat  struct with Time/Voltage/Current (McMaster/Digatron 'meas'), or variables of those names
%   text  (.csv .txt .tsv .mpt .dta)  header found automatically among the first 400 lines:
%         Digatron CSV (metadata block + "Time Stamp,Step,..." + units row "[V],[A]")
%         Bio-Logic EC-Lab ASCII (freq/Hz, Re(Z)/Ohm, -Im(Z)/Ohm, time/s, <I>/mA, Ewe/V; decimal comma ok)
%         Gamry DTA ZCURVE (Freq Zreal Zimag Zmod Zphz + units row)
%         'Name, unit' headers split by the delimiter (e.g. "I, A,U, V," Wuppertal cell tester)
%         whitespace tables with an unnamed leading index column ("Frequency/Hz Impedance/Ohm Phase/deg")
%         Arbin-like CSV (Frequency, Zreal, Zimg, *_ID columns)
%   .xlsx every sheet whose header maps to EIS or time-series roles (e.g. ACIM_* sheets: Freq, Zmod, Zphz)
% readRaw build 2026-11-06d (categorical per-row IDs; duplicate roles never picked; data row = most NON-EMPTY fields numeric; datetime locale en_US)
% Rules: column ROLE from the name, UNIT only from the name/units row (never guessed). Unknown unit -> bare
% canonical name (e.g. 'current'), so prepare.m asks the user. Setpoint columns (Itarget, I_soll, control) are
% never used as measurements. Chamber temperature is kept separately from cell temperature.
% Only conversions prepare.m cannot do are applied here and logged (min/h -> s, uA -> A, kHz -> Hz,
% K -> degC, clock strings -> s). report.Mapping lists every decision; report.Requests lists what is unclear.
arguments
    file (1,1) string
    settings (1,1) struct = uecm.defaults()
end
if ~isfile(file),error('uecm:File','파일을 찾을 수 없습니다: %s',file);end
[~,stem,ext]=fileparts(file);ext=lower(ext);
report=struct('File',file,'Profile',"",'Kind',"",'HeaderLine',NaN,'Metadata',strings(0,2), ...
    'Mapping',table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),'VariableNames',{'role','source_column','unit','note'}), ...
    'Requests',strings(0,1),'Hints',strings(0,1),'Suggested',struct(),'DroppedRows',0);
switch ext
    case ".mat"
        [R,report]=fromMat(file,report);
    case {".xlsx",".xls"}
        [R,report]=fromExcel(file,report,settings);
    otherwise
        [R,report]=fromText(file,report,settings);
end
if ~isfield(report,'ObservedColumns'),report.ObservedColumns=string(R.Properties.VariableNames);end
[R,profileNotes]=uecm.applyResearchProfile(R,file);
report.Hints=[report.Hints(:);profileNotes(:)];
[T,report]=canonical(R,report,stem,settings);
end

% ---------------------------------------------------------------- readers -> raw table + column names
function [R,report]=fromMat(file,report)
S=load(file);names=fieldnames(S);R=table();
% Some research exports define channel names and units beside a scalar data structure.
if all(isfield(S,{'data','channelNames','channelUnits'}))&&isstruct(S.data)&&isscalar(S.data)
    channels=string(S.channelNames(:));units=string(S.channelUnits(:));source=fieldnames(S.data);
    valid=matlab.lang.makeValidName(channels);
    for j=1:numel(channels)
        hit=find(string(source)==valid(j),1);
        if isempty(hit),continue,end
        x=S.data.(source{hit});
        if isvector(x),R.(channels(j))=x(:);end
    end
    if ~isempty(R)
        names=string(R.Properties.VariableNames);u=strings(size(names));
        for j=1:numel(names)
            hit=find(channels==names(j),1);
            unit=units(hit);
            if unit=="x_ss_xxx_",unit="s";
            else,unit=regexprep(unit,'^x_|_$','');end
            u(j)=unit;
        end
        R.Properties.VariableUnits=cellstr(u);report.Profile="mat_channel_schema";
        report.Hints(end+1)="열 이름·단위는 원본 MAT의 channelNames/channelUnits 정의를 사용했습니다.";
        return
    end
end
for k=1:numel(names)
    v=S.(names{k});
    if isstruct(v)&&all(isfield(v,{'Time','Voltage','Current'}))
        f=fieldnames(v);
        for j=1:numel(f)
            x=v.(f{j});
            if (isnumeric(x)||isstring(x)||iscellstr(x))&&numel(x)==numel(v.Time),R.(f{j})=x(:);end
        end
        report.Profile="mat_struct:"+names{k};
        if strcmp(names{k},'meas')   % McMaster README: Time [s], Voltage [V], Current [A], Battery_Temp_degC [degC]
            u=repmat({''},1,width(R));vn=R.Properties.VariableNames;
            u(strcmp(vn,'Time'))={'s'};u(strcmp(vn,'Voltage'))={'V'};u(strcmp(vn,'Current'))={'A'};u(strcmp(vn,'Battery_Temp_degC'))={'C'};
            R.Properties.VariableUnits=u;report.Hints(end+1)="단위는 McMaster 데이터셋 README 기준(Time s, Voltage V, Current A, Battery_Temp_degC °C).";
        end
        break
    end
end
if isempty(R)
    for k=1:numel(names)
        x=S.(names{k});if isnumeric(x)&&isvector(x),R.(names{k})=x(:);end
    end
    report.Profile="mat_variables";
end
if isempty(R)
    for k=1:numel(names)
        x=S.(names{k});
        if isnumeric(x)&&ismatrix(x)&&size(x,2)>=2&&size(x,2)<=12&&size(x,1)>size(x,2)
            R=array2table(x,'VariableNames',"col_"+string(1:size(x,2)));report.Profile="mat_matrix:"+names{k};break
        end
    end
end
if isempty(R),error('uecm:RawMat','MAT 파일에서 시간·전압·전류 또는 주파수·임피던스 변수를 찾지 못했습니다.');end
if report.Profile=="mat_struct:meas"
    report.Suggested.DuplicateTimePolicy="keep_last";report.Suggested.TimeResetPolicy="keep_first_log";report.Suggested.MaxPulseDuration_s=60;
end
if report.Profile=="mat_struct:meas",report.Hints(end+1)="McMaster/Digatron 형식: 원본 전류는 방전이 음수입니다(데이터셋 README). 앱에서 '충전할 때 +'를 선택하세요.";end
end

function [R,report]=fromExcel(file,report,settings)
sheets=sheetnames(file);
if isfield(settings,'Sheet')&&strlength(settings.Sheet)>0,sheets=string(settings.Sheet);end
R=table();
X0=readmatrix(file,'Sheet',sheets(1));
if ~isempty(X0)&&all(isfinite(X0(1,:)))&&size(X0,2)<=12              % no header row: numeric from row 1
    H=readcell(file,'Sheet',sheets(1),'Range','A1:A1');
    if isnumeric(H{1})
        R=array2table(X0,'VariableNames',"col_"+string(1:size(X0,2)));report.Profile="excel_matrix";return
    end
end
% Sheets are sorted into EIS sheets and time-series sheets. With Type "auto" a workbook holding BOTH (Arbin EIS
% export: channel time series + ACIM sheet) used to be resolved by sheet order: the first qualifying sheet won and the
% other kind was dropped with a non-blocking note (Kiel/Salerno hold-out, 2026-11-09: 15 files returned the time
% series instead of the EIS). Now "auto" stops and asks, exactly like a text file with both signal kinds.
E=table();H=table();eisS=strings(0,1);timS=strings(0,1);otherS=strings(0,1);
for k=1:numel(sheets)
    try
        io=detectImportOptions(file,'Sheet',sheets(k),'VariableNamingRule','preserve','TextType','string');
        r0=rolesOf(string(io.VariableNames));
        if ~matchesType(r0,settings.Type)
            if matchesType(r0,"auto"),otherS(end+1)=sheets(k);end %#ok<AGROW>  % other analysis kind: report, do not read
            continue
        end
        X=readtable(file,io);
    catch
        continue
    end
    roles=rolesOf(string(X.Properties.VariableNames));
    if ~matchesType(roles,settings.Type),continue,end
    X.raw_sheet=repmat(sheets(k),height(X),1);X.raw_sheet_row=(2:height(X)+1)';
    if isEISRoles(roles),[E,report]=stack(E,X,sheets(k),report);eisS(end+1)=sheets(k); %#ok<AGROW>
    else,[H,report]=stack(H,X,sheets(k),report);timS(end+1)=sheets(k);end %#ok<AGROW>
end
if ~isempty(E)&&~isempty(H)
    if settings.Type=="EIS",R=E;report.Hints(end+1)="분석 종류 EIS: 시계열 시트("+join(timS,", ")+")는 사용하지 않았습니다.";
    elseif settings.Type=="HPPC",R=H;report.Hints(end+1)="분석 종류 HPPC: EIS 시트("+join(eisS,", ")+")는 사용하지 않았습니다.";
    else
        error('uecm:RawExcelMixed',"이 엑셀에는 EIS 시트(%s)와 시계열 시트(%s)가 함께 있습니다. 분석 종류에서 EIS 또는 HPPC를 골라 주세요.", ...
            char(join(eisS,", ")),char(join(timS,", ")));
    end
elseif ~isempty(E),R=E;
else,R=H;
end
if ~isempty(R)&&~isempty(otherS)   % Type EIS/HPPC: say which sheets of the other kind were left out
    report.Hints(end+1)="분석 종류 "+string(settings.Type)+": 다른 종류 시트("+join(otherS,", ")+")는 사용하지 않았습니다.";
end
if isempty(R),error('uecm:RawExcel','엑셀 시트에서 EIS/시계열 열을 찾지 못했습니다.');end
report.Profile="excel_sheets";
end

function [A,report]=stack(A,X,sheet,report)
% append a sheet of the same kind; different column sets are reported, never silently merged
if isempty(A),A=X;return,end
try,A=[A;X];catch,report.Requests(end+1)="시트 '"+sheet+"'의 열 구성이 달라 합치지 않았습니다.";end
end

function [R,report]=fromText(file,report,settings)
if contains(string(file),"Molicel_P42A_Independent_EIS")&&contains(string(file),"Factor_CurrentAmplitude")
    values=readmatrix(file);
    if size(values,2)==3
        R=array2table(values,'VariableNames',{'Frequency [Hz]','Zreal [Ohm]','-Zimag [Ohm]'});
        report.Profile="molicel_p42a_author_numeric";
        report.Hints(end+1)="열·부호·단위 근거: 원 연구 demo01_CurrentAmplitude.m의 data(:,2:3)*1000 및 −Imag(mΩ) 축, 논문 3.1절 주파수 Hz.";
        return
    end
end
% Encoding (2026-11-10, fixed after smoke): UTF-16 only from a BOM or many NUL bytes (a real Digatron CSV has ONE
% stray NUL line); CP949 only as a SECOND try when the UTF-8 header search finds nothing and the text shows U+FFFD.
enc=sniffEncoding(file);lines=headLines(file,enc);
if enc=="UTF-16LE",report.Hints(end+1)="파일 인코딩을 UTF-16LE로 읽었습니다.";end
if numel(lines)>0,lines(1)=erase(lines(1),char(65279));end   % BOM
best=findHeader(lines,settings);
if best.score==0 && enc=="UTF-8" && any(contains(lines,char(65533)))   % invalid UTF-8 -> Korean Windows instruments (PNE, Wonatech)
    enc="windows-949";lines=headLines(file,enc);best=findHeader(lines,settings);
    if best.score>0,report.Hints(end+1)="UTF-8로 읽을 수 없는 글자가 있어 CP949(한글 Windows) 인코딩으로 다시 읽었습니다. 머리말 글자를 확인하세요.";end
end
if best.score==0
    error('uecm:RawHeader','선택한 입력 종류에 맞는 시간·전류·전압 또는 EIS 주파수·임피던스 열을 원본 머리말에서 찾지 못했습니다. 입력 종류와 머리말(인코딩 포함)을 확인하세요.');
end
report.HeaderLine=best.line;
for li=1:best.line-1                                              % metadata block "key,value" / "key : value"
    kv=regexp(lines(li),'^\s*([^,:\t;]+?)\s*[,:\t;]\s*(.+?)\s*,*$','tokens','once');
    if ~isempty(kv),report.Metadata(end+1,:)=[string(kv{1}),string(kv{2})];end
end
names=best.names;units=strings(size(names));first=best.line+1;
while first<=numel(lines)                                         % units row and blank rows
    tok=mergeUnitTokens(splitLine(lines(first),best.delim));
    if strlength(strtrim(lines(first)))==0,first=first+1;continue,end
    nums=str2double(strrep(tok,',','.'));
    % data row = most NON-EMPTY fields are numbers (a Wuppertal row has 27 fields but only ~11 filled)
    if sum(isfinite(nums))>=max(2,0.5*sum(strlength(strtrim(tok))>0)),break,end
    if any(contains(tok,["[","°","Hz","ohm","Ohm","#"])) && numel(tok)<=numel(names)+1
        tok=[tok,strings(1,max(0,numel(names)-numel(tok)))];
        units=regexprep(strtrim(tok(1:numel(names))),'^\[|\]$','');
        for q=1:numel(units),cu=canonicalUnit(units(q));if strlength(cu)>0,units(q)=cu;else,units(q)="";end,end
    end
    first=first+1;
end
sample=splitLine(lines(min(first,numel(lines))),best.delim);
if numel(sample)==numel(names)+1
    names=["raw_index",names];units=["",units];                  % unnamed leading index
    report.Hints(end+1)="머리말보다 자료 열이 1개 많아 첫 열을 이름 없는 행 번호(raw_index)로 보았습니다.";
elseif best.delim=="ws" && numel(sample)~=numel(names)
    error('uecm:RawColumns',['공백 구분 표의 머리말 이름 %d개와 자료 값 %d개가 맞지 않아 열이 밀릴 수 있습니다(%d번째 줄). ' ...
        '단위를 "Freq/Hz"처럼 이름에 붙이거나 쉼표·탭 구분으로 저장해 주세요.'],numel(names),numel(sample),best.line);
end
names=strtrim(names);
for q=find(strlength(names)==0),names(q)="col_"+q;end               % Gamry rows start with a tab
names=matlab.lang.makeUniqueStrings(names);nv=numel(names);
if best.delim=="ws"
    opts=delimitedTextImportOptions('NumVariables',nv,'Delimiter',{' ','\t'},'ConsecutiveDelimitersRule','join','LeadingDelimitersRule','ignore');
else
    opts=delimitedTextImportOptions('NumVariables',nv,'Delimiter',char(best.delim));
end
opts.DataLines=[first Inf];opts.VariableNames=cellstr(names);opts.VariableNamingRule='preserve';
opts.ExtraColumnsRule='ignore';opts.EmptyLineRule='skip';opts.Encoding=char(enc);
% column types from up to 50 sample rows
S=strings(0,nv);
for li=first:min(numel(lines),first+49)
    tok=splitLine(lines(li),best.delim);if numel(tok)<nv,tok=[tok,strings(1,nv-numel(tok))];end
    S(end+1,:)=tok(1:nv); %#ok<AGROW>
end
if isempty(S),error('uecm:RawData','머리말(%d번째 줄) 아래 400줄 안에서 숫자 자료 줄을 찾지 못했습니다.',best.line);end
% decimal comma per COLUMN from the number pattern (a German date "14.03.2019" in another column no longer
% switches it off, and "3,6512" is never read by str2double as 36512)
commaCol=false(1,nv);
if best.delim~=","
    for j=1:nv
        x=strtrim(S(:,j));
        nc=nnz(~cellfun(@isempty,regexp(x,'^[-+]?\d+,\d+([eE][-+]?\d+)?$','once')));
        nd=nnz(~cellfun(@isempty,regexp(x,'^[-+]?\d*\.\d+([eE][-+]?\d+)?$','once')));
        commaCol(j)=nc>0&&nd==0;
    end
end
comma=any(commaCol);
num=false(1,nv);
for j=1:nv
    x=S(:,j);if commaCol(j),x=strrep(x,",",".");end
    filled=strlength(strtrim(x))>0;                                % sparse logger columns: judge filled cells only
    num(j)=any(filled)&&mean(isfinite(str2double(x(filled))))>=0.8;
end
if any(num),opts=setvartype(opts,cellstr(names(num)),'double');end
if any(~num),opts=setvartype(opts,cellstr(names(~num)),'string');end
if any(num&commaCol),opts=setvaropts(opts,cellstr(names(num&commaCol)),'DecimalSeparator',',');end
% Read recognized channels plus extra numeric/short categorical conditions.
% Long per-row prose remains in the original file and ObservedColumns audit.
report.ObservedColumns=names;
roles=rolesOf(names);keepRole=~ismember(roles,["","setpoint","steptime"])|ismember(names,["cell_model","cathode_family","cathode_composition","cell_format"]);
for j=find(roles=="")
    [~,uu,nt]=roleOf(names(j));
    if contains(nt,"불일치")
        report.Mapping=[report.Mapping;{"(제외)",names(j),uu,nt}];continue
    end
    sample=strip(S(:,j));sample=sample(~ismissing(sample)&strlength(sample)>0);
    compact=~isempty(sample)&&numel(unique(sample))<=20&&all(strlength(sample)<=64);
    if num(j)||compact,keepRole(j)=true;end
end
for j=find(keepRole&~num&ismember(roles,["time","timestamp"]))   % absolute clock -> import as datetime directly
    fm=datetimeFormat(S(1,j));
    % DatetimeLocale fixed to en_US: on a Korean MATLAB 'PM' (Digatron '3/14/2019 5:34:30 PM') is not parsed otherwise
    if strlength(fm)>0,opts=setvartype(opts,char(names(j)),'datetime');opts=setvaropts(opts,char(names(j)),'InputFormat',char(fm),'DatetimeLocale','en_US');end
end
if any(keepRole),opts.SelectedVariableNames=cellstr(names(keepRole));units=units(keepRole);end
R=readtable(file,opts);
R.Properties.VariableUnits=cellstr(units);
report.Profile=profileName(lines,names);
if ismember(report.Profile,["digatron_csv","wuppertal_celltester"])
    report.Suggested.DuplicateTimePolicy="keep_last";report.Suggested.TimeResetPolicy="keep_first_log";report.Suggested.MaxPulseDuration_s=60;
end
if report.Profile=="digatron_csv",report.Hints(end+1)="Digatron 형식: 전류는 방전이 음수입니다(McMaster README). 앱에서 '충전할 때 +'를 선택하세요.";end
if report.Profile=="biologic_eclab",report.Hints(end+1)="EC-Lab 형식: <I>/mA는 작업전극(WE)의 산화(anodic) 전류가 양수입니다. WE가 양극인 풀셀이면 충전이 +이므로, 펄스 판정 결과와 함께 확인하세요.";end
end

% ---------------------------------------------------------------- raw table -> canonical table
function [T,report]=canonical(R,report,stem,settings)
[R,report]=knownMatrixProfile(R,report,stem);
R.raw_source_row=(1:height(R))';
names=string(R.Properties.VariableNames);n=height(R);
units=strings(size(names));
if numel(R.Properties.VariableUnits)==numel(names),units=string(R.Properties.VariableUnits);end
roles=strings(size(names));nameUnit=strings(size(names));unclassified=false(size(names));
for j=1:numel(names)
    [roles(j),nameUnit(j),rnote]=roleOf(names(j));unclassified(j)=roles(j)==""&&~contains(rnote,"불일치");
    if strlength(rnote)>0,report.Mapping=[report.Mapping;{"(이름 해석)",names(j),nameUnit(j),rnote}];end
    if strlength(units(j))==0,units(j)=nameUnit(j);end
    % [C] the units ROW can also contradict the role (e.g. a column named 'T' whose unit row says °C)
    if roles(j)~=""&&~roleUnitOK(roles(j),units(j))
        report.Mapping=[report.Mapping;{"(제외)",names(j),units(j),"역할–단위 불일치로 제외: '"+roles(j)+"' 역할에 단위 "+units(j)}];
        roles(j)="";
    end
end
if settings.Type=="HPPC"&&isTimeRoles(roles),report.Kind="HPPC";
elseif settings.Type=="EIS"&&isEISRoles(roles),report.Kind="EIS";
elseif settings.Type=="auto"&&isEISRoles(roles),report.Kind="EIS";
elseif settings.Type=="auto"&&isTimeRoles(roles),report.Kind="HPPC";
else,report.Kind="unknown";end
% Two columns with the same meaning (e.g. 'Z' [Ohm]' and 'Real [Ohm]') are never chosen automatically (v2 rule).
need=["temperature"];
if report.Kind=="EIS"
    need=[need,"frequency","real","imag","negimag"];
    if ~any(roles=="real")||~any(ismember(roles,["imag","negimag"]))
        need=[need,"magnitude","phase"];
    end
end
if report.Kind=="HPPC",need=[need,"time","duration","timestamp","current","voltage","status"];end
for rname=need
    jj=find(roles==rname);
    if numel(jj)>1
        report.Requests(end+1)="같은 의미('"+rname+"')의 열이 여러 개입니다("+join(names(jj),", ")+"). 열 연결에서 하나를 골라 주세요.";
        roles(jj)="ambiguous_"+rname;
    end
end
T=table();T.raw_source_row=R.raw_source_row;T.source_id=repmat(categorical(string(stem)),n,1);   % categorical: 1 label, millions of rows
pick=@(role) choose(names,roles,role);
if report.Kind=="EIS"
    j=pick("frequency");[T,report]=put(T,report,R,names(j),units(j),"frequency","frequency_hz","frequency");
    jr=pick("real");ji=pick("imag");jn=pick("negimag");jm=pick("magnitude");jp=pick("phase");
    if ~isempty(jr)&&(~isempty(ji)||~isempty(jn))
        [T,report]=put(T,report,R,names(jr),units(jr),"impedance","z_real_ohm","z_real");
        if ~isempty(ji),[T,report]=put(T,report,R,names(ji),units(ji),"impedance","z_imag_ohm","z_imag");
        else,[T,report]=put(T,report,R,names(jn),units(jn),"impedance","neg_im_z_ohm","neg_im_z");end
    elseif ~isempty(jm)&&~isempty(jp)
        [T,report]=put(T,report,R,names(jm),units(jm),"impedance","magnitude_ohm","magnitude");
        [T,report]=put(T,report,R,names(jp),units(jp),"phase","phase_deg","phase");
    else
        report.Requests(end+1)="임피던스 실수부·허수부 또는 크기·위상 열을 모두 찾지 못했습니다.";
    end
    idc=find(roles=="id");
    if ~isempty(idc)
        key=strings(n,1);
        for c=idc,key=key+string(R{:,c})+"_";end
        key=extractBefore(key,strlength(key));T.test_id=key;T.spectrum_id=key;
        report.Mapping=[report.Mapping;{"spectrum_id",join(names(idc),"+"),"","시험 ID 열 조합"}];
    else
        fj=find(startsWith(string(T.Properties.VariableNames),"frequency"),1);
        if isempty(fj)                                 % ambiguous/missing frequency: keep one test, the Request above asks the user
            T.test_id=repmat(string(stem),n,1);T.spectrum_id=T.test_id;sweep=1;
        else
            sweep=uecm.sweepIndex(T{:,fj});
        end                     % shared rule (prepare.m uses it for tidy tables too)
        if ~isempty(fj),T.test_id=stem+"_sweep"+string(sweep);T.spectrum_id=T.test_id;end
        report.Mapping=[report.Mapping;{"spectrum_id","(주파수 스윕 재시작 감지)","","스펙트럼 "+max(sweep)+"개"}];
    end
elseif report.Kind=="HPPC"
    j=pick("time");
    if isempty(j),j=pick("duration");end
    if isempty(j),j=pick("timestamp");end
    [T,report]=put(T,report,R,names(j),units(j),"time","time_s","time");
    j=pick("current");[T,report]=put(T,report,R,names(j),units(j),"current","current_A","current");
    j=pick("voltage");[T,report]=put(T,report,R,names(j),units(j),"voltage","voltage_V","voltage");
    T.test_id=repmat(categorical(string(stem)),n,1);
    st=pick("step");
    if ~isempty(st),T.raw_step=categorical(string(R{:,st}));report.Mapping=[report.Mapping;{"raw_step",names(st),"","보존(구간 판단 보조)"}];end
    % [J] instrument status/mode column (Maccor-type C/D/R): carried unchanged so prepare.m can rebuild the sign of
    % an UNSIGNED current. Text only (trimmed, upper case); values are never altered here.
    ss=pick("status");
    if ~isempty(ss)
        sc=upper(strtrim(string(R{:,ss})));sc(ismissing(sc))="";
        T.status_code=categorical(sc);                    % categorical: few labels, millions of rows
        report.Mapping=[report.Mapping;{"status_code",names(ss),"","보존(무부호 전류의 충·방전 판정용)"}];
    end
else
    report.Requests(end+1)="EIS(주파수+임피던스) 또는 시계열(시간+전류+전압) 열 조합을 찾지 못했습니다.";
end
% Preserve explicit experiment conditions and identifiers before filename fallbacks.
for field=["source","cell","test","spectrum","soc","soh","cycle","calendar"]
    mm=uecm.inferMapping(names);
    if strlength(mm.(field))==0,continue,end
    original=mm.(field);
    if ismember(field,["source","cell","test","spectrum"])
        target=field+"_id";
        T.(target)=string(R.(original));
    else
        target=original;
        T.(target)=R.(original);
    end
    report.Mapping=[report.Mapping;{target,original,"","원본 조건·ID 보존"}];
end
[initial,current]=uecm.capacityData(R);
if any(isfinite(initial)),T.initial_capacity_Ah=initial;end
if any(isfinite(current)),T.current_capacity_Ah=current;end
if ismember("protocol_cycle_index",names),T.protocol_cycle_index=R.protocol_cycle_index;end
for field=["cell_model","cathode_family","cathode_composition","cell_format"]
    if ismember(field,names),T.(field)=string(R.(field));end
end
% Keep ambiguous source channels available for explicit user mapping.
for j=find(startsWith(roles,"ambiguous_"))
    T.(names(j))=R.(names(j));
end
jt=pick("temperature");
if ~isempty(jt),[T,report]=put(T,report,R,names(jt),units(jt),"temperature","temperature_C","temperature");end
jc=pick("temperature_chamber");
if ~isempty(jc),T.chamber_temperature_raw=R{:,jc};report.Mapping=[report.Mapping;{"chamber_temperature",names(jc),units(jc),"보존만(셀 온도로 쓰지 않음)"}];end
if ismember("raw_sheet",names)
    T.raw_sheet=R.raw_sheet;T.raw_sheet_row=R.raw_sheet_row;
    T.test_id=string(T.test_id)+"|sheet="+string(R.raw_sheet);
    if report.Kind=="EIS",T.spectrum_id=string(T.spectrum_id)+"|sheet="+string(R.raw_sheet);end
end
% Preserve genuinely unclassified source columns for later condition inspection.
% Do not resurrect rejected signal/unit roles, setpoints, or converter row bookkeeping.
for j=find(unclassified)
    col=names(j);
    if startsWith(col,"raw_")||startsWith(col,"uecm_")||ismember(col,string(T.Properties.VariableNames)),continue,end
    if size(R.(col),2)~=1,continue,end
    T.(col)=R.(col);
    report.Mapping=[report.Mapping;{col,col,units(j),"추가 원본 열 보존 (축은 사용자가 선택)"}];
end
[T,report]=conditionsFromName(T,report,stem);
if report.Kind=="HPPC",[T,report]=dropEventRows(T,report);report=suggestFromData(T,report);end
setp=names(roles=="setpoint");
if ~isempty(setp),report.Mapping=[report.Mapping;{"(제외)",join(setp,", "),"","설정값 열은 측정값으로 쓰지 않음"}];end
end

function [T,report]=put(T,report,R,name,unit,kind,knownName,bareName)
if isempty(name),report.Requests(end+1)="'"+bareName+"' 역할의 열을 찾지 못했습니다. 열 연결에서 직접 골라 주세요.";return,end
x=R.(char(name));note="";
if kind=="time"&&(isstring(x)||iscellstr(x)||isdatetime(x)||isduration(x))
    [x,note]=clockToSeconds(x);unit="s";
elseif isstring(x)||iscellstr(x)
    x=str2double(strrep(string(x),",","."));note="문자열→숫자";
end
[x,outUnit,factor]=normalizeUnit(double(x),unit,kind);
if kind=="temperature"&&unit=="K",note=note+" K→°C (−273.15)";end
if factor~=1,note=strtrim(note+" ×"+factor+" ("+unit+"→"+outUnit+")");end
if strlength(outUnit)>0
    col=knownName;
    if kind=="current"&&outUnit=="mA",col="current_mA";end
    if kind=="voltage"&&outUnit=="mV",col="voltage_mV";end
    if kind=="time"&&outUnit=="ms",col="time_ms";end
    if kind=="impedance"&&outUnit=="mOhm",col=replace(knownName,"_ohm","_mohm");end
else
    col=bareName;report.Requests(end+1)="'"+name+"' 열의 단위를 알 수 없습니다. 앱의 단위 설정에서 원본 단위를 골라 주세요.";
end
T.(col)=x(:);
report.Mapping=[report.Mapping;{col,name,unit,note}];
end

% ---------------------------------------------------------------- name rules
function [role,unit,note]=roleOf(name)
% [C] (2026-11-09 merge) a role whose unit is not a unit of that quantity in config/unit_catalog.csv is cancelled.
note="";raw=string(name);[base,unit]=splitUnit(raw);b=lower(strtrim(base));b=regexprep(b,'\s+',' ');b=regexprep(b,'^we\(\d+\)\.','');b=replace(b,"_"," ");
role="";
% Arbin's Celsius token can be exported as Latin-1 bytes of GB2312 ℃ (¡æ).
% Require an explicit unit and leave multiple Aux channels ambiguous below.
if ~isempty(regexpi(char(raw),'^Aux[_ ]Temperature\((C|degC|°C|℃|¡æ)\)[_ ]\d+$','once'))
    role="temperature";unit="C";return
end
calendarInfo=uecm.columnInfo(name,"calendar");calendarKey=lower(regexprep(calendarInfo.Base,'[^a-zA-Z0-9가-힣]',''));
if ismember(calendarKey,["calendar","calendarage","calendardays","calendaragedays","aging","ageing","agingtime","ageingtime","agingdays","ageingdays","storage","storageage","storagedays","elapsedagingdays","열화경과일"])
    role="calendar";return
end
if ~isempty(regexp(b,'^(initial|baseline|current|measured) capacity|^(initial|baseline|current|measured)capacity|^qinitial|^qcurrent','once')),role="capacity";return,end
key=regexprep(b,'[^a-z0-9]','');
conditionRoles=["source","cell","soc","soh","cycle"];
aliases={["sourceid","datasetid"],["cellid","batteryid","cellname"], ...
    ["soc","socpct","socpercent","socnom","stateofcharge"],["soh","sohpct","sohpercent","stateofhealth"], ...
    ["cycle","cyclenumber","cycleindex","cyclecount"]};
for q=1:numel(conditionRoles)
    if ismember(key,aliases{q}),role=conditionRoles(q);return,end
end
if b==""||b=="raw_index",return,end
% Some instrument exports use R and X for the signed impedance components.
if (b=="r"||b=="x")&&strlength(unit)>0&&roleUnitOK("real",unit)
    if b=="r",role="real";else,role="imag";end
    return
end

if ~isempty(regexp(b,'(target|soll|set ?point|setpoint|control|_set$|\<set\>)','once')),role="setpoint";return,end
if ~isempty(regexp(b,'^(-|neg[ _]?)\s*(im\(z\)|z''''|zimag|zimg|im ?z|imag|im_z)','once'))||~isempty(regexp(b,'^-z''''$','once')),role="negimag";
elseif ~isempty(regexp(b,'^(im\(z\)|z''''|zimag|zimg|z ?imag|z_imag|im ?z|imaginary|zim|impedance'''')$','once')),role="imag";
elseif ~isempty(regexp(b,'^(re\(z\)|z''|zreal|z ?real|z_real|re ?z|real|zre|impedance'')$','once')),role="real";
elseif ~isempty(regexp(b,'^(\|z\||zmod|z ?mod|z ?amp|impedance|magnitude|abs ?z|\|z\| ?)$','once')),role="magnitude";
elseif ~isempty(regexp(b,'^(phase\(z\)|zphz|z ?ph|phase|phi|z ?phase|phase ?angle|phase / rad|phase / deg)$','once')),role="phase";
elseif ~isempty(regexp(b,'^(freq|frequency|f)$','once')),role="frequency";
elseif ~isempty(regexp(b,'^(time ?stamp|date ?time|datetime|date|absolute ?time)$','once')),role="timestamp";
elseif ~isempty(regexp(b,'^(step ?time)$','once')),role="steptime";       % resets every step: never the time axis
elseif ~isempty(regexp(b,'^(prog ?time|program ?time)$','once')),role="duration";
elseif ~isempty(regexp(b,'^(time|test ?time|elapsed ?time|total ?time|t|time_s|relative ?time|run ?time)$','once')),role="time";
elseif ~isempty(regexp(b,'^(i|current|<i>|i ?ist|i ?meas|current_a|cell ?current|idc)$','once')),role="current";
elseif ~isempty(regexp(b,'^(u|v|voltage|ewe|<ewe>|ecell|e ?cell|cell ?voltage|vcell|terminal ?voltage|u ?cell|potential|e)$','once')),role="voltage";
elseif ~isempty(regexp(b,'(clima|chamber|ambient|oven)','once')),role="temperature_chamber";
elseif ~isempty(regexp(b,'^(temp|temperature|battery_temp(_degc)?|battery ?temp|cell ?temp|temp\[1\]|t ?cell|t ?avg|aux ?temp|aux ?temperature ?\d*)$','once')),role="temperature";   % 'battery ?temp': underscores are now spaces (McMaster Battery_Temp_degC)
elseif ~isempty(regexp(b,'^(status|state|md|mode|status ?code)$','once')),role="status";   % [J] Maccor-type C/D/R
elseif ~isempty(regexp(b,'^(step|step ?index|ns|step_id|step ?no)$','once')),role="step";
elseif ~isempty(regexp(b,'(test[ _]?id|eis[ _]?test[ _]?id|channel[ _]?id|cycle[ _]?id|step[ _]?id|sweep|spectrum)','once')),role="id";
end
if role=="step"&&~isempty(regexp(b,'_id$','once')),role="id";end
if role~=""&&~roleUnitOK(role,unit)
    note="역할–단위 불일치로 제외: '"+role+"' 역할에 단위 "+unit;role="";
end
end

function tf=roleUnitOK(role,unit)
% [C] The unit must belong to the role's quantity in config/unit_catalog.csv (single source of unit truth).
% Empty unit = not checked (prepare.m asks). Roles without a physical quantity (id, step, status ...) are not checked.
tf=true;
if strlength(unit)==0,return,end
switch role
    case {"time","duration"},q="time";
    case "current",q="current";
    case "voltage",q="voltage";
    case {"temperature","temperature_chamber"},q="temperature";
    case "frequency",q="frequency";
    case {"real","imag","negimag","magnitude"},q="impedance";
    case "phase",q="phase";
    otherwise, return
end
tf=uecm.unitDefinition(unit,q).Known;
end

function [base,unit]=splitUnit(name)
name=strtrim(string(name));unit="";base=name;
pats={'^(.*?)\s*\[([^\]]+)\]\s*$','^(.*?)\s*\(([^\)]+)\)\s*$','^(.*?)\s*/\s*([^/]+)$','^(.*?),\s*([^,]+)$','^(.*?)_(v|mv|a|ma|ua|s|ms|min|h|hz|khz|ohm|mohm|deg|rad|c|degc|k)$'};
for k=1:numel(pats)
    t=regexp(name,pats{k},'tokens','once','ignorecase');
    if ~isempty(t)
        u=canonicalUnit(string(t{2}));
        if strlength(u)>0,base=string(t{1});unit=u;return,end
    end
end
end

function u=canonicalUnit(u)
info=uecm.unitDefinition(string(u));
if info.Known,u=info.Unit;return,end
% Keep non-signal unit labels used in logger headers, without lowercasing SI prefixes.
extra=["J","W","Wh","Ws"];
hit=find(lower(extra)==lower(strip(string(u))),1);
if isempty(hit),u="";else,u=extra(hit);end
end

function [x,out,f]=normalizeUnit(x,unit,kind)
info=uecm.unitDefinition(unit,kind);f=1;out="";
if info.Known
    x=x*info.Factor+info.Offset;f=info.Factor;out=info.TargetUnit;
end
end

function [s,note]=clockToSeconds(x)
note="";
if isduration(x),s=seconds(x);note="duration→s";return,end
if isdatetime(x),k0=find(~isnat(x),1);if isempty(k0),k0=1;end;s=seconds(x-x(k0));note="절대시각→경과 s";return,end
x=strtrim(string(x));s=nan(size(x));
hms=regexp(x,'^(\d+):(\d{2}):(\d{2}(?:\.\d+)?)$','tokens','once');
ok=~cellfun(@isempty,hms);
if mean(ok)>0.9
    v=str2double(vertcat(hms{ok}));                             % vectorised (10^6 rows: seconds instead of a loop)
    s(ok)=v(:,1)*3600+v(:,2)*60+v(:,3);
    note="hh:mm:ss→s";return
end
fmts=["dd.MM.uuuu HH:mm:ss.SSSSSSS","dd.MM.uuuu HH:mm:ss","M/d/uuuu h:mm:ss a","uuuu-MM-dd HH:mm:ss.SSS","uuuu-MM-dd HH:mm:ss"];
for fm=fmts
    try
        d=datetime(x,'InputFormat',fm,'Locale','en_US');
        if mean(~isnat(d))>0.9,s=seconds(d-d(find(~isnat(d),1)));note="절대시각("+fm+")→경과 s";return,end
    catch
    end
end
s=str2double(strrep(x,",","."));note="문자열→숫자";
end

% ---------------------------------------------------------------- helpers
function best=findHeader(lines,settings)
delims=[",",char(9),";","ws"];best=struct('score',0);
for li=1:numel(lines)
    for d=delims
        tok=splitLine(lines(li),d);if numel(tok)<2,continue,end
        tok=mergeUnitTokens(tok);roles=rolesOf(tok);
        sc=sum(roles~="");
        for q=1:numel(tok),[~,u]=splitUnit(tok(q));sc=sc+3*(strlength(u)>0);end
        if sc>best.score && matchesType(roles,settings.Type)
            best=struct('score',sc,'line',li,'delim',d,'names',tok);
        end
    end
end
end

function enc=sniffEncoding(file)
enc="UTF-8";fid=fopen(file,'r');if fid<0,return,end
b=fread(fid,4096,'*uint8')';fclose(fid);
if numel(b)>=2&&((b(1)==255&&b(2)==254)||(b(1)==254&&b(2)==255)),enc="UTF-16LE";if b(1)==254,enc="UTF-16BE";end,return,end
if ~isempty(b)&&mean(b==0)>0.2,enc="UTF-16LE";end
end

function lines=headLines(file,enc)
fid=fopen(file,'r','n',char(enc));if fid<0,error('uecm:File','파일을 열 수 없습니다.');end
cleaner=onCleanup(@()fclose(fid));lines=strings(0,1);
while numel(lines)<400
    l=fgetl(fid);if ~ischar(l),break,end
    lines(end+1,1)=string(l); %#ok<AGROW>
end
end

function r=rolesOf(names)
r=strings(size(names));
for k=1:numel(names),r(k)=roleOf(names(k));end
end

function tok=splitLine(l,d)
l=string(l);
if d=="ws"
    tok=split(strtrim(l))';tok=tok(strlength(tok)>0);
    out=strings(1,0);                                              % "Freq (Hz) Zre (Ohm)" -> ["Freq (Hz)","Zre (Ohm)"]
    for k=1:numel(tok)
        br=~isempty(regexp(tok(k),'^[\[\(][^\]\)]+[\]\)]$','once'));
        prevName=~isempty(out)&&isempty(regexp(out(end),'[\]\)]$','once'))&&isnan(str2double(out(end)));
        if br&&prevName,out(end)=out(end)+" "+tok(k);else,out(end+1)=tok(k);end %#ok<AGROW>
    end
    tok=out;
else,tok=split(l,d)';if ~isempty(tok)&&strlength(strtrim(tok(end)))==0,tok(end)=[];end
end
end

function tok=mergeUnitTokens(tok)
% "ClimaTemp, °C" split by ',' -> ["ClimaTemp"," °C"] : glue a pure-unit token to the previous name
out=strings(1,0);
for k=1:numel(tok)
    t=strtrim(tok(k));
    % only a token that STARTS WITH A SPACE after the delimiter (", °C") is a unit; "time,V,A" stays three columns
    if k>1 && startsWith(tok(k)," ") && strlength(canonicalUnit(t))>0 && strlength(t)<=4 && ~isempty(out) && strlength(canonicalUnit(out(end)))==0
        out(end)=out(end)+" ["+t+"]";
    else
        out(end+1)=tok(k); %#ok<AGROW>
    end
end
tok=out;
end

function j=choose(names,roles,role)
j=find(roles==role);
if numel(j)>1,j=[];end   % ambiguous: reported in canonical(), never picked
end
function u=splitUnitUnit(n)
[~,u]=splitUnit(n);
end

function tf=isEISRoles(r)
tf=any(r=="frequency")&&((any(r=="real")&&(any(r=="imag")||any(r=="negimag")))||(any(r=="magnitude")&&any(r=="phase")));
end
function tf=isTimeRoles(r)
tf=(any(r=="time")||any(r=="duration")||any(r=="timestamp"))&&any(r=="current")&&any(r=="voltage");
end

function p=profileName(lines,names)
txt=lower(join(lines(1:min(60,numel(lines)))," "));
if contains(txt,"ec-lab")||any(names=="freq/Hz")||any(names=="Re(Z)/Ohm"),p="biologic_eclab";
elseif contains(txt,"zcurve")||contains(txt,"gamry"),p="gamry_dta";
elseif contains(txt,"measurement id")&&contains(txt,"time stamp"),p="digatron_csv";
elseif any(contains(names,"hp_pulse")),p="wuppertal_celltester";
else,p="generic_delimited";end
end

% ---------------------------------------------------------------- documented headerless layouts
function [R,report]=knownMatrixProfile(R,report,stem)
names=string(R.Properties.VariableNames);
if ~all(startsWith(names,"col_")),return,end
% Warwick LG M50 EIS (Data in Brief 2023, Mendeley 10.17632/mn9fb7xdx6.3): files
% CellNN_<SOH>SOH_<T>degC_<SOC>SOC_<tag>.mat/.xls, 3 columns = frequency [Hz], Z' [Ohm], Z'' [Ohm] (signed, +inductive).
% Verified 2026-11-06: all 360 raw files equal the team's D005 conversion (max |diff| 1.1e-13), f = 1e4 ... 1e-2 Hz.
if numel(names)==3 && ~isempty(regexp(stem,'^Cell\d+_\d+SOH_\d+degC_\d+SOC_\d+$','once'))
    R.Properties.VariableNames={'Frequency [Hz]','Zreal [Ohm]','Zimag [Ohm]'};
    report.Profile=report.Profile+"+warwick_lgm50_eis";
    report.Hints(end+1)="Warwick LG M50 EIS 형식(열 3개: 주파수 Hz, Z' Ω, Z'' Ω 부호 포함)으로 읽었습니다. 근거: Data in Brief 2023 데이터셋 구성, 팀 D005 변환본과 값 일치.";
    return
end
report.Requests(end+1)="열 이름이 없는 표입니다("+numel(names)+"열). 열 연결에서 각 열의 의미와 단위를 지정해 주세요.";
end

function [T,report]=conditionsFromName(T,report,stem)
% Conditions written in the FILE NAME (e.g. Cell28_100SOH_25degC_50SOC_10000, 729_HPPC_25degC). Only explicit
% tokens are used; a column already present in the data is never overwritten.
n=height(T);tok=@(p)regexp(stem,p,'tokens','once','ignorecase');
c=tok('(?:^|_)cell[_-]?(\d+)');
if ~isempty(c)&&~ismember("cell_id",string(T.Properties.VariableNames)),T.cell_id=repmat("Cell"+c{1},n,1);report.Mapping=[report.Mapping;{"cell_id","(파일명)","","Cell"+c{1}}];end
c=regexp(stem,'(?:^|_)([nm-]?)(\d+(?:\.\d+)?)degC(?=_|$)','tokens','once');   % case-sensitive "degC" + boundary: "40degChannel" is not 40 °C; n10degC/m10degC = -10 °C
if ~isempty(c),tv=str2double(c{2});if strlength(c{1})>0,tv=-tv;end,c={tv};end
if ~isempty(c)&&~ismember("temperature_C",string(T.Properties.VariableNames)),T.temperature_C=repmat(c{1},n,1);report.Mapping=[report.Mapping;{"temperature_C","(파일명)","C","설정(챔버) 온도로 표기된 값"}];end
c=tok('(?:^|_)(\d+(?:\.\d+)?)SOC');
if ~isempty(c)&&~ismember("soc_pct",string(T.Properties.VariableNames))
    sv=str2double(c{1});
    if sv<=1&&contains(c{1},"."),report.Requests(end+1)="파일명 SOC 값 "+c{1}+"이 비율(0~1)인지 %인지 불분명합니다. SOC 열 또는 조건표로 확인해 주세요.";end
    if report.Kind=="HPPC"
        % an HPPC run sweeps SOC: the file-name value is only the START label, never a per-pulse SOC
        T.soc_label_pct=repmat(sv,n,1);
        report.Mapping=[report.Mapping;{"soc_label_pct","(파일명)","%","HPPC 시작 SOC 라벨 — 펄스별 SOC로 쓰지 않음(적산·앵커로 계산)"}];
        report.Hints(end+1)="파일명 SOC "+c{1}+"%는 HPPC 시작 라벨로만 보존했습니다. 펄스별 SOC는 초기 SOC·용량 적산 또는 자동 앵커로 계산합니다.";
    else
        T.soc_pct=repmat(sv,n,1);report.Mapping=[report.Mapping;{"soc_pct","(파일명)","%",""}];
    end
end
c=tok('(?:^|_)(\d+(?:\.\d+)?)SOH');
if ~isempty(c)
    T.soh_label_pct=repmat(str2double(c{1}),n,1);
    report.Mapping=[report.Mapping;{"soh_label_pct","(파일명)","%","명목 그룹 라벨 — soh_pct로 쓰지 않음"}];
    t=tok('SOC_(\d{4,5})$');
    if ~isempty(t)
        T.soh_tag_raw=repmat(str2double(t{1}),n,1);
        report.Hints(end+1)="파일명 끝 숫자("+t{1}+")는 측정 SOH×100으로 보입니다(Warwick: 24/24 셀이 용량시험 그룹 폴더와 3%p 이내 일치, 명목 라벨은 7셀 불일치). 문서에 정의가 없어 soh_pct에 자동 반영하지 않았습니다.";
    end
end
end

function [T,report]=dropEventRows(T,report)
% Cell testers write event/summary rows (step end, energy counters) without a measurement. They carry no
% current/voltage, so they are removed and counted (Wuppertal MCU1: 79 of 6,638,226 rows).
c=intersect(["current_A","current_mA","current","voltage_V","voltage_mV","voltage"],string(T.Properties.VariableNames));
if numel(c)<2,return,end
ev=all(isnan(T{:,cellstr(c)}),2);
if any(ev)
    T(ev,:)=[];report.DroppedRows=sum(ev);
    report.Hints(end+1)="측정값(전류·전압)이 없는 이벤트 행 "+sum(ev)+"개를 제외했습니다.";
end
end

function report=suggestFromData(T,report)
% Current sign from physics, not from names: a passive cell's voltage rises when it is charged.
% For each pulse (>=5 samples, rest before), compare voltage right after the step with the rest just before.
names=string(T.Properties.VariableNames);
ci=find(startsWith(names,"current"),1);vi=find(startsWith(names,"voltage"),1);
if isempty(ci)||isempty(vi),return,end
i=T{:,ci};v=T{:,vi};ok=isfinite(i)&isfinite(v);i=i(ok);v=v(ok);
if numel(i)<20,return,end
thr=min(0.02*max(abs(i)),0.05*(1+999*(names(ci)=="current_mA")));act=abs(i)>thr;
st=find(diff([false;act])==1);en=find(diff([act;false])==-1);votes=[];
for k=1:numel(st)
    if en(k)-st(k)<4||st(k)<6,continue,end
    if k>1&&st(k)-en(k-1)<6,continue,end
    dv=median(v(st(k):min(en(k),st(k)+4)))-median(v(st(k)-5:st(k)-1));
    if dv~=0,votes(end+1)=sign(dv)*sign(median(i(st(k):min(en(k),st(k)+4))));end   % same window as dV (bipolar pulses) %#ok<AGROW>
end
if numel(votes)>=3 && abs(mean(votes))>=0.8
    if mean(votes)>0,s="charge_positive";else,s="discharge_positive";end
    report.Suggested.CurrentSign=s;
    report.Hints(end+1)="전류 부호를 자료에서 판정: 펄스 "+numel(votes)+"개 중 "+sum(votes==sign(mean(votes)))+"개에서 "+ ...
        ifelse(s=="charge_positive","양(+)전류일 때 전압 상승 → 충전이 +","양(+)전류일 때 전압 하강 → 방전이 +")+".";
end
end
function out=ifelse(c,a,b)
if c,out=a;else,out=b;end
end

function fm=datetimeFormat(sample)
fm="";sample=strtrim(string(sample));
for f=["dd.MM.uuuu HH:mm:ss.SSSSSSS","dd.MM.uuuu HH:mm:ss.SSS","dd.MM.uuuu HH:mm:ss","uuuu-MM-dd HH:mm:ss.SSSSSS","uuuu-MM-dd HH:mm:ss.SSS","uuuu-MM-dd HH:mm:ss","M/d/uuuu h:mm:ss a"]
    try
        d=datetime(sample,'InputFormat',f,'Locale','en_US');
        if ~isnat(d),fm=f;return,end
    catch
    end
end
end

function yes=matchesType(roles,type)
if string(type)=="EIS",yes=isEISRoles(roles);
elseif string(type)=="HPPC",yes=isTimeRoles(roles);
else,yes=isEISRoles(roles)||isTimeRoles(roles);end
end
