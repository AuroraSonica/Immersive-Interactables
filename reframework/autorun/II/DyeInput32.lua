local D={ready=false,alive=true,draining=false,masks={}}
local C=require("II.Compat32")
function D.directions(mask)
    local out={}
    for name,bit in pairs(D.masks) do out[name]=D.ready and (mask & bit)~=0 or false end
    return out
end
function D.install(active,raw_mask)
    local ok,err=pcall(function()
        for name,enum in pairs({up="LUp",down="LDown",left="LLeft",right="LRight"}) do
            D.masks[name]=C.enum("via.hid.GamePadButton",enum)
        end
        local tn="app.PawnOrderController"
        local found,method=pcall(C.method,tn,"tryGetOrderInputNew",{})
        D.method=found and "tryGetOrderInputNew" or "tryGetOrderInput"
        if not found then method=C.method(tn,D.method,{}) end
        assert(not method:is_static(),"Pawn input reader unexpectedly static")
        assert(method:get_return_type():get_full_name()==tn..".PawnOrder","Pawn input return type changed")
        local none=C.enum(tn..".PawnOrder","None")
        sdk.hook(method,function()
            local storage=thread.get_hook_storage()
            storage.ii_dye_order_block=false
            if not D.alive then return end
            local ran,blocked=pcall(function()
                local owns=active()==true
                local held=false
                if D.draining and not owns then
                    local mask=raw_mask()
                    for _,bit in pairs(D.masks) do if (mask & bit)~=0 then held=true; break end end
                end
                D.draining=owns or held
                return D.draining
            end)
            if ran and blocked then
                D.blocked=(D.blocked or 0)+1
                if D.blocked==1 then pcall(function() log.info("[DyeInput32] blocked pawn input via "..D.method) end) end
                storage.ii_dye_order_block=true
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end,function(retval)
            local storage=thread.get_hook_storage()
            local blocked=storage.ii_dye_order_block
            storage.ii_dye_order_block=nil
            if blocked then return sdk.to_ptr(none) end
            return retval
        end)
        D.ready=true
    end)
    if not ok then D.ready=false; D.error=tostring(err) end
    re.on_script_reset(function() D.alive=false; D.draining=false; D.ready=false end)
    return D.ready,D.error
end
return D
