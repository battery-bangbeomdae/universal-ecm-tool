function types=eisFitTypes(settings)
%EISFITTYPES Resolve only requested EIS families, preserving old Circuit settings.
o=uecm.withDefaults(settings);allowed=["RC","2RC","CPE","2CPE"];
choice=string(o.Circuit);
if choice~="auto"&&choice~="ZarcL"
    families=erase(choice,"+W");useW=endsWith(choice,"+W");
else
    families=string(o.EISModels);useW=logical(o.EISAutoWarburg);
end
if isempty(families)||any(~ismember(families,allowed))
    error('uecm:EISModels','EIS 피팅 모델을 하나 이상 선택하세요: 1RC, 2RC, 1CPE, 2CPE.');
end
families=allowed(ismember(allowed,families));types=strings(1,0);
for family=families
    types(end+1)=family; %#ok<AGROW>
    if useW,types(end+1)=family+"+W";end %#ok<AGROW>
end
end
