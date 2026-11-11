classdef MainView < handle
    properties
        UIFigure
    end
    properties (Access=private)
        VM
        ConditionView
        MapFilterView
        FileSettingsTable
        FileSettingsTab
        ImportLogTab
        ImportLogTable
        AxisCoverageTab
        AxisCoverageTable
        AxisCoverageLabel
        ConditionsTab
        ConditionsTable
        EISModelChecks = struct()
        EISWarburgCheck
        EISOutlierCheck
        EISRepeatCheck
        EISExcludedCheck
        EISFullRangeCheck
        EISPreprocessingTable
        ConditionTargetsData = table()
        FileDD
        ExperimentTab
        ExperimentGrid
        ExperimentPageLabel
        ExperimentPage = 1
        FileGraphMetricDD
        OverlayTab
        OverlayTable
        OverlayTableFiles = strings(0,1)
        OverlayDataTable
        OverlayDataLabel
        OverlayDataIndices = []
        OverlayDataEnabled = false(0,1)
        OverlayMeasuredEnabled = false(0,1)
        OverlayModelSelection = false(0,9)
        OverlayDataToken string = ""

        OverlayFileDD
        OverlayModeDD
        OverlayModelsCheck
        OverlayNote
        OverlayAxes = {}
        OverlayParameterAxes
        OverlayParameterAxesList = {}
        OverlayParameterGrid
        OverlayLayoutDD
        MapScopeDD
        OverlayExpandCheck
        RenderingOverlay = false
        Closing = false
        LastAxisY string = ""
        OverlayResponsePanel
        OverlayPlotsGrid
        OverlayParameterPanel
        OverlaySelection = false(0,1)
        OverlayToken string = ""
        OverlayChosenFiles = strings(0,1)
        LastMapFile string = ""

        Listeners = event.proplistener.empty
        StatusLabel
        DetailsFigure
        InputTabs
        InputInfoTab
        OptionsTab
        TableTabs
        InputTableTab
        ResultTableTab
        AxisControls
        PathLabel
        ExampleDD
        TypeDD
        SignDD
        MapTable
        PreviewTable
        RequestsTable
        NotesArea
        ResultsTable
        ComparisonDD
        ComparisonTable
        ProcessTab
        ProcessNotes
        ProcessAxes
        ProcessStartTable
        ProcessScores
        CircuitAxes
        FitParameterTable
        PrimaryFitDD
        SecondaryFitDD
        SecondaryModelDD
        OverlayResponseCheck
        ComparisonGrid
        PrimaryCard
        SecondaryCard
        PrimaryConditions
        ResponseModeDD
        SecondaryConditions
        SecondaryCircuitAxes
        SecondaryResponseAxes
        SecondaryParameters
        MapModelDD
        MapAxes
        MapSinglePanel
        MapMultiplePanel
        MapMultipleGrid
        MapMultipleAxes = {}
        MeasurementDetailsFigure
        VariableImportView
        ResponseAxes
        XDD
        YDD
        ZDD
        GroupDD
        QualityDD
        SurfaceCheck
        ChartNote
        RotateButton
        GraphPanel
        MainContentPanel
        RootGrid
        MapPointCallback = []
        MapView = [-37.5,30]
        Tabs
        DataTab
        ResponseTab
        OptionControls = struct()
        ActionButtons = {}
        CurrentChartIndices = []
        CustomAxisTask = struct('Fcn',[],'CompleteFcn',[],'ProgressFcn',[],'Future',[], ...
            'Queue',[],'Running',false,'StopRequested',false,'Generation',0)
        ConditionTask = struct('Fcn',[],'CompleteFcn',[],'ProgressFcn',[],'Future',[], ...
            'Queue',[],'Running',false,'StopRequested',false,'Generation',0)
        LoadTask = struct('Fcn',[],'CompleteFcn',[],'ProgressFcn',[],'Future',[], ...
            'Queue',[],'Running',false,'StopRequested',false,'Generation',0)
        FitTask = struct('Fcn',[],'CompleteFcn',[],'ProgressFcn',[],'Future',[], ...
            'Queue',[],'Running',false,'StopRequested',false,'Generation',0)
        SaveTask = struct('Fcn',[],'CompleteFcn',[],'ProgressFcn',[],'Future',[], ...
            'Queue',[],'Running',false,'StopRequested',false,'Generation',0)
        NormalizeSaveTask = struct('Fcn',[],'CompleteFcn',[],'ProgressFcn',[],'Future',[], ...
            'Queue',[],'Running',false,'StopRequested',false,'Generation',0)
    end
    methods
        function app=MainView(vm)
            arguments
                vm uecm.ViewModels.MainViewModel
            end
            app.VM=vm;app.createUI();
            app.CustomAxisTask.Fcn=@uecm.selectedFileVariables;app.CustomAxisTask.CompleteFcn=@app.onCustomConditionsRead;
            app.ConditionTask.Fcn=@uecm.Models.SessionModel.conditionComparison;app.ConditionTask.CompleteFcn=@app.onConditionComparison;
            app.LoadTask.Fcn=@uecm.Models.SessionModel.loadWorkspace;app.LoadTask.CompleteFcn=@app.onLoaded;app.LoadTask.ProgressFcn=@app.onProgress;
            app.FitTask.Fcn=@uecm.Models.SessionModel.fitWorkspace;app.FitTask.CompleteFcn=@app.onFitComplete;
            app.FitTask.ProgressFcn=@app.onProgress;
            app.SaveTask.Fcn=@uecm.Models.SessionModel.saveResults;app.SaveTask.CompleteFcn=@app.onSaved;
            app.NormalizeSaveTask.Fcn=@uecm.exportNormalized;app.NormalizeSaveTask.CompleteFcn=@app.onNormalizedSaved;
            app.Listeners=[addlistener(vm,'Status','PostSet',@(~,~)app.syncStatus()), ...
                addlistener(vm,'MapFilters','PostSet',@(~,~)app.refreshMapPlots()), ...
                addlistener(vm,'Busy','PostSet',@(~,~)app.syncBusy()), ...
                addlistener(vm,'Revision','PostSet',@(~,~)app.refresh()), ...
                addlistener(vm,'SelectedFit','PostSet',@(~,~)app.onSelectedFit()), ...
                addlistener(vm,'SelectionRevision','PostSet',@(~,~)app.onSelectedFit()), ...
                addlistener(vm,'SelectedCandidate','PostSet',@(~,~)app.renderResponse())];
            app.syncStatus();app.refresh();app.UIFigure.Visible='on';
        end
        function delete(app)
            if app.Closing,return,end
            app.Closing=true;
            % Detach UI observers before cancellation can deliver completion events.
            try,delete(app.Listeners);catch,end
            app.Listeners=event.proplistener.empty;
            windows={app.MeasurementDetailsFigure,app.DetailsFigure,app.UIFigure};
            for k=1:numel(windows)
                try
                    fig=windows{k};
                    if ~isempty(fig)&&isvalid(fig)&&strcmp(fig.BeingDeleted,'off')
                        fig.CloseRequestFcn=[];fig.Visible='off';
                    end
                catch
                end
            end
            resources={app.VariableImportView,app.MeasurementDetailsFigure,app.ConditionView,app.MapFilterView,app.DetailsFigure,app.UIFigure};
            for k=1:numel(resources)
                try
                    obj=resources{k};
                    if isempty(obj)||~isvalid(obj),continue,end
                    if isgraphics(obj,'figure')&&strcmp(obj.BeingDeleted,'on'),continue,end
                    if isgraphics(obj,'figure'),obj.DeleteFcn=[];end
                    delete(obj);
                catch ex
                    fprintf(2,'ECM shutdown resource: %s\n',ex.message);
                end
            end
            % Flush native window closure before cancellation can take time.
            drawnow nocallbacks
            try,app.cleanupBackground();catch ex,fprintf(2,'ECM shutdown: %s\n',ex.message);end
        end
        function requestClose(app)
            if isvalid(app)&&~app.Closing,delete(app);end
        end
        function onFigureDeleted(app)
            if isvalid(app)&&~app.Closing,delete(app);end
        end
        function loadExample(app,kind)
            arguments
                app
                kind (1,1) string = "real"
            end
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            kinds=["real","realhppc","hppc","eis","missing","hppc2","eis2"];pick=find(kinds==kind,1);
            if ~isempty(pick),app.ExampleDD.Value=app.ExampleDD.Items{pick};end
            settings=uecm.defaults();meta="";
            if kind=="real",file=fullfile(root,'examples','REAL_D010_eis_12spectra.csv');
            elseif kind=="realhppc",file=fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv');settings.CurrentSign="charge_positive";
            elseif kind=="hppc",file=fullfile(root,'examples','SYNTHETIC_hppc_practice.csv');settings.CurrentSign="discharge_positive";
            elseif kind=="hppc2",file=fullfile(root,'examples','SYNTHETIC_2RC_hppc_practice.csv');settings.CurrentSign="discharge_positive";
            elseif kind=="eis2",file=fullfile(root,'examples','SYNTHETIC_2RC_eis_practice.csv');
            elseif kind=="missing",file=fullfile(root,'examples','SYNTHETIC_missing_time.csv');settings.CurrentSign="discharge_positive";
            else,file=fullfile(root,'examples','SYNTHETIC_eis_practice.csv');end
            app.beginLoad(file,settings,meta);
        end
        function setOverlaySelection(app,indices,value)
            app.syncOverlaySelection();
            if isempty(indices)
                if ~value,app.OverlayChosenFiles=strings(0,1);end
            else
                indices=indices(indices>=1&indices<=numel(app.OverlayDataEnabled));
                app.OverlayDataEnabled(indices)=logical(value);
                if value
                    paths=string(cellfun(@(f)f.SourceFile,app.VM.Bundle.Fits(indices),'UniformOutput',false));
                    app.OverlayChosenFiles=union(app.OverlayChosenFiles,paths,'stable');
                end
            end
            app.syncOverlaySelection();app.renderOverlay();
        end
        function setOverlayFileSelection(app,files,value)
            app.syncOverlaySelection();files=string(files(:));
            if ~isempty(fieldnames(app.VM.Input)),files=files(ismember(files,app.inputFiles()));end
            if value
                app.OverlayChosenFiles=union(app.OverlayChosenFiles,files,'stable');
                b=app.VM.Bundle;
                if isfield(b,'Fits')&&~isempty(b.Fits)
                    paths=string(cellfun(@(f)f.SourceFile,b.Fits,'UniformOutput',false));
                    app.OverlayDataEnabled(ismember(paths,files))=true;
                end
            else,app.OverlayChosenFiles=setdiff(app.OverlayChosenFiles,files,'stable');end
            app.syncOverlaySelection();app.renderOverlay();
        end
        function setDatasetOption(app,index,field,value)
            app.syncOverlaySelection();
            if index<1||index>numel(app.OverlayDataEnabled),return,end
            value=logical(value);names=["1RC","2RC","ZarcL","1RC+W","2RC+W","CPE+W","2CPE+W","CPE","2CPE"];
            if string(field)=="enabled",app.OverlayDataEnabled(index)=value;
            elseif string(field)=="measured",app.OverlayMeasuredEnabled(index)=value;
            else
                col=find(names==string(field),1);if isempty(col),return,end
                cc=uecm.candidatesOf(app.VM.Bundle.Fits{index});
                available=any(cellfun(@(c)c.ModelName==string(field),cc));
                if value&&~available
                    app.VM.Status="이 데이터에서 계산하지 않은 모델입니다: "+string(field);app.renderOverlay();return
                end
                app.OverlayModelSelection(index,col)=value;
            end
            if value
                app.OverlayDataEnabled(index)=true;
                app.OverlayChosenFiles=union(app.OverlayChosenFiles,string(app.VM.Bundle.Fits{index}.SourceFile),'stable');
            end
            app.syncOverlaySelection();app.renderOverlay();
        end
        function selectOverlayScope(app,file)
            if ismember(string(file),string(app.OverlayFileDD.ItemsData))
                app.OverlayFileDD.Value=char(file);app.renderOverlay();
            end
        end
        function selectFileDatasets(app,file,value)
            b=app.VM.Bundle;if ~isfield(b,'Fits'),return,end
            indices=find(cellfun(@(f)string(f.SourceFile)==string(file),b.Fits));
            if isempty(indices),return,end
            app.setOverlaySelection(indices,value);
        end
        function setFileGraphMode(app,mode)
            app.FileGraphMetricDD.Value=char(mode);app.renderExperimentGallery();
        end
        function files=selectedOverlayFiles(app)
            app.syncOverlaySelection();files=app.OverlayChosenFiles;
        end
        function indices=selectedOverlayExperiments(app)
            app.syncOverlaySelection();indices=find(app.OverlaySelection);
        end
        function setOverlayMode(app,mode)
            if string(mode)~="응답·잔차"
                if string(mode)=="2D ECM 파라미터",app.YDD.Value='none';end
                app.MapScopeDD.Value=app.OverlayLayoutDD.Value;app.refreshMapPlots();return
            end
            app.OverlayModeDD.Value=char(mode);app.renderOverlay();
        end
        function setFilePlotMode(app,mode)
            app.MapScopeDD.Value=char(mode);app.onMapScope();
        end
        function expandOverlay(app,enabled)
            app.OverlayExpandCheck.Value=logical(enabled);app.layoutMainVisualization();
        end
        function showVariablePicker(app,M,source,info,context)
            if nargin<4,info=table();end
            if nargin<5,context=struct();end
            if ~isvalid(app)||app.Closing,return,end
            if ~isempty(app.VariableImportView)&&isvalid(app.VariableImportView),delete(app.VariableImportView);end
            app.VariableImportView=uecm.Views.VariableImportView(app.VM,M,source,info,context);
        end
        function showMeasurementDetails(app,which)
            if nargin<2,which="primary";end
            b=app.VM.Bundle;if ~isfield(b,'Results')||isempty(b.Results),return,end
            index=app.VM.SelectedFit;if which=="secondary",index=app.SecondaryFitDD.Value;end
            if index<1||index>height(b.Results),return,end
            row=b.Results(index,:);parts=["측정 상세 정보";app.measurementConditions(row);"";"전체 결과 필드 (원문 유지)"];
            for f=string(row.Properties.VariableNames)
                raw=row.(f);if isnumeric(raw),value=compose('%.17g',raw);else,value=string(raw);end
                parts(end+1,1)=f+": "+join(value(:),", ");
            end
            if ~isempty(app.MeasurementDetailsFigure)&&isvalid(app.MeasurementDetailsFigure),delete(app.MeasurementDetailsFigure);end
            app.MeasurementDetailsFigure=uifigure('Name','측정 조건 · 출처 · 주석','Position',[100,100,1000,720],'Tag','MeasurementDetails');
            g=uigridlayout(app.MeasurementDetailsFigure,[1,1]);
            uitextarea(g,'Value',cellstr(splitlines(join(parts,newline))),'Editable','off','Tag','FullMeasurementMetadata');
        end
        function setOverlayLayout(app,layout)
            app.OverlayLayoutDD.Value=char(layout);app.MapScopeDD.Value=char(layout);app.refreshMapPlots();
        end
        function setOverlayModels(app,value)
            app.OverlayModelsCheck.Value=logical(value);app.renderOverlay();
        end
        function configureFile(app,file,type,sign)
            app.VM.setFileOption(file,type,sign);app.VM.diagnose();
        end
        function showExperimentPage(app,page)
            app.ExperimentPage=max(1,floor(page));app.renderExperimentGallery();
        end
        function loadSaved(app,file)
            arguments
                app
                file (1,1) string
            end
            app.beginLoad(file,uecm.defaults(),"","session");
        end
        function showConditionComparison(app)
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="파일을 먼저 불러오세요. EIS/HPPC 모두 피팅 없이 비교할 수 있습니다.";return,end
            if app.VM.Busy,app.VM.Status="현재 작업이 끝난 뒤 조건별 비교를 열어 주세요.";return,end
            prepared=struct();if isfield(app.VM.Bundle,'Prepared'),prepared=app.VM.Bundle.Prepared;end
            app.VM.Busy=true;app.VM.Status="조건별 실측 비교 자료를 준비합니다. 피팅은 실행하지 않습니다.";
            try,app.startBackground('ConditionTask',app.VM.analysisInput(),prepared,app.VM.Bundle);
            catch ex,app.VM.Busy=false;app.VM.Status="조건 비교 준비 실패: "+string(ex.message);end
        end
        function showMapConditionFilter(app)
            if ~isfield(app.VM.Bundle,'Results')||isempty(app.VM.Bundle.Results),app.VM.Status="피팅 결과가 준비되면 나머지 조건을 한정할 수 있습니다.";return,end
            if ~isempty(app.MapFilterView)&&isvalid(app.MapFilterView),delete(app.MapFilterView);end
            app.MapFilterView=uecm.Views.MapConditionFilterView(app.VM,string(app.XDD.Value),string(app.YDD.Value));
        end
        function startAnalysis(app)
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="파일 추가를 눌러 자료를 열어 주세요.";return,end
            app.VM.Busy=true;app.VM.Status="계산 중입니다. 취소 버튼으로 멈출 수 있습니다.";
            try,app.startBackground('FitTask',app.VM.analysisInput(),app.VM.Bundle);
            catch ex,app.VM.Busy=false;app.VM.Status="계산 시작 실패: "+string(ex.message);end
        end
        function resetData(app)
            if app.VM.Busy,app.VM.Status="진행 중인 작업을 취소한 후 초기화해 주세요.";return,end
            if ~isempty(app.ConditionView)&&isvalid(app.ConditionView),delete(app.ConditionView);app.ConditionView=[];end
            if ~isempty(app.MapFilterView)&&isvalid(app.MapFilterView),delete(app.MapFilterView);app.MapFilterView=[];end
            app.ConditionTargetsData=table();app.ConditionsTable.Data=table();
            app.AxisCoverageTable.Data=table();app.AxisCoverageLabel.Text='자료를 불러오세요.';app.ImportLogTable.Data=table();
            app.LastMapFile="";app.ExperimentPage=1;
            app.VM.resetWorkspace();app.syncOptions();
        end
        function stopAnalysis(app)
            app.cancelBackground('LoadTask');app.cancelBackground('FitTask');app.cancelBackground('SaveTask');app.cancelBackground('NormalizeSaveTask');app.cancelBackground('ConditionTask');app.cancelBackground('CustomAxisTask');
            app.VM.Status="취소를 요청했습니다. 종료될 때까지 잠시 기다려 주세요.";
        end
        function exportTo(app,parent)
            arguments
                app
                parent (1,1) string
            end
            if ~isfield(app.VM.Bundle,'Prepared'),app.VM.Status="자료 확인 또는 계산을 먼저 해 주세요.";return,end
            app.VM.Busy=true;app.VM.Status="새 폴더에 결과를 저장합니다.";
            app.startBackground('SaveTask',app.VM.Bundle,parent,app.viewSettings());
        end
        function exportNormalizedTo(app,parent)
            if app.VM.Busy,return,end
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="파일을 먼저 불러오세요.";return,end
            app.VM.Busy=true;app.VM.Status="피팅 없이 정제 데이터를 표준 CSV로 저장합니다.";
            try,app.startBackground('NormalizeSaveTask',app.VM.analysisInput(),string(parent));
            catch ex,app.VM.Busy=false;app.VM.Status="CSV 저장 시작 실패: "+string(ex.message);end
        end
        function setAxes(app,x,y,z)
            arguments
                app
                x (1,1) string
                y (1,1) string
                z (1,1) string
            end
            app.refreshAxisChoices();
            if ~isvalid(app)||app.Closing,return,end
            if ismember(x,string(app.XDD.ItemsData)),app.XDD.Value=char(x);end
            app.refreshAxisChoices();
            if ~isvalid(app)||app.Closing,return,end
            if ismember(y,string(app.YDD.ItemsData)),app.YDD.Value=char(y);else,app.YDD.Value='none';end
            if ismember(z,string(app.ZDD.Items)),app.ZDD.Value=char(z);end
            app.refreshMapPlots();
        end
        function setMapView(app,preset)
            switch string(preset)
                case "front",camera=[0,0];
                case "side",camera=[90,0];
                case "top",camera=[0,90];
                otherwise,camera=[-37.5,30];
            end
            if string(app.YDD.Value)=="none",camera=[0,90];end
            app.MapView=camera;
            view(app.MapAxes,camera);
            for j=1:numel(app.MapMultipleAxes),if isvalid(app.MapMultipleAxes{j}),view(app.MapMultipleAxes{j},camera);end,end
        end
        function setRotation(app,enabled)
            app.RotateButton.Value=logical(enabled);app.configureMapInteractions();
        end
        function setSurface(app,enabled)
            arguments
                app
                enabled (1,1) logical
            end
            if enabled,key=app.VM.surfaceGroup(string(app.MapModelDD.Value));if ismember(key,string(app.GroupDD.Items)),app.GroupDD.Value=char(key);end;end
            app.SurfaceCheck.Value=enabled;app.renderMap();
        end
        function showStage(app,stage)
            arguments
                app
                stage (1,1) string
            end
            if ismember(stage,["inputs","data","settings"])
                switch stage
                    case "inputs",app.InputTabs.SelectedTab=app.InputInfoTab;
                    case "settings",app.InputTabs.SelectedTab=app.OptionsTab;
                    otherwise,app.InputTabs.SelectedTab=app.DataTab;
                end
                app.DetailsFigure.Visible='on';figure(app.DetailsFigure);return
            end
            switch stage
                case "overlay",app.Tabs.SelectedTab=app.OverlayTab;
                case "3d",app.Tabs.SelectedTab=app.ResponseTab;
                case "experiments",app.Tabs.SelectedTab=app.ExperimentTab;
                case "process",app.Tabs.SelectedTab=app.ProcessTab;
                case {"comparison","circuit"},app.Tabs.SelectedTab=app.ResponseTab;
            end
            app.layoutMainVisualization();app.DetailsFigure.Visible='off';figure(app.UIFigure);
        end
        function setMapModel(app,model)
            app.MapModelDD.Value=char(model);app.refreshMapPlots();
        end
        function model=openSelectedSimulink(app)
            model="";b=app.VM.Bundle;
            if ~isfield(b,'Fits')||isempty(b.Fits)
                app.VM.Status="먼저 피팅한 뒤 1RC 또는 2RC 후보를 선택하세요.";return
            end
            cc=uecm.candidatesOf(b.Fits{app.VM.SelectedFit});candidate=cc{min(app.VM.SelectedCandidate,numel(cc))};
            try
                model=string(uecm.openSimulink(candidate));
                app.VM.Status="Simulink 모델을 열었습니다: "+model+". 입력 I·Ubase와 적합 상태를 확인하고 다른 이름으로 저장하세요.";
            catch ex
                app.VM.Status="Simulink 보기: "+string(ex.message);
            end
        end
        function saveScreenshot(app,path)
            target=app.UIFigure;
            if strcmp(app.DetailsFigure.Visible,'on'),target=app.DetailsFigure;end
            exportapp(target,path);
        end
    end
    methods (Access=private)
        function createUI(app)
            app.UIFigure=uifigure('Name','Universal ECM Tool v8.1 | 피팅 상세 · 2D/3D 맵', ...
                'Visible','off','Position',[40,40,1600,900],'WindowState','maximized','Tag','UniversalECMMainWindow','Interruptible','on','BusyAction','queue','CloseRequestFcn',@(~,~)app.requestClose(),'DeleteFcn',@(~,~)app.onFigureDeleted());
            root=uigridlayout(app.UIFigure,[3,3]);app.RootGrid=root;root.RowHeight={38,'1x',30};root.ColumnWidth={220,'1.3x','1x'};
            root.Padding=[18,12,18,12];root.ColumnSpacing=16;root.RowSpacing=12;
            headerGrid=uigridlayout(root,[1,3]);headerGrid.Layout.Row=1;headerGrid.Layout.Column=[1,3];
            headerGrid.ColumnWidth={90,'1x',90};headerGrid.Padding=[0,0,0,0];
            header=uilabel(headerGrid,'Text','셀 데이터 · ECM','HorizontalAlignment','center','FontSize',21,'FontWeight','bold');header.Layout.Column=2;
            exitButton=uibutton(headerGrid,'Text','종료','Tag','ECMExitButton','Interruptible','on','BusyAction','queue', ...
                'Tooltip','진행 작업을 취소하고 ECM 창을 닫습니다. 저장은 결과 저장을 이용하세요.','ButtonPushedFcn',@(~,~)app.requestClose());exitButton.Layout.Column=3;
            side=uipanel(root,'Title','파일 · 피팅','TitlePosition','centertop');side.Layout.Row=2;side.Layout.Column=1;
            sg=uigridlayout(side,[15,1]);sg.RowHeight={42,36,34,38,240,46,38,20,30,20,30,30,32,32,48};sg.Scrollable='on';
            app.button(sg,'파일 추가',@(~,~)app.onOpen());
            app.button(sg,'실험 폴더 추가 (여러 개)',@(~,~)app.onFolder());
            app.button(sg,'데이터 초기화',@(~,~)app.resetData());
            app.button(sg,'조건별 EIS · HPPC 비교',@(~,~)app.showConditionComparison());
            modelPanel=uipanel(sg,'Title','EIS 계산 모델 (실행 전 선택)','TitlePosition','centertop');
            modelGrid=uigridlayout(modelPanel,[5,2]);modelGrid.RowHeight={30,30,38,30,30};modelGrid.ColumnWidth={'1x','1x'};
            families=["RC","2RC","CPE","2CPE"];labels=["1RC","2RC","1CPE","2CPE"];
            for k=1:numel(families)
                app.EISModelChecks.("Model_"+families(k))=uicheckbox(modelGrid,'Text',labels(k),'Value',true, ...
                    'Tag',"EISModel_"+families(k),'ValueChangedFcn',@(~,~)app.onEISModelsChanged());
            end
            app.EISWarburgCheck=uicheckbox(modelGrid,'Text','Warburg 자동 검토','Value',true, ...
                'Tag','EISAutoWarburg','Tooltip','선택한 모델만 W 없이/포함하여 계산하고, 정확도·품질 기준이 개선될 때만 W를 채택합니다. 해제하면 W 계산을 생략합니다.', ...
                'ValueChangedFcn',@(~,~)app.onEISModelsChanged());
            app.EISWarburgCheck.Layout.Column=[1,2];
            app.EISOutlierCheck=uicheckbox(modelGrid,'Text','이상점 제외','Value',true,'Tag','EISOutlierFilter', ...
                'Tooltip','로그 주파수 국소 곡선 편차와 MAD로 판별합니다. 원본은 유지합니다.', ...
                'ValueChangedFcn',@(src,~)app.VM.setOption('EISOutlierFilter',logical(src.Value)));
            app.EISExcludedCheck=uicheckbox(modelGrid,'Text','제외점 × 표시','Value',true,'Tag','EISShowExcluded', ...
                'ValueChangedFcn',@(~,~)app.renderResponse());
            app.EISRepeatCheck=uicheckbox(modelGrid,'Text','불안정 반복 구간 제외','Value',true,'Tag','EISRepeatFilter', ...
                'Tooltip','동일 주파수 반복 5점 이상에서 상대 산포 3%와 통계 기준을 함께 초과하는 구간만 제외합니다.', ...
                'ValueChangedFcn',@(src,~)app.VM.setOption('EISRepeatFilter',logical(src.Value)));
            app.EISRepeatCheck.Layout.Column=[1,2];
            app.button(sg,'피팅 실행',@(~,~)app.startAnalysis());
            app.button(sg,'정제 데이터 CSV 저장',@(~,~)app.onNormalizedSave());
            uilabel(sg,'Text','데이터 종류','HorizontalAlignment','center');
            app.TypeDD=uidropdown(sg,'Items',{'자동 확인','EIS','HPPC','일반 동적 시계열 (미지원)'}, ...
                'ItemsData',{'auto','EIS','HPPC','dynamic'},'ValueChangedFcn',@(src,~)app.VM.setOption('Type',string(src.Value)));
            uilabel(sg,'Text','전류 부호 (HPPC)','HorizontalAlignment','center');
            app.SignDD=uidropdown(sg,'Items',{'자동 판별','방전할 때 +','충전할 때 +'}, ...
                'ItemsData',{'unknown','discharge_positive','charge_positive'}, ...
                'ValueChangedFcn',@(src,~)app.VM.setOption('CurrentSign',string(src.Value)));
            uibutton(sg,'Text','계산 취소','ButtonPushedFcn',@(~,~)app.stopAnalysis());
            uibutton(sg,'Text','상세 설정 · 열 연결','ButtonPushedFcn',@(~,~)app.showStage("data"));
            app.button(sg,'결과 저장',@(~,~)app.onSave());
            uibutton(sg,'Text','데이터 · 파일 · 축 정보','Tag','InputInfoButton','ButtonPushedFcn',@(~,~)app.showStage("inputs"));

            app.DetailsFigure=uifigure('Name','v8.1 · 입력 데이터 · 축 정보 · 설정','Visible','off', ...
                'Tag','InputInformationWindow','CloseRequestFcn',@(src,~)set(src,'Visible','off'));
            app.DetailsFigure.Position(3:4)=[1150,800];
            detailGrid=uigridlayout(app.DetailsFigure,[1,1]);app.InputTabs=uitabgroup(detailGrid);
            app.InputInfoTab=uitab(app.InputTabs,'Title','데이터 · 파일 · 축 정보');
            cg=uigridlayout(app.InputInfoTab,[3,1]);cg.RowHeight={42,'1x',180};
            app.PathLabel=uilabel(cg,'Text','열린 파일 없음','WordWrap','on');
            app.TableTabs=uitabgroup(cg);app.TableTabs.Layout.Row=2;
            app.InputTableTab=uitab(app.TableTabs,'Title','원본 데이터');pg=uigridlayout(app.InputTableTab,[1,1]);
            app.PreviewTable=uitable(pg,'Tag','InputPreview','Tooltip','원본 앞 500행 미리보기. 피팅은 읽을 수 있는 전체 그룹을 사용합니다.');
            app.ResultTableTab=uitab(app.TableTabs,'Title','ECM 결과표');rg=uigridlayout(app.ResultTableTab,[1,1]);
            app.ResultsTable=uitable(rg,'CellSelectionCallback',@(~,e)app.onResultSelection(e));
            center=uipanel(root,'Title','피팅 상세 · 실측 비교 · 오차 분석','TitlePosition','centertop');center.Layout.Row=2;center.Layout.Column=2;
            app.MainContentPanel=center;resultGrid=uigridlayout(center,[1,1]);app.Tabs=uitabgroup(resultGrid,'Tag','MainFittingResults','SelectionChangedFcn',@(~,~)app.layoutMainVisualization());
            graph=uipanel(root,'Title','2D/3D ECM 맵 · 축 설정','Tag','MainMapPanel','TitlePosition','centertop');app.GraphPanel=graph;graph.Layout.Row=2;graph.Layout.Column=3;
            app.buildChartPanel(graph);
            app.FileSettingsTab=uitab(app.TableTabs,'Title','파일별 설정');
            fg=uigridlayout(app.FileSettingsTab,[2,1]);fg.RowHeight={55,'1x'};
            uilabel(fg,'Text','파일마다 자동으로 EIS/HPPC를 구분합니다. HPPC 전류 부호는 원본 규약에 맞게 선택하세요. 보류된 파일이 있어도 다른 준비된 파일은 계산합니다.','WordWrap','on');
            app.FileSettingsTable=uitable(fg,'Tag','FileSettings', ...
                'ColumnName',{'파일','분석 종류','HPPC 전류 부호','입력 상태'}, ...
                'ColumnEditable',[false,true,true,false], ...
                'ColumnFormat',{'char',{'자동 확인','EIS','HPPC'},{'자동 판별','방전할 때 +','충전할 때 +'},'char'}, ...
                'CellEditCallback',@(~,e)app.onFileOptionEdit(e));

            app.ImportLogTab=uitab(app.TableTabs,'Title','폴더 가져오기 내역');
            importGrid=uigridlayout(app.ImportLogTab,[1,1]);
            app.ImportLogTable=uitable(importGrid,'Tag','FolderImportLog');
            outlierTab=uitab(app.TableTabs,'Title','선택 EIS 제외점');outlierGrid=uigridlayout(outlierTab,[1,1]);
            app.EISPreprocessingTable=uitable(outlierGrid,'Tag','EISPreprocessingAudit','Tooltip','InputIndex는 선택 측정 그룹 내부의 원본 행 순서입니다. 원본은 수정하지 않습니다.');
            app.AxisCoverageTab=uitab(app.TableTabs,'Title','축 정보 점검');
            ag=uigridlayout(app.AxisCoverageTab,[3,1]);ag.RowHeight={95,'1x',38};
            app.AxisCoverageLabel=uilabel(ag,'Text','가져오기 후 축·용량 정보의 연결 상태를 점검합니다.','WordWrap','on','Tag','AxisCoverageNotice');
            app.AxisCoverageTable=uitable(ag,'Tag','AxisConditionCoverage');
            ab=uigridlayout(ag,[1,3]);ab.ColumnWidth={'1x','1x','1x'};ab.Padding=[0,0,0,0];
            uibutton(ab,'Text','빈 조건 직접 입력','ButtonPushedFcn',@(~,~)app.openConditionEditor());
            uibutton(ab,'Text','열 연결 확인','ButtonPushedFcn',@(~,~)app.showStage("data"));
            uibutton(ab,'Text','점검 보고서 · LLM 지시 저장','ButtonPushedFcn',@(~,~)app.onCoverageSave());
            app.ConditionsTab=uitab(app.TableTabs,'Title','측정 조건 · 용량 (선택)');
            conditionGrid=uigridlayout(app.ConditionsTab,[2,1]);conditionGrid.RowHeight={65,'1x'};
            conditionControls=uigridlayout(conditionGrid,[1,2]);conditionControls.ColumnWidth={'1x',125};
            uilabel(conditionControls,'Text','원본 조건을 우선 사용합니다. 빈 조건·초기/현재 실측 용량만 입력하거나 생략하세요. HPPC는 펄스 시작 조건입니다. 조건 변경 후 피팅을 실행하세요.','WordWrap','on');
            uibutton(conditionControls,'Text','조건 다시 확인','ButtonPushedFcn',@(~,~)app.refreshConditions());
            app.ConditionsTable=uitable(conditionGrid,'Tag','MeasurementConditions','Tooltip','NaN은 미기록입니다. 조건을 입력하지 않아도 신호 피팅은 실행할 수 있습니다.', ...
                'CellEditCallback',@(~,event)app.onConditionEdit(event));
            diagnosis=uipanel(cg,'Title','진단 · 추가로 필요한 자료','TitlePosition','centertop');diagnosis.Layout.Row=3;
            dg=uigridlayout(diagnosis,[1,2]);dg.ColumnWidth={'2x','1x'};
            app.RequestsTable=uitable(dg,'ColumnName',{'항목','이유','필요한 자료','계산 보류'});
            app.NotesArea=uitextarea(dg,'Editable','off','Value',{'파일을 추가하면 자료 상태를 확인합니다.'});
            app.StatusLabel=uilabel(root,'Text','','WordWrap','on');app.StatusLabel.Layout.Row=3;app.StatusLabel.Layout.Column=[1,3];

            app.buildDataTab();app.buildOptionsTab();app.buildProcessTab();app.buildResponseTab();app.buildExperimentTab();app.buildOverlayTab();
            app.Tabs.SelectedTab=app.ResponseTab;
            % Center short categorical fields; keep descriptions left and numbers right.
            centered=uistyle('HorizontalAlignment','center');numeric=uistyle('HorizontalAlignment','right');
            addStyle(app.FileSettingsTable,centered,'column',2:4);
            addStyle(app.OverlayTable,centered,'column',[1,3,4,5]);
            addStyle(app.OverlayDataTable,centered,'column',[1,3:12,14]);
            addStyle(app.OverlayDataTable,numeric,'column',13);
            addStyle(app.ComparisonTable,numeric,'column',2);
            addStyle(app.SecondaryParameters,numeric,'column',2);
        end
        function button(app,parent,text,callback)
            b=uibutton(parent,'Text',text,'ButtonPushedFcn',callback);app.ActionButtons{end+1}=b;
        end
        function buildDataTab(app)
            app.DataTab=uitab(app.InputTabs,'Title','열 연결');g=uigridlayout(app.DataTab,[2,2]);
            g.RowHeight={38,'1x'};g.ColumnWidth={'1x','1.3x'};
            a=uilabel(g,'Text','열 연결과 단위가 맞는지 확인하세요. 수정 후 자료 확인을 누르세요.','WordWrap','on');a.Layout.Column=[1,2];
            app.MapTable=uitable(g,'ColumnName',{'뜻','내 파일의 열'},'ColumnEditable',[false,true], ...
                'CellEditCallback',@(~,e)app.onMapEdit(e));app.MapTable.Layout.Row=2;app.MapTable.Layout.Column=1;
            actions=uigridlayout(g,[8,1]);actions.Layout.Row=2;actions.Layout.Column=2;
            actions.RowHeight={32,32,32,32,32,32,32,32};actions.Scrollable='on';
            app.button(actions,'자료 확인',@(~,~)app.onDiagnose());
            app.button(actions,'조건표 추가 / 바꾸기',@(~,~)app.onMetadata());
            app.button(actions,'저장한 결과 다시 열기',@(~,~)app.onSession());
            app.ExampleDD=uidropdown(actions,'Items',{'실제 EIS · 공개 자료 12개','실제 HPPC · 주의 사례 1개','가상 HPPC · 화면 연습','가상 EIS · 화면 연습','시간 없는 자료 · 요청 연습','가상 2RC HPPC · 비교 연습','가상 2RC EIS · 비교 연습'});
            app.button(actions,'선택한 예제 열기',@(~,~)app.onExample());
            app.button(actions,'쉬운 사용법 열기',@(~,~)app.onHelp());
            uibutton(actions,'Text','단위 설정','ButtonPushedFcn',@(~,~)app.showStage("settings"));
            app.button(actions,'입력형식 적용 · 다시 읽기',@(~,~)app.onReload());
        end
        function buildOptionsTab(app)
            tab=uitab(app.InputTabs,'Title','단위·추가 정보');app.OptionsTab=tab;g=uigridlayout(tab,[22,2]);g.ColumnWidth={250,'1x'};
            g.RowHeight=repmat({32},1,22);g.Scrollable='on';
            specs={ ...
                'ImpedanceUnit','임피던스 단위',{'auto','Ohm','mOhm','uOhm','kOhm','MOhm'}; ...
                'ImaginarySign','허수부가 뜻하는 값',{'auto','signed_imaginary','negative_imaginary'}; ...
                'FrequencyUnit','주파수 단위',{'auto','Hz','kHz','mHz','MHz'}; ...
                'TimeUnit','시간 단위',{'auto','s','ms','min','h'}; ...
                'CurrentUnit','전류 단위',{'auto','A','mA','uA'}; ...
                'VoltageUnit','전압 단위',{'auto','V','mV','uV'}; ...
                'PhaseUnit','위상 단위',{'auto','deg','rad'}; ...
                'SOCUnit','SOC 단위',{'auto','percent','fraction'}; ...
                'SOHUnit','SOH 단위',{'auto','percent','fraction'}; ...
                'TemperatureUnit','온도 단위',{'auto','C','K'}; ...
                'ImagSignCheck','EIS 허수부 물리 검사',{'on','off'}; ...
                'Delimiter','표 구분자 (다시 읽기 적용)',{'auto',',',';','tab'}; ...
                'DecimalSeparator','소수점 (다시 읽기 적용)',{'.',','}};
            for k=1:size(specs,1)
                name=specs{k,1};uilabel(g,'Text',specs{k,2});dd=uidropdown(g,'Items',specs{k,3}, ...
                    'ValueChangedFcn',@(src,~)app.VM.setOption(name,string(src.Value)));app.OptionControls.(name)=dd;
            end
            numericFields={'SampleInterval_s','시간 열이 없을 때: 확인한 간격[s]';'InitialSOC_pct','시험 시작 SOC[%] (선택)'; ...
                'Capacity_Ah','사용 가능 용량[Ah] (선택)'; ...
                'RestCurrent_A','휴지 전류 임계값[A] (선택)'; ...
                'MaxPulseDuration_s','최대 펄스 길이[s] (선택)'; ...
                'SOCTolerance_pct','SOC 경계 보정 허용폭[%p] (0=해제)'};
            for k=1:size(numericFields,1)
                name=numericFields{k,1};uilabel(g,'Text',numericFields{k,2});
                c=uieditfield(g,'text','ValueChangedFcn',@(src,~)app.onNumeric(name,src));app.OptionControls.(name)=c;
            end
            a=uilabel(g,'Text','auto = 열 이름에 적힌 단위만 사용합니다. 모르면 임의로 채우지 않고 요청합니다.','WordWrap','on');a.Layout.Column=[1,2];
            b=uilabel(g,'Text','signed_imaginary = Z″, negative_imaginary = −Z″. percent=0~100%, fraction=0~1.','WordWrap','on');b.Layout.Column=[1,2];
        end
        function buildChartPanel(app,parent)
            g=uigridlayout(parent,[7,1]);g.RowHeight={34,36,36,160,'1x',48,65};
            app.FileDD=uidropdown(g,'Tag','ExperimentFileChoice','Items',{'파일 없음'},'ItemsData',{'none'}, ...
                'ValueChangedFcn',@(~,~)app.onFileChoice());
            app.FileDD.Layout.Row=1;app.FileDD.Tooltip='선택 파일만 모드의 표시 파일입니다. 합쳐 보기와 나눠 보기는 불러온 전체 파일의 유효한 값을 사용합니다.';
            app.AxisControls=uigridlayout(g,[1,6]);app.AxisControls.Layout.Row=6;
            app.AxisControls.ColumnWidth={48,'1x',48,'1x',48,'1x'};app.AxisControls.RowHeight={32};
            app.AxisControls.Padding=[0,4,0,4];controls=app.AxisControls;
            vars={'none'};displayNames={'연결된 축 없음'};
            uilabel(controls,'Text','X축 변수','HorizontalAlignment','center');app.XDD=uidropdown(controls,'Tag','XAxisChoice','Items',displayNames,'ItemsData',vars,'Value','none','Enable','off','ValueChangedFcn',@(~,~)app.refreshMapPlots());
            uilabel(controls,'Text','Y축 변수','HorizontalAlignment','center');app.YDD=uidropdown(controls,'Tag','YAxisChoice','ItemsData',{'none'},'Items',{'없음 (2D)'},'Value','none','Enable','off','ValueChangedFcn',@(~,~)app.refreshMapPlots());
            uilabel(controls,'Text','Z축 변수','HorizontalAlignment','center');app.ZDD=uidropdown(controls,'Tag','ZAxisChoice','Items',{'연결된 파라미터 없음'},'Enable','off','ValueChangedFcn',@(~,~)app.refreshMapPlots());
            tools=uigridlayout(g,[1,2]);tools.Layout.Row=2;tools.ColumnWidth={'1.6x','1x'};tools.Padding=[0,0,0,0];tools.RowHeight={32};
            app.MapScopeDD=uidropdown(tools,'Tag','MapFileScope','Tooltip','이 맵 안에서 선택 파일, 전체 파일 합쳐 보기, 파일별 나눠 보기를 전환합니다.','Items',{'선택 파일만','여러 파일 한 그래프','파일별 나눠 보기'},'ItemsData',{'single','combined','split'},'ValueChangedFcn',@(~,~)app.onMapScope());
            app.RotateButton=uibutton(tools,'state','Tag','RotateMap','Text','마우스 회전','Value',true, ...
                'ValueChangedFcn',@(src,~)app.setRotation(src.Value));
            cameras=uigridlayout(g,[1,4]);cameras.Layout.Row=3;cameras.ColumnWidth={'1x','1x','1x','1x'};cameras.Padding=[0,0,0,0];cameras.RowHeight={30};
            labels={'기본','정면','측면','위'};presets=["default","front","side","top"];
            for k=1:4
                preset=presets(k);uibutton(cameras,'Text',labels{k},'ButtonPushedFcn',@(~,~)app.setMapView(preset));
            end
            filters=uigridlayout(g,[4,2]);filters.Layout.Row=4;filters.RowHeight={28,28,30,30};filters.ColumnWidth={'1x','1x'};
            app.MapModelDD=uidropdown(filters,'Items',{'권장 모델'},'ValueChangedFcn',@(~,~)app.refreshMapPlots());
            app.GroupDD=uidropdown(filters,'Items',{'모두 (점으로 비교)'},'ValueChangedFcn',@(~,~)app.refreshMapPlots());
            app.QualityDD=uidropdown(filters,'Items',{'모두 (주의 포함)','후보만'},'ValueChangedFcn',@(~,~)app.refreshMapPlots());
            app.SurfaceCheck=uicheckbox(filters,'Text','조건 맞으면 면 연결','ValueChangedFcn',@(~,~)app.refreshMapPlots());
            uibutton(filters,'Text','나머지 조건 한정','Tag','MapConditionFilterButton','ButtonPushedFcn',@(~,~)app.showMapConditionFilter());
            uibutton(filters,'Text','조건 한정 초기화','Tag','MapConditionFilterReset','ButtonPushedFcn',@(~,~)app.VM.setMapFilters(struct()));
            uibutton(filters,'Text','추가 변수 키 템플릿 저장','Tag','CustomAxisTemplate','ButtonPushedFcn',@(~,~)app.onCustomAxisTemplate());
            uibutton(filters,'Text','변수 추가하기','Tag','CustomAxisImport','ButtonPushedFcn',@(~,~)app.onCustomAxisImport());
            host=uigridlayout(g,[1,1]);host.Layout.Row=5;host.Padding=[0,0,0,0];
            app.MapSinglePanel=uipanel(host,'BorderType','none');app.MapSinglePanel.Layout.Row=1;app.MapSinglePanel.Layout.Column=1;
            app.MapMultiplePanel=uipanel(host,'BorderType','none','Visible','off');app.MapMultiplePanel.Layout.Row=1;app.MapMultiplePanel.Layout.Column=1;
            one=uigridlayout(app.MapSinglePanel,[1,1]);one.Padding=[0,0,0,0];
            app.MapMultipleGrid=uigridlayout(app.MapMultiplePanel,[1,1]);app.MapMultipleGrid.Tag='MainMapPlotGrid';app.MapMultipleGrid.Scrollable='on';
            app.MapAxes=uiaxes(one,'Tag','ParameterMap');grid(app.MapAxes,'on');view(app.MapAxes,3);
            app.ChartNote=uilabel(g,'Text','피팅 후 ECM 값을 표시합니다.','WordWrap','on');app.ChartNote.Layout.Row=7;
        end
        function buildOverlayTab(app)
            app.OverlayTab=uitab(app.Tabs,'Title','선택 그래프 겹쳐 보기');
            g=uigridlayout(app.OverlayTab,[3,1]);g.Tag='OverlayScrollLayout';g.ColumnWidth={'1x'};g.RowHeight={800,160,540};g.Scrollable='on';
            controls=uigridlayout(g,[4,3]);controls.Layout.Row=2;controls.Layout.Column=1;
            controls.RowHeight={28,28,28,30};controls.ColumnWidth={'1x','1x','1x'};
            app.OverlayFileDD=uidropdown(controls,'Tag','OverlayFileChoice','Items',{'파일 없음'},'ItemsData',{'none'},'ValueChangedFcn',@(~,~)app.renderOverlay());
            uibutton(controls,'Text','이 파일 체크','ButtonPushedFcn',@(~,~)app.selectOverlayFile());
            uibutton(controls,'Text','모두 체크 해제','ButtonPushedFcn',@(~,~)app.setOverlaySelection([],false));
            app.OverlayModeDD=uidropdown(controls,'Tag','OverlayMode','Items',{'응답·잔차'},'Visible','off', ...
                'ValueChangedFcn',@(~,~)app.renderOverlay());
            app.OverlayModelsCheck=uicheckbox(controls,'Text','체크한 피팅 모델 표시','Value',true,'ValueChangedFcn',@(~,~)app.renderOverlay());
            uibutton(controls,'Text','오른쪽 맵 축 설정','ButtonPushedFcn',@(~,~)app.expandOverlay(false));
            app.OverlayLayoutDD=uidropdown(controls,'Tag','OverlayParameterLayout','Visible','off','Items',{'한 그래프에 합쳐 보기','파일별로 나눠 보기'},'ItemsData',{'combined','split'},'ValueChangedFcn',@(~,~)app.renderOverlay());app.OverlayLayoutDD.Layout.Row=3;app.OverlayLayoutDD.Layout.Column=[1,2];
            note=uilabel(controls,'Text','2D/3D 비교는 오른쪽 맵에서 설정','WordWrap','on');note.Layout.Row=3;note.Layout.Column=[1,2];
            app.OverlayExpandCheck=uicheckbox(controls,'Text','응답 그래프 확대','Tag','ExpandOverlayGraph','Value',false, ...
                'Tooltip','켜면 오른쪽 단일 파일 맵·축 선택을 접습니다. 끄면 맵과 축 선택을 계속 표시합니다.', ...
                'ValueChangedFcn',@(~,~)app.layoutMainVisualization());app.OverlayExpandCheck.Layout.Row=3;app.OverlayExpandCheck.Layout.Column=3;
            app.OverlayNote=uilabel(controls,'Text','위쪽은 큰 그래프입니다. 아래 표에서 비교할 파일을 체크하세요. 피팅 전에도 원본을 볼 수 있습니다.','WordWrap','on');app.OverlayNote.Layout.Row=4;app.OverlayNote.Layout.Column=[1,3];
            selection=uigridlayout(g,[4,1]);selection.Layout.Row=3;selection.Layout.Column=1;selection.RowHeight={170,42,34,260};
            app.OverlayTable=uitable(selection,'Tag','OverlayFiles','ColumnName',{'선택','파일','종류','결과 수','상태'}, ...
                'ColumnEditable',[true,false,false,false,false],'ColumnFormat',{'logical','char','char','numeric','char'}, ...
                'ColumnWidth',{40,170,50,60,115},'CellSelectionCallback',@(~,e)app.onOverlayFileRow(e),'CellEditCallback',@(~,e)app.setOverlayFileSelection(app.OverlayTableFiles(e.Indices(1)),logical(e.NewData)));
            app.OverlayDataLabel=uilabel(selection,'Text','파일 체크 후 아래에서 스윕/펄스와 측정·모델을 선택하세요.','WordWrap','on');
            bulk=uigridlayout(selection,[1,2]);bulk.Padding=[0,0,0,0];
            uibutton(bulk,'Text','이 파일 데이터 전체 선택','ButtonPushedFcn',@(~,~)app.selectFileDatasets(string(app.OverlayFileDD.Value),true));
            uibutton(bulk,'Text','이 파일 데이터 해제','ButtonPushedFcn',@(~,~)app.selectFileDatasets(string(app.OverlayFileDD.Value),false));
            app.OverlayDataTable=uitable(selection,'Tag','OverlayDatasets', ...
                'ColumnName',{'선택','데이터 ID','측정','1RC','2RC','ZarcL','1RC+W','2RC+W','CPE+W','2CPE+W','CPE','2CPE','권장 RMSE','단위'}, ...
                'ColumnEditable',[true,false,true,true,true,true,true,true,true,true,true,true,false,false], ...
                'ColumnFormat',{'logical','char','logical','logical','logical','logical','logical','logical','logical','logical','logical','logical','numeric','char'}, ...
                'ColumnWidth',{38,115,38,38,38,48,55,55,55,60,48,48,85,40},'CellEditCallback',@(~,e)app.onDatasetEdit(e));
            host=uigridlayout(g,[1,1]);host.Layout.Row=1;host.Layout.Column=1;host.Padding=[0,0,0,0];host.Tag='OverlayGraphHost';
            app.OverlayResponsePanel=uipanel(host,'BorderType','none');app.OverlayResponsePanel.Layout.Row=1;app.OverlayResponsePanel.Layout.Column=1;
            app.OverlayParameterPanel=uipanel(host,'BorderType','none','Visible','off');app.OverlayParameterPanel.Layout.Row=1;app.OverlayParameterPanel.Layout.Column=1;
            plots=uigridlayout(app.OverlayResponsePanel,[2,2]);plots.Tag='SelectedExperimentPlots';app.OverlayPlotsGrid=plots;
            app.OverlayAxes={uiaxes(plots,'Tag','OverlayEISResponse'),uiaxes(plots,'Tag','OverlayHPPCResponse'), ...
                uiaxes(plots,'Tag','OverlayEISResidual'),uiaxes(plots,'Tag','OverlayHPPCResidual')};
            parameterGrid=uigridlayout(app.OverlayParameterPanel,[1,1]);app.OverlayParameterGrid=parameterGrid;
            app.OverlayParameterAxes=uiaxes(parameterGrid,'Tag','OverlayParameterMap','Visible','off');
        end
        function syncOverlaySelection(app)
            files=strings(0,1);
            if ~isempty(fieldnames(app.VM.Input)),files=app.inputFiles();files=files(:);end
            token=join(files,char(31));
            if token~=app.OverlayToken
                app.OverlayChosenFiles=strings(0,1);app.OverlayToken=token;
            end
            app.OverlayChosenFiles=app.OverlayChosenFiles(ismember(app.OverlayChosenFiles,files));
            b=app.VM.Bundle;app.OverlaySelection=false(0,1);
            count=0;dataToken="none";
            if isfield(b,'Fits')&&~isempty(b.Fits),count=numel(b.Fits);dataToken=string(b.Timestamp)+"|"+count+"|"+token;end
            if dataToken~=app.OverlayDataToken||numel(app.OverlayDataEnabled)~=count
                app.OverlayDataToken=dataToken;app.OverlayDataEnabled=true(count,1);
                app.OverlayMeasuredEnabled=true(count,1);app.OverlayModelSelection=false(count,9);
                names=["1RC","2RC","ZarcL","1RC+W","2RC+W","CPE+W","2CPE+W","CPE","2CPE"];
                for k=1:count
                    col=find(names==b.Fits{k}.ModelName,1);if ~isempty(col),app.OverlayModelSelection(k,col)=true;end
                end
            end
            if isfield(b,'Fits')&&~isempty(b.Fits)
                paths=string(cellfun(@(f)f.SourceFile,b.Fits,'UniformOutput',false));
                app.OverlaySelection=ismember(paths,app.OverlayChosenFiles)&app.OverlayDataEnabled;
            end
        end
        function selectOverlayFile(app)
            app.setOverlayFileSelection(string(app.OverlayFileDD.Value),true);
        end
        function renderOverlay(app)
            if ~isvalid(app)||app.Closing||app.VM.Updating||app.RenderingOverlay||isempty(app.OverlayTable)||~isvalid(app.OverlayTable),return,end
            app.RenderingOverlay=true;renderCleanup=onCleanup(@()app.finishOverlayRender()); %#ok<NASGU>
            app.syncOverlaySelection();b=app.VM.Bundle;
            indices=find(app.OverlaySelection);n=numel(app.OverlaySelection);
            fitFiles=strings(n,1);
            if n>0,fitFiles=string(cellfun(@(f)f.SourceFile,b.Fits,'UniformOutput',false));end
            files=unique(fitFiles,'stable');
            if ~isempty(fieldnames(app.VM.Input)),files=app.inputFiles();files=files(:);end
            app.OverlayTableFiles=files;data=cell(numel(files),5);
            for k=1:numel(files)
                members=find(fitFiles==files(k));[~,name,ext]=fileparts(files(k));
                checked=ismember(files(k),app.OverlayChosenFiles);
                kind="";status="원본 표시 · 피팅 전/보류";
                d=uecm.filePlotData(b,files(k));kind=d.Domain;
                if ~isempty(members)
                    domains=string(cellfun(@(f)f.Domain,b.Fits(members),'UniformOutput',false));
                    kind=join(unique(domains,'stable')," / ");status="결과 있음";
                    if any(b.Results.fit_status(members)=="review"),status="주의 결과 포함";end
                    status=status+" · 선택 "+sum(app.OverlaySelection(members))+"/"+numel(members);
                end
                data(k,:)={checked,char(name+ext),char(kind),numel(members),char(status)};
            end
            app.OverlayTable.Data=data;
            old=string(app.OverlayFileDD.Value);
            if ~isempty(files)
                names=strings(size(files));
                for k=1:numel(files),[~,name,ext]=fileparts(files(k));names(k)=string(k)+": "+name+ext;end
                app.OverlayFileDD.ItemsData={};app.OverlayFileDD.Items=cellstr(names);app.OverlayFileDD.ItemsData=cellstr(files);
                if ~ismember(old,files),old=files(1);end
                app.OverlayFileDD.Value=char(old);
            else
                app.OverlayFileDD.ItemsData={};app.OverlayFileDD.Items={'파일 없음'};app.OverlayFileDD.ItemsData={'none'};
            end
            app.renderDatasetTable();
            checks=findall(app.ExperimentGrid,'Tag','OverlayFileInclude');
            for k=1:numel(checks)
                members=find(fitFiles==string(checks(k).UserData));
                checks(k).Value=ismember(string(checks(k).UserData),app.OverlayChosenFiles);
            end
            mode=string(app.OverlayModeDD.Value);response=mode=="응답·잔차";
            % Swap full-size panes with Visible: zero-height native axes can produce NaN geometry.
            app.OverlayResponsePanel.Visible=matlab.lang.OnOffSwitchState(response);
            app.OverlayParameterPanel.Visible=matlab.lang.OnOffSwitchState(~response);
            for k=1:numel(app.OverlayAxes),app.OverlayAxes{k}.Visible=matlab.lang.OnOffSwitchState(response);end
            app.OverlayParameterAxes.Visible=matlab.lang.OnOffSwitchState(~response);
            if response
                scrollLayout=findall(app.OverlayTab,'Tag','OverlayScrollLayout');scrollLayout.RowHeight{1}=800;
                uecm.plotSelectedFitData(app.OverlayAxes,b,app.OverlayChosenFiles,indices,app.OverlayMeasuredEnabled,app.OverlayModelSelection,app.OverlayModelsCheck.Value,@()app.uiCheckpoint());
                if ~isvalid(app)||app.Closing,return,end
                app.layoutOverlayPlots();
                app.OverlayNote.Text=char("선택 파일 "+numel(app.OverlayChosenFiles)+"개 · 체크한 데이터 "+numel(indices)+"개 · 측정·모델 체크에 따라 표시 · EIS [Ω] / HPPC [V]");
            else
                try,app.renderOverlayParameters(indices,mode);
                catch ex
                    if ~isvalid(app)||app.Closing,return,end
                    app.OverlayNote.Text=char("그래프 갱신 실패: "+string(ex.message)+". 마지막 그래프를 유지합니다. 축/조건을 확인하세요.");
                end
            end
        end
        function finishOverlayRender(app)
            if ~isvalid(app)||app.Closing,return,end
            app.RenderingOverlay=false;
        end
        function onOverlayFileRow(app,event)
            if isempty(event.Indices),return,end
            row=event.Indices(1,1);
            if row<=numel(app.OverlayTableFiles),app.selectOverlayScope(app.OverlayTableFiles(row));end
        end
        function onDatasetEdit(app,event)
            row=event.Indices(1);col=event.Indices(2);
            if row>numel(app.OverlayDataIndices),return,end
            fields=["enabled","","measured","1RC","2RC","ZarcL","1RC+W","2RC+W","CPE+W","2CPE+W","CPE","2CPE"];
            if col<=numel(fields)&&strlength(fields(col))>0
                app.setDatasetOption(app.OverlayDataIndices(row),fields(col),logical(event.NewData));
            end
        end
        function renderDatasetTable(app)
            file=string(app.OverlayFileDD.Value);b=app.VM.Bundle;indices=[];
            if isfield(b,'Fits'),indices=find(cellfun(@(f)string(f.SourceFile)==file,b.Fits));end
            app.OverlayDataIndices=indices;data=cell(numel(indices),14);
            for row=1:numel(indices)
                k=indices(row);f=b.Fits{k};id=b.Results(k,:);
                label=id.fit_id;
                if isfinite(id.soc_pct),label=label+" | SOC "+compose('%.3g',id.soc_pct)+"%";end
                if isfinite(id.temperature_C),label=label+" | "+compose('%.3g',id.temperature_C)+"°C";end
                label=label+" | "+id.test_id+" | "+id.spectrum_id;
                data(row,:)={app.OverlayDataEnabled(k),char(label),app.OverlayMeasuredEnabled(k), ...
                    app.OverlayModelSelection(k,1),app.OverlayModelSelection(k,2),app.OverlayModelSelection(k,3), ...
                    app.OverlayModelSelection(k,4),app.OverlayModelSelection(k,5),app.OverlayModelSelection(k,6),app.OverlayModelSelection(k,7), ...
                    app.OverlayModelSelection(k,8),app.OverlayModelSelection(k,9), ...
                    sqrt(mean(abs(f.Measured-f.Predicted).^2)),char(f.ErrorUnit)};
            end
            app.OverlayDataTable.Data=data;
            app.OverlayDataTable.UserData=indices;
            if isempty(indices),app.OverlayDataLabel.Text='이 파일은 피팅 후 스윕/펄스별 선택이 가능합니다. 현재는 원본 표시.';
            else,app.OverlayDataLabel.Text=char("이 파일의 데이터 "+numel(indices)+"개 · 측정/모델 체크 · RMSE는 권장 모델");end
            if ismember(file,app.OverlayChosenFiles),app.OverlayDataTable.Enable='on';else,app.OverlayDataTable.Enable='off';end
        end
        function restoreDatasetOptions(app,settings)
            app.syncOverlaySelection();n=numel(app.OverlayDataEnabled);
            if isfield(settings,'OverlayDataEnabled')&&numel(settings.OverlayDataEnabled)==n
                app.OverlayDataEnabled=logical(settings.OverlayDataEnabled(:));
            end
            if isfield(settings,'OverlayMeasuredEnabled')&&numel(settings.OverlayMeasuredEnabled)==n
                app.OverlayMeasuredEnabled=logical(settings.OverlayMeasuredEnabled(:));
            end
            if isfield(settings,'OverlayModelSelection')&&size(settings.OverlayModelSelection,1)==n
                cols=size(settings.OverlayModelSelection,2);
                if ismember(cols,[3,5,6,7,9]),app.OverlayModelSelection(:,1:cols)=logical(settings.OverlayModelSelection);end
            end
            app.syncOverlaySelection();app.renderOverlay();
        end
        function renderOverlayParameters(app,indices,mode)
            x=string(app.XDD.Value);y=string(app.YDD.Value);z=string(app.ZDD.Value);
            if mode=="2D ECM 파라미터",y="none";end
            layout=string(app.OverlayLayoutDD.Value);
            opts=struct('Model',string(app.MapModelDD.Value),'Filters',app.VM.MapFilters,'Rotate',app.RotateButton.Value,'ContinueFcn',@()app.uiCheckpoint());
            [axesList,shown]=uecm.plotParameterFiles(app.OverlayParameterGrid,app.VM.Bundle,indices,x,y,z,layout,opts);
            if ~isvalid(app)||app.Closing,return,end
            app.OverlayParameterAxesList=axesList;app.OverlayParameterAxes=axesList{1};
            for j=1:numel(axesList)
                ax=axesList{j};xlabel(ax,app.axisLabel(x),'Interpreter','none');
                if y=="none",ylabel(ax,app.axisLabel(z),'Interpreter','none');
                else,ylabel(ax,app.axisLabel(y),'Interpreter','none');zlabel(ax,app.axisLabel(z),'Interpreter','none');end
            end
            container=findall(app.OverlayTab,'Tag','OverlayScrollLayout');
            if layout=="split",container.RowHeight{1}=max(800,440*numel(axesList));else,container.RowHeight{1}=800;end
            app.OverlayNote.Text=char("체크한 데이터 "+numel(indices)+"개 중 유효한 "+numel(shown)+"개 · "+string(app.OverlayLayoutDD.Value)+" · 파일별 색상 · 결측/중복 좌표는 채우거나 평균내지 않습니다.");
        end
        function buildExperimentTab(app)
            app.ExperimentTab=uitab(app.Tabs,'Title','오차 분석');
            g=uigridlayout(app.ExperimentTab,[2,1]);g.RowHeight={38,'1x'};
            controls=uigridlayout(g,[1,5]);controls.ColumnWidth={85,'1x',155,140,85};controls.Padding=[0,0,0,0];
            uibutton(controls,'Text','이전 파일','ButtonPushedFcn',@(~,~)app.showExperimentPage(app.ExperimentPage-1));
            app.ExperimentPageLabel=uilabel(controls,'Text','파일별 모델 오차 분포를 표시합니다.','HorizontalAlignment','center');
            app.FileGraphMetricDD=uidropdown(controls,'Tag','FileErrorMode','Items',{'RMSE','RMSE 누적분포','잔차','파일 원본·피팅'}, ...
                'Value','RMSE','ValueChangedFcn',@(src,~)app.setFileGraphMode(string(src.Value)));
            uibutton(controls,'Text','체크한 파일 겹쳐 보기','ButtonPushedFcn',@(~,~)app.showStage("overlay"));
            uibutton(controls,'Text','다음 파일','ButtonPushedFcn',@(~,~)app.showExperimentPage(app.ExperimentPage+1));
            app.ExperimentGrid=uigridlayout(g,[1,1]);app.ExperimentGrid.Tag='FileGraphGallery';
        end
        function renderExperimentGallery(app)
            if isempty(app.ExperimentGrid)||~isvalid(app.ExperimentGrid),return,end
            delete(app.ExperimentGrid.Children);
            if isempty(fieldnames(app.VM.Input)),app.ExperimentPageLabel.Text='파일을 추가하세요.';return,end
            files=app.inputFiles();files=files(:);b=app.VM.Bundle;total=numel(files);
            index=min(max(1,app.ExperimentPage),total);app.ExperimentPage=index;
            app.ExperimentPageLabel.Text=char("파일 "+index+" / "+total+" · "+string(app.FileGraphMetricDD.Value));
            app.syncOverlaySelection();
            file=files(index);[~,name,ext]=fileparts(file);
            panel=uipanel(app.ExperimentGrid,'Title',char(name+ext),'Tooltip',char(file));
            grid=uigridlayout(panel,[3,1]);grid.RowHeight={28,'1x',44};
            bar=uigridlayout(grid,[1,2]);bar.ColumnWidth={95,'1x'};bar.Padding=[0,0,0,0];
            uicheckbox(bar,'Text','파일 비교','Tag','OverlayFileInclude','UserData',file, ...
                'Value',ismember(file,app.OverlayChosenFiles),'ValueChangedFcn',@(src,~)app.setOverlayFileSelection(string(src.UserData),src.Value));
            uibutton(bar,'Text','이 파일의 피팅 상세 / 설정','ButtonPushedFcn',@(~,~)app.showFileDetails(file));
            ax=uiaxes(grid,'Tag','FileResponse');
            mode=string(app.FileGraphMetricDD.Value);
            if mode=="파일 원본·피팅",d=uecm.plotFileData(ax,b,file,true);
            else,d=uecm.plotFileErrors(ax,b,file,mode);end
            if isfield(d,'Statistics')
                grid.RowHeight={28,'1x',185};
                tables=uitabgroup(grid);
                summary=uitab(tables,'Title','요약 통계');
                summaryGrid=uigridlayout(summary,[1,1]);summaryGrid.Padding=[0,0,0,0];
                uitable(summaryGrid,'Data',d.Statistics,'Tooltip',char(d.Note),'ColumnWidth','fit');
                bins=uitab(tables,'Title','구간별 건수 · 비율');
                binGrid=uigridlayout(bins,[1,1]);binGrid.Padding=[0,0,0,0];
                uitable(binGrid,'Data',d.Bins,'ColumnWidth','fit', ...
                    'Tooltip','하한 포함 · 상한 제외. 마지막 구간은 상한도 포함합니다.');
            else
                uilabel(grid,'Text',char(d.Note),'WordWrap','on');
            end
        end
        function showFileDetails(app,file)
            app.VM.SelectedFile=string(file);b=app.VM.Bundle;hit=[];
            if isfield(b,'Fits'),hit=find(cellfun(@(f)string(f.SourceFile)==string(file),b.Fits),1);end
            if ~isempty(hit),app.VM.selectFit(hit);app.showStage("comparison");
            else
                app.refreshFileControls();app.renderMap();
                app.TableTabs.SelectedTab=app.FileSettingsTab;app.showStage("inputs");
            end
        end
        function onSelectedFit(app)
            if ~isvalid(app)||app.Closing||app.VM.Updating,return,end
            app.refreshFileControls();app.renderResponse();app.refreshMapPlots();
        end
        function onFileChoice(app)
            file=string(app.FileDD.Value);app.VM.SelectedFile=file;
            b=app.VM.Bundle;
            if isfield(b,'Fits')
                hit=find(cellfun(@(f)string(f.SourceFile)==file,b.Fits),1);
                if ~isempty(hit),app.VM.selectFit(hit);return,end
            end
            app.refreshMapPlots();
        end
        function onFileOptionEdit(app,event)
            row=event.Indices(1);files=app.inputFiles();D=app.FileSettingsTable.Data;
            type=string(D{row,2});if type=="자동 확인",type="auto";end
            signs=["unknown","discharge_positive","charge_positive"];
            labels=["자동 판별","방전할 때 +","충전할 때 +"];
            sign=signs(labels==string(D{row,3}));
            app.configureFile(files(row),type,sign);
        end
        function refreshFileControls(app)
            if isempty(fieldnames(app.VM.Input)),app.FileSettingsTable.Data=cell(0,4);return,end
            files=app.inputFiles();files=files(:);labels=strings(size(files));data=cell(numel(files),4);
            for k=1:numel(files)
                [~,base,ext]=fileparts(files(k));labels(k)=string(k)+": "+base+ext;
                type=app.VM.Settings.Type;sign=app.VM.Settings.CurrentSign;status="확인 전";
                if isfield(app.VM.Settings,'FileOptions')
                    options=app.VM.Settings.FileOptions;hit=find(string({options.File})==files(k),1);
                    if ~isempty(hit),type=options(hit).Type;sign=options(hit).CurrentSign;end
                end
                if isfield(app.VM.Bundle,'Prepared')
                    q=app.VM.Bundle.Prepared;
                    if isfield(q,'FilePrepared'),q=q.FilePrepared{k};end
                    sign=q.Input.Settings.CurrentSign;
                    status=q.Type+" · 준비";
                    if q.Blocked,status=q.Type+" · 보류 (진단 확인)";end
                end
                typeLabel=string(type);if typeLabel=="auto",typeLabel="자동 확인";end
                signLabels=["자동 판별","방전할 때 +","충전할 때 +"];
                signValues=["unknown","discharge_positive","charge_positive"];
                signLabel=signLabels(find(signValues==string(sign),1));
                if isempty(signLabel),signLabel="자동 판별";end
                data(k,:)={char(files(k)),char(typeLabel),char(signLabel),char(status)};
            end
            app.FileSettingsTable.Data=data;
            selected=app.VM.SelectedFile;
            app.FileDD.ItemsData={};app.FileDD.Items=cellstr(labels);app.FileDD.ItemsData=cellstr(files);
            if ~ismember(selected,files),selected=files(1);app.VM.SelectedFile=selected;end
            app.FileDD.Value=char(selected);
            if selected~=app.LastMapFile
                app.LastMapFile=selected;app.GroupDD.Value='모두 (점으로 비교)';
                if isfield(app.VM.Bundle,'Fits')
                    fits=app.VM.Bundle.Fits;hit=find(cellfun(@(f)string(f.SourceFile)==selected,fits),1);
                    if ~isempty(hit)
                        f=fits{hit};values=f.Parameters;names=string(fieldnames(values));
                        valid=names(arrayfun(@(name)isfinite(values.(name)),names));
                        valid=valid(ismember(valid,string(app.ZDD.Items)));
                        if ~ismember(string(app.ZDD.Value),valid)&&~isempty(valid),app.ZDD.Value=char(valid(1));end
                    end
                end
            end
        end
        function buildProcessTab(app)
            app.ProcessTab=uitab(app.Tabs,'Title','피팅 과정');g=uigridlayout(app.ProcessTab,[5,2]);
            g.RowHeight={30,'1.4x',85,'1x','1x'};
            label=uilabel(g,'Text','측정별 조건·후보 파라미터 · 표의 행을 선택한 뒤 회로와 응답을 열 수 있습니다.');
            label.Layout.Column=1;
            uibutton(g,'Text','선택 측정의 회로 · 응답','ButtonPushedFcn',@(~,~)app.showStage("comparison"));
            app.FitParameterTable=uitable(g,'Tag','FitParameterTable','CellSelectionCallback',@(~,e)app.onParameterRow(e));
            app.FitParameterTable.Layout.Row=2;app.FitParameterTable.Layout.Column=[1,2];
            app.ProcessNotes=uitextarea(g,'Editable','off','Value',{'계산 뒤 실제 반복 이력과 초기값별 결과가 나옵니다.'});app.ProcessNotes.Layout.Row=3;app.ProcessNotes.Layout.Column=[1,2];
            app.ProcessAxes=uiaxes(g,'Tag','FittingProcess');app.ProcessAxes.Layout.Row=4;app.ProcessAxes.Layout.Column=[1,2];
            app.ProcessStartTable=uitable(g);app.ProcessStartTable.Layout.Row=5;app.ProcessStartTable.Layout.Column=1;
            app.ProcessScores=uitable(g);app.ProcessScores.Layout.Row=5;app.ProcessScores.Layout.Column=2;
        end
        function buildResponseTab(app)
            app.ResponseTab=uitab(app.Tabs,'Title','ECM 회로 · 피팅 비교');
            g=uigridlayout(app.ResponseTab,[3,1]);g.RowHeight={38,'1x',0};g.Scrollable='on';app.ComparisonGrid=g;
            controls=uigridlayout(g,[1,6]);controls.ColumnWidth={'1x','1x',85,105,90,90};
            app.PrimaryFitDD=uidropdown(controls,'Tag','PrimaryFit','Items',{'측정 1 없음'},'ItemsData',0, ...
                'ValueChangedFcn',@(src,~)app.VM.selectFit(src.Value));
            app.SecondaryFitDD=uidropdown(controls,'Tag','SecondaryFit','Items',{'두 번째 측정 없음'},'ItemsData',0, ...
                'ValueChangedFcn',@(~,~)app.renderResponse());
            app.OverlayResponseCheck=uicheckbox(controls,'Text','응답 겹치기','Tag','OverlayResponses','ValueChangedFcn',@(~,~)app.renderResponse());
            uibutton(controls,'Text','Simulink로 열기','Tag','OpenSimulink','ButtonPushedFcn',@(~,~)app.openSelectedSimulink());
            uibutton(controls,'Text','피팅 과정','ButtonPushedFcn',@(~,~)app.showStage("process"));

            app.EISFullRangeCheck=uicheckbox(controls,'Text','전체 점 범위','Tag','EISFullRange','Value',false, ...
                'Tooltip','켜면 제외점까지 전체 범위를 표시합니다. 끄면 사용점과 피팅 곡선으로 확대합니다.', ...
                'ValueChangedFcn',@(~,~)app.renderResponse());
            app.PrimaryCard=uigridlayout(g,[4,2]);app.PrimaryCard.Layout.Row=2;
            app.PrimaryCard.RowHeight={68,30,126,'1x'};
            header=uigridlayout(app.PrimaryCard,[1,2]);header.Layout.Row=1;header.Layout.Column=[1,2];header.ColumnWidth={'1x',85};header.Padding=[0,0,0,0];
            app.PrimaryConditions=uilabel(header,'WordWrap','on','Tag','PrimaryConditions');
            uibutton(header,'Text','상세 정보','Tag','PrimaryConditionDetails','ButtonPushedFcn',@(~,~)app.showMeasurementDetails("primary"));
            app.ComparisonDD=uidropdown(app.PrimaryCard,'Items',{'없음'},'ItemsData',1, ...
                'ValueChangedFcn',@(src,~)app.VM.selectCandidate(src.Value));
            app.ResponseModeDD=uidropdown(app.PrimaryCard,'Items',{'실측 · 피팅','잔차'}, ...
                'ValueChangedFcn',@(~,~)app.renderResponse());
            app.ResponseModeDD.Layout.Row=2;app.ResponseModeDD.Layout.Column=2;
            app.ComparisonTable=uitable(app.PrimaryCard);app.ComparisonTable.Layout.Row=3;app.ComparisonTable.Layout.Column=2;
            app.CircuitAxes=uiaxes(app.PrimaryCard,'Tag','ECMCircuit');app.CircuitAxes.Layout.Row=3;app.CircuitAxes.Layout.Column=1;
            app.ResponseAxes=uiaxes(app.PrimaryCard,'Tag','PrimaryResponse');app.ResponseAxes.Layout.Row=4;app.ResponseAxes.Layout.Column=[1,2];

            app.SecondaryCard=uigridlayout(g,[4,2]);app.SecondaryCard.Layout.Row=3;
            app.SecondaryCard.RowHeight={68,30,126,'1x'};
            header=uigridlayout(app.SecondaryCard,[1,2]);header.Layout.Row=1;header.Layout.Column=[1,2];header.ColumnWidth={'1x',85};header.Padding=[0,0,0,0];
            app.SecondaryConditions=uilabel(header,'WordWrap','on','Tag','SecondaryConditions');
            uibutton(header,'Text','상세 정보','Tag','SecondaryConditionDetails','ButtonPushedFcn',@(~,~)app.showMeasurementDetails("secondary"));
            app.SecondaryModelDD=uidropdown(app.SecondaryCard,'Items',{'없음'},'ItemsData',1, ...
                'ValueChangedFcn',@(~,~)app.renderResponse());
            app.SecondaryCircuitAxes=uiaxes(app.SecondaryCard);
            app.SecondaryCircuitAxes.Layout.Row=3;app.SecondaryCircuitAxes.Layout.Column=1;
            app.SecondaryParameters=uitable(app.SecondaryCard);app.SecondaryParameters.Layout.Row=3;app.SecondaryParameters.Layout.Column=2;
            app.SecondaryResponseAxes=uiaxes(app.SecondaryCard,'Tag','SecondaryResponse');
            app.SecondaryResponseAxes.Layout.Row=4;app.SecondaryResponseAxes.Layout.Column=[1,2];
            app.SecondaryCard.Visible='off';
        end
        function onParameterRow(app,event)
            if isempty(event.Indices),return,end
            row=event.Indices(1,1);entry=app.FitParameterTable.Data(row,:);
            k=find(app.VM.Bundle.Results.fit_id==entry.fit_id,1);
            if isempty(k),return,end
            app.VM.selectFit(k);
            candidates=uecm.candidatesOf(app.VM.Bundle.Fits{k});
            j=find(cellfun(@(c)c.ModelName==entry.model,candidates),1);
            if ~isempty(j),app.VM.selectCandidate(j);end
        end
        function onExample(app)
            values=["real","realhppc","hppc","eis","missing","hppc2","eis2"];index=find(strcmp(app.ExampleDD.Value,app.ExampleDD.Items));app.loadExample(values(index));
        end
        function [opts,ok]=chooseInputOptions(app)
            labels={'혼합·자동 판별 · EIS와 HPPC 모두','정리된 템플릿 · EIS','정리된 템플릿 · HPPC', ...
                '정리된 템플릿 · EIS와 HPPC 모두','원시 데이터 · EIS','원시 데이터 · HPPC', ...
                '원시 데이터 · EIS와 HPPC 모두','혼합·자동 판별 · EIS','혼합·자동 판별 · HPPC'};
            [pick,ok]=listdlg('Name','입력 종류 선택','PromptString','입력 방식과 실험 종류를 선택하세요.', ...
                'SelectionMode','single','ListString',labels,'ListSize',[390,230]);
            opts=app.VM.Settings;
            if ~ok,return,end
            modes=["auto","template","template","template","raw","raw","raw","auto","auto"];
            types=["auto","EIS","HPPC","auto","EIS","HPPC","auto","EIS","HPPC"];
            opts.ImportMode=modes(pick);opts.Type=types(pick);
            opts.Delimiter=app.VM.Settings.Delimiter;opts.DecimalSeparator=app.VM.Settings.DecimalSeparator;
        end
        function openConditionEditor(app)
            app.refreshConditions();app.TableTabs.SelectedTab=app.ConditionsTab;app.showStage("inputs");
        end
        function refreshCoverage(app,p)
            if isfield(p,'AxisCoverage'),C=p.AxisCoverage;else,C=uecm.conditionCoverage(p);end
            app.AxisCoverageTable.Data=C;
            [message,~]=uecm.coverageMessage(C);
            app.AxisCoverageLabel.Text=char(message+newline+ ...
                "집계 단위는 원래 셀·시험·스펙트럼 그룹입니다. 일부 행이 비어 있으면 ‘일부 미연결’로 표시합니다. 열 이름 후보는 근거 확인이 필요하며 자동으로 값을 채우지 않습니다.");
        end
        function onCoverageSave(app)
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="먼저 자료를 불러오세요.";return,end
            if app.VM.Busy,return,end
            if ~isfield(app.VM.Bundle,'Prepared'),app.VM.diagnose();end
            parent=uigetdir(pwd,'축 정보 점검 보고서를 저장할 상위 폴더');if isequal(parent,0),return,end
            try
                folder=uecm.exportConditionReport(app.VM.Bundle.Prepared,string(parent));
                app.VM.Status="축 정보 점검 보고서 저장 완료: "+folder;
            catch ex,app.VM.Status="점검 보고서 저장 오류: "+string(ex.message);end
        end
        function refreshConditions(app)
            if isempty(fieldnames(app.VM.Input)),return,end
            try
                prepared=struct();if isfield(app.VM.Bundle,'Prepared'),prepared=app.VM.Bundle.Prepared;end
                targets=uecm.conditionTargets(app.VM.analysisInput(),prepared);
                app.ConditionTargetsData=targets;
                if isempty(targets),app.ConditionsTable.Data=table();return,end
                cols=["source_file","cell_id","test_id","spectrum_id","scope", ...
                    "soc_pct","soh_pct","temperature_C","cycle_number","initial_capacity_Ah","current_capacity_Ah","calendar_days", ...
                    "soc_source","soh_source","temperature_source","cycle_source","initial_capacity_source","current_capacity_source","calendar_source"];
                app.ConditionsTable.Data=targets(:,cols);
                app.ConditionsTable.ColumnName={'파일·시트','셀','시험','스펙트럼','적용 범위','SOC [%]','SOH [%]', ...
                    '온도 [°C]','사이클 수','초기 실측 용량 [Ah]','현재 실측 용량 [Ah]','열화 경과일 [day]', ...
                    'SOC 근거','SOH 근거','온도 근거','사이클 근거','초기 용량 근거','현재 용량 근거','경과일 근거'};
                app.ConditionsTable.ColumnEditable=[false(1,5),true(1,7),false(1,7)];
            catch ex
                app.VM.Status="조건 확인 오류: "+string(ex.message);
            end
        end
        function onConditionEdit(app,event)
            row=event.Indices(1);col=event.Indices(2);
            fields=["soc_pct","soh_pct","temperature_C","cycle_number","initial_capacity_Ah","current_capacity_Ah","calendar_days"];
            sources=["soc_source","soh_source","temperature_source","cycle_source","initial_capacity_source","current_capacity_source","calendar_source"];
            j=col-5;if j<1||j>numel(fields),return,end
            target=app.ConditionTargetsData(row,:);
            try
                if ismember(target.(sources(j)),["source_data","metadata"])
                    error('uecm:ConditionValue','원본 또는 연결 조건표에 값이 있습니다. 해당 원본·조건표에서 확인해 주세요.');
                end
                value=uecm.validateConditionValue(fields(j),event.NewData);
                keys=["source_file","source_id","cell_id","test_id","spectrum_id","row_start","row_end"];
                entry=target(:,[keys,fields]);
                for field=fields,entry.(field)=NaN;end
                labels=entry([],:);
                if isfield(app.VM.Input,'ConditionLabels'),labels=app.VM.Input.ConditionLabels;end
                for field=fields
                    if ~ismember(field,string(labels.Properties.VariableNames)),labels.(field)=nan(height(labels),1);end
                end
                labels=labels(:,entry.Properties.VariableNames);
                hit=find(labels.source_file==entry.source_file&labels.row_start==entry.row_start ...
                    &labels.row_end==entry.row_end&labels.test_id==entry.test_id&labels.spectrum_id==entry.spectrum_id,1);
                if isempty(hit),labels=[labels;entry];hit=height(labels);end
                labels.(fields(j))(hit)=value;
                app.VM.setConditionLabels(labels);app.VM.diagnose();
            catch ex
                app.VM.Status="조건 입력: "+string(ex.message);
            end
            app.refreshConditions();
        end
        function onFolder(app)
            [opts,ok]=app.chooseInputOptions();if ~ok,return,end
            projectRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            initial=fullfile(projectRoot,'complete_datasets');
            if opts.ImportMode=="template"
                initial=fullfile(projectRoot,'processed_data_v7_llm');
                if ~isfolder(initial),initial=fullfile(projectRoot,'processed_data_v5_llm');end
                if ~isfolder(initial)
                    initial=fullfile(projectRoot,'Universal_ECM_Tool','templates','filled_real_data');
                    if opts.Type~="auto",initial=fullfile(initial,opts.Type);end
                end
            end
            if ~isfolder(initial),initial=projectRoot;end
            initial=uecm.lastInputFolder("",string(initial));
            folders=uecm.chooseFolders(string(initial));
            if isempty(folders),return,end
            uecm.lastInputFolder(string(folders(end)));
            app.beginLoad(folders,opts,"");
        end
        function onOpen(app)
            [opts,ok]=app.chooseInputOptions();if ~ok,return,end
            filter='*.csv;*.tsv;*.txt;*.xlsx;*.xls';
            if opts.ImportMode~="template",filter=[filter,';*.mat;*.mpt;*.dta'];end
            initial=uecm.lastInputFolder();if ~endsWith(initial,filesep),initial=initial+filesep;end
            [f,p]=uigetfile({filter,'선택한 종류의 측정 파일'},'배터리 자료 고르기 (Ctrl/Shift로 여러 파일 선택)',char(initial),'MultiSelect','on');
            if isequal(f,0),return,end
            uecm.lastInputFolder(string(p));
            files=string(fullfile(p,f));files=files(:);
            app.beginLoad(files,opts,"");
        end
        function files=inputFiles(app)
            files=app.VM.Input.File;
            if isfield(app.VM.Input,'Files'),files=app.VM.Input.Files;end
        end
        function onSession(app)
            [f,p]=uigetfile('*.mat','이 도구에서 저장한 session.mat 고르기');if isequal(f,0),return,end
            app.beginLoad(fullfile(p,f),uecm.defaults(),"");
        end
        function labels=mappingLabels(~,fields)
            dict=struct('frequency','주파수','real','임피던스 실수부','imag','임피던스 허수부', ...
                'magnitude','임피던스 크기','phase','위상','time','시간','current','전류','voltage','전압', ...
                'source','자료 출처 ID','cell','셀 ID','test','시험 ID','spectrum','스펙트럼/구간 ID', ...
                'soc','남은 충전량 SOC','temperature','온도','soh','건강 상태 SOH','cycle','사이클 수','calendar','열화 경과일 [day]','status','충·방전 상태 코드');
            labels=strings(numel(fields),1);
            for k=1:numel(fields),if isfield(dict,fields{k}),labels(k)=dict.(fields{k});else,labels(k)=string(fields{k});end,end
        end
        function onMetadata(app)
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="먼저 신호 파일을 열어 주세요.";return,end
            [f,p]=uigetfile({'*.csv;*.tsv;*.txt;*.xlsx;*.xls','조건표 (CSV/TSV/TXT/Excel)'},'셀/스펙트럼 ID가 있는 조건표 고르기');if isequal(f,0),return,end
            file=string(fullfile(p,f));[sheet,ok]=app.chooseSheet(file);if ~ok,return,end
            opts=app.VM.Settings;opts.MetadataSheet=sheet;
            app.beginLoad(app.inputFiles(),opts,file,"reload");
        end
        function onReload(app)
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="먼저 파일을 열어 주세요.";return,end
            app.beginLoad(app.inputFiles(),app.VM.Settings,app.VM.MetadataFile,"reload");
        end
        function [sheet,ok]=chooseSheet(~,file)
            sheet="";ok=true;[~,~,ext]=fileparts(file);
            if ~ismember(lower(ext),[".xlsx",".xls"]),return,end
            sheets=sheetnames(file);
            if numel(sheets)==1,sheet=sheets(1);return,end
            [selected,ok]=listdlg('PromptString','읽을 Excel 시트를 선택하세요.','SelectionMode','single','ListString',cellstr(sheets));
            if ok,sheet=sheets(selected);end
        end
        function beginLoad(app,file,settings,meta,mode)
            if nargin<5,mode="append";end
            if app.VM.Busy,return,end
            app.VM.Busy=true;app.VM.Status="자료를 읽고 있습니다. 원본은 바꾸지 않습니다.";
            try,app.startBackground('LoadTask',string(file),settings,string(meta),app.VM.analysisInputSafe(),app.VM.Bundle,mode);
            catch ex,app.VM.Busy=false;app.VM.Status="파일 읽기 시작 실패: "+string(ex.message);end
        end
        function onLoaded(app,input,err,cancelled)
            if ~isvalid(app)||app.Closing,return,end
            app.VM.Busy=false;
            if cancelled,app.VM.Status="파일 열기를 취소했습니다.";return,end
            if ~isempty(err)
                app.VM.Status="파일을 읽지 못했습니다: "+string(err.message);
                uialert(app.UIFigure,string(err.message),'가져오기 실패','Icon','error');
                return
            end
            if isfield(input,'LoadedWorkspace')
                if ~isempty(app.ConditionView)&&isvalid(app.ConditionView),delete(app.ConditionView);app.ConditionView=[];end
                if ~isempty(app.MapFilterView)&&isvalid(app.MapFilterView),delete(app.MapFilterView);app.MapFilterView=[];end
                app.VM.acceptWorkspace(input.Input,input.Bundle);if ~isvalid(app)||app.Closing,return,end;app.syncOptions();app.refreshConditions();
                app.VM.Status=input.Message;app.showStage("3d");return
            end
            if isfield(input,'SavedSession')
                app.MapModelDD.Value='권장 모델';app.VM.acceptInput(input.Bundle.Prepared.Input);app.VM.acceptFit(input.Bundle);if ~isvalid(app)||app.Closing,return,end;app.syncOptions();
                if ~isempty(input.ViewSettings)&&all(isfield(input.ViewSettings,{'X','Y','Z'}))
                    vs=input.ViewSettings;
                    if isfield(vs,'ExpandOverlay'),app.OverlayExpandCheck.Value=logical(vs.ExpandOverlay);end
                    if isfield(vs,'MapFileScope')&&ismember(string(vs.MapFileScope),["single","combined","split"]),app.MapScopeDD.Value=char(vs.MapFileScope);end
                    % Select the saved file/model before validating its available axes.
                    if isfield(vs,'SelectedFit'),app.VM.selectFit(vs.SelectedFit);end
                    if isfield(vs,'MapModel')&&ismember(string(vs.MapModel),string(app.MapModelDD.Items)),app.setMapModel(vs.MapModel);end
                    app.setAxes(vs.X,vs.Y,vs.Z);
                    if isfield(vs,'Rotate'),app.setRotation(vs.Rotate);end
                    if isfield(vs,'Group')&&ismember(string(vs.Group),string(app.GroupDD.Items)),app.GroupDD.Value=char(vs.Group);end
                    if isfield(vs,'Quality'),app.QualityDD.Value=char(vs.Quality);end
                    if isfield(vs,'Surface'),app.SurfaceCheck.Value=vs.Surface;end
                    app.renderMap();
                    if isfield(vs,'SelectedFit'),app.VM.selectFit(vs.SelectedFit);end
                    if isfield(vs,'SelectedCandidate'),app.VM.selectCandidate(vs.SelectedCandidate);end
                    if isfield(vs,'MapModel')&&ismember(string(vs.MapModel),string(app.MapModelDD.Items)),app.setMapModel(vs.MapModel);end
                    if isfield(vs,'CameraView')&&numel(vs.CameraView)==2&&all(isfinite(vs.CameraView))
                        app.MapView=vs.CameraView;if app.mapDimension()=="3D",view(app.MapAxes,vs.CameraView);else,view(app.MapAxes,2);end
                    end
                end
                if isfield(input.ViewSettings,'OverlayFiles')||isfield(input.ViewSettings,'OverlayIndices')
                    if isfield(input.ViewSettings,'OverlayFiles')
                        app.setOverlayFileSelection(string(input.ViewSettings.OverlayFiles),true);
                    else
                        old=input.ViewSettings.OverlayIndices;old=old(old>=1&old<=numel(app.VM.Bundle.Fits));
                        paths=string(cellfun(@(f)f.SourceFile,app.VM.Bundle.Fits(old),'UniformOutput',false));
                        app.setOverlayFileSelection(paths,true);
                    end
                    if isfield(input.ViewSettings,'OverlayShowModels'),app.setOverlayModels(input.ViewSettings.OverlayShowModels);end
                    if isfield(input.ViewSettings,'OverlayLayout'),app.OverlayLayoutDD.Value=char(input.ViewSettings.OverlayLayout);end
                    if isfield(input.ViewSettings,'OverlayMode'),app.setOverlayMode(input.ViewSettings.OverlayMode);end
                end
                app.restoreDatasetOptions(input.ViewSettings);
                if isfield(input.ViewSettings,'MapFilters'),app.VM.setMapFilters(input.ViewSettings.MapFilters);end
                if isfield(input.ViewSettings,'FileGraphMode'),app.setFileGraphMode(string(input.ViewSettings.FileGraphMode));end
                app.VM.Status="저장된 결과를 다시 열었습니다. 다시 계산하지 않고 볼 수 있습니다.";
                app.TableTabs.SelectedTab=app.ResultTableTab;app.refreshConditions();return
            end
            app.FileGraphMetricDD.Value='RMSE';
            app.MapModelDD.Value='권장 모델';app.VM.acceptInput(input);app.syncOptions();app.TableTabs.SelectedTab=app.InputTableTab;app.VM.diagnose();
            if isfield(input,'Files')&&numel(input.Files)>1,app.TableTabs.SelectedTab=app.FileSettingsTab;end
            if isfield(input,'ImportLog')&&any(input.ImportLog.status~="loaded")
                app.TableTabs.SelectedTab=app.ImportLogTab;
            end
            C=app.VM.Bundle.Prepared.AxisCoverage;[~,missing]=uecm.coverageMessage(C);
            if missing,app.TableTabs.SelectedTab=app.AxisCoverageTab;end
            app.refreshConditions();app.showStage("3d");
        end
        function onConditionComparison(app,data,err,cancelled)
            if ~isvalid(app)||app.Closing,return,end
            app.VM.Busy=false;
            if cancelled,app.VM.Status="조건 비교 준비를 취소했습니다.";return,end
            if ~isempty(err),app.VM.Status="조건 비교 오류: "+string(err.message);return,end
            if isempty(data.Measurements),app.VM.Status="비교할 실제 EIS/HPPC 구간이 없습니다. "+join(data.Issues," / ");return,end
            if ~isempty(app.ConditionView)&&isvalid(app.ConditionView),delete(app.ConditionView);end
            vm=uecm.ViewModels.ConditionComparisonViewModel(data);app.ConditionView=uecm.Views.ConditionComparisonView(vm);
            app.VM.Status="조건별 실측·저장 피팅 비교를 열었습니다. 재피팅하지 않았습니다.";
        end
        function onFitComplete(app,bundle,err,cancelled)
            if ~isvalid(app)||app.Closing,return,end
            app.VM.Busy=false;
            if cancelled,app.VM.Status="계산을 취소했습니다. 취소된 실행의 결과는 게시하지 않습니다.";return,end
            if ~isempty(err),app.VM.Status="계산 오류: "+string(err.message);return,end
            app.VM.acceptFit(bundle);
            if ~isvalid(app)||app.Closing,return,end
            if isfield(bundle,'CacheSummary'),app.VM.Status=bundle.CacheSummary;end
            if ~isempty(bundle.Results)
                app.TableTabs.SelectedTab=app.ResultTableTab;app.ExperimentPage=1;
                app.showStage("3d");
            end
        end
        function onProgress(app,data)
            if ~isvalid(app)||app.Closing,return,end
            if iscell(data),data=data{1};end
            app.VM.Status=string(data.Message);
        end
        function onDiagnose(app)
            try,app.VM.diagnose();
            catch ex,app.VM.Status="자료 확인 오류: "+string(ex.message);end
        end
        function onMapEdit(app,e)
            fields=fieldnames(app.VM.Input.Mapping);name=string(e.NewData);
            if name=="(연결 안 함)",name="";end
            app.VM.setMapping(fields{e.Indices(1)},name);
        end
        function onNumeric(app,name,src)
            v=str2double(src.Value);
            if strlength(string(src.Value))>0&&(~isfinite(v)||v<0)
                app.VM.Status="0 이상의 숫자를 넣거나 빈칸으로 두세요.";return,end
            if name=="InitialSOC_pct"&&v>100,app.VM.Status="시작 SOC는 0~100%로 넣어 주세요.";return,end
            app.VM.setOption(name,v);
        end
        function onEISModelsChanged(app)
            names=["RC","2RC","CPE","2CPE"];selected=strings(1,0);
            for name=names
                if app.EISModelChecks.("Model_"+name).Value,selected(end+1)=name;end
            end
            app.VM.setOption('Circuit',"auto");
            app.VM.setOption('EISModels',selected);
            app.VM.setOption('EISAutoWarburg',logical(app.EISWarburgCheck.Value));
            if isempty(selected),app.VM.Status="EIS는 피팅 모델을 하나 이상 체크하세요. HPPC 피팅은 이 선택과 무관합니다.";
            else,app.VM.Status="EIS 계산 모델: "+join(selected,", ")+". 체크한 모델만 피팅합니다.";end
        end
        function syncOptions(app)
            o=app.VM.Settings;defaults=uecm.defaults();app.TypeDD.Value=char(o.Type);app.SignDD.Value=char(o.CurrentSign);
            resolved=uecm.withDefaults(o);families=string(resolved.EISModels);warburg=resolved.EISAutoWarburg;
            if resolved.Circuit~="auto"&&resolved.Circuit~="ZarcL"
                families=erase(string(resolved.Circuit),"+W");warburg=endsWith(string(resolved.Circuit),"+W");
            end
            for name=["RC","2RC","CPE","2CPE"],app.EISModelChecks.("Model_"+name).Value=ismember(name,families);end
            app.EISWarburgCheck.Value=logical(warburg);app.EISOutlierCheck.Value=logical(resolved.EISOutlierFilter);app.EISRepeatCheck.Value=logical(resolved.EISRepeatFilter);
            names=fieldnames(app.OptionControls);
            for k=1:numel(names)
                c=app.OptionControls.(names{k});
                if isfield(o,names{k}),v=o.(names{k});else,v=defaults.(names{k});end
                if isnumeric(v),if isnan(v),c.Value='';else,c.Value=char(string(v));end
                else,if names{k}=="Circuit"&&string(v)=="ZarcL",v="auto";end;c.Value=char(v);end
            end
        end
        function alive=uiCheckpoint(app)
            alive=isvalid(app)&&~app.Closing;if ~alive,return,end
            revision=app.VM.Revision;
            drawnow limitrate
            alive=isvalid(app)&&~app.Closing&&app.VM.Revision==revision;
        end
        function refresh(app)
            if ~isvalid(app)||app.Closing||app.VM.Updating,return,end
            vm=app.VM;revision=vm.Revision;
            if ~isempty(fieldnames(vm.Input))
                T=vm.Input.Data;[~,base,extension]=fileparts(vm.Input.File);app.PathLabel.Text=char(base+extension+" · "+height(T)+"행");app.PathLabel.Tooltip=char(vm.Input.File);
                if isfield(vm.Input,'Files')&&numel(vm.Input.Files)>1
                    app.PathLabel.Text=char(numel(vm.Input.Files)+"개 파일 · "+height(T)+"행");
                    app.PathLabel.Tooltip=char(join(vm.Input.Files,newline));
                end
                app.PreviewTable.Data=T(1:min(500,height(T)),:);
                fields=fieldnames(vm.Input.Mapping);labels=app.mappingLabels(fields);values=strings(numel(fields),1);
                for k=1:numel(fields),values(k)=vm.Input.Mapping.(fields{k});if values(k)=="",values(k)="(연결 안 함)";end,end
                app.MapTable.Data=[cellstr(labels),cellstr(values)];
                app.MapTable.ColumnFormat={'char',[{'(연결 안 함)'},T.Properties.VariableNames]};
            else
                app.PreviewTable.Data=table();app.MapTable.Data=cell(0,2);app.PathLabel.Text='파일을 추가하세요.';app.PathLabel.Tooltip='';
            end
            if isfield(vm.Bundle,'Prepared')
                p=vm.Bundle.Prepared;app.RequestsTable.Data=p.Requests(:,{'Field','Reason','Action','Blocking'});
                app.refreshCoverage(p);
                notes=["분석 종류: "+p.Type;string(p.Notes(:))];
                if isfield(vm.Input,'ImportLog')
                    L=vm.Input.ImportLog;
                    app.ImportLogTable.Data=L;
                    notes(end+1)="폴더 가져오기: "+sum(L.status=="loaded")+"개 읽음 · "+sum(L.status~="loaded")+"개 제외/읽기 실패. 가져오기 내역 탭을 확인하세요.";
                else
                    app.ImportLogTable.Data=table();
                end
                if numel(notes)==1,notes(end+1)="추가 안내 없음";end
                app.NotesArea.Value=cellstr(notes);
            else,app.RequestsTable.Data=table();app.NotesArea.Value={'입력 조건이 바뀌면 이전 결과를 지웁니다. 자료 확인을 다시 눌러 주세요.'};end
            if isfield(vm.Bundle,'Results')&&~isempty(vm.Bundle.Results)
                R=vm.Bundle.Results;
                cols=["fit_id","source_file","domain","model","cell_id","soc_pct","temperature_C","soh_pct","cycle_number","calendar_days","initial_capacity_Ah","current_capacity_Ah","soh_source","fit_status", ...
                    "Rs_Ohm","Rct_Ohm","Cdl_F","Ceff_F","R0_Ohm","R1_Ohm","C1_F","R2_Ohm","C2_F","tau1_s","tau2_s","tau_s","Warburg_sigma_Ohm_s_mhalf","rmse","error_unit"];
                if isfield(vm.Bundle,'CustomAxes'),cols=[cols,string({vm.Bundle.CustomAxes.Field})];end
                cols=cols(ismember(cols,string(R.Properties.VariableNames)));app.ResultsTable.Data=R(:,cols);
                groups=vm.groupChoices(@()app.uiCheckpoint());
                if ~isvalid(app)||app.Closing,return,end
                if vm.Revision~=revision,app.refresh();return,end
                app.updateItems(app.GroupDD,groups);
            else,app.ResultsTable.Data=table();end
            app.refreshAxisChoices();
            if ~isvalid(app)||app.Closing,return,end
            if ~isempty(app.ConditionView)&&isvalid(app.ConditionView)
                app.ConditionView.VM.updateCustomConditions(vm.Bundle);
            end
            app.refreshFitParameterTable();
            if ~isvalid(app)||app.Closing,return,end
            if vm.Revision~=revision,app.refresh();return,end
            app.refreshFileControls();app.refreshAxisChoices();if ~isvalid(app)||app.Closing,return,end;app.renderMap();if ~isvalid(app)||app.Closing,return,end;app.renderResponse();app.renderExperimentGallery();app.renderOverlay();
        end
        function syncStatus(app)
            if ~isvalid(app)||app.Closing,return,end
            app.StatusLabel.Text=char(app.VM.Status);
        end
        function syncBusy(app)
            if ~isvalid(app)||app.Closing,return,end
            on='on';if app.VM.Busy,on='off';end
            for k=1:numel(app.ActionButtons),app.ActionButtons{k}.Enable=on;end
            app.FileSettingsTable.Enable=on;app.FileDD.Enable=on;
            app.TypeDD.Enable=on;app.SignDD.Enable=on;app.MapTable.Enable=on;app.ExampleDD.Enable=on;
            for name=["RC","2RC","CPE","2CPE"],app.EISModelChecks.("Model_"+name).Enable=on;end
            app.EISWarburgCheck.Enable=on;app.EISOutlierCheck.Enable=on;app.EISRepeatCheck.Enable=on;
            names=fieldnames(app.OptionControls);for k=1:numel(names),app.OptionControls.(names{k}).Enable=on;end
        end
        function updateItems(~,dd,items)
            old=string(dd.Value);dd.Items=cellstr(items);
            if ismember(old,items),dd.Value=char(old);else,dd.Value=char(items(1));end
        end
        function refreshMapPlots(app)
            if ~isvalid(app)||app.Closing||app.VM.Updating,return,end
            app.refreshAxisChoices();
            if ~isvalid(app)||app.Closing,return,end
            app.LastAxisY=string(app.YDD.Value);app.renderMap();if ~isvalid(app)||app.Closing,return,end;app.renderOverlay();
        end
        function onMapScope(app)
            app.refreshMapPlots();
        end
        function refreshAxisChoices(app)
            revision=app.VM.Revision;scope=app.VM.SelectedFile;if ~isempty(app.MapScopeDD)&&string(app.MapScopeDD.Value)~="single",scope="*";end
            [fields,labels]=app.VM.availableAxisChoices(scope,@()app.uiCheckpoint());
            if ~isvalid(app)||app.Closing||app.VM.Revision~=revision,return,end
            oldX=string(app.XDD.Value);oldY=string(app.YDD.Value);
            app.XDD.ItemsData={};app.YDD.ItemsData={};
            if isempty(fields)
                app.XDD.Items={'연결된 축 없음'};app.XDD.ItemsData={'none'};app.XDD.Value='none';app.XDD.Enable='off';
            else
                app.XDD.Items=cellstr(labels);app.XDD.ItemsData=cellstr(fields);app.XDD.Enable='on';
                if ismember(oldX,fields),app.XDD.Value=char(oldX);else,app.XDD.Value=char(fields(1));end
            end
            second=fields~=string(app.XDD.Value);yFields=fields(second);yLabels=labels(second);
            app.YDD.Items=cellstr(["없음 (2D)",yLabels]);app.YDD.ItemsData=cellstr(["none",yFields]);
            if ismember(oldY,yFields),app.YDD.Value=char(oldY);else,app.YDD.Value='none';end
            app.YDD.Enable=matlab.lang.OnOffSwitchState(~isempty(yFields));
            parameters=app.VM.parameterChoices(string(app.MapModelDD.Value),scope);oldZ=string(app.ZDD.Value);
            if isempty(parameters)
                app.ZDD.Items={'연결된 파라미터 없음'};app.ZDD.Enable='off';
            else
                app.ZDD.Items=cellstr(parameters);app.ZDD.Enable='on';
                if ismember(oldZ,parameters),app.ZDD.Value=char(oldZ);else,app.ZDD.Value=char(parameters(1));end
            end
            is3=string(app.YDD.Value)~="none";
            app.RotateButton.Enable=matlab.lang.OnOffSwitchState(is3);app.SurfaceCheck.Enable=matlab.lang.OnOffSwitchState(is3);
        end
        function layoutMainVisualization(app)
            if isempty(app.GraphPanel)||isempty(app.OverlayTab),return,end
            if app.Tabs.SelectedTab==app.OverlayTab&&~isempty(app.OverlayExpandCheck)&&app.OverlayExpandCheck.Value
                app.GraphPanel.Visible='off';app.RootGrid.ColumnWidth={220,'1.3x','1x'};
                app.MainContentPanel.Layout.Column=[2,3];
            else
                app.MainContentPanel.Layout.Column=2;app.RootGrid.ColumnWidth={220,'1.3x','1x'};app.GraphPanel.Visible='on';
            end
        end
        function layoutOverlayPlots(app)
            % Hide the absent domain, retaining large live axes and native scrolling.
            present=false(1,2);
            for j=1:2,present(j)=~isempty(app.OverlayAxes{j}.UserData.Files);end
            if ~any(present),present(1)=true;end
            app.OverlayPlotsGrid.ColumnWidth={'1x','1x'};
            for j=1:4
                domain=1+mod(j-1,2);ax=app.OverlayAxes{j};
                ax.Layout.Row=1+(j>2);ax.Layout.Column=domain;
                if present(domain)&&~all(present),ax.Layout.Column=[1,2];end
                ax.FontSize=13;ax.TitleFontSizeMultiplier=1.1;ax.Toolbar.Visible='on';
                if present(domain),ax.Visible='on';else,ax.Visible='off';end
                if present(domain),ax.Interactions=[panInteraction,zoomInteraction,dataTipInteraction];end
            end
            % Flush native layout before making the selected domain visible.
            drawnow limitrate nocallbacks
            for j=1:4
                ax=app.OverlayAxes{j};domain=1+mod(j-1,2);
                if present(domain),ax.Visible='on';else,ax.Visible='off';end
            end
        end
        function renderMap(app)
            if ~isvalid(app)||app.Closing||app.VM.Updating,return,end
            if isempty(app.MapAxes)||~isvalid(app.MapAxes),return,end
            if string(app.MapScopeDD.Value)~="single"
                app.MapSinglePanel.Visible='off';app.MapMultiplePanel.Visible='on';app.renderMultipleMap();return
            end
            app.MapMultiplePanel.Visible='off';app.MapSinglePanel.Visible='on';
            ax=app.MapAxes;
            if app.mapDimension()=="3D"&&isequal(ax.View,[0,90]),app.MapView=[-37.5,30];else,app.MapView=ax.View;end
            cla(ax,'reset');ax.Visible='on';ax.Tag='ParameterMap';legend(ax,'off');app.MapPointCallback=[];
            x=string(app.XDD.Value);y=string(app.YDD.Value);z=string(app.ZDD.Value);
            [R,idx,msg]=app.VM.chartData(x,y,z,string(app.GroupDD.Value),string(app.QualityDD.Value),string(app.MapModelDD.Value),app.mapDimension());
            app.CurrentChartIndices=idx;app.ChartNote.Text=char(msg);
            is3=app.mapDimension()=="3D";
            if is3,view(ax,app.MapView);else,view(ax,2);end
            app.configureMapInteractions();
            if isempty(R),colorbar(ax,'off');title(ax,'표시할 값이 없습니다 · 피팅 결과와 선택한 조건을 확인하세요');return,end
            hold(ax,'on');
            categoricalAxis=false;
            if isfield(app.VM.Bundle,'AxisCategories'),categoricalAxis=any(ismember([x,y],string({app.VM.Bundle.AxisCategories.Field})));end
            if is3&&app.SurfaceCheck.Value&&~categoricalAxis
                [tri,note]=uecm.surfaceMesh(R,x,y,z);app.ChartNote.Text=char(msg+" "+note);
                if ~isempty(tri),patch(ax,'Faces',tri,'Vertices',[R.(x),R.(y),R.(z)],'FaceVertexCData',R.(z),'FaceColor','interp','FaceAlpha',0.35,'HandleVisibility','off','PickableParts','none');end
            end
            if is3,sc=scatter3(ax,R.(x),R.(y),R.(z),60,R.(z),'filled');
            else,sc=scatter(ax,R.(x),R.(z),60,R.(z),'filled');end
            app.MapPointCallback=@(~,e)app.onPoint(e,R,idx,x,y,z);
            if is3
                ylabel(ax,app.axisLabel(y),'Interpreter','none');zlabel(ax,app.axisLabel(z),'Interpreter','none');view(ax,app.MapView);
            else,ylabel(ax,app.axisLabel(z),'Interpreter','none');view(ax,2);end
            if is3,hint=" 마우스 회전 ON: 드래그로 회전 · OFF: 점 선택.";
            else,hint=" Y축 없음: 2D 표시 · 가로축 조건 / 세로축 ECM 값 · 점 선택 가능.";end
            sc.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('fit_id',R.fit_id);
            sc.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('상태',R.fit_status);
            for name=["soc_pct","temperature_C","soh_pct","cycle_number","calendar_days"]
                if ismember(name,string(R.Properties.VariableNames))&&any(isfinite(R.(name)))
                    sc.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow(app.axisLabel(name),R.(name));
                end
            end
            hold(ax,'off');grid(ax,'on');colorbar(ax);xlabel(ax,app.axisLabel(x),'Interpreter','none');
            title(ax,app.mapDimension()+" · 조건별 ECM 추정값");app.ChartNote.Tooltip=char(string(app.ChartNote.Text)+hint);app.ChartNote.Text=char(app.mapDimension()+" · "+height(R)+"개 표시 · 주의 "+sum(R.fit_status=="review")+"개 · 자세한 진단은 마우스를 올려 확인");
            if is3,uecm.applyCategoryTicks(ax,app.VM.Bundle,x,y,z);else,uecm.applyCategoryTicks(ax,app.VM.Bundle,x,z,"");end
            app.configureMapInteractions();
        end
        function renderMultipleMap(app)
            b=app.VM.Bundle;x=string(app.XDD.Value);y=string(app.YDD.Value);z=string(app.ZDD.Value);
            [~,indices,msg]=app.VM.chartData(x,y,z,string(app.GroupDD.Value),string(app.QualityDD.Value),string(app.MapModelDD.Value),app.mapDimension(),"*");
            opts=struct('Model',string(app.MapModelDD.Value),'Filters',app.VM.MapFilters,'Rotate',app.RotateButton.Value,'AxisTag',"MainParameterMap",'LegendLocation',"southoutside",'ContinueFcn',@()app.uiCheckpoint());
            [axesList,shown]=uecm.plotParameterFiles(app.MapMultipleGrid,b,indices,x,y,z,string(app.MapScopeDD.Value),opts);
            if ~isvalid(app)||app.Closing,return,end
            app.MapMultipleAxes=axesList;
            for j=1:numel(axesList)
                ax=axesList{j};xlabel(ax,app.axisLabel(x),'Interpreter','none');
                if y=="none",ylabel(ax,app.axisLabel(z),'Interpreter','none');else,ylabel(ax,app.axisLabel(y),'Interpreter','none');zlabel(ax,app.axisLabel(z),'Interpreter','none');end
            end
            app.CurrentChartIndices=shown;
            app.ChartNote.Text=char(app.mapDimension()+" · "+numel(shown)+"개 표시 · "+string(app.MapScopeDD.Items{find(strcmp(app.MapScopeDD.ItemsData,app.MapScopeDD.Value),1)})+" · 파일별 색상/범례");
            app.ChartNote.Tooltip=char(msg);
        end
        function dimension=mapDimension(app)
            dimension="3D";if string(app.YDD.Value)=="none",dimension="2D";end
        end
        function configureMapInteractions(app)
            if isempty(app.MapAxes)||~isvalid(app.MapAxes),return,end
            isRotate=app.RotateButton.Value&&app.mapDimension()=="3D";
            if string(app.MapScopeDD.Value)~="single"
                for j=1:numel(app.MapMultipleAxes)
                    ax=app.MapMultipleAxes{j};if ~isvalid(ax),continue,end
                    if isRotate,ax.Interactions=[rotateInteraction,zoomInteraction,dataTipInteraction];else,ax.Interactions=[panInteraction,zoomInteraction,dataTipInteraction];end
                end
                return
            end
            ax=app.MapAxes;
            sc=findall(ax,'Type','scatter');
            if isRotate
                ax.Interactions=[rotateInteraction,zoomInteraction,dataTipInteraction];
                for k=1:numel(sc),sc(k).ButtonDownFcn=[];end
            else
                ax.Interactions=[panInteraction,zoomInteraction,dataTipInteraction];
                for k=1:numel(sc),sc(k).ButtonDownFcn=app.MapPointCallback;end
            end
            ax.Toolbar.Visible='on';
        end
        function selectMapPoint(app,index)
            app.VM.selectFit(index);
            if string(app.MapModelDD.Value)~="권장 모델"
                c=uecm.candidatesOf(app.VM.Bundle.Fits{index});pick=find(cellfun(@(a)a.ModelName==string(app.MapModelDD.Value),c),1);
                if ~isempty(pick),app.VM.selectCandidate(pick);end
            end
            app.showStage("comparison");
        end
        function onPoint(app,event,R,idx,x,y,z)
            q=event.IntersectionPoint;
            if y=="none",points=[R.(x),R.(z),zeros(height(R),1)];else,points=[R.(x),R.(y),R.(z)];end;scale=max(max(points,[],1)-min(points,[],1),eps);
            [~,j]=min(sum(((points-q)./scale).^2,2));app.selectMapPoint(idx(j));
        end
        function onResultSelection(app,event)
            if ~isempty(event.Indices),app.VM.selectFit(event.Indices(1,1));end
        end
        function refreshFitParameterTable(app)
            b=app.VM.Bundle;
            app.FitParameterTable.Data=table();
            if ~isfield(b,'Results')||isempty(b.Results)
                app.updateItems(app.MapModelDD,"권장 모델");
                app.PrimaryFitDD.ItemsData=[];app.PrimaryFitDD.Items={'측정 1 없음'};app.PrimaryFitDD.ItemsData=0;
                app.SecondaryFitDD.ItemsData=[];app.SecondaryFitDD.Items={'두 번째 측정 없음'};app.SecondaryFitDD.ItemsData=0;
                return
            end
            R=b.Results;rows=cell(height(R),1);
            for k=1:height(R)
                if mod(k-1,32)==0&&~app.uiCheckpoint(),return,end
                candidates=uecm.candidatesOf(b.Fits{k});identity=table2struct(R(k,:));
                candidateRows=cellfun(@(c)uecm.candidateRow(identity,c),candidates(:),'UniformOutput',false);
                rows{k}=vertcat(candidateRows{:});
            end
            T=struct2table(vertcat(rows{:}));
            app.updateItems(app.MapModelDD,["권장 모델";unique(string(T.model),"stable")]);
            cols=["fit_id","cell_id","test_id","spectrum_id","cell_model","cathode_family","cathode_composition","cell_format","domain","soc_pct","soh_pct","temperature_C","cycle_number","calendar_days","initial_capacity_Ah","current_capacity_Ah","soh_source", ...
                "model","fit_status","R0_Ohm","R1_Ohm","R2_Ohm","C1_F","C2_F","tau_s","tau1_s","tau2_s", ...
                "Rs_Ohm","Rct_Ohm","Cdl_F","Ceff_F","CPE_Q","CPE_alpha","CPE1_Q","CPE2_Q","CPE1_alpha","CPE2_alpha","Ceff1_F","Ceff2_F","L_H","Warburg_sigma_Ohm_s_mhalf","rmse","error_unit","source_file"];
            app.FitParameterTable.Data=T(:,cols(ismember(cols,string(T.Properties.VariableNames))));
            labels=R.fit_id+" · "+R.cell_id+" · "+R.test_id+" · "+R.spectrum_id;
            if isequal(string(app.PrimaryFitDD.Items(:)),labels(:)),return,end
            app.PrimaryFitDD.ItemsData=[];app.PrimaryFitDD.Items=cellstr(labels);app.PrimaryFitDD.ItemsData=1:height(R);
            app.SecondaryFitDD.ItemsData=[];app.SecondaryFitDD.Items=cellstr(["두 번째 측정 없음";labels(:)]);app.SecondaryFitDD.ItemsData=0:height(R);
            app.SecondaryFitDD.Value=0;
        end
        function renderResponse(app)
            if ~isvalid(app)||app.Closing||app.VM.Updating,return,end
            if isempty(app.ResponseAxes)||~isvalid(app.ResponseAxes),return,end
            cla(app.ResponseAxes);cla(app.ProcessAxes,'reset');cla(app.CircuitAxes,'reset');
            legend(app.ProcessAxes,'off');legend(app.ResponseAxes,'off');
            b=app.VM.Bundle;k=app.VM.SelectedFit;
            if ~isfield(b,'Fits')||isempty(b.Fits)||k>numel(b.Fits)
                app.PrimaryConditions.Text='피팅 후 측정을 선택하세요.';app.EISPreprocessingTable.Data=table();
                app.SecondaryCard.Visible='off';app.ComparisonGrid.RowHeight={38,'1x',0};
                app.ComparisonTable.Data=table();app.ProcessScores.Data=table();app.ProcessStartTable.Data=table();
                app.ProcessNotes.Value={'새 입력의 피팅 이력은 아직 없습니다. 자료를 확인하고 다시 계산해 주세요.'};
                app.ComparisonDD.ItemsData=[];app.ComparisonDD.Items={'없음'};app.ComparisonDD.ItemsData=1;app.ComparisonDD.Value=1;return
            end
            app.PrimaryFitDD.Value=k;
            app.PrimaryConditions.Text=char(uecm.measurementBrief(b.Results(k,:)));app.PrimaryConditions.Tooltip='전체 조건·출처·주석은 상세 정보에서 확인하세요.';
            app.PrimaryCard.RowHeight{1}=68;
            f=b.Fits{k};cc=uecm.candidatesOf(f);selected=min(app.VM.SelectedCandidate,numel(cc));
            if isfield(cc{selected},'Preprocessing'),R=cc{selected}.Preprocessing;app.EISPreprocessingTable.Data=R(R.Reason~="used",:);else,app.EISPreprocessingTable.Data=table();end
            app.ComparisonDD.ItemsData=[];app.ComparisonDD.Items=cellfun(@(a)char(a.ModelName),cc,'UniformOutput',false);
            app.ComparisonDD.ItemsData=1:numel(cc);app.ComparisonDD.Value=selected;
            summary="이전 세션에는 다른 후보/반복 이력이 없습니다. 비교하려면 다시 계산하세요.";
            if isfield(f,'ComparisonSummary'),summary=f.ComparisonSummary;end
            if isfield(f,'CandidateScores')
                scores=f.CandidateScores;
                short=["Model","NParameters","RMSE","ErrorUnit","BIC","Status","Recommended"];
                short=short(ismember(short,string(scores.Properties.VariableNames)));
                if isempty(short),app.ProcessScores.Data=scores;else,app.ProcessScores.Data=scores(:,short);end
            end
            uecm.drawCircuit(app.CircuitAxes,cc{selected});
            app.ComparisonTable.Data=app.circuitParameters(cc{selected});
            exclusion="";
            if isfield(f,'ExcludedPositiveImaginary')
                exclusion=" · Im(Z)>0 제외 "+f.ExcludedPositiveImaginary+"점";
            end
            if isfield(f,'ExcludedOutlierCount'),exclusion=exclusion+" · 통계 이상점 제외 "+f.ExcludedOutlierCount+"점";end
            if isfield(f,'ExcludedRepeatCount'),exclusion=exclusion+" · 반복 구간 불안정 제외 "+f.ExcludedRepeatCount+"점";end
            app.ProcessNotes.Value=cellstr(["1. 입력 전체 "+height(b.Prepared.Input.Data)+"행 중 선택한 측정의 "+f.FitPoints+"점을 피팅/비교에 사용했습니다."+exclusion; ...
                "2. 모든 후보가 같은 측정 행·단위·기준전압/가중 조건을 사용했습니다."; ...
                "3. 양의 저항·시정수 제약 아래 여러 초기값으로 최소제곱 피팅했습니다."; ...
                "4. 아래 선은 선택 모델의 최종 최적 시작점에서 기록된 실제 반복 이력입니다. 가상 애니메이션이 아닙니다."; ...
                "5. "+summary]);
            if isfield(f,'KK')
                app.ProcessNotes.Value=[app.ProcessNotes.Value;cellstr("Lin-KK (필터 전 전체 측정, 참고 진단): "+f.KK.Status+" · "+string(f.KK.Reason))];
            end
            logs={};hold(app.ProcessAxes,'on');
            for j=1:numel(cc)
                cand=cc{j};H=cand.History;
                if ~isempty(H)
                    if j==selected
                        best=H(H.Start==cand.BestStart,:);
                        semilogy(app.ProcessAxes,best.Iteration,max(best.ScaledSSE,realmin),'-o','DisplayName',cand.ModelName);
                    end
                    S=cand.StartSummary;S.Model=repmat(cand.ModelName,height(S),1);logs{end+1}=S;
                end
            end
            hold(app.ProcessAxes,'off');set(app.ProcessAxes,'YScale','log');grid(app.ProcessAxes,'on');xlabel(app.ProcessAxes,'실제 최적화 반복 횟수');
            ylabel(app.ProcessAxes,'정규화 잔차 제곱합 (낮을수록 작음)');title(app.ProcessAxes,'피팅 과정 · 선택 모델의 최적화 이력');
            if ~isempty(logs),allStarts=vertcat(logs{:});app.ProcessStartTable.Data=allStarts(:,["Model","Start","InitialScaledSSE","FinalScaledSSE","ExitFlag","Iterations"]);legend(app.ProcessAxes,'show','Location','best');end
            app.renderPair(b,k,selected);
        end
        function renderPair(app,b,k,selected)
            second=app.SecondaryFitDD.Value;
            hasSecond=second>0&&second~=k&&second<=numel(b.Fits);
            sameDomain=false;
            if hasSecond,sameDomain=b.Fits{k}.Domain==b.Fits{second}.Domain;end
            app.OverlayResponseCheck.Enable=matlab.lang.OnOffSwitchState(sameDomain);
            if ~sameDomain,app.OverlayResponseCheck.Value=false;end
            overlay=app.OverlayResponseCheck.Value;
            app.SecondaryCard.Visible=matlab.lang.OnOffSwitchState(hasSecond);
            app.ComparisonGrid.RowHeight={38,'1x',0};
            app.PrimaryCard.RowHeight={68,30,126,'1x'};
            app.ResponseAxes.Visible=matlab.lang.OnOffSwitchState(~overlay);
            if ~overlay,app.plotMeasurements(app.ResponseAxes,b,k,selected);end
            if ~hasSecond,return,end
            app.ComparisonGrid.RowHeight={38,660,660};
            app.SecondaryConditions.Text=char(uecm.measurementBrief(b.Results(second,:)));app.SecondaryConditions.Tooltip='전체 조건·출처·주석은 상세 정보에서 확인하세요.';
            app.SecondaryCard.RowHeight{1}=68;
            if ~sameDomain
                app.SecondaryConditions.Text=char(string(app.SecondaryConditions.Text)+" · EIS와 HPPC는 개별 축으로 표시");
            end
            candidates=uecm.candidatesOf(b.Fits{second});
            previous=app.SecondaryModelDD.Value;
            if ~isequal(app.SecondaryModelDD.UserData,second),previous=1;end
            app.SecondaryModelDD.ItemsData=[];app.SecondaryModelDD.Items=cellfun(@(c)char(c.ModelName),candidates,'UniformOutput',false);
            app.SecondaryModelDD.ItemsData=1:numel(candidates);app.SecondaryModelDD.Value=min(previous,numel(candidates));
            app.SecondaryModelDD.UserData=second;
            candidate=candidates{app.SecondaryModelDD.Value};
            uecm.drawCircuit(app.SecondaryCircuitAxes,candidate);
            app.SecondaryParameters.Data=app.circuitParameters(candidate);
            if overlay
                app.PrimaryCard.RowHeight={68,30,126,0};
                app.ComparisonGrid.RowHeight={38,230,660};
                app.plotMeasurements(app.SecondaryResponseAxes,b,[k,second],[selected,app.SecondaryModelDD.Value]);
            else
                app.plotMeasurements(app.SecondaryResponseAxes,b,second,app.SecondaryModelDD.Value);
            end
        end
        function T=circuitParameters(~,candidate)
            names=string(fieldnames(candidate.Parameters));
            values=cellfun(@(name)candidate.Parameters.(name),cellstr(names));
            keep=isfinite(values);
            names=names(keep);values=values(keep);
            if candidate.Domain=="HPPC"
                names(end+1,1)="Ubase [V]";values(end+1,1)=candidate.Baseline;
            end
            names(end+1,1)="RMSE ["+candidate.ErrorUnit+"]";
            T=table(names,[values;candidate.RMSE],'VariableNames',{'Parameter','EstimatedValue'});
        end
        function label=measurementConditions(app,r)
            label=r.fit_id+" · 셀 "+r.cell_id+" · 시험 "+r.test_id+" · "+r.domain;
            if strlength(r.spectrum_id)>0,label=label+" · "+r.spectrum_id;end
            for field=["cell_model","cathode_family","cathode_composition","cell_format"]
                if ismember(field,string(r.Properties.VariableNames))&&strlength(r.(field))>0
                    label=label+" · "+r.(field);
                end
            end
            extra=uecm.customConditionText(app.VM.Bundle,r);
            if strlength(extra)>0,label=label+newline+extra;end
            values=[r.soc_pct,r.soh_pct,r.temperature_C,r.cycle_number];
            text=compose("%.5g",values);text(~isfinite(values))="미기록";
            label=label+newline+"SOC [%] "+text(1)+" · SOH [%] "+text(2)+" · 온도 [°C] "+text(3)+" · 사이클 "+text(4);
            if ismember('calendar_days',r.Properties.VariableNames)&&isfinite(r.calendar_days)
                label=label+" · 열화 경과일 "+compose("%.5g",r.calendar_days)+" day";
            end
            for field=["initial_capacity_Ah","current_capacity_Ah"]
                if ismember(field,string(r.Properties.VariableNames))&&isfinite(r.(field))
                    label=label+" · "+field+" "+compose("%.5g",r.(field));
                end
            end
        end
        function plotMeasurements(app,ax,b,indices,selected)
            tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;hold(ax,'on');palette=ax.ColorOrder;
            residual=strcmp(app.ResponseModeDD.Value,'잔차');displayData=complex(zeros(0,1));allEIS=true;
            for n=1:numel(indices)
                candidates=uecm.candidatesOf(b.Fits{indices(n)});
                c=candidates{selected(n)};
                ink=palette(n,:);prefix=b.Results.fit_id(indices(n))+" ";
                if c.Domain=="EIS"
                    displayData=[displayData;c.Measured(:);c.Predicted(:)];
                    if residual
                        e=c.Measured-c.Predicted;
                        plot(ax,c.Frequency,real(e),'-','Color',ink,'DisplayName',prefix+c.ModelName+" ΔRe");
                        plot(ax,c.Frequency,imag(e),'--','Color',ink,'DisplayName',prefix+c.ModelName+" ΔIm");
                        ax.XScale='log';xlabel(ax,'주파수 [Hz]');ylabel(ax,'실측 − 모델 [Ω]');
                    else
                        plot(ax,real(c.Measured),-imag(c.Measured),'o','Color',ink,'DisplayName',prefix+"실측");
                        plot(ax,real(c.Predicted),-imag(c.Predicted),'-','LineWidth',1.8,'Color',ink,'DisplayName',prefix+c.ModelName);
                        if app.EISExcludedCheck.Value,uecm.plotExcludedEIS(ax,c,prefix);end
                        xlabel(ax,'Z′ [Ω]');ylabel(ax,'−Z″ [Ω]');
                    end
                else
                    allEIS=false;xlabel(ax,'펄스 시작 기준 시간 [s]');
                    if residual
                        plot(ax,c.Time,c.Measured-c.Predicted,'-','Color',ink,'DisplayName',prefix+c.ModelName);
                        ylabel(ax,'실측 − 모델 [V]');
                    else
                        plot(ax,c.Time,c.Measured,'o','MarkerSize',3,'Color',ink,'DisplayName',prefix+"실측");
                        plot(ax,c.Time,c.Predicted,'-','LineWidth',1.8,'Color',ink,'DisplayName',prefix+c.ModelName);
                        ylabel(ax,'전압 [V]');
                    end
                end
            end
            hold(ax,'off');grid(ax,'on');legend(ax,'show','Location','best','Interpreter','none');
            if allEIS&&~residual&&~isempty(displayData)&&~app.EISFullRangeCheck.Value
                uecm.zoomNyquist(ax,displayData);
            end
            if residual,title(ax,'선택 모델 잔차');else,title(ax,'실측 · 선택 모델 피팅');end
        end
        function text=axisLabel(app,name)
            if startsWith(string(name),"custom_"),text=char(app.VM.conditionAxisLabel(name));return,end
            switch name
                case 'soc_pct',text='SOC · 남은 충전량 [%]';case 'temperature_C',text='온도 [°C]';
                case 'soh_pct',text='SOH · 건강 상태 [%]';case 'cycle_number',text='사이클 수';case 'calendar_days',text='열화 경과일 [day]';
                otherwise,text=strrep(char(name),'_',' ');
            end
        end
        function onCustomAxisTemplate(app)
            if app.VM.Busy,return,end
            if ~isfield(app.VM.Bundle,'Results')||isempty(app.VM.Bundle.Results),uialert(app.UIFigure,'먼저 피팅을 실행하세요.','추가 변수');return,end
            [name,folder]=uiputfile('*.csv','측정 키와 추가 변수 입력용 CSV 저장','custom_conditions.csv');if isequal(name,0),return,end
            try
                R=app.VM.Bundle.Results;keys=["fit_id","source_file","source_id","cell_id","test_id","spectrum_id"];
                keys=keys(ismember(keys,string(R.Properties.VariableNames)));T=R(:,keys);T.new_variable=nan(height(T),1);writetable(T,fullfile(folder,name));
                app.VM.Status="추가 변수 키 템플릿 저장 완료. new_variable 열 이름과 값을 바꿔 가져오세요. 키는 수정하지 마세요.";
            catch ex,uialert(app.UIFigure,ex.message,'CSV 저장 오류');end
        end
        function onCustomAxisImport(app)
            if app.VM.Busy,return,end
            if ~isfield(app.VM.Bundle,'Results')||isempty(app.VM.Bundle.Results),uialert(app.UIFigure,'먼저 피팅을 실행하세요.','추가 변수');return,end
            try
                file=string(app.FileDD.Value);
                if file=="none"||strlength(file)==0,error('uecm:SelectedVariables','파일 목록에서 변수를 가져올 파일을 선택하세요.');end
                app.VM.Busy=true;app.VM.Status="현재 선택 파일의 변수 열을 확인하고 있습니다.";
                app.startBackground('CustomAxisTask',app.VM.Bundle,file,app.VM.Revision);
            catch ex,app.VM.Busy=false;uialert(app.UIFigure,ex.message,'선택 파일 변수 확인 오류');end
        end
        function onCustomConditionsRead(app,result,err,cancelled)
            if ~isvalid(app)||app.Closing,return,end
            app.VM.Busy=false;
            if cancelled,app.VM.Status="추가 조건 가져오기를 취소했습니다.";return,end
            if ~isempty(err),uialert(app.UIFigure,err.message,'추가 조건 읽기 오류');return,end
            try
                if app.VM.Revision~=result.Revision||string(app.VM.SelectedFile)~=result.Context.SelectedFile
                    app.VM.Status="결과 또는 선택 파일이 변경됐습니다. ‘변수 추가하기’를 다시 눌러 주세요.";return
                end
                app.showVariablePicker(result.Table,result.File,result.ColumnInfo,result.Context);
            catch ex,uialert(app.UIFigure,ex.message,'추가 변수 연결 오류');end
        end
        function onNormalizedSave(app)
            if isempty(fieldnames(app.VM.Input)),app.VM.Status="파일을 먼저 불러오세요.";return,end
            parent=uigetdir(pwd,'정제 데이터 CSV를 담을 상위 폴더 선택');
            if isequal(parent,0),return,end
            app.exportNormalizedTo(string(parent));
        end
        function onNormalizedSaved(app,folder,err,cancelled)
            if ~isvalid(app)||app.Closing,return,end
            app.VM.Busy=false;
            if cancelled,app.VM.Status="CSV 저장을 취소했습니다. _INCOMPLETE.txt가 있는 폴더는 사용하지 마세요.";return,end
            if ~isempty(err),app.VM.Status="정제 CSV 저장 오류: "+string(err.message);return,end
            app.VM.Status="표준 CSV 저장 완료: "+string(folder)+" · export_log.csv에서 보류 항목을 확인하세요.";
        end
        function onSave(app)
            parent=uigetdir(pwd,'결과를 담을 상위 폴더 고르기');if isequal(parent,0),return,end
            try,app.exportTo(string(parent));catch ex,app.VM.Busy=false;app.VM.Status="저장 시작 실패: "+string(ex.message);end
        end
        function onSaved(app,folder,err,cancelled)
            if ~isvalid(app)||app.Closing,return,end
            app.VM.Busy=false;
            if cancelled,app.VM.Status="저장을 취소했습니다. 불완전한 새 폴더가 남아 있을 수 있습니다.";return,end
            if ~isempty(err),app.VM.Status="저장 오류: "+string(err.message);return,end
            try
                if string(app.MapScopeDD.Value)=="single",exportgraphics(app.MapAxes,fullfile(folder,'current_3D.png'),'Resolution',160);
                else,for j=1:numel(app.MapMultipleAxes),exportgraphics(app.MapMultipleAxes{j},fullfile(folder,"current_map_"+j+".png"),'Resolution',200);end;end
                if isfield(app.VM.Bundle,'Fits')&&~isempty(app.VM.Bundle.Fits)
                    responseAxes=app.ResponseAxes;
                    if app.OverlayResponseCheck.Value,responseAxes=app.SecondaryResponseAxes;end
                    exportgraphics(responseAxes,fullfile(folder,'selected_response.png'),'Resolution',160);
                    exportgraphics(app.ProcessAxes,fullfile(folder,'fitting_history.png'),'Resolution',160);
                    exportgraphics(app.CircuitAxes,fullfile(folder,'selected_ECM.png'),'Resolution',160);
                end
                if ~isempty(app.OverlayChosenFiles)
                    if string(app.OverlayModeDD.Value)=="응답·잔차"
                        labels=["eis_response","hppc_response","eis_residual","hppc_residual"];
                        for j=1:4,exportgraphics(app.OverlayAxes{j},fullfile(folder,"overlay_"+labels(j)+".png"),'Resolution',160);end
                    else
                        if isempty(app.OverlayParameterAxesList),app.OverlayParameterAxesList={app.OverlayParameterAxes};end
                        for j=1:numel(app.OverlayParameterAxesList),exportgraphics(app.OverlayParameterAxesList{j},fullfile(folder,"overlay_parameters_"+j+".png"),'Resolution',200);end
                    end
                end
                app.VM.Status="저장 완료: "+string(folder);
            catch ex,app.VM.Status="표·세션은 저장됐지만 그림 저장 오류: "+string(ex.message);end
        end
        function s=viewSettings(app)
            s=struct('MapFilters',app.VM.MapFilters,'X',string(app.XDD.Value),'Y',string(app.YDD.Value),'Z',string(app.ZDD.Value), ...
                'Group',string(app.GroupDD.Value),'Quality',string(app.QualityDD.Value),'Surface',app.SurfaceCheck.Value, ...
                'PlotDimension',app.mapDimension(),'CameraView',app.MapAxes.View,'Rotate',app.RotateButton.Value, ...
                'SelectedFit',app.VM.SelectedFit,'SelectedCandidate',app.VM.SelectedCandidate,'MapModel',string(app.MapModelDD.Value), ...
                'OverlayIndices',find(app.OverlaySelection),'OverlayFiles',app.selectedOverlayFiles(),'OverlayShowModels',app.OverlayModelsCheck.Value, ...
                'ExpandOverlay',app.OverlayExpandCheck.Value,'MapFileScope',string(app.MapScopeDD.Value),'OverlayLayout',string(app.OverlayLayoutDD.Value),'OverlayMode',string(app.OverlayModeDD.Value),'FileGraphMode',string(app.FileGraphMetricDD.Value), ...
                'OverlayDataEnabled',app.OverlayDataEnabled,'OverlayMeasuredEnabled',app.OverlayMeasuredEnabled, ...
                'OverlayModelSelection',app.OverlayModelSelection);
        end
        function onHelp(~)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            web(fullfile(root,'START_HERE_ko.html'),'-browser');
        end
        function cleanupBackground(app)
            names=["LoadTask","FitTask","SaveTask","NormalizeSaveTask","CustomAxisTask","ConditionTask"];
            futures=cell(1,numel(names));
            for k=1:numel(names)
                task=app.(names(k));futures{k}=task.Future;
                task.Generation=task.Generation+1;task.StopRequested=true;task.Running=false;
                task.Future=[];task.Queue=[];task.CompleteFcn=[];task.ProgressFcn=[];
                app.(names(k))=task;
            end
            messages=uecm.cancelForClose(futures);
            for k=1:numel(messages),fprintf(2,'ECM shutdown cancellation: %s\n',messages(k));end
            if ~isempty(app.VM)&&isvalid(app.VM),app.VM.Busy=false;end
        end
    end

    methods (Access=private)

        function startBackground(app, taskName, varargin)
        % startBackground  Launch a background task. Pass task arguments after the name.
        %   app.startBackground('TaskName', arg1, arg2, ...)
            if ~isvalid(app)||app.Closing,return,end
            task = app.(taskName);
            if task.Running
                error('Background work is already running. Cancel it first.');
            end
            task.Running = true;
            task.StopRequested = false;
            task.Generation = task.Generation + 1;
            generation = task.Generation;
            nOut = max(0, nargout(task.Fcn));
            if ~isempty(task.ProgressFcn)
                task.Queue = parallel.pool.DataQueue;
                afterEach(task.Queue, @(d) app.safeProgress(taskName, d, generation));
                queue = task.Queue;
                sendProgress = @(data) send(queue, struct(Type="Progress", Data={data}));
                task.Future = parfeval(backgroundPool, task.Fcn, nOut, varargin{:}, sendProgress);
                afterAll(task.Future, @(~) send(queue, struct(Type="Finished")), 0, 'PassFuture', true);
            else
                task.Future = parfeval(backgroundPool, task.Fcn, nOut, varargin{:});
                afterAll(task.Future, @(f) app.handleBackgroundComplete(taskName, f, generation), 0, 'PassFuture', true);
            end
            app.(taskName) = task;
        end

        function cancelBackground(app, taskName)
        % cancelBackground  Cancel a running background task (no-op if idle).
            task = app.(taskName);
            hadFuture = ~isempty(task.Future);
            task.StopRequested = true;
            task.Running = false;
            app.(taskName) = task;
            if hadFuture
                cancel(task.Future);
            end
        end

        function handleBackgroundComplete(app, taskName, future, generation)
        % handleBackgroundComplete  Routes results/errors to the task's CompleteFcn.
            if ~isvalid(app)||app.Closing; return; end
            task = app.(taskName);
            if generation ~= task.Generation; return; end
            task.Running = false;
            task.Future = [];
            task.Queue = [];
            app.(taskName) = task;
            wasCancelled = task.StopRequested || ...
                (~isempty(future.Error) && ...
                 strcmp(future.Error.identifier, "parallel:fevalqueue:ExecutionCancelled"));
            try
                if wasCancelled
                    task.CompleteFcn([], [], true);
                elseif ~isempty(future.Error)
                    task.CompleteFcn([], future.Error, false);
                else
                    nOut = max(0, nargout(task.Fcn));
                    if nOut == 0
                        task.CompleteFcn([], [], false);
                    elseif nOut == 1
                        task.CompleteFcn(fetchOutputs(future), [], false);
                    else
                        results = cell(1, nOut);
                        [results{:}] = fetchOutputs(future);
                        task.CompleteFcn(results, [], false);
                    end
                end
            catch cbErr
                fprintf(2, 'Error in CompleteFcn for task ''%s'': %s\n', taskName, cbErr.getReport());
                if isvalid(app)&&~app.Closing&&isgraphics(app.UIFigure)
                    uialert(app.UIFigure, cbErr.message, 'Background Task Error');
                end
            end
        end

        function safeProgress(app, taskName, msg, generation)
        % safeProgress  Wraps progress callbacks so errors appear in Command Window.
            if ~isvalid(app)||app.Closing; return; end
            task = app.(taskName);
            if generation ~= task.Generation; return; end
            if msg.Type == "Progress"
                if ~task.Running; return; end
                if isempty(task.ProgressFcn); return; end
                try
                    task.ProgressFcn(msg.Data);
                catch bgErr
                    fprintf(2, 'Progress callback error (disabling): %s\n', bgErr.getReport());
                    task.ProgressFcn = [];
                    app.(taskName) = task;
                end
            else
                app.handleBackgroundComplete(taskName, task.Future, generation);
            end
        end
    end
end
