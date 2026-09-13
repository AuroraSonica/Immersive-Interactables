local T={alive=true,status='Secondary buff test off.',events={}}
local function addr(o) return o and tostring(o:get_address()) end
local function player() return sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer') end
local function positive(n) return n and n==n and n>0 and n<10000000 end
function T.stop(reason) T.mode=nil; T.until_at=nil; T.status=reason or 'Secondary buff test off.'; T.dirty=true end
local function active(mode) return T.alive and T.mode==mode and os.clock()<T.until_at end
local function record(e)
    if #T.events>=30 then table.remove(T.events,1) end
    T.events[#T.events+1]=e; T.dirty=true
    T.last=string.format('%s: %.2f -> %.2f (write/readback only)',e.kind,e.base,e.modified)
end
local function exact(td,name,params,result)
    local found
    for _,m in ipairs(assert(sdk.find_type_definition(td)):get_methods()) do
        local p=m:get_param_types() or {}; local match=#p==#params
        for i,n in ipairs(params) do if not p[i] or p[i]:get_full_name()~=n then match=false end end
        if match and m:get_name()==name and not m:is_static() and m:get_return_type():get_full_name()==result then
            assert(not found,'Ambiguous buff method'); found=m
        end
    end
    return assert(found,'Captured buff method unavailable')
end
function T.start(mode)
    assert(T.alive and (mode=='stamina' or mode=='reaction'),'Invalid test')
    T.stop()
    local ch=assert(player()); T.character=addr(ch); T.actor=addr(ch:call('get_GameObject'))
    T.installed=T.installed or {}
    if not T.installed[mode] then
        local method=mode=='stamina' and exact('app.HumanStaminaController','Chara_OnConsumeStaminaHandler',
            {'System.Single','app.StaminaParameterBase.Parameter'},'System.Single')
            or exact('app.HitController','calcDamageReaction',{'app.HitController.DamageInfo'},'System.Void')
        T.installed[mode]=true
        local key='ii_temper_secondary_'..mode
        sdk.hook(method,function(args)
            local s=thread.get_hook_storage(); s[key]=nil
            if not active(mode) then return end
            local ok,err=pcall(function()
                if T.guard and not T.guard() then return end
                if mode=='stamina' then
                    local controller=sdk.to_managed_object(args[2])
                    if addr(controller:get_field('Chara'))~=T.character then return end
                    local param=sdk.to_managed_object(args[4])
                    if not param or param:get_type_definition():get_full_name()~='app.HumanStaminaParameterAdditional'
                        or param:get_field('IsCustomSkill')~=true then return end
                    s[key]={eligible=true}
                else
                    local di=sdk.to_managed_object(args[3]); if not di then return end
                    local owner=di:get_field('<AttackOwnerObject>k__BackingField')
                    if addr(owner)~=T.actor then return end
                    local hc=sdk.to_managed_object(args[2])
                    if addr(hc:call('get_GameObject'))==T.actor then return end
                    s[key]={di=di}
                end
            end)
            if not ok then T.stop('Test stopped: '..tostring(err)) end
        end,function(retval)
            local s=thread.get_hook_storage(); local row=s[key]; s[key]=nil
            if not row or not active(mode) then return retval end
            local replacement=retval
            local ok,err=pcall(function()
                if mode=='stamina' then
                    local base=tonumber(sdk.to_float(retval))
                    if not positive(base and -base) then return end
                    local modified=base*.95; local ptr=sdk.float_to_ptr(modified)
                    assert(math.abs(sdk.to_float(ptr)-modified)<.01,'Stamina float readback mismatch')
                    record({kind='Skill Stamina Cost',base=-base,modified=-modified})
                    replacement=ptr
                else
                    local base=tonumber(row.di:get_field('DamageReaction'))
                    if not positive(base) then return end
                    local damage=tonumber(row.di:get_field('Damage'))
                    row.di:set_field('DamageReaction',base*1.08)
                    local actual=tonumber(row.di:get_field('DamageReaction'))
                    assert(actual and math.abs(actual-base*1.08)<math.max(.01,base*.00001),'Reaction readback mismatch')
                    assert(tonumber(row.di:get_field('Damage'))==damage,'Health damage changed unexpectedly')
                    record({kind='Reaction Power',base=base,modified=actual,health_damage=damage})
                end
            end)
            if not ok then T.stop('Test stopped: '..tostring(err)) end
            return replacement
        end)
    end
    T.mode=mode; T.receipt_mode=mode; T.until_at=os.clock()+1800; T.events={}; T.last=nil; T.dirty=true
    T.status=mode=='stamina' and '-5% Skill Stamina test active.' or '+8% Arisen-owned Reaction test active (not weapon-filtered).'
end
function T.tick()
    if T.mode then
        local ok,ch=pcall(player)
        local valid,id=pcall(addr,ch)
        if not ok or not valid or id~=T.character then T.stop('Test stopped: player changed/unavailable.')
        elseif os.clock()>=T.until_at then T.stop('Secondary test expired.') end
    end
    if T.dirty and os.clock()>=(T.flush_at or 0) then
        T.dirty=false; T.flush_at=os.clock()+1
        if T.receipt_mode then
            pcall(json.dump_file,'ImmersiveInteractables_TemperSecondaryTest32_'..T.receipt_mode..'.json',{status=T.status,mode=T.mode,events=T.events})
        end
    end
end
re.on_script_reset(function() T.stop(); T.alive=false end)
return T
