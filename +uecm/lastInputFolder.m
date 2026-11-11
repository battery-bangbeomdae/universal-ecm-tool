function folder=lastInputFolder(selected,fallback)
%LASTINPUTFOLDER Remember the last confirmed input location on this computer.
arguments
    selected (1,1) string = ""
    fallback (1,1) string = string(pwd)
end
group='UniversalECMToolV81';key='LastInputFolder';
if strlength(selected)>0&&isfolder(selected)
    folder=selected;
    try,setpref(group,key,char(folder));catch,end
    return
end
try,folder=string(getpref(group,key,char(fallback)));catch,folder=fallback;end
if ~isscalar(folder)||ismissing(folder)||~isfolder(folder),folder=fallback;end
if ~isfolder(folder),folder=string(pwd);end
end
