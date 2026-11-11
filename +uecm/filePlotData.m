function data=filePlotData(bundle,file)
%FILEPLOTDATA Full normalized original file, with predictions at original rows.
file=string(file);p=[];offset=0;
if isfield(bundle,'Prepared')
    prepared=bundle.Prepared;
    if isfield(prepared,'FilePrepared')
        for k=1:numel(prepared.FilePrepared)
            q=prepared.FilePrepared{k};
            if string(q.Input.File)==file,p=q;break,end
            offset=offset+height(q.Input.Data);
        end
    elseif string(prepared.Input.File)==file,p=prepared;end
end
data=struct('File',file,'Domain',"unknown",'Data',table(),'Prediction',[], ...
    'Breaks',false(0,1),'FitIndices',[],'OriginalRows',0,'CurrentSign',"unknown",'Note',"자료 확인을 먼저 실행하세요.");
if isempty(p),return,end
data.Domain=p.Type;T=p.Data;n=height(T);data.Data=T;data.OriginalRows=n;
data.CurrentSign=string(p.Input.Settings.CurrentSign);data.Prediction=nan(n,1);
if p.Type=="EIS",data.Prediction=complex(data.Prediction,data.Prediction);end
key=T.source+char(31)+T.cell+char(31)+T.test+char(31)+T.spectrum;
data.Breaks=[false;key(2:end)~=key(1:end-1)];
if p.Type=="HPPC"&&ismember('time',T.Properties.VariableNames)
    data.Breaks=data.Breaks|[false;diff(T.time)<=0];
end
if isfield(bundle,'Fits')
    for k=1:numel(bundle.Fits)
        f=bundle.Fits{k};if string(f.SourceFile)~=file,continue,end
        rows=f.SourceRows-offset;
        valid=rows>=1&rows<=n;
        data.Prediction(rows(valid))=f.Predicted(valid);
        data.FitIndices(end+1)=k;
    end
end
data.Note="전체 "+n+"행 · 피팅 "+numel(data.FitIndices)+"개. 다른 시험/시간 재시작 사이에는 선을 끊습니다.";
if isempty(data.FitIndices),data.Note=data.Note+" 피팅 전/보류 상태에서도 원본 신호를 표시합니다.";end
if data.Domain=="HPPC"&&data.CurrentSign=="unknown",data.Note=data.Note+" 전류 부호 미확인: 원본 부호로 표시합니다.";end
if p.Blocked,data.Note=data.Note+" 입력 보류 이유는 진단에서 확인하세요.";end
end
