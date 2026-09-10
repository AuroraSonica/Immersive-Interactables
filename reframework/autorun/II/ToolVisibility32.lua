local V={enabled=false}
V.auto_until=nil
function V.observe_carry(id)
    if not V.auto_until then return end
    if os.clock()>V.auto_until then V.auto_until=nil; return end
    if id==42 then
        V.auto_until=nil
        V.enabled=true; V.until_at=os.clock()+45
    end
end
local function read(fn) local ok,v=pcall(fn); if ok then return v end end
function V.snapshot(holder)
    local out={}
    local function scalar(name,fn)
        local v=read(fn)
        out[name]=(type(v)=="number" or type(v)=="string" or type(v)=="boolean") and v or "unknown"
        if v==false then out[name]=false end
    end
    local pick=read(function() return holder:get_field("PickableObject") end)
    local equip=read(function() return holder:get_field("EquipItem") end)
    scalar("id",function() return pick and tonumber(pick:get_field("EquipID")) end)
    scalar("contextId",function() return tonumber(holder:get_field("Context"):get_field("EquipItemID")) end)
    local ch=read(function() return holder:get_field("Chara") end)
    scalar("action0",function()
        local action=ch:call("get_ActionManager"):get_field("CurrentActionList"):call("get_Item",0)
        return action and action:get_field("Name")
    end)
    scalar("jacked",function() return ch:call("get_IsJacked") end)
    scalar("drawnWeapon",function() return ch:call("get_IsDrawedWeapon") end)
    for _,name in ipairs({"IsDrawEquipItem","IsPreparingEquipItem","IsPreparedEquipItem"}) do
        scalar(name,function() return holder:get_field(name) end)
    end
    local mesh=read(function() return holder:get_field("EquipItemMesh") end)
    local go=read(function() return equip and equip:call("get_GameObject") end)
    if not go then go=read(function() return pick and pick:get_field("EquipObj") end) end
    if not mesh and go then mesh=read(function() return go:call("getComponent(System.Type)",sdk.typeof("via.render.Mesh")) end) end
    out.pickable=pick~=nil; out.equipment=equip~=nil; out.mesh=mesh~=nil
    scalar("drawSelf",function() return go and go:call("get_DrawSelf") end)
    scalar("meshEnabled",function() return mesh and mesh:call("get_Enabled") end)
    scalar("forceAlphaTest",function() return mesh and mesh:call("get_ForceAlphaTest") end)
    scalar("name",function() return go and go:call("get_Name") end)
    local dissolve=read(function()
        return go and go:call("getComponent(System.Type)",sdk.typeof("app.DissolveController"))
    end)
    scalar("dissolveMode",function() return dissolve and tonumber(dissolve:call("get_ApplicateModeHash")) end)
    scalar("constraint",function() return holder:get_field("ConstraintEquipItem")~=nil end)
    scalar("holdCount",function() return tonumber(holder:get_field("HoldObjects"):call("get_Count")) end)
    scalar("continueFlag",function() return holder:get_field("Human"):call("get_IsContinueMultipleInteract") end)
    scalar("interacting",function()
        return sdk.get_managed_singleton("app.InteractManager"):call("isInteracting(app.Character)",ch)==true
    end)
    local function upos(g) return g:call("get_Transform"):call("get_UniversalPosition") end
    scalar("equipDist",function()
        local a,b=upos(go),upos(ch:call("get_GameObject"))
        return math.floor(math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)*100)/100
    end)
    scalar("pileDist",function()
        local a=upos(go); local b=holder:get_field("Context"):get_field("BollowedGimmickPosition")
        return math.floor(math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)*100)/100
    end)
    return out
