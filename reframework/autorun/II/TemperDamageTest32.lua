local T={alive=true,status='Damage test off.',events={}}
local function read(f) local ok,v=pcall(f); if ok then return v end end
local function address(o) return o and tostring(o:get_address()) end
function T.stop(reason)
    T.until_at=nil; T.actor=nil; T.status=reason or 'Damage test off.'; T.dirty=true
end
function T.start(options)
    options=options or {}
    T.multiplier=options.multiplier or 1.05; T.receiver_guard=options.receiver_guard
    assert(T.multiplier==1.05 or T.multiplier==1.08,'Unsupported damage multiplier')
    assert(T.alive,'Reset required')
    local ch=assert(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'))
    local actor=assert(address(ch:call('get_GameObject')))
    if not T.installed then
        local chosen
        for _,m in ipairs(assert(sdk.find_type_definition('app.HitController')):get_methods()) do
            local p=m:get_param_types() or {}
            if m:get_name()=='updateDamageHp' and not m:is_static() and #p==3
                and p[1]:get_full_name()=='app.HitController.DamageInfo'
                and p[2]:get_full_name()=='System.Single' and p[3]:get_full_name()=='System.Boolean'
                and m:get_return_type():get_full_name()=='System.Void' then
                assert(not chosen,'Ambiguous damage method'); chosen=m
            end
        end
        assert(chosen,'Captured damage method unavailable')
        assert(type(sdk.float_to_ptr)=='function','Float argument conversion unavailable')
        T.installed=true
        sdk.hook(chosen,function(args)
            local storage=thread.get_hook_storage(); storage.ii_temper_damage_test=nil
            if not T.alive or not T.until_at or os.clock()>=T.until_at then return end
            local ok,err=pcall(function()
                if T.guard and not T.guard() then return end
                local di=sdk.to_managed_object(args[3]); if not di then return end
                local owner=read(function() return di:get_field('<AttackOwnerObject>k__BackingField') end)
                if not owner then
                    local ahc=read(function() return di:get_field('<AttackHitController>k__BackingField') end)
                    local ch=ahc and read(function() return ahc:get_field('<CachedCharacter>k__BackingField') end)
                    owner=ch and read(function() return ch:call('get_GameObject') end)
                end
                if address(owner)~=T.actor then return end
                local hc=sdk.to_managed_object(args[2])
                local receiver=assert(address(hc:call('get_GameObject')))
                if receiver==T.actor then return end
                if T.receiver_guard and not T.receiver_guard(receiver) then return end
                local base=tonumber(sdk.to_float(args[4]))
                if not base or base~=base or base<=0 or base>10000000 then return end
                local before=tonumber(hc:call('get_Hp'))
                if not before or before<=0 then return end
                local boosted=base*T.multiplier
                local ptr=sdk.float_to_ptr(boosted)
                assert(math.abs(sdk.to_float(ptr)-boosted)<math.max(.001,boosted*.000001),'Float conversion mismatch')
                storage.ii_temper_damage_test={hc=hc,event={base=base,requested=boosted,before=before,receiver=receiver}}
                args[4]=ptr
            end)
            if not ok then T.stop('Damage test stopped: '..tostring(err)) end
        end,function(retval)
            local s=thread.get_hook_storage(); local row=s.ii_temper_damage_test; s.ii_temper_damage_test=nil
            if row and T.alive then
                local e=row.event
                e.after=read(function() return tonumber(row.hc:call('get_Hp')) end)
                if e.after then
                    e.loss=e.before-e.after
                    e.expected=math.min(e.before,e.requested)
                    e.matches=math.abs(e.loss-e.expected)<math.max(.01,e.expected*.00001)
                    T.last=string.format('Base %.2f -> Requested %.2f | HP Lost %.2f (%s)',e.base,e.requested,e.loss,e.matches and 'Matched' or 'Mismatch')
                else T.last='HP readback unavailable; benefit unverified.' end
                if #T.events>=30 then table.remove(T.events,1) end
                T.events[#T.events+1]=e; T.dirty=true
            end
            return retval
        end)
    end
    T.actor=actor; T.until_at=os.clock()+1800; T.events={}; T.last=nil
    T.status=options.status or '+5% Arisen-owned damage test active (not weapon-filtered).'; T.dirty=true
end
function T.tick()
    if T.until_at then
        local actor=read(function() return address(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'):call('get_GameObject')) end)
        if actor~=T.actor then T.stop('Damage test stopped: player unavailable or changed.')
        elseif os.clock()>=T.until_at then T.stop('Damage test expired.') end
    end
    if T.dirty and os.clock()>=(T.flush_at or 0) then
        T.dirty=false; T.flush_at=os.clock()+1
        pcall(json.dump_file,'ImmersiveInteractables_TemperDamageTest32.json',{status=T.status,events=T.events})
    end
end
re.on_script_reset(function() T.stop(); T.alive=false end)
return T
