local P={alive=true,status='Stamina capture not started.',events={}}
local function read(f) local ok,v=pcall(f); if ok then return v end end
local function addr(o) return o and tostring(o:get_address()) end
function P.arm()
    local ch=assert(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'))
    P.actor=addr(ch); P.events={}; P.errors=0; P.last_error=nil
    if not P.installed then
        local selected
        for _,m in ipairs(assert(sdk.find_type_definition('app.HumanStaminaController')):get_methods()) do
            local p=m:get_param_types() or {}
            if m:get_name()=='Chara_OnConsumeStaminaHandler' and not m:is_static() and #p==2
                and p[1]:get_full_name()=='System.Single'
                and p[2]:get_full_name()=='app.StaminaParameterBase.Parameter' then
                assert(not selected,'Ambiguous stamina handler'); selected=m
            end
        end
        assert(selected,'Stamina handler signature unavailable')
        P.result=selected:get_return_type():get_full_name()
        assert(P.result=='System.Single','Stamina return type changed; capture withheld')
        P.installed=true
        sdk.hook(selected,function(args)
            local s=thread.get_hook_storage(); s.ii_temper_stamina=nil
            if not P.alive or not P.until_at or os.clock()>P.until_at or #P.events>=100 then return end
            local ok,err=pcall(function()
                local controller=sdk.to_managed_object(args[2])
                local owner=controller:get_field('Chara')
                if addr(owner)~=P.actor then return end
                local sm=owner:call('get_StaminaManager')
                local e={amount=sdk.to_float(args[3]),at=os.clock(),before=read(function() return tonumber(sm:call('get_RemainingAmount')) end)}
                local param=sdk.to_managed_object(args[4])
                e.parameter_type=param and read(function() return param:get_type_definition():get_full_name() end)
                e.parameter_fields={}
                if param then
                    for i,f in ipairs(param:get_type_definition():get_fields()) do
                        if i>32 then break end
                        local n=f:get_name(); local v=read(function() return param:get_field(n) end)
                        if type(v)=='number' or type(v)=='boolean' or type(v)=='string' then e.parameter_fields[n]=v end
                    end
                end
                s.ii_temper_stamina={event=e,sm=sm}
            end)
            if not ok then P.errors=P.errors+1; P.last_error=tostring(err); P.dirty=true end
        end,function(retval)
            local s=thread.get_hook_storage(); local row=s.ii_temper_stamina; s.ii_temper_stamina=nil
            if row and P.alive then
                row.event.returned_amount=read(function() return tonumber(sdk.to_float(retval)) end)
                row.event.after=read(function() return tonumber(row.sm:call('get_RemainingAmount')) end)
                if #P.events<100 then P.events[#P.events+1]=row.event end
                P.dirty=true
            end
            return retval
        end)
    end
    P.until_at=os.clock()+60; P.status='Read-only stamina capture active for 60 seconds.'; P.dirty=true
end
function P.tick()
    if P.until_at and (os.clock()>P.until_at or #P.events>=100) then
        P.until_at=nil; P.status='Stamina capture complete.'; P.dirty=true
    end
    if P.dirty and os.clock()>=(P.flush_at or 0) then
        P.dirty=false; P.flush_at=os.clock()+1
        pcall(json.dump_file,'ImmersiveInteractables_TemperStamina32.json',{revision=2,status=P.status,events=P.events,errors=P.errors,last_error=P.last_error,result=P.result})
    end
end
re.on_script_reset(function() P.alive=false; P.until_at=nil end)
return P
