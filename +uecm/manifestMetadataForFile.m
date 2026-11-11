function [metadataFile,sidecars]=manifestMetadataForFile(file)
%MANIFESTMETADATAFORFILE Find only an explicitly paired conditions file.
% Walk upward from a signal file and use a manifest row whose signal_file
% resolves to that exact file. Never guess from neighboring filenames.
arguments
    file (1,1) string
end
metadataFile="";sidecars=strings(0,1);
if contains(file,"#uecm_sheet=")
    file=extractBefore(file,"#uecm_sheet=");
end
[ok,info]=fileattrib(char(file));
if ~ok,return,end
signalPath=string(info.Name);
folder=string(fileparts(signalPath));
while strlength(folder)>0
    manifest=fullfile(folder,"manifest.csv");
    if isfile(manifest)
        try
            M=readtable(manifest,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
            required=["signal_file","conditions_file"];
            if all(ismember(required,string(M.Properties.VariableNames)))
                for k=1:height(M)
                    signalEntry=strip(string(M.signal_file(k)));
                    conditionEntry=strip(string(M.conditions_file(k)));
                    if ismissing(signalEntry)||strlength(signalEntry)==0||ismissing(conditionEntry)||strlength(conditionEntry)==0
                        continue
                    end
                    candidateSignal=resolveManifestPath(folder,signalEntry);
                    [signalOK,signalInfo]=fileattrib(char(candidateSignal));
                    if ~signalOK||string(signalInfo.Name)~=signalPath,continue,end
                    candidateConditions=resolveManifestPath(folder,conditionEntry);
                    [conditionsOK,conditionsInfo]=fileattrib(char(candidateConditions));
                    if conditionsOK
                        metadataFile=string(conditionsInfo.Name);
                        sidecars=[metadataFile;string(manifest)];
                        for field=["cells_file","provenance_file"]
                            if ~ismember(field,string(M.Properties.VariableNames)),continue,end
                            entry=strip(string(M.(field)(k)));
                            if ismissing(entry)||strlength(entry)==0,continue,end
                            [valid,detail]=fileattrib(char(resolveManifestPath(folder,entry)));
                            if valid,sidecars(end+1,1)=string(detail.Name);end
                        end
                        return
                    end
                end
            end
        catch
            % Ignore unrelated or malformed manifests and continue upward.
        end
    end
    parent=string(fileparts(folder));
    if parent==folder,break,end
    folder=parent;
end
end

function path=resolveManifestPath(base,entry)
% Resolve relative manifest entries against the manifest directory, not pwd.
if startsWith(entry,string(filesep)) || (ispc && ~isempty(regexp(char(entry),'^[A-Za-z]:[\\/]|^\\\\','once')))
    path=entry;
else
    path=fullfile(base,entry);
end
end
