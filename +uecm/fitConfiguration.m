function config=fitConfiguration(settings)
%FITCONFIGURATION Settings used by the ECM solvers; import effects are checked in prepared data.
o=uecm.withDefaults(settings);config=struct();
for f=["Circuit","EISModels","EISAutoWarburg","EISOutlierFilter","EISOutlierThreshold","EISOutlierMaxFraction","EISRepeatFilter","EISRepeatScatterLimit","EISRepeatMaxFraction","EISRelativeErrorLimit","PulseErrorLimit_V","MaxPulseDuration_s","RestCurrent_A"],config.(f)=o.(f);end
end
