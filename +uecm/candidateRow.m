function row = candidateRow(identity,candidate)
% CANDIDATEROW Keep identity, replace ALL model-specific parameters/diagnostics.
arguments
    identity (1,1) struct
    candidate (1,1) struct
end
row=identity;
for name=["Rs_Ohm","Rct_Ohm","Cdl_F","Ceff_F","CPE1_Q","CPE2_Q","CPE1_alpha","CPE2_alpha","Ceff1_F","Ceff2_F","CPE_Q","CPE_alpha","L_H","Warburg_sigma_Ohm_s_mhalf", ...
        "R0_Ohm","R1_Ohm","C1_F","R2_Ohm","C2_F","tau_s","tau1_s","tau2_s"]
    row.(name)=NaN;
end
fields=fieldnames(candidate.Parameters);for k=1:numel(fields),row.(fields{k})=candidate.Parameters.(fields{k});end
row.model=candidate.ModelName;row.circuit=candidate.Circuit;row.fit_status=candidate.Status;row.reason=candidate.Reason;
row.rmse=candidate.RMSE;row.error_unit=candidate.ErrorUnit;row.relative_error=candidate.RelativeError;
row.solver=candidate.Solver;row.exit_flag=candidate.ExitFlag;row.jacobian_condition=candidate.Condition;
end
