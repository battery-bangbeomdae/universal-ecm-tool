function info=columnInfo(name,field)
%COLUMNINFO Recognize explicit header units/operators; never infer from values.
arguments
 name (1,1) string
 field (1,1) string
end
text=strip(name);text=replace(text,["Ω","Ω","μ","µ","−","–","℃","°C"],["Ohm","Ohm","u","u","-","-","C","C"]);
info=struct('Base',text,'Unit',"unknown",'ImaginarySign',"unknown");
switch field
 case "frequency",units=["MHz","kHz","mHz","Hz","hz"];
 case {"real","imag","magnitude"},units=["MOhm","kOhm","mOhm","mohm","uOhm","uohm","Ohms","ohms","Ohm","ohm"];
 case "time",units=["milliseconds","msec","ms","seconds","second","sec","minutes","minute","min","hours","hour","hr","s","h"];
 case "calendar",units=["days","day","weeks","week","hours","hour","seconds","second","d","h","s"];
 case "current",units=["mA","ma","uA","ua","A","a"];
 case "voltage",units=["mV","mv","uV","uv","V","v"];
 case "phase",units=["degrees","degree","deg","°","radians","radian","rad"];
 case {"soc","soh"},units=["percent","fraction","ratio","0-1","pct","%"];
 case "temperature",units=["Celsius","Kelvin","degC","deg C","C","K","c","k"];
 otherwise,units=strings(0,1);
end
for token=units
 pattern=regexptranslate('escape',token)+"[\]\)\s]*$";
 if ismember(token,["Hz","kHz","Ohm","ohm","Ohms","ohms","milliseconds","msec","seconds","second","sec","minutes","minute","min","hours","hour","hr","degrees","degree","deg","radians","radian","rad","percent","fraction","ratio","pct","Celsius","Kelvin","days","day","weeks","week"])
  pattern="(?i)"+pattern;
 end
 [first,~]=regexp(char(text),char(pattern),'start','end','once');
 if isempty(first),continue,end
 prefix=extractBefore(text,first);
 if isempty(regexp(char(prefix),'[\s_\[\(/]$','once'))&&~attachedBase(prefix,field),continue,end
 base=strip(regexprep(prefix,'[\s_\[\(/]+$',''));
 if strlength(base)==0,continue,end
 info.Base=base;unit=token;
 switch field
  case {"real","imag","magnitude"}
   if ismember(token,["ohm","ohms","Ohms"]),unit="Ohm";elseif token=="mohm",unit="mOhm";elseif token=="uohm",unit="uOhm";end
  case "frequency"
   if token=="hz",unit="Hz";end
  case "time"
   if ismember(token,["milliseconds","msec"]),unit="ms";
   elseif ismember(token,["seconds","second","sec"]),unit="s";
   elseif ismember(token,["minutes","minute"]),unit="min";
   elseif ismember(token,["hours","hour","hr"]),unit="h";end
  case "calendar"
   if ismember(token,["days","day","d"]),unit="d";elseif ismember(token,["weeks","week"]),unit="week";elseif ismember(token,["hours","hour","h"]),unit="h";else,unit="s";end
  case "current"
   if token=="ma",unit="mA";elseif token=="ua",unit="uA";elseif token=="a",unit="A";end
  case "voltage"
   if token=="mv",unit="mV";elseif token=="uv",unit="uV";elseif token=="v",unit="V";end
  case "phase"
   if ismember(token,["degrees","degree","°"]),unit="deg";elseif ismember(token,["radians","radian"]),unit="rad";end
  case {"soc","soh"}
   if ismember(token,["percent","pct","%"]),unit="percent";else,unit="fraction";end
  case "temperature",unit=upper(replace(token,["Celsius","Kelvin","degC","deg C"],["C","K","C","C"]));
 end
 info.Unit=unit;break
end
if field=="imag"
 base=lower(strip(info.Base));
 if startsWith(base,"-")||contains(base,"neg")||contains(base,"음의")
  info.ImaginarySign="negative_imaginary";
 elseif contains(base,"im")||contains(base,"img")||contains(base,"''")||contains(base,"″")||contains(base,"허수")||ismember(regexprep(base,'[^a-z0-9]',''),["zi","zdoubleprime"])
  info.ImaginarySign="signed_imaginary";
 end
end
end

function ok=attachedBase(prefix,field)
base=lower(regexprep(prefix,'[^a-zA-Z0-9가-힣]',''));
switch field
 case "frequency",known=["frequency","freq","f","주파수"];
 case "time",known=["time","timestamp","elapsedtime","testtime","t","시간","경과시간"];
 case "calendar",known=["calendar","calendarage","aging","ageing","agingtime","ageingtime","storage","storageage","열화경과일"];
 case "current",known=["current","i","전류"];
 case "voltage",known=["voltage","v","u","ecell","cellvoltage","전압","단자전압"];
 case {"real","imag","magnitude"},known=["zreal","real","rez","re","zr","rreal","zimag","imag","imz","im","zi","rimg","z","absz","magnitude","zamp","zmag","실수부","허수부"];
 case "phase",known=["phase","phasez","zph","zphase","위상"];
 case {"soc","soh"},known=["soc","soh","stateofcharge","stateofhealth"];
 case "temperature",known=["temperature","temp","eistemp","temperaturestart","온도"];
 otherwise,known=strings(0,1);
end
ok=ismember(base,known);
end
