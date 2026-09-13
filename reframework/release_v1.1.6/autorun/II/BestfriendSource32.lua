local C = require("II.Compat32")
local P = {status="Bestfriend source inspection has not run.", pending=false}
local TARGET = "appsystem/clone/prefab/bestfriendlynpcclone.pfb"
local function attempt(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return nil, tostring(value)
end
local function field(obj, name)
    assert(obj:get_type_definition():get_field(name), "Current field unavailable: "..name)
    return obj:get_field(name)
end
local function getter(obj, name, result)
    local method = C.method(obj:get_type_definition():get_full_name(), name, {})
    assert(method:get_return_type():get_full_name()==result, "Unexpected return type: "..name)
    return method:call(obj)
end
function P.request() P.pending=true end
function P.capture()
    P.pending=false
    local receipt={revision=1,time=os.date("%Y-%m-%d %H:%M:%S"),stage="started",sources={},types={}}
    local chosen, keeper
    local function save()
        local ok, result=pcall(json.dump_file,"ImmersiveInteractables_BestfriendSources32.json",receipt)
        assert(ok and result~=false,"Bestfriend source receipt write failed: "..tostring(result))
    end
    save()
    local function inspect(label, resolve)
        local row={source=label}; receipt.sources[#receipt.sources+1]=row
        local ok, err=pcall(function()
            local prefab, owner=resolve()
            row.present=prefab~=nil
            if not prefab then return end
            row.type=prefab:get_type_definition():get_full_name()
            assert(row.type=="via.Prefab", "Source is not a via.Prefab")
            row.path=getter(prefab,"get_Path","System.String")
            row.match=type(row.path)=="string" and row.path:gsub("\\","/"):lower()==TARGET
            row.ready=getter(prefab,"get_Ready","System.Boolean")
            if row.match and row.ready==true and not chosen then
                prefab:add_ref()
                if owner then owner:add_ref() end
                chosen,keeper=prefab,owner
                receipt.selected=label
            end
        end)
        if not ok then row.error=tostring(err) end
    end
    inspect("TalkEventManager._ClonePrefabController",function()
        local manager=sdk.get_managed_singleton("app.TalkEventManager")
        if not manager then return nil end
        local ctrl=field(manager,"_ClonePrefabController")
        if not ctrl then return nil end
        return getter(ctrl,"get_Item","via.Prefab"),ctrl
    end)
    local ok,err=pcall(function()
        local sm=sdk.get_native_singleton("via.SceneManager")
        local td=sdk.find_type_definition("via.SceneManager")
        local scene=sm and td and sdk.call_native_func(sm,td,"get_CurrentScene")
        assert(scene,"Current scene unavailable")
        local arr=scene:call("findComponents(System.Type)",sdk.typeof("app.BestFriendlyNPCCloneGenerator"))
        if arr then arr:add_ref() end
        receipt.generators=arr and tonumber(arr:call("get_Length")) or 0
        receipt.truncated=receipt.generators>64
        for i=0,math.min(receipt.generators,64)-1 do
            inspect("BestFriendlyNPCCloneGenerator["..i.."].NPCClonePrefab",function()
                local gen=arr:get_element(i)
                assert(gen,"Generator expired")
                return field(gen,"NPCClonePrefab"),gen
            end)
        end
    end)
    if not ok then receipt.scene_error=tostring(err) end
    for _,name in ipairs({"app.TalkEventManager","app.PrefabController",
            "app.BestFriendlyNPCCloneGenerator","app.CloneBuilder"}) do
        local row={type=name,fields={},methods={}}; receipt.types[#receipt.types+1]=row
        local _,why=attempt(function()
            local td=sdk.find_type_definition(name)
            row.present=td~=nil
            if not td then return end
            for _,f in ipairs(td:get_fields() or {}) do
                row.fields[#row.fields+1]=f:get_name()..": "..f:get_type():get_full_name()
            end
            for _,m in ipairs(td:get_methods() or {}) do
                local params={}
                for _,p in ipairs(m:get_param_types() or {}) do params[#params+1]=p:get_full_name() end
                row.methods[#row.methods+1]=m:get_name().."("..table.concat(params,",")..") -> "..m:get_return_type():get_full_name()
            end
        end)
        row.error=why
    end
    receipt.stage="complete"
    receipt.ready_bestfriend=chosen~=nil
    save()
    P.status=chosen and "Ready bestfriend source found; spawning/positioning still gated."
        or "Bestfriend sources saved; no ready bestfriend prefab found."
    return chosen,keeper,receipt
end
function P.tick()
    if not P.pending then return end
    local ok,err=pcall(P.capture)
    if not ok then P.status="Bestfriend source inspection failed: "..tostring(err) end
end
return P
