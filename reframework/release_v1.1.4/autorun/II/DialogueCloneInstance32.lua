local C=require("II.Compat32")
local Loader=require("II.DialogueCloneLoad32")
local function session(options)
options=options or {}
local R={state="idle",status="Separate dialogue mannequin test has not run."}
local FILE=options.receipt_path or (options.preview and "ImmersiveInteractables_DyePreview32.json" or "ImmersiveInteractables_DialogueCloneInstance32.json")
local function keep(o) assert(o,"Required object missing"); o:add_ref(); return o end
local function id(o) return o and o:get_address() end
local function save(stage)
    R.receipt.stage=stage
    local ok,v=pcall(json.dump_file,FILE,R.receipt)
    assert(ok and v~=false,"Cannot save clone receipt: "..tostring(v))
end
local function method(t,n,p,result,static)
    local m=C.method(t,n,p)
    assert(m:get_return_type():get_full_name()==result and m:is_static()==(static==true),
        "Unexpected current signature: "..t.."."..n)
    return m
end
local function valid(o)
    local v=o and o:call("get_Valid")
    assert(type(v)=="boolean","Cannot establish object validity")
    return v
end
local function player()
    local cm=assert(sdk.get_managed_singleton("app.CharacterManager"),"No character manager")
    local ch=assert(cm:call("get_ManualPlayer"),"No player")
    local go=assert(ch:call("get_GameObject"),"No player object")
    assert(valid(go),"Player object invalid")
    return ch,go
end
local function available()
    if options.preview then assert(options.allowed(),"Dye preview session has ended")
    else assert(not rawget(_G,"InteractablesDyeUIOpen"),"Close the dye menu first") end
    local ch,go=player()
    if not options.preview then assert(ch:call("get_IsJacked")==false,"Finish the current interaction first") end
    local gm=assert(sdk.get_managed_singleton("app.GuiManager"),"No GUI manager")
    assert(gm:call("get_IsLoadGui")==false and gm:call("isDispMenuUI")==false
        and gm:call("isPausedGUI")==false,"Close native menus and finish loading first")
    return ch,go
end
local function failed(reason)
    R.state="cleanup_failed"
    R.status="Clone cleanup unconfirmed; restart game. "..tostring(reason)
    R.receipt.error=tostring(reason); R.receipt.cleanup_confirmed=false
    pcall(save,"cleanup_failed")
end
local function finish()
    if R.lease then
        assert(not R.release_attempted,"Resource release already attempted; refusing retry")
        R.release_attempted=true
        R.lease.cancel()
        assert(R.lease.receipt and R.lease.receipt.cleanup_confirmed==true,
            "Resource lease cleanup unconfirmed")
    end
    R.receipt.cleanup_confirmed=true
    R.state="finished"
    R.status=R.receipt.build_completed and "Clone test finished; owned shell removed and resource released."
        or "Clone test stopped: "..tostring(R.receipt.result)
    R.inst,R.builder,R.ch,R.pgo,R.folder,R.lease=nil,nil,nil,nil,nil,nil
    save("finished")
end
local function destroy_owned(now)
    if options.detach then options.detach() end
    if R.spawn_unknown then error("Spawn may have taken effect without returning an owned handle") end
    if not R.inst then finish(); return end
    assert(R.owned and id(R.inst)==R.instance_id and id(R.inst)~=R.player_id,
        "Refusing destruction without owned-clone identity")
    if not valid(R.inst) then
        R.receipt.destroy_confirmed=true; finish(); return
    end
    if not R.destroy_attempted then
        save("destroy owned shell")
        R.destroy_attempted=true
        R.m.destroy:call(nil,R.inst)
    end
    R.state="removing"; R.remove_at=R.remove_at or now
    R.status="Removing test clone; wait before resetting scripts."
    if not valid(R.inst) then R.receipt.destroy_confirmed=true; finish() end
end
function R.active()
    return R.state~="idle" and R.state~="finished" and R.state~="cleanup_failed"
end
function R.request()
    if R.state~="idle" then return false end
    R.state="queued"; R.status="Clone test queued. Keep world unpaused; do not teleport/reset yet."
    return true
