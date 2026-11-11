function candidates=candidatesOf(fit)
%CANDIDATESOF Also read old v0.1 sessions without inventing absent alternatives.
if isfield(fit,'Alternatives'),candidates=fit.Alternatives;else,candidates={fit};end
for k=1:numel(candidates)
    c=candidates{k};
    if ~isfield(c,'ModelName')
        c.ModelName="1RC";if contains(c.Candidate,'Zarc'),c.ModelName="ZarcL";end
    end
    if ~isfield(c,'History'),c.History=table();c.StartSummary=table();c.BestStart=1;end
    candidates{k}=c;
end
end
