function data=attachComparisonResults(data,bundle)
%ATTACHCOMPARISONRESULTS Join registered conditions and saved fits once by identity.
[matched,index]=uecm.comparisonFitLinks(data.Measurements,bundle);
links=struct('Matched',matched,'Index',index);
data=uecm.attachCustomComparison(data,bundle,links);
data=uecm.attachFittedComparison(data,bundle,links);
end
