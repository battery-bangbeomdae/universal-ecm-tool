function [Summary, Files] = validate_holdout(holdoutRoot, opts)
%VALIDATE_HOLDOUT Independent (hold-out) validation of the raw-data conversion on files NOT used in development.
%
%   [Summary,Files] = validate_holdout("D:\holdout")
%   [Summary,Files] = validate_holdout("D:\holdout", struct('RelTol',1e-9,'Settings',uecm.defaults()))
%
% Folder layout (one sub-folder per dataset):
%   <holdoutRoot>\<dataset>\raw\*.*              instrument exports exactly as the instrument wrote them
%   <holdoutRoot>\<dataset>\reference\<stem>.csv  OPTIONAL independent reference for raw file <stem>.<ext>
%       HPPC columns : time_s, current_A (DISCHARGE positive), voltage_V
%       EIS  columns : frequency_Hz, real_ohm, imag_ohm (SIGNED Im, capacitive < 0), optional spectrum_id
%       The reference must come from a source independent of this tool (instrument software export,
%       another reader). Row order must match the converted data (event rows without I/U excluded).
%
% Each file is classified (no human input; every Blocking request counts as a stop):
%   정상 변환   finished without Blocking AND every compared signal max relative error <= RelTol
%               AND row count / spectrum count match the reference
%   안전 실패   error or Blocking request: the tool stopped instead of producing values
%   조용한 오류 finished without Blocking BUT values / sign / units / spectrum split differ from the reference
%   기준 없음   finished without Blocking, no reference file -> not counted as correct
%
% Relative error = max|x - ref| / max(max|ref|, eps). 1.1e-13 (Warwick) is an OBSERVED result, not a tolerance:
% text exports cannot be matched beyond their printed digits, so RelTol is an option (default 1e-9).
%
% Output: table printed in the Command Window and saved as holdout_results_<yyyyMMdd_HHmmss>.csv (summary)
% and holdout_files_<...>.csv (per file) in holdoutRoot. The code version (SHA-256 of +uecm\*.m) is recorded.
% If an earlier run on the same dataset used a DIFFERENT code version, this run is labelled '재검증'
% (re-validation after code changes is not an independent validation).
arguments
    holdoutRoot (1,1) string
    opts (1,1) struct = struct()
end
if ~isfolder(holdoutRoot),error('uecm:Holdout','검증 폴더를 찾을 수 없습니다: %s',holdoutRoot);end
toolRoot=string(fileparts(mfilename('fullpath')));addpath(toolRoot);
if ~isfield(opts,'RelTol'),opts.RelTol=1e-9;end
if ~isfield(opts,'Settings'),opts.Settings=uecm.defaults();end
codeHash=hashCode(fullfile(toolRoot,'+uecm'));
stamp=string(datetime('now','Format','yyyyMMdd_HHmmss'));

d=dir(holdoutRoot);d=d([d.isdir]&~startsWith({d.name},'.'));
rows={};
for k=1:numel(d)
    ds=string(d(k).name);rawDir=fullfile(holdoutRoot,ds,"raw");
    if ~isfolder(rawDir),continue,end
    f=dir(rawDir);f=f(~[f.isdir]);
    for j=1:numel(f)
        rows{end+1,1}=checkOne(ds,string(fullfile(f(j).folder,f(j).name)),fullfile(holdoutRoot,ds,"reference"),opts); %#ok<AGROW>
        fprintf('[%s] %-40s %s\n',ds,f(j).name,rows{end}.category);
    end
end
if isempty(rows),error('uecm:Holdout','%s 아래에 <데이터셋>\\raw 폴더가 없습니다.',holdoutRoot);end
Files=struct2table(vertcat(rows{:}));
Files.code_hash=repmat(codeHash,height(Files),1);

