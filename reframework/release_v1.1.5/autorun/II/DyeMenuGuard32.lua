local D={revision=3,alive=true,ready=false,blocked=0,calls=0,queue_calls=0,queue_blocked=0,events={}}
local C=require("II.Compat32")
local dirty,next_save=true,0
local function record(route,raw,kind,blocked)
    if #D.events>=32 then return end
    D.events[#D.events+1]={route=route,raw=tostring(raw),kind=kind,blocked=blocked}
    dirty=true
end
function D.flush(force)
    local now=os.clock()
    if not dirty or (not force and now<next_save) then return end
    next_save=now+1
    local ok=pcall(json.dump_file,"ImmersiveInteractables_DyeMenuGuard32.json",{
        revision=D.revision,time=os.date(),ready=D.ready,alive=D.alive,
        blocked=D.blocked,calls=D.calls,queue_calls=D.queue_calls,queue_blocked=D.queue_blocked,
        error=D.error,queue_error=D.queue_error,
        enums=D.enums,events=D.events,previous=D.previous})
    if ok then dirty=false end
end
function D.install(active)
    pcall(function()
        local old=json.load_file("ImmersiveInteractables_DyeMenuGuard32.json")
        if type(old)~="table" then return end
        D.previous=old.previous
        if type(old.events)=="table" and #old.events>0 then
            D.previous={revision=old.revision,time=old.time,ready=old.ready,
                error=old.error,blocked=old.blocked,calls=old.calls,
                queue_calls=old.queue_calls,queue_blocked=old.queue_blocked,events=old.events}
        end
    end)
    local ok,err=pcall(function()
        local tn="app.GuiDefine.GuiType"
        local pause,map=C.enum(tn,"GameMenu"),C.enum(tn,"MapDirect")
        D.enums={GameMenu=pause,MapDirect=map}
        local method=C.method("app.GuiManager","requestMenuUI",{
            tn,"System.Boolean","System.Action`1<app.GUIBase>","System.Boolean"})
        assert(not method:is_static(),"Menu request unexpectedly static")
        assert(method:get_return_type():get_full_name()=="System.Boolean","Menu request return type changed")
        sdk.hook(method,function(args)
            local storage=thread.get_hook_storage()
            storage.ii_dye_menu_block=false
            if not D.alive then return end
            local ran,block=pcall(function()
                if active()~=true then return false end
                local raw=sdk.to_int64(args[3])
                local kind=raw & 0xFFFFFFFF
                local blocked=kind==pause or kind==map
                D.calls=D.calls+1
                record("requestMenuUI",raw,kind,blocked)
                return blocked
            end)
            if not ran and D.error~=tostring(block) then D.error=tostring(block); dirty=true end
            if ran and block then
                storage.ii_dye_menu_block=true
                D.blocked=D.blocked+1
                if D.blocked==1 then
                    pcall(function() log.info("[DyeMenuGuard32] pause/map request suppressed") end)
                end
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,function(retval)
            local storage=thread.get_hook_storage()
            local blocked=storage.ii_dye_menu_block
            storage.ii_dye_menu_block=nil
            if blocked then return sdk.to_ptr(0) end
            return retval
        end)
        local queued,queue_err=pcall(function()
            local queue=C.method("app.GuiManager","requestGuiType",{tn})
            assert(not queue:is_static() and queue:get_return_type():get_full_name()=="System.Void",
                "GUI queue signature changed")
            sdk.hook(queue,function(args)
                if not D.alive then return end
                local ran,block=pcall(function()
                    if active()~=true then return false end
                    local raw=sdk.to_int64(args[3])
                    local kind=raw & 0xFFFFFFFF
                    local blocked=kind==pause or kind==map
                    D.queue_calls=D.queue_calls+1
                    record("requestGuiType",raw,kind,blocked)
                    return blocked
                end)
                if not ran and D.queue_error~=tostring(block) then D.queue_error=tostring(block); dirty=true end
                if ran and block then
                    D.queue_blocked=D.queue_blocked+1
                    D.blocked=D.blocked+1
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end
            end,function(retval) return retval end)
        end)
        D.ready=queued
        if not queued then D.queue_error=tostring(queue_err); D.error=D.queue_error end
    end)
    if not ok then D.error=tostring(err) end
    dirty=true
    D.flush(true)
    re.on_frame(function() D.flush(false) end)
    re.on_script_reset(function() D.alive=false; D.ready=false; dirty=true; D.flush(true) end)
    return D.ready,D.error
end
return D
