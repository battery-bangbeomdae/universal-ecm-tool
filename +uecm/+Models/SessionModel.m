classdef SessionModel < handle
    properties (SetObservable)
        Input = struct()
        Bundle = struct()
    end
    methods
        function obj=SessionModel()
        end
    end
    methods (Static)
        function input=loadFile(file,settings,metadataFile,sendProgress)
            arguments
                file (:,1) string
                settings (1,1) struct
                metadataFile (1,1) string
                sendProgress (1,1) function_handle = @(~)[]
            end
            if ~isempty(file)&&all(isfolder(file)),input=uecm.readFolder(file,settings,sendProgress);return,end
            if numel(file)>1,input=uecm.readInputs(file,settings,metadataFile);return,end
            [~,~,extension]=fileparts(file);
            if ismember(lower(extension),[".xlsx",".xls"])&&strlength(settings.Sheet)==0
                input=uecm.readInputs(file,settings,metadataFile);return
            end
            if extension==".mat"
                variables=whos('-file',file);
                if ~ismember('bundle',string({variables.name}))
                    input=uecm.readInput(file,settings,metadataFile);return
                end
                names={'bundle'};if ismember('viewSettings',string({variables.name})),names{end+1}='viewSettings';end
                saved=load(file,names{:});
                if ~isfield(saved,'bundle')||~isfield(saved.bundle,'Prepared')||~isfield(saved.bundle,'Version')
                    error('uecm:Session','이 도구로 저장한 session.mat 파일이 아닙니다.');
                end
                vs=struct();if isfield(saved,'viewSettings'),vs=saved.viewSettings;end
                input=struct('SavedSession',true,'Bundle',saved.bundle,'ViewSettings',vs);
            else,input=uecm.readInput(file,settings,metadataFile);end
        end
        function result=loadWorkspace(files,settings,meta,current,bundle,mode,sendProgress)
            if nargin<7,sendProgress=@(~)[];end
            result=uecm.workspaceLoad(files,settings,meta,current,bundle,mode,sendProgress);
        end
        function result=fitWorkspace(input,bundle,sendProgress)
            result=uecm.workspaceFit(input,bundle,true,sendProgress);
        end
        function result=readCustomConditions(file)
            info=dir(file);if isempty(info)||info.bytes>20e6,error('uecm:CustomAxis','20MB 이하의 측정별 조건 CSV를 사용하세요.');end
            opts=detectImportOptions(file,'VariableNamingRule','preserve','TextType','string');
            ids=["fit_id","measurement_id","source_id","source_file","cell_id","test_id","spectrum_id"];
            ids=ids(ismember(ids,string(opts.VariableNames)));if ~isempty(ids),opts=setvartype(opts,cellstr(ids),'string');end
            M=readtable(file,opts);result=struct('File',string(file),'Table',M,'ColumnInfo',uecm.variableColumnInfo(M));
        end
        function result=conditionComparison(input,prepared,bundle)
            if nargin<3,bundle=struct();end
            if isempty(fieldnames(prepared)),prepared=uecm.prepare(input);end
            result=uecm.conditionComparisonData(prepared);result=uecm.attachComparisonResults(result,bundle);
        end
        function result=fit(input,prepared,sendProgress)
            arguments
                input (1,1) struct
                prepared (1,1) struct
                sendProgress (1,1) function_handle
            end
            result=uecm.analyze(input,sendProgress,prepared);
        end
        function result=saveResults(bundle,parent,viewSettings)
            result=uecm.exportBundle(bundle,parent,viewSettings);
        end
    end
end