% ---- summary per dataset
cats=["정상 변환","안전 실패","조용한 오류","기준 없음"];vars=["n_ok","n_safe_fail","n_silent","n_no_ref"];
G=unique(Files.dataset);Summary=table();
for k=1:numel(G)
    r=Files.dataset==G(k);s=table(G(k),nnz(r),'VariableNames',{'dataset','files'});
    for c=1:numel(cats),s.(vars(c))=nnz(r&Files.category==cats(c));end
    s.pct_ok=100*s.n_ok/s.files;s.pct_safe_fail=100*s.n_safe_fail/s.files;s.pct_silent=100*s.n_silent/s.files;
    for sig=["time","current","voltage","frequency","real","imag"]
        v=Files.("relerr_"+sig)(r);s.("max_relerr_"+sig)=maxOrNaN(v);
    end
    s.label=labelFor(holdoutRoot,G(k),codeHash);
    Summary=[Summary;s]; %#ok<AGROW>
end
Summary.code_hash=repmat(codeHash,height(Summary),1);
Summary.rel_tol=repmat(opts.RelTol,height(Summary),1);

fprintf('\n=== 독립 검증 요약 (RelTol = %g, 코드 버전 %s) ===\n',opts.RelTol,codeHash);
disp(Summary(:,["dataset","files","n_ok","n_safe_fail","n_silent","n_no_ref","pct_ok","pct_silent", ...
    "max_relerr_time","max_relerr_current","max_relerr_voltage","max_relerr_frequency","max_relerr_real","max_relerr_imag","label"]));
if any(Summary.n_silent>0)
    fprintf(2,'조용한 오류 %d건: holdout_files_%s.csv 의 reason 열을 확인하세요.\n',sum(Summary.n_silent),stamp);
end
try
    writetable(Summary,fullfile(holdoutRoot,"holdout_results_"+stamp+".csv"),'Encoding','UTF-8');
    writetable(Files,fullfile(holdoutRoot,"holdout_files_"+stamp+".csv"),'Encoding','UTF-8');
catch ex
    warning('uecm:HoldoutWrite','결과 CSV를 저장하지 못했습니다: %s',ex.message);
end
end

% ======================================================================= one file
function r=checkOne(ds,file,refDir,opts)
[~,stem]=fileparts(file);
r=struct('dataset',ds,'file',string(stem),'kind',"",'category',"",'reason',"",'blocking',"", ...
    'rows',NaN,'ref_rows',NaN,'spectra',NaN,'ref_spectra',NaN, ...
    'relerr_time',NaN,'relerr_current',NaN,'relerr_voltage',NaN,'relerr_frequency',NaN,'relerr_real',NaN,'relerr_imag',NaN);
try
    p=uecm.prepare(uecm.readInput(file,opts.Settings));
catch ex
    r.category="안전 실패";r.reason="오류: "+string(ex.message);return
end
r.kind=string(p.Type);D=p.Data;r.rows=height(D);
if p.Blocked
    b=p.Requests(p.Requests.Blocking,:);
    r.category="안전 실패";r.blocking=join(unique(b.Field),", ");r.reason=join(unique(b.Reason)," / ");return
end
refFile=fullfile(refDir,stem+".csv");
if ~isfile(refFile),r.category="기준 없음";r.reason="reference\"+stem+".csv 없음";return,end
Ref=readtable(refFile,'VariableNamingRule','preserve','TextType','string');
problems=strings(0,1);
if r.kind=="HPPC"
    pairs=["time","time_s";"current","current_A";"voltage","voltage_V"];
elseif r.kind=="EIS"
    pairs=["frequency","frequency_Hz";"real","real_ohm";"imag","imag_ohm"];
    if ismember("spectrum_id",string(Ref.Properties.VariableNames))
        r.ref_spectra=numel(unique(string(Ref.spectrum_id)));
        r.spectra=numel(unique(string(D.source)+"|"+string(D.cell)+"|"+string(D.test)+"|"+string(D.spectrum)));
        if r.spectra~=r.ref_spectra,problems(end+1)="스펙트럼 수 "+r.spectra+" ≠ 기준 "+r.ref_spectra;end
    end
