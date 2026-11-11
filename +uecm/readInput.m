function input=readInput(file,settings,metadataFile)
%READINPUT Read CSV/TSV/TXT/Excel while retaining source columns and explicit IDs.
arguments
 file (1,1) string
 settings (1,1) struct = uecm.defaults()
 metadataFile (1,1) string = ""
end
settings=uecm.withDefaults(settings);inputKey=file;
if ~isfile(file)&&contains(file,"#uecm_sheet=")
    physical=extractBefore(file,"#uecm_sheet=");
    if isfile(physical)
        settings.Sheet=extractAfter(file,"#uecm_sheet=");file=physical;
    end
end
if ~isfile(file),error('uecm:File','파일을 찾을 수 없습니다: %s',file);end
if metadataFile=="",metadataFile=uecm.manifestMetadataForFile(file);end
[~,~,ext]=fileparts(file);ext=lower(ext);
if ~ismember(ext,[".csv",".txt",".tsv",".xlsx",".xls",".mpt",".dta",".mat"])
 error('uecm:Format','CSV·TSV·TXT·XLSX·XLS·MAT·EC-Lab .mpt·Gamry .dta를 지원합니다. EC-Lab .mpr 같은 이진 파일은 텍스트로 내보내 주세요.');
end
mode=string(settings.ImportMode);
if ~ismember(mode,["auto","raw","template"])
    error('uecm:ImportMode','입력 방식은 raw 또는 template이어야 합니다.');
end
tableFormat=ismember(ext,[".csv",".txt",".tsv",".xlsx",".xls"]);
if mode=="template"&&~tableFormat
    error('uecm:ImportMode','정리된 템플릿은 CSV·TXT·TSV·Excel 형식으로 선택하세요. 장비 MAT·MPT·DTA는 원시 데이터를 선택하세요.');
end
useRaw=mode=="raw";
if mode=="auto",useRaw=~tableFormat||~isTemplateTable(file,settings);end
if useRaw
 [T,raw]=uecm.readRaw(file,settings);
 [settings,applied]=applySuggested(settings,raw.Suggested);raw.Applied=applied;
 if raw.Kind=="HPPC"
     [T,screening]=uecm.cleanImportedTimeSeries(T,settings);
     raw.Hints=[raw.Hints(:);screening(:)];
 end
 mapping=signalMapping(T.Properties.VariableNames);
 if isfield(settings,'Mapping')
  keys=fieldnames(settings.Mapping);
  for k=1:numel(keys),mapping.(keys{k})=string(settings.Mapping.(keys{k}));end
 end
 validateRequestedType(mapping,settings.Type);
 format=struct('Delimiter',"",'DecimalSeparator',".",'Sheet',"",'RawProfile',raw.Profile);
 input=struct('Data',T,'File',inputKey,'SourceFile',file,'SourceSheet',string(settings.Sheet),'Mapping',mapping,'Settings',settings, ...
  'Metadata',table(),'MetadataFile',metadataFile,'Synthetic',false,'ImportFormat',format,'RawReport',raw);
 if ismember('synthetic',T.Properties.VariableNames),input.Synthetic=any(ismember(lower(string(T.synthetic)),["true","1"]));end
 if metadataFile~=""
  if ~isfile(metadataFile),error('uecm:Metadata','조건표 파일을 찾을 수 없습니다.');end
  [mi,metaFormat]=tableOptions(metadataFile,settings,true);
  mi=textIdentifiers(mi,uecm.inferMapping(mi.VariableNames));
  input.Metadata=readtable(metadataFile,mi);input.MetadataImportFormat=metaFormat;
 end
 return
end
[io,format]=tableOptions(file,settings,false);
mapping=signalMapping(io.VariableNames);
if isfield(settings,'Mapping')
 keys=fieldnames(settings.Mapping);
 for k=1:numel(keys),mapping.(keys{k})=string(settings.Mapping.(keys{k}));end
end
if mode=="template",validateRequestedType(mapping,settings.Type);end
io=textIdentifiers(io,mapping);
T=readtable(file,io);
profileNotes=strings(0,1);
if mode=="auto",[T,profileNotes]=uecm.applyResearchProfile(T,file);end
if ~isempty(profileNotes)
    mapping=signalMapping(T.Properties.VariableNames);
    fields=fieldnames(settings.Mapping);
    for j=1:numel(fields),mapping.(fields{j})=string(settings.Mapping.(fields{j}));end
