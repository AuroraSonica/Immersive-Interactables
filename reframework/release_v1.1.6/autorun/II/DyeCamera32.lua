local C=require("II.Compat32")
local D={status="Dye camera input lock inactive.",alive=true}
local attempted,owner,framed
function D.release() owner=nil; framed=nil; D.status="Dye camera input lock released."; return true end
local function frame(ctrl,key)
    local identity=tostring(key)..":"..ctrl:get_address()
    if framed==identity then return end
    framed=identity
    local ok,err=pcall(function()
        local m=C.method("app.RotateCameraControllerBase","setPitch",{"System.Single"})
        assert(not m:is_static() and m:get_return_type():get_full_name()=="System.Void","Pitch signature changed")
        m:call(ctrl,0.0)
    end)
    D.frame_status=ok and "Level opening view requested." or "Opening view unavailable: "..tostring(err)
    pcall(json.dump_file,"ImmersiveInteractables_DyeFraming32.json",
        {time=os.date(),requested=ok,pitch=0,detail=D.frame_status})
end
function D.install()
    if attempted then return end
    attempted=true
    local ok,err=pcall(function()
        local m=C.method("app.RotateCameraControllerBase","updateManualCameraControl",{})
        assert(not m:is_static() and m:get_return_type():get_full_name()=="System.Void","Manual camera signature changed")
        sdk.hook(m,function(args)
            if not (D.alive and owner) then return end
            local ok,same=pcall(function()
                local obj=sdk.to_managed_object(args[2])
                return obj and obj:get_address()==owner
            end)
            if ok and same then
                D.hits=(D.hits or 0)+1
                if D.hits==1 then
                    pcall(json.dump_file,"ImmersiveInteractables_DyeCamera32.json",{stage="manual input suppressed",owner=owner})
                end
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,function(ret) return ret end)
        D.ready=true
    end)
    if not ok then
        D.status="Camera lock unavailable: "..tostring(err)
        pcall(json.dump_file,"ImmersiveInteractables_DyeCamera32.json",{stage="hook unavailable",error=tostring(err)})
    end
end
function D.tick(key,open)
    if not (open and key and D.alive) then if owner then D.release() end; return end
    D.install()
    if not D.ready then return end
    owner=nil
    local ok,err=pcall(function()
        local cm=assert(sdk.get_managed_singleton("app.CameraManager"))
        local main=assert(cm:get_field("_MainCameraControllers")[0])
        local ctrl=assert(main:get_field("_CurrentCameraController"))
        owner=ctrl:get_address()
        frame(ctrl,key)
    end)
    D.status=ok and "Manual camera lock active (mouse + right stick)." or "Camera unavailable: "..tostring(err)
end
re.on_script_reset(function() D.alive=false; D.release() end)
return D
