function n = count_ping_pongs(events, window_s)
%COUNT_PING_PONGS Handovers that return to the previous node within a window.
%
%   n = count_ping_pongs(events, window_s)
%
%   A ping-pong is a handover A -> B followed by B -> A where the second
%   handover happens within window_s seconds of the first. Only executed
%   handovers count (see is_handover_event).

if isempty(events), n = 0; return; end
ho = events(is_handover_event({events.type}));
n = 0;
for i = 2:numel(ho)
    if ho(i).to == ho(i-1).from && ho(i).from == ho(i-1).to && ...
            (ho(i).t_s - ho(i-1).t_s) <= window_s
        n = n + 1;
    end
end
end
