local C=require("II.Compat32")
local I={}
local function numeric_method(td,name,count)
    local found
    for _,m in ipairs(td:get_methods() or {}) do
        if m:get_name()==name and not m:is_static() then
            local ps=m:get_param_types() or {}; local good=#ps==count
            for _,p in ipairs(ps) do
                local n=p:get_full_name(); good=good and (n=="System.Int32" or n=="System.UInt32")
            end
            if good then assert(not found,"Ambiguous motion method: "..name); found=m end
        end
    end
    return assert(found,"No current motion method: "..name)
end
function I.apply(go)
    local receipt={time=os.date("%Y-%m-%d %H:%M:%S"),bank=0,motion=10,phase="pre-UpdateBehavior"}
    local function save(stage)
        receipt.stage=stage
        local ok,v=pcall(json.dump_file,"ImmersiveInteractables_PreviewIdle32.json",receipt)
        assert(ok and v~=false,"Cannot save idle receipt")
    end
    local ok,err=pcall(function()
        save("resolve owned motion")
        local motion=assert(go:call("getComponent(System.Type)",sdk.typeof("via.motion.Motion")),"Clone has no root motion component")
        assert(motion:call("get_GameObject"):get_address()==go:get_address(),"Motion belongs to another object")
        local td=motion:get_type_definition()
        local has=numeric_method(td,"hasMotion",2)
        assert(has:get_return_type():get_full_name()=="System.Boolean","hasMotion return changed")
        receipt.available=has:call(motion,0,10)==true
        if not receipt.available then save("idle absent; banks unchanged"); return end
        local layer=assert(numeric_method(td,"getLayer",1):call(motion,0),"No base motion layer")
        local change=C.method(layer:get_type_definition():get_full_name(),"changeMotion",{
            "System.UInt32","System.UInt32","System.Single","System.Single",
            "via.motion.InterpolationMode","via.motion.InterpolationCurve"})
        assert(not change:is_static() and change:get_return_type():get_full_name()=="System.Void","changeMotion signature changed")
        save("request owned idle")
        change:call(layer,0,10,0.0,4.0,1,1)
        receipt.requested=true; save("idle requested; visual confirmation needed")
    end)
    if not ok then receipt.error=tostring(err); pcall(save,"idle unavailable") end
    return receipt.requested==true,receipt.error or (receipt.available==false and "Clone lacks motion 0:10" or nil)
end
return I
