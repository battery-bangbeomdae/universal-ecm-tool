function plotExperiment(ax,rx,fit)
%PLOTEXPERIMENT One independent experiment per pair of axes.
cc=uecm.candidatesOf(fit);hold(ax,'on');hold(rx,'on');
if fit.Domain=="EIS"
    plot(ax,real(fit.Measured),-imag(fit.Measured),'o','DisplayName','측정');
    uecm.plotExcludedEIS(ax,fit); 
    for k=1:numel(cc)
        c=cc{k};plot(ax,real(c.Predicted),-imag(c.Predicted),'DisplayName',c.ModelName);
        e=c.Measured-c.Predicted;
        semilogx(rx,c.Frequency,real(e),'DisplayName',c.ModelName+" Re");
        semilogx(rx,c.Frequency,imag(e),'--','DisplayName',c.ModelName+" Im");
    end
    xlabel(ax,"Z′ [Ω]");ylabel(ax,"−Z″ [Ω]");xlabel(rx,"주파수 [Hz]");ylabel(rx,"잔차 [Ω]");rx.XScale='log';
else
    plot(ax,fit.Time,fit.Measured,'DisplayName','측정');
    for k=1:numel(cc)
        c=cc{k};plot(ax,c.Time,c.Predicted,'DisplayName',c.ModelName);
        plot(rx,c.Time,c.Measured-c.Predicted,'DisplayName',c.ModelName);
    end
    xlabel(ax,"펄스 시작부터 시간 [s]");ylabel(ax,"전압 [V]");xlabel(rx,"시간 [s]");ylabel(rx,"잔차 [V]");
end
hold(ax,'off');hold(rx,'off');grid(ax,'on');grid(rx,'on');legend(ax,'show','Location','best');
title(ax,fit.Domain+" · "+fit.Status+" · RMSE "+compose('%.4g',fit.RMSE)+" "+fit.ErrorUnit,'Interpreter','none');
end
