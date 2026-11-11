function model = openSimulink(candidate)
%OPENSIMULINK Open a fresh 1RC/2RC Simulink signal model of a fitted candidate.
%   Inputs: I_discharge_A and Ubase_V. Outputs: Vterminal_V and Vdrop_V.
%   Ubase is a local reference for HPPC, and is not inferred for EIS.
arguments
    candidate (1,1) struct
end
if ~isfield(candidate,'ModelName')||~ismember(string(candidate.ModelName),["1RC","2RC"])
    error('uecm:SimulinkCircuit','Simulink 보기는 1RC·2RC를 지원합니다. 와버그 및 기존 CPE/ZarcL을 이상 RC로 변환하지 않습니다. 비교 화면에서 1RC 또는 2RC를 선택하세요.');
end
if isempty(ver('simulink'))||~license('test','Simulink')
    error('uecm:SimulinkLicense','Simulink 설치와 사용 가능한 라이선스가 필요합니다.');
end
p=candidate.Parameters;two=string(candidate.ModelName)=="2RC";
if string(candidate.Domain)=="EIS"
    R0=p.Rs_Ohm;
    if two,R1=p.R1_Ohm;C1=p.C1_F;else,R1=p.Rct_Ohm;C1=p.Cdl_F;end
else
    R0=p.R0_Ohm;R1=p.R1_Ohm;C1=p.C1_F;
end
values=struct('R0',R0,'R1',R1,'C1',C1);
if two,values.R2=p.R2_Ohm;values.C2=p.C2_F;end
numbers=cell2mat(struct2cell(values));
if any(~isfinite(numbers)|numbers<=0)
    error('uecm:SimulinkParameters','유한한 양의 R·C 추정값이 필요합니다. 선택한 후보의 적합 상태를 확인하세요.');
end
root=fileparts(fileparts(mfilename('fullpath')));
template=fullfile(root,'assets','simulink',"UECM_"+candidate.ModelName+".slx");
if ~isfile(template),error('uecm:SimulinkTemplate','Simulink 템플릿 파일이 없습니다: %s',template);end
folder=string(tempname);mkdir(folder);[~,suffix]=fileparts(folder);
model=char(matlab.lang.makeValidName("ECM_"+candidate.ModelName+"_"+suffix));
file=fullfile(folder,string(model)+".slx");copyfile(template,file);
open_system(file);
try
    workspace=get_param(model,'ModelWorkspace');
    names=fieldnames(values);
    for k=1:numel(names),assignin(workspace,names{k},values.(names{k}));end
    reference=NaN;
    if string(candidate.Domain)=="HPPC"&&isfield(candidate,'Baseline'),reference=candidate.Baseline;end
    assignin(workspace,'FittedUbase_V',reference);
    description="Fitted "+candidate.ModelName+" / "+candidate.Domain+" / "+candidate.Status+newline+ ...
        "Vterminal = Ubase - R0*I - sum(Vp). Vp(s)/I(s) = R/(R*C*s+1). Initial polarization = 0."+newline+ ...
        "Positive current = discharge. Ubase is an external input; EIS does not supply OCV. HPPC FittedUbase_V is a local reference, not verified equilibrium OCV."+newline+ ...
        "This is a Simulink signal model, not a Simscape physical circuit. Constant local parameters; no SOC/temperature dynamics or BMS validation implied."+newline+ ...
        "Source: "+string(candidate.SourceFile)+newline+ ...
        "Parameters: "+string(jsonencode(values));
    assignin(workspace,'UECM_Candidate',candidate);
    set_param(model,'Description',char(description));
    [~,sourceName,sourceExt]=fileparts(string(candidate.SourceFile));
    parameterLines=strings(numel(names),1);
    for k=1:numel(names)
        unit="Ohm";if startsWith(names{k},'C'),unit="F";end
        parameterLines(k)=string(names{k})+" = "+compose('%.8g',values.(names{k}))+" "+unit;
    end
    referenceText="not provided";if isfinite(reference),referenceText=compose('%.8g',reference)+" V";end
    noteText=strjoin(["Fitted "+candidate.ModelName+" / "+candidate.Domain+" / "+candidate.Status; ...
        "Vterminal = Ubase - R0*I - sum(Vp); Vp/I = R/(R*C*s+1)"; ...
        "Current positive = discharge; initial polarization = 0.";parameterLines; ...
        "Ubase: external input. FittedUbase_V = "+referenceText+" (EIS: unavailable)."; ...
        "Simulink signal model; constant local parameters; inspect fit quality."; ...
        "Source: "+sourceName+sourceExt],newline);
    note=find_system(model,'FindAll','on','Type','annotation');
    for k=1:numel(note)
        if strcmp(get_param(note(k),'Tag'),'FittedParameters')
            set_param(note(k),'Text',char(noteText));
        end
    end
    save_system(model,file);
catch ex
    close_system(model,0);rethrow(ex)
end
end
