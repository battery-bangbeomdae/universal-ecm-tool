function app = launch_universal_ecm()
%LAUNCH_UNIVERSAL_ECM Open the standalone MATLAB Universal ECM Tool v8.1.
%   app = launch_universal_ecm();
%   CSV EIS and local HPPC 1RC/2RC comparison. See START_HERE_ko.md.
model=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(model);
view=uecm.Views.MainView(vm);
app=struct('model',model,'viewModel',vm,'view',view);
% Keep the view alive even if called without an output argument.
setappdata(view.UIFigure,'UniversalECMApp',app);
end
