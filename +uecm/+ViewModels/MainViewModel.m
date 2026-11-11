classdef MainViewModel < handle
    properties (SetObservable)
        Input = struct()
        MapFilters = struct()
        Bundle = struct()
        Status string = "파일 추가를 눌러 셀 데이터를 열어 주세요."
        Busy logical = false
        SelectedFit double = 1
        SelectedCandidate double = 1
        SelectionRevision double = 0
        Revision double = 0
    end
    properties (Dependent, SetAccess=private)
        Updating
    end
    properties
        Settings = uecm.defaults()
        MetadataFile string = ""
        SelectedFile string = ""
    end
    properties (Access=private)
        UpdateDepth double = 0
        Model
        Listeners
    end
    methods
        function obj=MainViewModel(model)
            arguments
                model uecm.Models.SessionModel
            end
            obj.Model=model;
            obj.Listeners=[addlistener(model,'Input','PostSet',@(~,~)obj.syncInput()), ...
                addlistener(model,'Bundle','PostSet',@(~,~)obj.syncBundle())];
        end
        function delete(obj)
            delete(obj.Listeners);
        end
        function value=get.Updating(obj)
            value=obj.UpdateDepth>0;
        end
        function acceptInput(obj,input)
            obj.beginUpdate();transaction=onCleanup(@()obj.finishUpdate(true)); %#ok<NASGU>
            obj.SelectedFile=input.File;obj.Settings=input.Settings;obj.Model.Input=input;obj.clearFit();obj.MapFilters=struct();
            obj.Status="열·단위를 확인한 뒤 ‘피팅 실행’를 눌러 주세요.";
        end
        function acceptWorkspace(obj,input,bundle)
            obj.beginUpdate();transaction=onCleanup(@()obj.finishUpdate(true)); %#ok<NASGU>
            obj.Model.Input=input;obj.Settings=input.Settings;obj.SelectedFile=input.File;
            obj.Model.Bundle=bundle;obj.MapFilters=struct();obj.SelectedFit=1;obj.SelectedCandidate=1;
            obj.selectFit(1);
        end
        function resetWorkspace(obj)
            obj.beginUpdate();transaction=onCleanup(@()obj.finishUpdate(true)); %#ok<NASGU>
            obj.Model.Input=struct();obj.Model.Bundle=struct();obj.Settings=uecm.defaults();
            obj.SelectedFile="";obj.MetadataFile="";obj.MapFilters=struct();obj.SelectedFit=1;obj.SelectedCandidate=1;
            obj.Status="데이터를 초기화했습니다. 원본과 ecm_result 백업은 보존됩니다.";
        end
        function setConditionLabels(obj,labels)
            input=obj.Input;input.ConditionLabels=labels;obj.Model.Input=input;obj.invalidate();
            obj.Status="선택한 측정의 빈 조건을 저장했습니다. 피팅 실행으로 조건과 결과를 연결하세요.";
        end
        function setFileOption(obj,file,type,sign)
            entry=struct('File',string(file),'Type',string(type),'CurrentSign',string(sign));
            options=entry;
            if isfield(obj.Settings,'FileOptions')
                options=obj.Settings.FileOptions;
                hit=find(string({options.File})==string(file),1);
                if isempty(hit),options(end+1)=entry;else,options(hit)=entry;end
            end
            obj.Settings.FileOptions=options;
            % Single-file inputs use the same controls without a batch dispatcher.
            if ~isfield(obj.Input,'OriginalInputs')
                obj.Settings.Type=entry.Type;obj.Settings.CurrentSign=entry.CurrentSign;
            end
            obj.invalidate();
        end
        function diagnose(obj)
            if isempty(fieldnames(obj.Input)),obj.Status="파일을 먼저 열어 주세요.";return,end
            input=obj.analysisInput();p=uecm.prepare(input);
            b=struct('Prepared',p,'Fits',{{}},'Results',table(),'Version',"0.5.0", ...
                'Timestamp',string(datetime('now','TimeZone','Asia/Seoul')),'Status',"needs_input");
            b.CustomAxes=p.CustomAxes;b.AxisCategories=p.AxisCategories;
            obj.Model.Bundle=b;
            if p.Blocked,obj.Status="추가 자료가 필요합니다. 주 화면 아래 진단 안내를 확인해 주세요.";
            else,[message,~]=uecm.coverageMessage(p.AxisCoverage);obj.Status="입력 확인 완료. "+message;end
        end
        function setMapping(obj,field,name)
            obj.Settings.Mapping.(field)=string(name);
            if ~isempty(fieldnames(obj.Input)),obj.Input.Mapping.(field)=string(name);end
            obj.invalidate();
        end
        function setOption(obj,name,value)
            obj.Settings.(name)=value;
            if ismember(string(name),["Circuit","EISModels","EISAutoWarburg"])
                obj.Status="모델 선택을 변경했습니다. 기존 결과는 보존하고 필요한 모델만 추가 계산합니다.";
            else,obj.invalidate();end
        end
        function invalidate(obj)
            obj.clearFit();obj.Status="입력 설정이 바뀌었습니다. 상세 설정에서 자료를 확인한 뒤 다시 피팅해 주세요.";
        end
        function clearFit(obj)
            obj.beginUpdate();transaction=onCleanup(@()obj.finishUpdate(true)); %#ok<NASGU>
            obj.Model.Bundle=struct();obj.SelectedFit=1;obj.SelectedCandidate=1;
        end
        function input=analysisInputSafe(obj)
            input=obj.Input;if ~isempty(fieldnames(input)),input.Settings=obj.Settings;end
        end
        function input=analysisInput(obj)
            input=obj.Input;input.Settings=obj.Settings;
        end
        function acceptFit(obj,bundle)
            obj.beginUpdate();transaction=onCleanup(@()obj.finishUpdate(true)); %#ok<NASGU>
            obj.Model.Bundle=bundle;obj.SelectedFit=1;
            obj.selectFit(1);
            if isempty(bundle.Results),obj.Status="계산 가능한 결과가 없습니다. 추가 자료 안내를 확인해 주세요.";
            else,obj.Status="계산 결과 "+height(bundle.Results)+"개. 모두 ECM 추정값이며 ‘주의’ 결과와 원본 비교를 확인하세요.";end
        end
        function selectFit(obj,index)
            if isfield(obj.Bundle,'Fits')&&index>=1&&index<=numel(obj.Bundle.Fits)
                obj.beginUpdate();transaction=onCleanup(@()obj.finishUpdate(false));
                obj.SelectedFit=index;f=obj.Bundle.Fits{index};obj.SelectedFile=string(f.SourceFile);pick=1;
                if isfield(f,'RecommendedIndex'),pick=f.RecommendedIndex;end
                obj.SelectedCandidate=pick;clear transaction
                if ~obj.Updating,obj.SelectionRevision=obj.SelectionRevision+1;end
            end
        end
        function selectCandidate(obj,index)
            if ~isfield(obj.Bundle,'Fits')||isempty(obj.Bundle.Fits),return,end
            c=uecm.candidatesOf(obj.Bundle.Fits{obj.SelectedFit});
            if index>=1&&index<=numel(c),obj.SelectedCandidate=index;end
        end
        function setMapFilters(obj,filters)
            if isfield(obj.Bundle,'Results')
                uecm.filterMapConditions(obj.Bundle.Results,filters,strings(0,1));
            end
            obj.MapFilters=filters;
        end
        function importCustomAxis(obj,M,column,label,unit,keys,source)
            if obj.Busy,error('uecm:CustomAxis','현재 작업이 끝난 뒤 추가하세요.');end
            [b,message]=uecm.addCustomAxis(obj.Bundle,M,column,label,unit,keys,source);
            obj.Model.Bundle=b;obj.Status=message+" 재피팅/새 입력 시 추가 변수를 다시 연결하세요.";
        end
        function importSelectedAxes(obj,M,columns,keys,source)
            if obj.Busy,error('uecm:CustomAxis','현재 작업이 끝난 뒤 추가하세요.');end
            [b,message]=uecm.addSelectedAxes(obj.Bundle,M,columns,keys,source);
            obj.Model.Bundle=b;obj.Status=message+" 재피팅/새 입력 시 추가 변수를 다시 연결하세요.";
        end
        function [fields,labels]=axisChoices(obj)
            fields=["soc_pct","soh_pct","temperature_C","cycle_number"];
            labels=["SOC [%]","SOH [%]","온도 [°C]","사이클 수"];
            if isfield(obj.Bundle,'CustomAxes')
                for a=obj.Bundle.CustomAxes
                    if startsWith(string(a.Source),"imported:"),continue,end
                    fields(end+1)=a.Field;labels(end+1)=a.Label;
                    if strlength(a.Unit)>0,labels(end)=labels(end)+" ["+a.Unit+"]";end
                end
            end
        end
        function [fields,labels]=availableAxisChoices(obj,file,continueFcn)
            % Four defaults plus explicit user axes; never auto-list remaining columns.
            if nargin<2,file=obj.SelectedFile;end
            if strlength(file)==0,file="*";end
            if nargin<3,continueFcn=[];end
            fields=strings(1,0);labels=strings(1,0);
            if ~isfield(obj.Bundle,'Results'),return,end
            R=obj.Bundle.Results;
            if file~="*"&&ismember('source_file',R.Properties.VariableNames),R=R(string(R.source_file)==file,:);end
            [catalog,names]=obj.axisChoices();
            for k=1:numel(catalog)
                if ~isempty(continueFcn)&&~continueFcn(),return,end
                f=catalog(k);if ~ismember(f,string(R.Properties.VariableNames))||~isnumeric(R.(f)),continue,end
                values=R.(f);values=values(isfinite(values));if isempty(values),continue,end
                fields(end+1)=f;label=names(k);if numel(unique(values))==1,label=label+" · 고정값";end
                labels(end+1)=label;
            end
        end
        function text=conditionAxisLabel(obj,field)
            [fields,labels]=obj.axisChoices();j=find(fields==string(field),1);
            if isempty(j),text=replace(string(field),"_"," ");else,text=labels(j);end
        end
        function groups=groupChoices(obj,continueFcn)
            if nargin<2,continueFcn=[];end
            groups="모두 (점으로 비교)";
            if ~isfield(obj.Bundle,'Results')||isempty(obj.Bundle.Results),return,end
            snapshot=obj.Bundle;keys=strings(0,1);R=snapshot.Results;
            for j=1:numel(snapshot.Fits)
                if ~isempty(continueFcn)&&mod(j-1,32)==0&&~continueFcn(),return,end
                cc=uecm.candidatesOf(snapshot.Fits{j});
                for k=1:numel(cc)
                    row=R(j,:);row.circuit=cc{k}.Circuit;
                    keys(end+1,1)=obj.groupKeys(row);
                    for field=["cell_model","cathode_family","cathode_composition"]
                        key=obj.descriptorKeys(row,field);
                        if strlength(key)>0,keys(end+1,1)=key;end
                    end
                end
            end
            groups=[groups;unique(keys,'stable')];
        end
        function [T,indices,message]=chartData(obj,x,y,z,group,quality,model,dimension,file)
            if nargin<7,model="권장 모델";end
            if nargin<8,dimension="3D";end
            if nargin<9,file=obj.SelectedFile;end
            T=table();indices=[];message="먼저 ECM을 계산해 주세요.";
            if ~isfield(obj.Bundle,'Results')||isempty(obj.Bundle.Results),return,end
            R=obj.Bundle.Results;parents=(1:height(R))';
            if model~="권장 모델"
                rows={};parents=[];
                for j=1:numel(obj.Bundle.Fits)
                    c=uecm.candidatesOf(obj.Bundle.Fits{j});
                    for k=1:numel(c)
                        if c{k}.ModelName==model
                            rows{end+1}=uecm.candidateRow(table2struct(obj.Bundle.Results(j,:)),c{k});parents(end+1,1)=j;
                        end
                    end
                end
                if isempty(rows),message="이 모델을 계산한 결과가 없습니다. 다시 계산해 주세요.";return,end
                R=struct2table(vertcat(rows{:}));
            end
            if y=="none",dimension="2D";end
            if dimension=="3D"&&x==y,message="X축과 Y축을 다르게 골라 주세요.";return,end
            needed=[x,z];if dimension=="3D",needed=[x,y,z];end
            if ~all(ismember(needed,string(R.Properties.VariableNames))),message="표시 가능한 조건 축/ECM 값이 연결되지 않았습니다. 축 정보 점검에서 미연결 조건을 확인하거나 직접 연결해 주세요.";return,end
            keep=isfinite(R.(x))&isfinite(R.(z));
            if strlength(file)==0,file=string(obj.Bundle.Fits{1}.SourceFile);end
            fileRows=string(cellfun(@(f)f.SourceFile,obj.Bundle.Fits,'UniformOutput',false));
            if file~="*",keep=keep&fileRows(parents)==file;end
            if dimension=="3D",keep=keep&isfinite(R.(y));end
            if group~="모두 (점으로 비교)"
                match=obj.groupKeys(R)==group;
                for field=["cell_model","cathode_family","cathode_composition"]
                    match=match|obj.descriptorKeys(R,field)==group;
                end
                keep=keep&match;
            end
            if quality=="후보만",keep=keep&R.fit_status=="candidate";end
            [conditionKeep,conditionMessage]=uecm.filterMapConditions(R,obj.MapFilters,[x,y]);keep=keep&conditionKeep;
            indices=parents(keep);T=R(keep,:);message="표시 "+height(T)+" / 전체 "+height(R)+"개 (주의 결과 "+sum(T.fit_status=="review")+"개 포함). 결측·그룹·품질 조건으로 빠진 점은 만들지 않습니다.";
            message=message+" "+conditionMessage+". "+uecm.mapConditionNotice(T,x,y);
            if isempty(T),message="선택한 축/그룹/추가 조건에 값이 없습니다. 조건 한정을 초기화하거나 범위·미연결 값을 확인하세요. "+conditionMessage;end
        end
        function key=surfaceGroup(obj,model)
            key="모두 (점으로 비교)";
            if ~isfield(obj.Bundle,'Fits')||isempty(obj.Bundle.Fits),return,end
            R=obj.Bundle.Results;keep=true(height(R),1);
            if strlength(obj.SelectedFile)>0
                keep=string(cellfun(@(f)f.SourceFile,obj.Bundle.Fits,'UniformOutput',false))==obj.SelectedFile;
            end
            selected=find(keep);if isempty(selected),return,end
            if model=="권장 모델",keys=obj.groupKeys(R);key=keys(selected(1));return,end
            for j=selected'
                cc=uecm.candidatesOf(obj.Bundle.Fits{j});
                for k=1:numel(cc)
                    if cc{k}.ModelName==model,key=R.source_id(j)+" | "+R.cell_id(j)+" | "+R.domain(j)+" | "+cc{k}.Circuit;return,end
                end
            end
        end
        function choices=parameterChoices(obj,model,file)
            if nargin<2,model="권장 모델";end
            if nargin<3,file=obj.SelectedFile;end
            choices=["Rs_Ohm","Rct_Ohm","Cdl_F","Ceff_F","CPE_alpha","CPE1_alpha","CPE2_alpha","Ceff1_F","Ceff2_F","R0_Ohm","R1_Ohm","C1_F","R2_Ohm","C2_F","tau_s","tau1_s","tau2_s","Warburg_sigma_Ohm_s_mhalf"];
            available=false(size(choices));
            if isfield(obj.Bundle,'Results')&&~isempty(obj.Bundle.Results)
                R=obj.Bundle.Results;
                for j=1:height(R)
                    if strlength(file)>0&&file~="*"&&ismember('source_file',R.Properties.VariableNames)&&string(R.source_file(j))~=file,continue,end
                    if model=="권장 모델"
                        for q=1:numel(choices)
                            if ismember(choices(q),string(R.Properties.VariableNames))
                                v=R.(choices(q));available(q)=available(q)||(isnumeric(v)&&isfinite(v(j)));
                            end
                        end
                    elseif isfield(obj.Bundle,'Fits')&&numel(obj.Bundle.Fits)>=j
                        cc=uecm.candidatesOf(obj.Bundle.Fits{j});
                        for k=1:numel(cc)
                            if cc{k}.ModelName~=model,continue,end
                            for q=1:numel(choices)
                                if isfield(cc{k}.Parameters,choices(q))&&isfinite(cc{k}.Parameters.(choices(q))),available(q)=true;end
                            end
                        end
                    end
                end
            end
            choices=choices(available);
        end
        function summary=fitSummary(obj,index)
            summary="점을 누르거나 결과 표의 줄을 눌러 주세요.";
            if ~isfield(obj.Bundle,'Fits')||index>numel(obj.Bundle.Fits)||index<1,return,end
            c=uecm.candidatesOf(obj.Bundle.Fits{index});f=c{min(obj.SelectedCandidate,numel(c))};[~,fileLabel,fileExt]=fileparts(f.SourceFile);p=struct2table(f.Parameters,'AsArray',true);
            summary=["회로: "+f.Circuit;"방법: "+f.Domain+" / 상태: "+f.Status; ...
                "학습 응답 RMSE: "+compose('%.5g',f.RMSE)+" "+f.ErrorUnit; ...
                "주의: "+f.Reason;"원본 파일: "+fileLabel+fileExt; ...
                "독립 검증: 미실시 (학습 자료 적합도만 표시)"; ...
                "파라미터: "+strjoin(string(p.Properties.VariableNames),', ')];
        end
    end
    methods (Access=private)
        function beginUpdate(obj)
            obj.UpdateDepth=obj.UpdateDepth+1;
        end
        function finishUpdate(obj,refresh)
            obj.UpdateDepth=max(0,obj.UpdateDepth-1);
            if refresh&&~obj.Updating,obj.Revision=obj.Revision+1;end
        end
        function syncInput(obj)
            obj.Input=obj.Model.Input;
        end
        function syncBundle(obj)
            obj.Bundle=obj.Model.Bundle;if ~obj.Updating,obj.Revision=obj.Revision+1;end
        end
    end
    methods (Static)
        function keys=descriptorKeys(R,field)
            keys=strings(height(R),1);
            if ~ismember(field,string(R.Properties.VariableNames)),return,end
            v=string(R.(field));known=~ismissing(v)&strlength(v)>0;
            keys(known)=field+": "+v(known)+" | "+R.source_id(known)+" | "+R.domain(known)+" | "+R.circuit(known);
        end
        function keys=groupKeys(R)
            keys=R.source_id+" | "+R.cell_id+" | "+R.domain+" | "+R.circuit;
        end
    end
end
