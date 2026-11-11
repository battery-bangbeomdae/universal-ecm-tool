classdef CancelProbe < handle
    properties
        Fail = false
        Calls = 0
    end
    methods
        function obj=CancelProbe(fail)
            obj.Fail=fail;
        end
        function cancel(obj)
            obj.Calls=obj.Calls+1;
            if obj.Fail,error('uecmtest:CancelFailure','Injected cancellation failure');end
        end
    end
end
