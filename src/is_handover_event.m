function tf = is_handover_event(types)
%IS_HANDOVER_EVENT True for event types that are executed handovers.
%   tf = is_handover_event({events.type})
%   'a3'     triggered by the baseline (hysteresis + time-to-trigger)
%   'score'  triggered by the intelligent algorithm
%   'forced' serving node lost, switched to another available node
%   'initial', 'rlf' and 'reestablish' are connection events, not handovers.
tf = ismember(types, {'a3', 'score', 'forced'});
end
