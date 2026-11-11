function text = methodsSummary(bundle, outFile)
%METHODSSUMMARY Write the data-processing record of one analysis as Markdown (draft for a report/paper Methods section).
%   txt = uecm.methodsSummary(bundle)                       % bundle from uecm.analyze
%   uecm.methodsSummary(bundle, "methods_summary_ko.md")     % also writes the file (UTF-8)
% Everything listed is READ from the bundle (files, instrument profile, unit/sign conversions, screening and
% sign decisions, fitted models, KK check, open requests, code fingerprint). Nothing is inferred or invented, so
% a reviewer can reproduce the numbers; the researcher only edits wording. Reduces the hours spent reconstructing
% "what exactly was done to the raw data" when writing up.
arguments
    bundle (1,1) struct
    outFile string = ""
end
p=bundle.Prepared;in=p.Input;L=strings(0,1);
L(end+1)="# 데이터 처리 기록 (자동 생성)";L(end+1)="";
L(end+1)="- 생성: "+string(datetime('now','TimeZone','Asia/Seoul','Format','yyyy-MM-dd HH:mm'))+" (Asia/Seoul)";
ver="";if isfield(bundle,'Version'),ver=string(bundle.Version);end
fp="(계산 실패)";try,fp=uecm.codeFingerprint();catch,end
L(end+1)="- 도구: Universal ECM Tool "+ver+", 코드 지문 `"+fp+"`";
status="unreported";if isfield(bundle,'Status'),status=string(bundle.Status);end
L(end+1)="- 분석 종류: "+string(p.Type)+", 상태: "+status;
L(end+1)="";L(end+1)="## 1. 입력 자료";
files=unique(string(in.File));if isfield(in,'OriginalInputs'),files=unique(string(cellfun(@(x)string(x.File),in.OriginalInputs,'UniformOutput',false)));end
files=files(:);shown=strings(0,1);for f=files(1:min(10,end))',shown(end+1)="`"+name(f)+"`";end %#ok<AGROW>
L(end+1)="- 파일 "+numel(files)+"개: "+join(shown,", ")+ifelse(numel(files)>10," 외","");
if isfield(in,'RawReport')
    r=in.RawReport;
    L(end+1)="- 장비 형식(자동 판정): "+string(r.Profile)+", 측정 종류 "+string(r.Kind);
    if isfield(r,'Mapping')&&istable(r.Mapping)&&~isempty(r.Mapping)
        M=r.Mapping(strlength(string(r.Mapping.role))>0&~startsWith(string(r.Mapping.role),"("),:);
        if ~isempty(M),L(end+1)="- 열 연결: "+join(string(M.source_column)+" → "+string(M.role),"; ");end
    end
    if isfield(r,'Applied')&&~isempty(r.Applied),L(end+1)="- 자동 적용 설정: "+join(string(r.Applied),"; ");end
    if isfield(r,'Hints')&&~isempty(r.Hints),L(end+1)="- 변환기 기록: "+join(unique(string(r.Hints),'stable')," / ");end
end
L(end+1)="- 측정 행 수(전처리 후): "+height(p.Data);
L(end+1)="";L(end+1)="## 2. 단위·부호 변환";
C=p.Conversions;
if isempty(C),L(end+1)="- 단위 변환 없음(내부 표준 단위 그대로).";
else
    for k=1:numel(C)
        L(end+1)="- "+string(C(k).Field)+": `"+string(C(k).SourceColumn)+"` "+string(C(k).SourceUnit)+" × "+string(C(k).Factor)+" → "+string(C(k).OutputUnit); %#ok<AGROW>
    end
end
L(end+1)="- 내부 표준: 주파수 Hz, 임피던스 Ω, 허수부 부호 있음(용량성 < 0), 시간 s, 전류 A.";
if ~isempty(p.Notes),L(end+1)="";L(end+1)="## 3. 전처리 판단 기록";for n=reshape(unique(string(p.Notes(:)),'stable'),1,[]),L(end+1)="- "+n;end,end %#ok<AGROW> row/column-safe: notes grown by end+1 from 0x1 become a ROW
R=bundle.Results;
L(end+1)="";L(end+1)="## 4. 모델 추정";
if isempty(R),L(end+1)="- 추정 결과 없음.";
else
    if ismember('model',R.Properties.VariableNames),L(end+1)="- 추정 "+height(R)+"건, 선택 모델: "+join(countLabel(string(R.model)),", ");
    else,L(end+1)="- 결과 "+height(R)+"건, 모델 이름은 미기록.";end
    if ismember('fit_status',R.Properties.VariableNames),L(end+1)="- 적합 상태: "+join(countLabel(string(R.fit_status)),", ");end
    if ismember('relative_error',R.Properties.VariableNames)&&any(isfinite(R.relative_error))
        L(end+1)=sprintf("- 상대 오차 중앙값 %.3g%% (최대 %.3g%%)",100*median(R.relative_error,'omitnan'),100*max(R.relative_error));
    end
    L(end+1)="- 검증 방식: 학습 적합 오차만 보고(별도 검증 자료 없음). 후보 모델은 같은 자료로 비교 후 선택.";
    if ismember('kk_status',R.Properties.VariableNames)&&any(strlength(R.kk_status)>0)
        k=R.kk_status(strlength(R.kk_status)>0);
        L(end+1)=sprintf("- Kramers–Kronig(Lin-KK) 검사: %s; 잔차 최대 %.2f%%.",join(countLabel(string(k)),", "),100*max(R.kk_max_residual,[],'omitnan'));
    end
end
Q=p.Requests;
if ~isempty(Q),L(end+1)="";L(end+1)="## 5. 남은 확인 요청";
    for k=1:height(Q),L(end+1)="- ["+ifelse(Q.Blocking(k),"차단","주의")+"] "+string(Q.Field(k))+": "+string(Q.Reason(k));end %#ok<AGROW>
end
L(end+1)="";L(end+1)="> 이 기록은 결과 묶음에서 읽은 사실만 담습니다. 연구 목적·시료 정보는 연구자가 덧붙여 주세요.";
text=join(L,newline);
if strlength(outFile)>0
    fid=fopen(outFile,'w','n','UTF-8');if fid<0,error('uecm:Output','기록 파일을 쓸 수 없습니다: %s',outFile);end
    fwrite(fid,unicode2native(char(text),'UTF-8'));fclose(fid);
end
end
function s=name(f)
[~,a,b]=fileparts(f);s=string(a)+string(b);
end
function c=countLabel(v)
[u,~,j]=unique(v);n=accumarray(j,1);c=u+" "+n+"건";
end
function out=ifelse(c,a,b)
if c,out=a;else,out=b;end
end