end
validateRequestedType(mapping,settings.Type);
input=struct('Data',T,'File',inputKey,'SourceFile',file,'SourceSheet',string(settings.Sheet),'Mapping',mapping,'Settings',settings, ...
 'Metadata',table(),'MetadataFile',metadataFile,'Synthetic',false,'ImportFormat',format);
if ~isempty(profileNotes)
    input.RawReport=struct('Profile',"research_defined_table",'Hints',profileNotes, ...
        'Requests',strings(0,1),'Mapping',table(strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
        'VariableNames',{'role','source_column','unit','note'}),'Applied',strings(0,1));
end
if metadataFile~=""
 if ~isfile(metadataFile),error('uecm:Metadata','조건표 파일을 찾을 수 없습니다.');end
 [mi,metaFormat]=tableOptions(metadataFile,settings,true);
 mi=textIdentifiers(mi,uecm.inferMapping(mi.VariableNames));
 input.Metadata=readtable(metadataFile,mi);input.MetadataImportFormat=metaFormat;
end
if ismember('synthetic',T.Properties.VariableNames)
 input.Synthetic=any(ismember(lower(string(T.synthetic)),["true","1"]));
end
end
function io=textIdentifiers(io,mapping)
for field=["source","cell","test","spectrum"]
 name=mapping.(field);
 if strlength(name)>0&&ismember(name,string(io.VariableNames)),io=setvartype(io,name,'string');end
end
desc=intersect(["cell_model","cathode_family","cathode_composition","cell_format"],string(io.VariableNames));
if ~isempty(desc),io=setvartype(io,desc,'string');end
end
function [io,format]=tableOptions(file,settings,isMetadata)
[~,~,ext]=fileparts(file);args={'VariableNamingRule','preserve','TextType','string'};
format=struct('Delimiter',"",'DecimalSeparator',".",'Sheet',"");
if ismember(lower(ext),[".xlsx",".xls"])
 sheet=option(settings,'Sheet',"");
 if isMetadata,sheet=option(settings,'MetadataSheet',"");end
 if strlength(string(sheet))==0
  names=sheetnames(file);
  if numel(names)~=1,error('uecm:Sheet','여러 Excel 시트가 있습니다. 사용할 시트를 선택하거나 Settings.Sheet/MetadataSheet에 이름을 지정하세요.');end
  sheet=names(1);
 end
 args=[args,{'Sheet',sheet}];format.Sheet=string(sheet);
else
 delimiter=option(settings,'Delimiter',"auto");
 if string(delimiter)=="auto"
  if strcmpi(ext,'.tsv'),delimiter=sprintf('\t');else,delimiter=detectDelimiter(file);end
 elseif string(delimiter)=="tab",delimiter=sprintf('\t');end
 decimal=option(settings,'DecimalSeparator',".");
 if ~ismember(string(decimal),[".",","]),error('uecm:DecimalSeparator','소수점 구분자는 . 또는 ,를 지정하세요.');end
 args=[args,{'Delimiter',char(delimiter),'DecimalSeparator',char(decimal)}];
 format.Delimiter=string(delimiter);format.DecimalSeparator=string(decimal);
end
io=detectImportOptions(file,args{:});
end
function delimiter=detectDelimiter(file)
% Score only explicit delimiter candidates using the header, never path-like IDs.
fid=fopen(file,'r','n','UTF-8');if fid<0,error('uecm:File','파일을 열 수 없습니다.');end
cleanup=onCleanup(@()fclose(fid));line=fgetl(fid);
if ~ischar(line),delimiter=',';return,end
line=erase(string(line),char(65279));tokens={',',';',sprintf('\t')};scores=zeros(1,3);
for k=1:3
 names=split(line,tokens{k});m=uecm.inferMapping(names);fields=struct2cell(m);
 scores(k)=sum(strlength(string(fields))>0)*100+min(numel(names)-1,50);
