local P={status='Combat capture not started.',alive=true,events={},methods={}}
local function read(f) local ok,v=pcall(f); if ok then return v end end
local function addr(o) return o and tostring(o:get_address()) end
function P.arm()
    P.events={}; P.errors=0; P.calls={}; P.until_at=os.clock()+60; P.dirty=true
    P.no_change_count=0; P.no_change_samples={}
    local ch=sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer')
    P.actor=addr(ch:call('get_GameObject'))
    if not P.installed then
        local td=assert(sdk.find_type_definition('app.HitController'))
        P.installed=true
        for _,m in ipairs(td:get_methods()) do
            local name=m:get_name()
            if name=='damageProc' or name=='calcDamageReaction' or name=='updateDamageHp' then
                local types={}; for _,t in ipairs(m:get_param_types() or {}) do types[#types+1]=t:get_full_name() end
                P.methods[#P.methods+1]={name=name,parameters=types,result=m:get_return_type():get_full_name()}
                if not m:is_static() and types[1]=='app.HitController.DamageInfo'
                    and ((#types==1 and name~='updateDamageHp') or
                        (name=='updateDamageHp' and #types==3 and types[2]=='System.Single' and types[3]=='System.Boolean')) then
                    local key='ii_temper_probe_'..name
                    sdk.hook(m,function(args)
                        local storage=thread.get_hook_storage(); storage[key]=nil
                        if not P.alive or not P.until_at or os.clock()>P.until_at or #P.events>=60 then return end
                        P.calls[name]=(P.calls[name] or 0)+1; P.dirty=true
                        local ok,err=pcall(function()
                            local di=sdk.to_managed_object(args[3]); if not di then return end
                            local owner=read(function() return di:get_field('<AttackOwnerObject>k__BackingField') end)
                            if not owner then
                                local ahc=read(function() return di:get_field('<AttackHitController>k__BackingField') end)
                                local ch=ahc and read(function() return ahc:get_field('<CachedCharacter>k__BackingField') end)
                                owner=ch and read(function() return ch:call('get_GameObject') end)
                            end
                            if addr(owner)~=P.actor then return end
                            local hc=sdk.to_managed_object(args[2])
                            local event={method=name,at=os.clock(),before=read(function() return tonumber(hc:call('get_Hp')) end),
                                reaction=read(function() return tonumber(di:get_field('Damage')) end)}
                            if name=='updateDamageHp' then event.amount=sdk.to_float(args[4]) end
                            if name=='calcDamageReaction' then
                                event.reaction_fields={}
                                for _,field in ipairs({'DamageReaction','DamageRateReaction','BlowDamage','DamageRate'}) do
                                    event.reaction_fields[field]=read(function() return tostring(di:get_field(field)) end)
                                end
                            end
                            event.receiver=read(function() return addr(hc:call('get_GameObject')) end)
                            if event.receiver then event.receiver_is_player=event.receiver==P.actor end
                            storage[key]={event=event,hc=hc,di=name=='calcDamageReaction' and di or nil}
                        end)
                        if not ok then P.errors=P.errors+1; P.last_error=tostring(err) end
                    end,function(retval)
                        local s=thread.get_hook_storage(); local row=s[key]; s[key]=nil
                        if row and P.alive then
                            local e=row.event
                            e.after=read(function() return tonumber(row.hc:call('get_Hp')) end)
                            if row.di then
                                e.reaction_fields_after={}
                                for _,field in ipairs({'DamageReaction','DamageRateReaction','BlowDamage','DamageRate','Damage'}) do
                                    e.reaction_fields_after[field]=read(function() return tostring(row.di:get_field(field)) end)
                                end
                            end
                            local changed=e.before and e.after and e.before~=e.after
                            if e.reaction_fields_after then
                                for field,value in pairs(e.reaction_fields or {}) do
                                    if e.reaction_fields_after[field]~=value then changed=true end
                                end
                            end
                            if changed or (e.reaction or 0)~=0 or (e.amount or 0)~=0 then
                                if #P.events<60 then P.events[#P.events+1]=e end
                            else
                                P.no_change_count=P.no_change_count+1
                                if #P.no_change_samples<6 then P.no_change_samples[#P.no_change_samples+1]=e end
                            end
                            P.dirty=true
                        end
                        return retval
                    end)
                end
            end
        end
    end
    P.status='Read-only capture: land a few ordinary weapon hits within 60 seconds.'
end
function P.tick()
    if P.until_at and (os.clock()>P.until_at or #P.events>=60) then P.until_at=nil; P.status='Capture complete; evidence saved.'; P.dirty=true end
    if not P.dirty or os.clock()<(P.flush_at or 0) then return end
    P.flush_at=os.clock()+1; P.dirty=false
    pcall(json.dump_file,'ImmersiveInteractables_TemperCombat32.json',{
        revision=2,methods=P.methods,events=P.events,calls=P.calls,errors=P.errors,last_error=P.last_error,status=P.status,
        no_change_count=P.no_change_count,no_change_samples=P.no_change_samples})
end
re.on_script_reset(function() P.alive=false; P.until_at=nil end)
return P
