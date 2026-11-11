function fit = solveFit(residual, starts, lower, upper)
%SOLVEFIT Deterministic bounded multistart, with REAL iteration/multistart logs.
arguments
    residual (1,1) function_handle
    starts double
    lower double
    upper double
end
best=Inf;fit=struct('x',[],'residual',[],'exitflag',-1,'solver',"",'condition',Inf,'boundary',true);
history=zeros(0,3);summary=cell(0,1);currentStart=0;
useLS=exist('lsqnonlin','file')>0&&license('test','Optimization_Toolbox');
for k=1:size(starts,1)
    currentStart=k;x0=max(lower+1e-7,min(upper-1e-7,starts(k,:)));
    r0=residual(x0);if any(~isfinite(r0)),continue,end
    if useLS
        opts=optimoptions('lsqnonlin','Display','off','MaxFunctionEvaluations',1600, ...
            'FunctionTolerance',1e-11,'StepTolerance',1e-10,'OutputFcn',@recordIteration);
        [x,~,r,flag,out]=lsqnonlin(residual,x0,lower,upper,opts);solver="lsqnonlin";
    else
        obj=@(x)boundedObjective(x,residual,lower,upper);
        [x,~,flag,out]=fminsearch(obj,x0,optimset('Display','off','MaxFunEvals',3000, ...
            'MaxIter',1800,'TolX',1e-8,'TolFun',1e-12,'OutputFcn',@recordIteration));
        r=residual(x);solver="fminsearch_bounded_penalty";
    end
    score=sum(r.^2);summary{end+1,1}=struct('Start',k,'InitialScaledSSE',sum(r0.^2), ...
        'FinalScaledSSE',score,'ExitFlag',flag,'Iterations',out.iterations, ...
        'InitialCoordinates',join(compose('%.8g',x0),','),'FinalCoordinates',join(compose('%.8g',x),',')); %#ok<AGROW>
    if isfinite(score)&&score<best
        best=score;fit.x=x;fit.residual=r;fit.exitflag=flag;fit.solver=solver;fit.BestStart=k;
    end
end
if isempty(fit.x),error('uecm:Fit','유한한 피팅 결과를 얻지 못했습니다.');end
J=zeros(numel(fit.residual),numel(fit.x));
for j=1:numel(fit.x)
    dx=1e-5*(1+abs(fit.x(j)));xp=fit.x;xm=xp;xp(j)=xp(j)+dx;xm(j)=xm(j)-dx;
    J(:,j)=(residual(xp)-residual(xm))/(2*dx);
end
s=svd(J,0);if ~isempty(s)&&s(end)>0,fit.condition=s(1)/s(end);end
fit.boundary=any(fit.x-lower<1e-4|upper-fit.x<1e-4);fit.rmse=sqrt(mean(fit.residual.^2));
fit.History=array2table(history,'VariableNames',{'Start','Iteration','ScaledSSE'});
fit.StartSummary=struct2table(vertcat(summary{:}));
    function stop=recordIteration(~,values,state)
        stop=false;
        if strcmp(state,'init')||strcmp(state,'iter')
            if isfield(values,'resnorm'),sse=values.resnorm;else,sse=values.fval;end
            history(end+1,:)=[currentStart,values.iteration,sse];
        end
    end
end
function v=boundedObjective(x,f,lo,hi)
if any(~isfinite(x))||any(x<lo)||any(x>hi)
    v=1e8+sum((max(lo-x,0)+max(x-hi,0)).^2);return
end
r=f(x);v=sum(r.^2);if ~isfinite(v),v=realmax/100;end
end
