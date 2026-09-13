local C=require("II.Compat32")
local function session(hold,vocation)
local R={state="idle",status="Dialogue clone load test has not run (no spawn)."}
local PATH=vocation and 'GuiManager.getPrefab(60)' or "appsystem/clone/prefab/talkeventhumanclone.pfb"
local FILE=vocation and 'ImmersiveInteractables_VocationLoad32.json' or (hold and "ImmersiveInteractables_DialogueCloneInstance32_Load.json" or "ImmersiveInteractables_DialogueCloneLoad32.json")
local function save(label)
    R.receipt.stage=label
    local ok,result=pcall(json.dump_file,FILE,R.receipt)
    assert(ok and result~=false,"Cannot save dialogue load receipt: "..tostring(result))
end
local function method(t,n,params,result)
    local m=C.method(t,n,params or {})
    assert(m:get_return_type():get_full_name()==result and not m:is_static(),"Unexpected signature: "..t.."."..n)
    return m
end
local function keep(obj)
    assert(obj,"Required object is absent"); obj:add_ref(); return obj
end
local function owner_field(obj,name)
    assert(obj and obj:get_type_definition():get_field(name),"Current field unavailable: "..name)
    return obj:get_field(name)
end
local function snapshot()
    if vocation then
        local p=R.prefab:read_qword(0x10)
        assert(p==0 or p>=0x10000,'Invalid low prefab resource pointer; readiness read refused')
    end
    return {ref_count=R.m.count:call(R.ctrl),has_reference=R.m.has:call(R.ctrl),
        controller_ready=R.m.ready:call(R.ctrl),prefab_ready=R.m.pready:call(R.prefab)}
end
local function cleanup(reason)
    local ok,err=pcall(function()
        if not R.owned or not R.acquire_attempted then return end
        local count=R.m.count:call(R.ctrl)
        if count==1 and R.acquire_attempted then
            R.receipt.release_attempted=true
            pcall(save,"release owned reference")
            R.m.release:call(R.ctrl)
        elseif count~=0 then error("Unexpected private reference count; refusing guessed release: "..tostring(count)) end
        R.m.update:call(R.ctrl)
        R.receipt.after_release=snapshot()
        assert(R.receipt.after_release.ref_count==0 and R.receipt.after_release.has_reference==false,
            "Private reference release could not be confirmed")
    end)
    R.receipt.result=reason
    R.receipt.cleanup_confirmed=ok
    R.receipt.cleanup_error=not ok and tostring(err) or nil
    R.state=ok and (R.receipt.loaded and "ready_released" or "stopped") or "cleanup_failed"
    R.status=ok and (R.receipt.loaded and "Dialogue clone loaded; test reference released. No mannequin spawned."
        or "Dialogue clone load stopped: "..reason) or "Dialogue clone cleanup unconfirmed: restart the game before further testing."
    local persisted,why=pcall(save,R.state)
    if not persisted then R.status=R.status.." Receipt save failed: "..tostring(why) end
    if ok then R.ctrl,R.prefab,R.source,R.manager=nil,nil,nil,nil end
end
function R.request()
    if R.state~="idle" then return false end
    R.state="queued"; R.status="Dialogue clone load queued (no spawn); keep the world unpaused."
    return true
