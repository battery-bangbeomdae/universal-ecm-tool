function saveFittingSnapshot(file,bundle,signature)
%SAVEFITTINGSNAPSHOT Support background threads, which cannot write v7.3 MAT.
try
 save(file,'bundle','signature','-v7.3');
catch original
 info=whos('bundle','signature');
 if sum([info.bytes])>=1.8e9,rethrow(original);end
 save(file,'bundle','signature','-v7');
end
end
