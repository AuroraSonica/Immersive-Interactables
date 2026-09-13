local R={}
local function read(fn)
    local ok,v=pcall(fn)
    if ok then return v end
    return nil,tostring(v)
end
function R.ensure_registered(io,go,now)
    if io:call("get_IsRegistered()") == true then
        local updated=io:call("get_IsUpdatedAfterRegisterd()") == true
        return updated, updated and "registered and updated" or "registered; awaiting first native update"
    end
    if R.registration and R.registration.io==io then
        return false, "registration already attempted; native registration still absent"
    end
    assert(tostring(go:call("get_Name")):lower()=="gm51_752","not the captured throne")
    assert(io:call("get_Valid()") == true,"invalid throne interaction")
    assert(io:call("isOwnerUpdateForSystem()") == true,"throne owner is not updating")
    local owner=assert(io:call("get_Owner()"),"interaction has no owner")
    assert(owner:get_address()==go:get_address(),"interaction belongs to another object")
    local mgr=assert(sdk.get_managed_singleton("app.InteractManager"),"InteractManager unavailable")
    local method=require("II.Compat32").method("app.InteractManager","register",{"app.InteractiveObject"})
    assert(method:get_return_type():get_full_name()=="System.Void","register return mismatch")
    R.registration={io=io,at=now}
    method:call(mgr,io)
    return false, "native registration requested; waiting for normal engine update"
end
function R.result_name(value)
    local td=sdk.find_type_definition("app.InteractManager.InteractRequestResultType")
    for _,name in ipairs({"NotProcessed","Denied","Accepted"}) do
        local n=read(function() return tonumber(td:get_field(name):get_data(nil)) end)
        if n~=nil and n==value then return name end
    end
    return "Unknown("..tostring(value)..")"
end
function R.poll(q,now)
    if now<(q.poll_at or 0) then return end
    q.poll_at=now+0.1
    local value,err=read(function() return tonumber(q.result:get_field("ResultType")) end)
    if value==nil then return "ReadError: "..tostring(err) end
    local name=R.result_name(value)
    if name~="NotProcessed" then return name end
    if now-q.started>=5 then return "TimedOut(NotProcessed)" end
end
function R.capture(owner,io,ch,status)
    local out={time=os.date("%Y-%m-%d %H:%M:%S"),status=status,checks={},works={},data={}}
    local function scalar(dst,key,fn)
        local v,e=read(fn)
        if type(v)=="boolean" or type(v)=="number" or type(v)=="string" then dst[key]=v
        else dst[key]=e or "unavailable" end
    end
    for _,method in ipairs({"get_Valid","get_IsRegistered","get_IsUpdatedAfterRegisterd","isOwnerUpdateForSystem"}) do
        scalar(out.checks,method,function() return io:call(method.."()") end)
    end
    scalar(out.checks,"canPlayer",function() return io:call("canPlayerInteract(System.UInt32)",0) end)
    scalar(out.checks,"enabled",function() return io:call("isInteractEnable(System.UInt32, app.Character)",0,ch) end)
    scalar(out.checks,"withoutCoordinates",function()
        return io:call("canCharacterInteractWithoutCoordCondition(System.UInt32, app.Character)",0,ch)
    end)
    scalar(out.checks,"jacked",function() return ch:call("get_IsJacked") end)
    scalar(out.checks,"chairEnabled",function() return owner:call("isInteractEnable(System.UInt32)",0) end)
    for _,spec in ipairs({{"Works",out.works,{"IsCoordCalculated","PointNo","_canPlayerInteract","_IsInteractEnable"}},
            {"DataList",out.data,{"CharacterType","IsFixCoord","IsNotifyOnly","ParentJointName","Distance","IsDrawIcon"}}}) do
        local list,err=read(function() return io:get_field(spec[1]) end)
        if not list then spec[2].error=err or "absent" else
            local first,e=read(function() return list:call("get_Item(System.Int32)",0) end)
            if not first then spec[2].error=e or "empty" else
                for _,f in ipairs(spec[3]) do scalar(spec[2],f,function() return first:get_field(f) end) end
                if spec[1]=="Works" then
                    scalar(spec[2],"hasOwnerTransform",function() return first:get_field("OwnerTransform")~=nil end)
                    local p=read(function() return first:get_field("Position") end)
                    if p then
                        out.works.position=read(function() return {x=p.x,y=p.y,z=p.z} end)
                    end
                    out.works.coordinate_methods=read(function()
                        local signatures={}
                        for _,m in ipairs(first:get_type_definition():get_methods() or {}) do
                            local name=m:get_name()
                            if name=="init" or name=="setup" or name=="updateCoord" or name=="calcBaseCoord" then
                                local params={}
                                for _,pt in ipairs(m:get_param_types() or {}) do params[#params+1]=pt:get_full_name() end
                                signatures[#signatures+1]=name.."("..table.concat(params,",")..") -> "..m:get_return_type():get_full_name()
                            end
                        end
                        return signatures
                    end)
                end
            end
        end
    end
    local ok,err=pcall(json.dump_file,"ImmersiveInteractables_ThroneRequest32.json",out)
    if not ok then error(err) end
    return out
end
return R