end
function R.tick(now)
    if R.state~="queued" and R.state~="loading" then return end
    if R.cancel_requested then R.cancel_requested=nil; R.cancel(); return end
    now=now or os.clock()
    local ok,err=pcall(function()
        if R.state=="queued" then
            R.receipt={revision=1,time=os.date("%Y-%m-%d %H:%M:%S"),path=PATH,
                mode=hold and "private_controller_retained_lease" or "private_controller_load_only",phase="pre-UpdateBehavior",loaded=false}
            save("resolve current signatures")
            R.m={}
            for key,spec in pairs({item={"get_Item","via.Prefab"},count={"get_RefCount","System.Int32"},
                    has={"get_HasReference","System.Boolean"},ready={"get_Ready","System.Boolean"},
                    acquire={"addRef","System.Void"},release={"release","System.Void"},update={"update","System.Void"}}) do
                R.m[key]=method("app.PrefabController",spec[1],{},spec[2])
            end
            R.m.path=method("via.Prefab","get_Path",{},"System.String")
            R.m.pready=method("via.Prefab","get_Ready",{},"System.Boolean")
            local td=assert(sdk.find_type_definition("app.PrefabController"))
            local field=assert(td:get_field("_Item"),"No current controller _Item field")
            assert(field:get_type():get_full_name()=="via.Prefab","Controller _Item changed type")
            save("read authored dialogue prefab")
            R.manager=keep(sdk.get_managed_singleton("app.TalkEventManager"))
            assert(owner_field(R.manager,"_IsTalkingAny")==false,"Finish dialogue before testing")
            if vocation then
                R.source=keep(sdk.get_managed_singleton('app.GuiManager'))
                assert(R.source:call('isPausedGUI')==false and R.source:call('get_IsLoadGui')==false,'Close native menus first')
                local lookup=method('app.GuiManager','getPrefab',{'app.GuiDefine.GuiType'},'via.Prefab')
                R.prefab=keep(lookup:call(R.source,60))
                local p=R.prefab:read_qword(0x10)
                assert(p==0 or p>=0x10000,'Invalid cached prefab pointer')
            else
                R.source=keep(owner_field(R.manager,"_ClonePrefabController"))
                R.prefab=keep(R.m.item:call(R.source))
            end
            assert(R.prefab:get_type_definition():get_full_name()=="via.Prefab","Invalid authored prefab type")
            local path=vocation and 'GuiManager.getPrefab(60)' or R.m.path:call(R.prefab)
            assert(vocation or (type(path)=="string" and path:gsub("\\","/"):lower()==PATH),"Unexpected dialogue prefab path")
            R.receipt.source_path=path
            R.receipt.source_address=tostring(R.source:get_address())
            R.receipt.prefab_address=tostring(R.prefab:get_address())
            save("allocate private controller")
            R.ctrl=keep(sdk.create_instance("app.PrefabController"))
            assert(R.ctrl:get_type_definition():get_full_name()=="app.PrefabController","Private controller type mismatch")
            assert(R.ctrl:get_address()~=R.source:get_address(),"Allocation returned shared controller")
            assert(R.m.count:call(R.ctrl)==0 and R.m.has:call(R.ctrl)==false,"Private controller not initially unreferenced")
            R.owned=true
            save("bind authored reference to private controller")
            R.ctrl:set_field("_Item",R.prefab)
            assert(R.m.item:call(R.ctrl):get_address()==R.prefab:get_address(),"Private prefab bind failed")
            R.receipt.before_acquire=snapshot()
            save("acquire private resource reference")
            R.acquire_attempted=true
            R.m.acquire:call(R.ctrl)
            assert(R.m.count:call(R.ctrl)==1,"Private resource acquire not confirmed")
            R.receipt.after_acquire=snapshot()
            save("update private resource controller")
            R.m.update:call(R.ctrl)
            R.started,R.next_poll=now,now+0.1
            R.state="loading"; R.status="Loading dialogue clone resource (no spawn; 20-second limit)."
            save("waiting for resource readiness")
            return
        end
        if now<R.next_poll then return end
        R.next_poll=now+0.1
        if owner_field(R.manager,"_IsTalkingAny")~=false then cleanup("Dialogue began during test"); return end
        local state=snapshot()
        R.receipt.last_sample=state
        R.receipt.elapsed_seconds=now-R.started
        if state.controller_ready==true and state.prefab_ready==true then
            R.receipt.loaded=true
            if hold then
                R.state="ready_held"; R.status="Dialogue resource held for owned instance."
                save("ready_held")
            else cleanup("Resource ready; no instance requested") end
        elseif now-R.started>=20 then cleanup("Timed out waiting for resource readiness") end
    end)
    if not ok then
        R.receipt=R.receipt or {revision=1,path=PATH}
        R.receipt.error=tostring(err)
        cleanup("Failed: "..tostring(err))
    end
end
function R.cancel()
    if R.state=="queued" then
        R.state="stopped"; R.status="Dialogue clone load cancelled before starting."
    elseif R.state=="loading" or R.state=="ready_held" then cleanup("Cancelled or owned lease released") end
end
function R.request_cancel() R.cancel_requested=true end
return R
end
local R=session(false)
function R.new_lease() return session(true) end
function R.new_vocation_test() return session(false,true) end
function R.new_vocation_lease() return session(true,true) end
return R