end
function R.request_stop() R.stop_requested=true end
function R.tick(now)
    if not R.active() then return end
    now=now or os.clock()
    if R.next_poll and now<R.next_poll then return end
    R.next_poll=now+0.1
    local ok,err=pcall(function()
        if R.state=="queued" then
            R.receipt={revision=1,time=os.date("%Y-%m-%d %H:%M:%S"),
                mode=options.preview and "dye_preview_likeness" or "owned_dialogue_clone_likeness",phase="pre-UpdateBehavior",cleanup_confirmed=false}
            if R.stop_requested then R.receipt.result="Cancelled before starting"; finish(); return end
            save("resolve instance signatures")
            R.m={
                spawn=method("via.Prefab","instantiate",{"via.Position","via.Folder"},"via.GameObject"),
                destroy=method("via.GameObject","destroy",{"via.GameObject"},"System.Void",true),
                component=method("via.GameObject","getComponent",{"System.Type"},"via.Component"),
                build=method("app.CloneBuilder","requestBuild",{"app.Character","System.Boolean",
                    "app.CharacterEditManager.BuildCompletedHandler"},"System.Boolean"),
                completed=method("app.CloneBuilder","get_Completed",{},"System.Boolean"),
                draw=method("via.GameObject","set_DrawSelf",{"System.Boolean"},"System.Void"),
                update=method("via.GameObject","set_UpdateSelf",{"System.Boolean"},"System.Void")}
            R.position_td=assert(sdk.find_type_definition("via.Position"))
            for _,axis in ipairs({"x","y","z"}) do
                local f=assert(R.position_td:get_field(axis),"Position field missing")
                assert(f:get_type():get_full_name()=="System.Double","Position coordinate is not Double")
            end
            R.builder_type=assert(sdk.typeof("app.CloneBuilder"))
            R.ch,R.pgo=available(); keep(R.ch); keep(R.pgo); R.player_id=id(R.pgo)
            R.receipt.player_address=tostring(R.player_id)
            R.lease=Loader.new_lease(); R.lease.request(); R.lease.tick(now)
            R.state="loading"; R.status="Loading clone resource; keep world unpaused."
            save("loading resource"); return
        end
        if R.state=="removing" then
            if not valid(R.inst) then R.receipt.destroy_confirmed=true; finish()
            elseif now-R.remove_at>5 then error("Owned shell destruction not confirmed in five seconds") end
            return
        end
        if R.state=="loading" then
            if R.stop_requested then R.receipt.result="Cancelled while loading"; finish(); return end
            R.lease.tick(now)
            if R.lease.state=="loading" or R.lease.state=="queued" then return end
            assert(R.lease.state=="ready_held",R.lease.status)
            assert(R.lease.manager:get_field("_IsTalkingAny")==false,"Dialogue started before spawn")
            local ch,go=available()
            assert(id(go)==R.player_id and id(ch)==id(R.ch),"Player changed during load")
            R.folder=keep(go:call("get_Folder"))
            local tf=assert(go:call("get_Transform"))
            local up=assert(tf:call("get_UniversalPosition"))
            local pos=ValueType.new(R.position_td)
            local xyz=options.preview and {x=up.x,y=up.y-30,z=up.z} or {x=up.x+2.0,y=up.y,z=up.z}
            for axis,v in pairs(xyz) do
                assert(type(v)=="number" and v==v and math.abs(v)<1e7,"Invalid spawn position")
                pos:set_field(axis,v)
            end
            R.receipt.spawn_position=xyz
            save("instantiate separate shell")
            R.spawn_unknown=true
            local inst=R.m.spawn:call(R.lease.prefab,pos,R.folder)
            assert(inst,"Instantiation returned no handle")
            assert(inst:get_type_definition():get_full_name()=="via.GameObject" and id(inst)~=R.player_id,
                "Instantiation did not return a separate GameObject")
            R.inst=inst; R.instance_id=id(inst); R.owned=true; R.spawn_unknown=false; keep(inst)
            R.receipt.instance_address=tostring(R.instance_id)
            assert(valid(inst),"Returned shell is invalid")
            R.m.draw:call(inst,true); R.m.update:call(inst,true)
            R.state="settling"; R.spawn_at=now
            R.status="Shell spawned; waiting briefly before likeness build."
            save("shell spawned"); return
        end
        if R.state=="settling" then
            if R.stop_requested then R.receipt.result="Cancelled before build"; destroy_owned(now); return end
            if now-R.spawn_at<0.5 then return end
            assert(R.lease.manager:get_field("_IsTalkingAny")==false,"Dialogue started before build")
            local ch,go=available()
            assert(id(go)==R.player_id and id(ch)==id(R.ch),"Player changed before build")
            assert(valid(R.inst),"Shell disappeared before build")
            R.builder=keep(R.m.component:call(R.inst,R.builder_type))
            assert(R.builder:get_type_definition():get_full_name()=="app.CloneBuilder","Wrong clone builder type")
            assert(id(R.builder:call("get_GameObject"))==R.instance_id,"Builder is not owned by shell")
            save("request player likeness")
            R.build_attempted=true; R.build_at=now; R.state="building"
            local accepted=R.m.build:call(R.builder,R.ch,false,nil)
            R.receipt.build_accepted=accepted==true
            if accepted~=true then R.stop_requested=true; R.receipt.result="Likeness request rejected" end
            R.status="Building player likeness; do not reset scripts while building."
            save("waiting for likeness"); return
        end
        if R.state=="building" then
            assert(valid(R.inst),"Shell disappeared during asynchronous build")
            if R.m.completed:call(R.builder)==true then
                R.receipt.build_completed=true
                if R.stop_requested then destroy_owned(now); return end
                R.state="display"; R.display_at=now
                R.status="Likeness built: inspect beside you. Auto-removal in 20 seconds; no dye applied."
                if options.ready then
                    save("attach preview pose")
                    options.ready(R.inst,R.pgo,R.builder)
                    R.status="Preview likeness ready."
                end
                save("likeness built")
            elseif now-R.build_at>30 then
                failed("Build not completed in 30 seconds; restart to clear pending native work")
            end
            return
        end
        if R.state=="display" then
            if R.stop_requested or (not options.preview and now-R.display_at>=20) then
                R.receipt.result="Display test ended"; destroy_owned(now)
            end
        end
    end)
    if not ok then
        R.receipt=R.receipt or {revision=1}
        R.receipt.result=tostring(err)
        if R.destroy_attempted or R.release_attempted or (R.build_attempted and not R.receipt.build_completed) then
            failed(err)
        else
            local cleaned,why=pcall(destroy_owned,now)
            if not cleaned then failed(tostring(err).."; "..tostring(why)) end
        end
    end
end
function R.reset()
    if not R.active() then return end
    if R.state=="queued" then R.state="finished"; return end
    if R.build_attempted and not R.receipt.build_completed then
        failed("Scripts reset with native build pending; restart game")
        return
    end
    local ok,err=pcall(destroy_owned,os.clock())
    if not ok then failed(err)
    elseif R.state=="removing" then
        failed("Scripts reset before native removal completed; resource not explicitly released; restart game")
    end
end
return R
end
local R=session()
function R.new_preview(options)
    assert(options and options.preview and type(options.allowed)=="function")
    return session(options)
end
return R