end
function V.install(get_holder,ids,get_phase)
    local C=require("II.Compat32")
    local state={revision=4,started=os.date("%Y-%m-%d %H:%M:%S"),samples={},events={},methods={}}
    local owner,at,save_at,last_id,started,signature=nil,0,0,nil,0,nil
    local last_seen=0
    local alive,dirty=true,true
    for _,name in ipairs({"setDrawEquipItem","setEnableEquipItemForceAlphaTest","forceReturnEquipItem","returnEquipItem"}) do
        local ok,err=pcall(function()
            local m=C.method("app.GimmickHolder",name,{"System.Boolean"})
            assert(not m:is_static() and m:get_return_type():get_full_name()=="System.Void","Signature mismatch")
            sdk.hook(m,function(args)
                if not alive or not V.enabled then return end
                pcall(function()
                    if not alive or not owner or sdk.to_int64(args[2])~=owner then return end
                    local value=(sdk.to_int64(args[3]) & 0xFF)~=0
                    local events=state.events
                    local last=nil
                    for i=#events,math.max(1,#events-3),-1 do
                        if events[i].method==name then last=events[i]; break end
                    end
                    if last and last.value==value and os.clock()-(last.last_clock or last.clock)<0.5 then
                        last.repeats=(last.repeats or 1)+1; last.last_clock=os.clock()
                    else
                        events[#events+1]={method=name,value=value,clock=os.clock()}
                        while #events>200 do table.remove(events,1) end
                    end
                    dirty=true
                end)
            end,function(retval) return retval end)
        end)
        state.methods[name]=ok and "installed" or tostring(err)
    end
    re.on_application_entry("LateUpdateBehavior",function()
        if not alive or not V.enabled or os.clock()<at then return end
        if V.until_at and os.clock()>=V.until_at then
            V.enabled=false; owner=nil
            pcall(json.dump_file,"ImmersiveInteractables_ToolVisibility32.json",state)
            return
        end
        local now=os.clock(); at=now+0.25
        owner=nil
        pcall(function()
            local holder=get_holder()
            local id=read(function() return tonumber(holder:get_field("PickableObject"):get_field("EquipID")) end)
            if not ids[id] then
                local context_id=read(function() return tonumber(holder:get_field("Context"):get_field("EquipItemID")) end)
                local equip=read(function() return holder:get_field("EquipItem") end)
                if equip and ids[context_id] then id=context_id end
            end
            if ids[id] then last_seen=now end
            if ids[id] or (last_id and now-last_seen<15) then
                owner=holder:get_address()
                if ids[id] and id~=last_id then started=now; signature=nil end
                local sample=V.snapshot(holder)
                sample.workPhase=get_phase and read(get_phase) or "idle"
                local bits={}
                for _,k in ipairs({"id","contextId","workPhase","action0","jacked","drawnWeapon","IsDrawEquipItem","IsPreparedEquipItem","equipment","mesh","drawSelf","meshEnabled","forceAlphaTest","dissolveMode","constraint","holdCount","continueFlag","interacting"}) do
                    bits[#bits+1]=k.."="..tostring(sample[k])
                end
                local current=table.concat(bits,";")
                if current~=signature or now-started<120 then
                    sample.clock=now; sample.since_pickup=now-started
                    state.samples[#state.samples+1]=sample
                    while #state.samples>520 do table.remove(state.samples,1) end
                    signature=current; dirty=true
                end
            else owner=nil end
            if ids[id] then last_id=id elseif now-last_seen>=15 then last_id=nil end
        end)
        if dirty and now>=save_at then
            local ok=pcall(json.dump_file,"ImmersiveInteractables_ToolVisibility32.json",state)
            if ok then dirty=false end
            save_at=now+1
        end
    end)
    re.on_script_reset(function()
        alive=false; owner=nil
        if V.enabled or V.until_at then pcall(json.dump_file,"ImmersiveInteractables_ToolVisibility32.json",state) end
    end)
    if re.on_draw_ui then re.on_draw_ui(function()
        if not imgui.tree_node("Interactables tool visibility (diagnostic)") then return end
        imgui.text(V.enabled and "Capturing tool state." or (V.auto_until and "Armed: next beam pickup within 3 minutes records 45 seconds." or "Idle: no periodic tool reads or file writes."))
        if imgui.button("Capture tool visibility for 60 seconds") then
            V.enabled=true; V.until_at=os.clock()+60
            state.samples,state.events={},{}; signature=nil; dirty=true
        end
        imgui.tree_pop()
    end) end
end
return V
