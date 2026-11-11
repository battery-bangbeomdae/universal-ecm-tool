function root=fittingRootForInput(file,fallback)
%FITTINGROOTFORINPUT Locate a study's backup even when a package/experiment is selected.
root=string(fullfile(fallback,'ecm_result','matlab_uecm_cache_v1'));
folder=string(fileparts(extractBefore(file+"#","#")));
while strlength(folder)>0
 candidate=string(fullfile(folder,'ecm_result','matlab_uecm_cache_v1'));
 if isfolder(candidate),root=candidate;return,end
 % Do not attach a research package to unrelated parent-directory caches.
 if isfile(fullfile(folder,'manifest.csv')),return,end
 parent=string(fileparts(folder));if parent==folder,return,end
 folder=parent;
end
end
