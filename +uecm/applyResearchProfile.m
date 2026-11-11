function [T,notes]=applyResearchProfile(T,file)
%APPLYRESEARCHPROFILE Scoped, documented column definitions for unitless exports.
notes=strings(0,1);
root=fileparts(fileparts(mfilename('fullpath')));
registry=jsondecode(fileread(fullfile(root,'config','research_profiles.json')));
for k=1:numel(registry.profiles)
    profile=registry.profiles(k);
    if isempty(regexp(char(file),profile.path_regex,'once')),continue,end
    columns=profile.columns;names=string(T.Properties.VariableNames);
    for j=1:numel(columns)
        hit=find(names==string(columns(j).source),1);
        if isempty(hit),continue,end
        names(hit)=string(columns(j).target);
        notes(end+1)=string(columns(j).source)+" → "+string(columns(j).target);
    end
    T.Properties.VariableNames=cellstr(names);
    if strlength(string(profile.soc_source))>0&&ismember(string(profile.soc_source),names)
        key=str2double(string(T.(profile.soc_source)));
        [found,idx]=ismember(key,profile.soc_codes);
        soc=nan(height(T),1);soc(found)=profile.soc_values(idx(found));
        T.soc_pct=soc;
    end
    notes(end+1)="연구 정의 "+string(profile.id)+" · "+string(profile.evidence);
end
end