else
    r.category="안전 실패";r.reason="분석 종류를 정하지 못함: "+r.kind;return
end
r.ref_rows=height(Ref);
if r.rows~=r.ref_rows
    problems(end+1)="행 수 "+r.rows+" ≠ 기준 "+r.ref_rows;
else
    for q=1:size(pairs,1)
        sig=pairs(q,1);col=pairs(q,2);
        if ~ismember(col,string(Ref.Properties.VariableNames)),problems(end+1)="기준에 "+col+" 열 없음";continue,end
        if ~ismember(sig,string(D.Properties.VariableNames)),problems(end+1)="변환 결과에 "+sig+" 없음";continue,end
        x=double(D.(sig));ref=double(Ref.(col));
        if any(isnan(x)~=isnan(ref)),problems(end+1)=sig+": 결측 위치 불일치";end
        ok=isfinite(x)&isfinite(ref);
        e=max(abs(x(ok)-ref(ok)))/max(max(abs(ref(ok))),eps);if isempty(e),e=NaN;end
        r.("relerr_"+sig)=e;
        if ~(e<=opts.RelTol)
            % a pure sign flip is reported explicitly (the most dangerous silent error)
            if any(ok)&&max(abs(x(ok)+ref(ok)))/max(max(abs(ref(ok))),eps)<=opts.RelTol
                problems(end+1)=sig+": 부호 반전";
            else
                problems(end+1)=sig+": 최대 상대오차 "+sprintf('%.3g',e);
            end
        end
    end
end
if isempty(problems),r.category="정상 변환";else,r.category="조용한 오류";r.reason=join(problems," / ");end
end

% ======================================================================= helpers
function v=maxOrNaN(x)
x=x(isfinite(x));if isempty(x),v=NaN;else,v=max(x);end
end

function h=hashCode(folder)
% Code-version fingerprint without Java (R2026b ships no JVM): CRC-32 of every +uecm .m file (sorted by
% relative path), then CRC-32 of that list. Not a security hash; it only tells code versions apart.
f=dir(fullfile(folder,'**','*.m'));full=string(fullfile({f.folder},{f.name}));[full,o]=sort(full);f=f(o);
tbl=crcTable();parts=strings(numel(f),1);
for k=1:numel(f)
    fid=fopen(full(k),'r');b=fread(fid,Inf,'*uint8');fclose(fid);
    parts(k)=extractAfter(full(k),strlength(string(folder)))+":"+string(dec2hex(crc32(b,tbl),8));
end
h=lower(string(dec2hex(crc32(unicode2native(char(join(parts,newline)),'UTF-8'),tbl),8)))+"-"+numel(f)+"files";
end

function c=crc32(b,tbl)
c=uint32(4294967295);b=uint32(b(:));
for i=1:numel(b),c=bitxor(tbl(bitand(bitxor(c,b(i)),uint32(255))+1),bitshift(c,-8));end
c=bitxor(c,uint32(4294967295));
end

function t=crcTable()
t=zeros(256,1,'uint32');
for n=0:255
    c=uint32(n);
    for k=1:8
        if bitand(c,uint32(1)),c=bitxor(uint32(3988292384),bitshift(c,-1));else,c=bitshift(c,-1);end
    end
    t(n+1)=c;
end
end

function lab=labelFor(root,ds,codeHash)
% '독립 검증' on the first code version that met this dataset; '재검증' if an earlier run used another version.
lab="독립 검증";
old=dir(fullfile(root,'holdout_results_*.csv'));
for k=1:numel(old)
    try
        P=readtable(fullfile(old(k).folder,old(k).name),'TextType','string');
        hit=P.dataset==ds;
        if any(hit)&&any(P.code_hash(hit)~=codeHash),lab="재검증";return,end
    catch
    end
end
end
