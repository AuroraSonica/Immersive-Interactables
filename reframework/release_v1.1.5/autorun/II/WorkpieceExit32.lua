local E={}
function E.new()
    local token,owner,exit_at,idle_at,unknown_at
    local gate={}
    gate.tick=function(now,session,state,safe)
        if safe and token and session==token and state and state.owner==owner
            and (state.paused==true or state.owned_dialog==true) and state.jacked==true and state.interacting==true then
            exit_at,idle_at,unknown_at=nil,nil,nil
            gate.reason='same anvil session paused in GUI'
            return token,false
        end
        if not safe or not state or not state.owner or state.loading~=false then
            gate.reason=not safe and "other interaction/preview" or "owner/loading state unavailable or loading"
            token,owner,exit_at,idle_at,unknown_at=nil,nil,nil,nil,nil; return nil,false
        end
        if session then
            token,owner,exit_at,idle_at,unknown_at=session,state.owner,nil,nil,nil
            return token,false
        end
        if not token then return nil,false end
        if owner~=state.owner then gate.reason="player changed"; token=nil; return nil,false end
        exit_at=exit_at or now
        local idle=state.jacked==false and state.interacting==false and state.action=="NormalLocomotion"
        if idle then idle_at=idle_at or now else idle_at=nil end
        if (idle_at and now-idle_at>=0.15) or now-exit_at>=20 then
            gate.reason=idle_at and "normal locomotion and released native interaction" or "exit timeout"
            token=nil; return nil,false
        end
        if type(state.jacked)~="boolean" or type(state.interacting)~="boolean" or type(state.action)~="string" then
            unknown_at=unknown_at or now
            if now-unknown_at>2 then gate.reason="exit action unreadable for two seconds"; token=nil; return nil,false end
        else unknown_at=nil end
        return token,true
    end
    return gate
end
return E
