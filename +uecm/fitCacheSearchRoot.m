function root=fitCacheSearchRoot(requested)
%FITCACHESEARCHROOT Preserve legacy ancestor lookup for relocated inputs.
root=string(requested);parent=string(fileparts(fileparts(root)));
while ~isfolder(root)
 next=string(fileparts(parent));if next==parent||strlength(next)==0,break,end
 parent=next;root=fullfile(parent,'ecm_result','matlab_uecm_cache_v1');
end
end
