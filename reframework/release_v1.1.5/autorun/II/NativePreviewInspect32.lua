local P={status="Open Equipment, wait for the character preview, then capture."}
local specs={
    {name="app.MockupCtrl",fields={"IsCreated","IsDisp","Obj","CamObj","CompBuilder",
        "TexMockup","DefaultRTT","Output","DispData","ReqData"}},
    {name="app.GUIMenuMockupList",fields={"IsActive","MockupCtrlList","MockupObj","ModelList"}},
    {name="app.MockupBuilder",fields={"LoadState","IsCapture","IsFreeze","Tex","DispEquip"}},
}
local function attempt(fn)
    local ok,v=pcall(fn)
    if ok then return v end
    return nil,tostring(v)
end
local function describe(v)
    if v==nil then return {present=false} end
    if type(v)=="boolean" or type(v)=="number" or type(v)=="string" then return {value=v} end
    local out={present=true}
    out.type,out.error=attempt(function() return v:get_type_definition():get_full_name() end)
    out.address=attempt(function() return tostring(v:get_address()) end)
    if out.type=="via.GameObject" then
        out.name=attempt(function() return v:call("get_Name") end)
        out.draw=attempt(function() return v:call("get_DrawSelf") end)
    end
    return out
end
function P.capture()
    local out={revision=1,time=os.date("%Y-%m-%d %H:%M:%S"),stage="started",components={},resources={}}
    local function save()
        local ok,res=pcall(json.dump_file,"ImmersiveInteractables_NativePreview32.json",out)
        assert(ok and res~=false,"preview snapshot could not be saved: "..tostring(res))
    end
    save()
    local ok,err=pcall(function()
        local gm=sdk.get_managed_singleton("app.GuiManager")
        for _,field in ipairs({"MockupModelPrefab","MockupCameraPrefab"}) do
            local row={field=field}; out.resources[#out.resources+1]=row
            local obj,e=attempt(function() return gm and gm:get_field(field) end)
            row.object=describe(obj); row.error=e
            if obj then
                for _,prop in ipairs({"Path","Ready","Valid","Exist"}) do
                    row[prop],row[prop.."_error"]=attempt(function() return obj:call("get_"..prop) end)
                end
            end
        end
        local scene=sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"),"get_CurrentScene")
        assert(scene,"current scene unavailable")
        for _,spec in ipairs(specs) do
            local group={type=spec.name,objects={},methods={}}; out.components[#out.components+1]=group
            local td=sdk.find_type_definition(spec.name)
            if td then
                for _,m in ipairs(td:get_methods() or {}) do
                    local params={}
                    for _,t in ipairs(m:get_param_types() or {}) do params[#params+1]=t:get_full_name() end
                    group.methods[#group.methods+1]=m:get_name().."("..table.concat(params,",")..") -> "..m:get_return_type():get_full_name()
                end
                local arr=scene:call("findComponents(System.Type)",sdk.typeof(spec.name))
                if arr then arr:add_ref() end
                group.count=arr and tonumber(arr:call("get_Length")) or 0
                group.truncated=group.count>24
                for i=0,math.min(group.count,24)-1 do
                    local row={index=i,fields={}}; group.objects[#group.objects+1]=row
                    local good,why=pcall(function()
                        local obj=arr:get_element(i)
                        assert(obj,"component unavailable")
                        obj:add_ref()
                        row.object=describe(obj)
                        row.owner=describe(obj:call("get_GameObject"))
                        for _,field in ipairs(spec.fields) do
                            if td:get_field(field) then
                                local value,e=attempt(function() return obj:get_field(field) end)
                                row.fields[field]=describe(value); row.fields[field].error=e
                            else row.fields[field]={missing=true} end
                        end
                    end)
                    if not good then row.error=tostring(why) end
                end
            else group.missing=true end
            save()
        end
    end)
    out.stage=ok and "complete" or "failed"; out.error=not ok and tostring(err) or nil
    save()
    P.status=ok and "Native preview snapshot saved (read-only)." or "Preview snapshot failed: "..tostring(err)
    return out
end
return P
