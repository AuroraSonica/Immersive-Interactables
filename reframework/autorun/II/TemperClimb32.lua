local T={status='Monster treatment inactive.',alive=true,hits=0}
local function id(o) return o and tostring(o:get_address()) end
local function player() return sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer') end
function T.target(ch,moving,controller)
    if not ch or ch:call('get_IsClimbOnCharacter')~=true then return nil end
    local target=ch:get_field('ClimbTargetCharacter'); if not target then return nil end
    local go=target:call('get_GameObject'); if not go then return nil end
    if not tostring(go:call('get_Name')):match('^ch2%d%d%d%d%d_') then return nil end
    local ctrl=ch:call('get_ClimbCtrl'); if not ctrl then return nil end
    if controller and id(controller)~=id(ctrl) then return nil end
    if id(ctrl:get_field('TargetRootObject'))~=id(go) then return nil end
    if moving and ctrl:get_field('<IsClimbMoving>k__BackingField')~=true then return nil end
    return id(go)
end
function T.stop(reason)
    T.until_at=nil; T.guard=nil; T.status=reason or 'Monster treatment inactive.'
end
function T.current(moving,ctrl)
    if not T.alive or not T.until_at or os.clock()>=T.until_at then return nil end
    local ch=player()
    if id(ch)~=T.owner or (T.guard and not T.guard()) then return nil end
    return T.target(ch,moving,ctrl)
end
function T.receiver(receiver) return T.current(false)==receiver end
function T.start(guard)
    assert(T.alive,'Reset required')
    if not T.installed then
        local found
        for _,m in ipairs(assert(sdk.find_type_definition('app.ObjectClimber')):get_methods()) do
            if m:get_name()=='get_ClimbMotionSpeed' and #(m:get_param_types() or {})==0
                and not m:is_static() and m:get_return_type():get_full_name()=='System.Single' then
                assert(not found,'Ambiguous climb speed getter'); found=m
            end
        end
        assert(found,'Captured climb speed getter unavailable')
        assert(type(sdk.float_to_ptr)=='function','Float conversion unavailable')
        T.installed=true
        sdk.hook(found,function(args)
            local s=thread.get_hook_storage(); s.ii_temper_climb=nil
            local ok,v=pcall(T.current,true,sdk.to_managed_object(args[2]))
            if not ok then T.stop('Climb treatment stopped: '..tostring(v))
            elseif v then s.ii_temper_climb=v end
        end,function(retval)
            local s=thread.get_hook_storage(); local target=s.ii_temper_climb; s.ii_temper_climb=nil
            if not target then return retval end
            local ok,result=pcall(function()
                if T.current(true)~=target then return retval end
                local base=tonumber(sdk.to_float(retval))
                if not base or base~=base or base<=0 or base>10 then return retval end
                local modified=base*1.10; local ptr=sdk.float_to_ptr(modified)
                assert(math.abs(sdk.to_float(ptr)-modified)<.0001,'Climb speed conversion mismatch')
                T.hits=T.hits+1; T.last=string.format('Climb speed: %.3f -> %.3f',base,modified)
                T.dirty=true; return ptr
            end)
            if not ok then T.stop('Climb treatment stopped: '..tostring(result)); return retval end
            return result
        end)
    end
    T.owner=id(assert(player())); T.guard=guard; T.until_at=os.clock()+1800
    T.hits=0; T.last=nil; T.dirty=true; T.status='Gold treatment active: awaiting monster climbing.'
end
function T.tick()
    if T.until_at then
        local ok,ch=pcall(player)
        if not ok or id(ch)~=T.owner or os.clock()>=T.until_at then T.stop('Gold treatment expired or player changed.') end
    end
    if T.dirty and os.clock()>=(T.flush_at or 0) then
        T.flush_at=os.clock()+1; T.dirty=false
        pcall(json.dump_file,'ImmersiveInteractables_TemperClimb32.json',{hits=T.hits,last=T.last,status=T.status})
    end
end
re.on_script_reset(function() T.stop(); T.alive=false end)
return T
