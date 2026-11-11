function paths=workspacePaths()
%WORKSPACEPATHS Resolve application/data roots after installation inside YJ or ECM.
app=string(fileparts(fileparts(mfilename('fullpath'))));candidate=app;workspace=fileparts(app);
while strlength(candidate)>0
 if isfolder(fullfile(candidate,'gh','data')),workspace=candidate;break,end
 parent=string(fileparts(candidate));if parent==candidate,break,end;candidate=parent;
end
paths=struct('AppRoot',app,'WorkspaceRoot',workspace,'GHRoot',string(fullfile(workspace,'gh')), ...
 'CompleteDatasets',string(fullfile(workspace,'complete_datasets')));
end