end
[best,pick]=max(scores);
if best<1,error('uecm:Delimiter','표의 구분자를 확인할 수 없습니다. 쉼표·세미콜론·탭 형식 또는 단위·추가 정보의 구분자 설정을 사용하세요.');end
delimiter=tokens{pick};
end
function value=option(settings,name,fallback)
value=fallback;if isfield(settings,name),value=settings.(name);end
end
function tf=isTemplateTable(file,settings)
% Tidy table = first line already names the signals AND has as many fields as the first data line.
% ("Time,ClimaTemp, °C,...,I, A" maps but splits units into extra fields -> raw reader.)
[~,~,ext]=fileparts(file);ext=lower(ext);tf=false;
if ismember(ext,[".xlsx",".xls"])
 try
  names=sheetnames(file);sheet=option(settings,'Sheet',"");
  if strlength(string(sheet))==0
      if numel(names)>1,return,end
      sheet=names(1);
  end
  % A failed header read used to be swallowed and routed to the template reader, so the SAME file could take
  % different paths on different runs (Kiel hold-out, cloud-synced folder, 2026-11-08). Now: retry once, then raw.
  for attempt=1:2
   try
    head=readcell(file,'Sheet',sheet,'Range','1:2');
    if isempty(head)||any(cellfun(@(x)isnumeric(x)&&~isempty(x)&&~isnan(x),head(1,:))),return,end   % headerless numbers
    h=head(1,:);h(cellfun(@(x)isa(x,'missing'),h))={''};   % blank header cells (Zhu 2022) were <missing>
    m=uecm.inferMapping(string(h));tf=hasSignals(m);
    return
   catch ex
    if attempt==1,pause(1);continue,end
    warning('uecm:HeaderRead','엑셀 머리말을 읽지 못해 원시 변환기로 처리합니다(%s): %s',file,ex.message);
    tf=false;
   end
  end
 catch ex
  warning('uecm:HeaderRead','엑셀 시트 목록을 읽지 못해 원시 변환기로 처리합니다(%s): %s',file,ex.message);
  tf=false;
 end
 return
end
fid=fopen(file,'r','n','UTF-8');if fid<0,return,end
c=onCleanup(@()fclose(fid));l1=fgetl(fid);
while ischar(l1)&&strlength(strtrim(string(l1)))==0,l1=fgetl(fid);end
l2=fgetl(fid);
if ~ischar(l1)||~ischar(l2),return,end
l1=erase(string(l1),char(65279));l2=string(l2);
for d=[",",";",sprintf('\t')]
 h=split(l1,d);r=split(l2,d);
 if numel(h)<2,continue,end
 if strlength(strtrim(h(end)))==0,h(end)=[];end
 if strlength(strtrim(r(end)))==0&&numel(r)>numel(h),r(end)=[];end
 if hasSignals(uecm.inferMapping(strtrim(h)))&&numel(h)==numel(r),tf=true;return,end
end
end
function tf=hasSignals(m)
has=@(f)isfield(m,f)&&strlength(m.(f))>0;
tf=(has('time')&&has('current')&&has('voltage'))||(has('frequency')&&(has('real')||has('magnitude'))) ...
    ||(has('source')&&has('current')&&has('voltage'));   % template with IDs but no time column: prepare asks for time
end
function [settings,applied]=applySuggested(settings,suggested)
% Apply raw-profile/data suggestions ONLY where the user left the default; every change is reported.
applied=strings(0,1);d=uecm.defaults();
if ~isstruct(suggested),return,end
f=fieldnames(suggested);
for k=1:numel(f)
 name=f{k};value=suggested.(name);
 if ~isfield(d,name),continue,end
 current=d.(name);if isfield(settings,name),current=settings.(name);end
 untouched=isequal(current,d.(name))||(isnumeric(current)&&isscalar(current)&&isnan(current)&&isnumeric(d.(name))&&isnan(d.(name)));
 if untouched
  settings.(name)=value;applied(end+1)=name+" = "+string(value); %#ok<AGROW>
 end
end
end


function m=signalMapping(names)
m=uecm.inferMapping(names);
% EIS acquisition time is auxiliary when no current/voltage signal is present.
if strlength(m.frequency)>0&&(strlength(m.real)>0||strlength(m.magnitude)>0) ...
        &&strlength(m.current)==0&&strlength(m.voltage)==0
    m.time="";
end
end

function validateRequestedType(mapping,type)
has=@(name)strlength(mapping.(name))>0;
if string(type)=="EIS"
    valid=has('frequency')&&((has('real')&&has('imag'))||(has('magnitude')&&has('phase')));
    required="주파수와 실수부·허수부 또는 임피던스 크기·위상";
elseif string(type)=="HPPC"
    valid=has('time')&&has('current')&&has('voltage');
    required="시간·전류·전압";
else
    return
end
if ~valid
    error('uecm:InputType','선택한 %s 입력에 필요한 %s 열을 찾지 못했습니다. 입력 방식과 열 이름·구조를 확인하세요.',type,required);
end
end
