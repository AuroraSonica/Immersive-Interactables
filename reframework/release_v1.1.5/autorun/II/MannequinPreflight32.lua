local P={}
local function attempt(fn)
    local ok,v=pcall(fn)
    if ok then return v end
    return nil,tostring(v)
end
function P.capture()
    local gate=rawget(_G,"RS32Gate")
    local out={revision=2,time=os.date("%Y-%m-%d %H:%M:%S"),
        transform_blocked=gate and gate.block_xform_setters==true or false,
        sources={},methods={}}
    local function save()
        local ok,res=pcall(json.dump_file,"ImmersiveInteractables_MannequinPreflight32.json",out)
        assert(ok and res~=false,"mannequin receipt write failed: "..tostring(res))
    end
    out.stage="started"; save()
    local gm=attempt(function() return sdk.get_managed_singleton("app.GuiManager") end)
    for _,field in ipairs({"MockupModelPrefab","MockupCameraPrefab"}) do
        local row={field=field}
        out.sources[#out.sources+1]=row
        local pfb,err=attempt(function() return gm and gm:get_field(field) end)
        row.present=pfb~=nil; row.error=err
        if pfb then
            for _,name in ipairs({"Path","Ready","Valid","Exist"}) do
                local v,e=attempt(function() return pfb:call("get_"..name) end)
                if type(v)=="string" or type(v)=="boolean" then row[name]=v end
                if e then row[name.."_error"]=e end
            end
        end
    end
    out.stage="sources read"; save()
    for _,tn in ipairs({"via.Prefab","via.PrefabManager","via.PrefabResourceHolder",
            "app.MockupBuilder","app.GUIMenuMockupList"}) do
        local row={type=tn,signatures={}}
        out.methods[#out.methods+1]=row
        local td=attempt(function() return sdk.find_type_definition(tn) end)
        row.present=td~=nil
        if td then
            local methods,err=attempt(function() return td:get_methods() end)
            row.error=err
            for _,m in ipairs(methods or {}) do
                local sig=attempt(function()
                    local params={}
                    for _,p in ipairs(m:get_param_types() or {}) do params[#params+1]=p:get_full_name() end
                    return m:get_name().."("..table.concat(params,",")..") -> "..m:get_return_type():get_full_name()
                end)
                if sig then row.signatures[#row.signatures+1]=sig end
            end
        end
    end
    out.stage="complete"; save()
    return out
end
return P
