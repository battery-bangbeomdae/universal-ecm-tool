function data=plotFileErrors(ax,bundle,file,mode)
%PLOTFILEERRORS Show file-level fit errors only when results are available.
[scores,overall]=uecm.fileErrorSummary(bundle,file);
if isempty(scores)
    tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;
    title(ax,'피팅 후 오차를 표시합니다.');
    data=struct('Note',"피팅 후 RMSE와 잔차를 확인할 수 있습니다.",'FitIndices',[]);
    return
end
tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;hold(ax,'on');
[~,name,ext]=fileparts(file);
if ismember(string(mode),["RMSE","RMSE 누적분포"])
    data=struct('FitIndices',unique(scores.fit_index,'stable'));
    scores=scores(isfinite(scores.rmse),:);
    if isempty(scores)
        title(ax,'유효한 RMSE가 없습니다.');hold(ax,'off');
        data.Note="유효한 RMSE가 없습니다.";return
    end
    [groups,model,unit]=findgroups(scores.model,scores.error_unit);
    n=zeros(numel(model),1);average=n;medianRMSE=n;p95=n;maximum=n;
    spread=n;minimum=n;mae=n;maxPoint=n;pooled=n;worst=strings(size(n));
    edges=linspace(0,max(max(scores.rmse),eps),min(20,max(5,ceil(sqrt(numel(unique(scores.fit_index))))))+1);
    counts=zeros(numel(model),numel(edges)-1);
    cumulative=string(mode)=="RMSE 누적분포";
    for j=1:numel(model)
        rows=scores(groups==j,:);values=sort(rows.rmse);
        n(j)=numel(values);average(j)=mean(values);medianRMSE(j)=median(values);
        minimum(j)=values(1);spread(j)=std(values);p95(j)=prctile(values,95);
        [maximum(j),k]=max(rows.rmse);worst(j)=rows.fit_id(k);
        mae(j)=sum(rows.mae.*rows.n_points)/sum(rows.n_points);
        pooled(j)=sqrt(sum(rows.rmse.^2.*rows.n_points)/sum(rows.n_points));
        maxPoint(j)=max(rows.max_abs_error);
        counts(j,:)=histcounts(values,edges);
        if cumulative
            stairs(ax,[0;values],[0;(1:n(j))'/n(j)*100], ...
                'LineWidth',1.8,'DisplayName',model(j),'Tag','FileRMSE');
        end
    end
    if ~cumulative
        centers=(edges(1:end-1)+edges(2:end))/2;
        bars=bar(ax,centers,counts.','grouped','FaceColor','flat','EdgeColor','none');
        palette=ax.ColorOrder;
        for j=1:numel(bars)
            bars(j).CData=repmat(palette(1+mod(j-1,size(palette,1)),:),numel(centers),1);
            bars(j).DisplayName=model(j);bars(j).Tag='FileRMSE';
        end
        xlim(ax,edges([1,end]));
    end
    data.Statistics=table(model,unit,n,minimum,average,medianRMSE,spread,p95,maximum,worst,pooled,mae,maxPoint, ...
        'VariableNames',{'Model','Unit','N','MinRMSE','MeanRMSE','MedianRMSE','StdRMSE','P95RMSE','MaxRMSE', ...
        'MaxRMSE_FitID','PooledRMSE','PointMAE','MaxPointError'});
    nBins=numel(edges)-1;
    data.Bins=table(reshape(repelem(model,nBins),[],1),reshape(repelem(unit,nBins),[],1), ...
        repmat(edges(1:end-1)',numel(model),1),repmat(edges(2:end)',numel(model),1), ...
        reshape(counts.',[],1),reshape((100*counts./n).',[],1), ...
        'VariableNames',{'Model','Unit','LowerRMSE','UpperRMSE','Count','Percent'});
    xlabel(ax,"RMSE ["+overall.ErrorUnit+"]");
    if cumulative
        ylim(ax,[0,105]);ylabel(ax,'누적 측정 비율 [%]');
        title(ax,name+ext+" · 모델별 RMSE 누적분포",'Interpreter','none');
    else
        ylabel(ax,'구간별 측정 건수');
        title(ax,name+ext+" · 모델별 RMSE 구간 분포",'Interpreter','none');
    end
    data.Note="스윕·펄스별 RMSE 집계. PooledRMSE·PointMAE·MaxPointError는 피팅에 사용한 점 단위입니다.";
    hold(ax,'off');grid(ax,'on');legend(ax,'show','Location','best','Interpreter','none');
    ax.UserData=struct('SourceFile',string(file),'FitIndices',data.FitIndices, ...
        'OverallRMSE',overall.RMSE,'ErrorUnit',overall.ErrorUnit,'Mode',string(mode));
    return
else
    data=uecm.filePlotData(bundle,file);
    T=data.Data;
    if data.Domain=="EIS"
        e=complex(T.real,T.imag)-data.Prediction;
        [x,y]=uecm.segmentPlotRows(T.frequency,real(e),data.Breaks);semilogx(ax,x,y,'DisplayName','실측−모델 Re','Tag','FileResidual');
        [x,y]=uecm.segmentPlotRows(T.frequency,imag(e),data.Breaks);semilogx(ax,x,y,'--','DisplayName','실측−모델 Im','Tag','FileResidual');
        ax.XScale='log';xlabel(ax,'주파수 [Hz]');
    else
        [x,y]=uecm.segmentPlotRows(T.time,T.voltage-data.Prediction,data.Breaks);
        plot(ax,x,y,'DisplayName','실측−모델 전압','Tag','FileResidual');xlabel(ax,'원본 경과 시간 [s]');
    end
    uecm.scaleResidualAxes(ax);ylabel(ax,"잔차 ["+overall.ErrorUnit+"]");yline(ax,0,':','HandleVisibility','off');
    title(ax,name+ext+" · 권장 모델 잔차",'Interpreter','none');
end
hold(ax,'off');grid(ax,'on');legend(ax,'show','Location','best','Interpreter','none');
ax.Tag=tag;ax.UserData=struct('SourceFile',string(file),'Domain',data.Domain, ...
    'FitIndices',data.FitIndices,'OriginalRows',data.OriginalRows,'OverallRMSE',overall.RMSE,'ErrorUnit',overall.ErrorUnit,'Mode',string(mode));
data.Note="권장 모델의 피팅점 가중 RMSE = "+compose('%.5g',overall.RMSE)+" "+overall.ErrorUnit+" · "+overall.NData+"개 데이터 / "+overall.NPoints+"점 · 피팅 오차";
end
