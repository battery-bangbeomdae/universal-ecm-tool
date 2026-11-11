function [P,C]=comparisonFitExport(data,T,model)
%COMPARISONFITEXPORT Selected metadata, saved parameters and full saved samples.
P=T;n=height(T);P.requested_fit_model=repmat(model,n,1);P.fit_available=false(n,1);
P.actual_fit_model=repmat("",n,1);P.saved_fit_status=repmat("",n,1);P.saved_rmse=nan(n,1);P.saved_error_unit=repmat("",n,1);rows={};
for k=1:n
 c=uecm.comparisonCandidate(data,T.curve_id(k),model);if isempty(c),continue,end
 P.fit_available(k)=true;P.actual_fit_model(k)=string(c.ModelName);
 if isfield(c,'Status'),P.saved_fit_status(k)=string(c.Status);end
 if isfield(c,'RMSE'),P.saved_rmse(k)=c.RMSE;end
 if isfield(c,'ErrorUnit'),P.saved_error_unit(k)=string(c.ErrorUnit);end
 if isfield(c,'Parameters')
  for f=string(fieldnames(c.Parameters))'
   name="parameter_"+f;if ~ismember(name,string(P.Properties.VariableNames)),P.(name)=nan(n,1);end
   P.(name)(k)=c.Parameters.(f);
  end
 end
 y=c.Predicted(:);m=numel(y);frequency=nan(m,1);time=frequency;realZ=frequency;imagZ=frequency;voltage=frequency;delta=frequency;
 if c.Domain=="EIS",frequency=c.Frequency(:);realZ=real(y);imagZ=imag(y);
 else,time=c.Time(:);voltage=y;delta=y-c.Baseline;end
 rows{end+1}=table(repmat(T.curve_id(k),m,1),repmat(T.measurement_id(k),m,1),repmat(string(c.ModelName),m,1),(1:m)',frequency,time,realZ,imagZ,voltage,delta, ...
  'VariableNames',{'curve_id','measurement_id','model','saved_sample_index','frequency_Hz','time_s','z_real_Ohm','z_imag_Ohm','voltage_V','delta_voltage_V'}); %#ok<AGROW>
end
C=table();if ~isempty(rows),C=vertcat(rows{:});end
end
