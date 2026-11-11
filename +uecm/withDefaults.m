function o = withDefaults(o)
%WITHDEFAULTS Add any setting missing from an older session/settings struct (v0.2 -> v0.3) with its default.
arguments
    o (1,1) struct
end
d=uecm.defaults(); names=fieldnames(d);
for k=1:numel(names)
    if ~isfield(o,names{k}),o.(names{k})=d.(names{k});end
end
end
