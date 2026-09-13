local P={state="idle",status="Prefab loading API inspection has not run."}
local FILE="ImmersiveInteractables_PrefabLoader32.json"
local TARGET="appsystem/clone/prefab/bestfriendlynpcclone.pfb"
local TYPES={"via.Prefab","via.PrefabResourceHolder","via.ResourceHolder",
    "via.ResourceManager","via.Folder","app.PrefabController",
    "app.ResourceStandbyMediator","app.PrefabInstantiateManager",
    "app.PrefabInstantiateRequestManager","via.PrefabManager"}
local function attempt(fn)
    local ok,v=pcall(fn)
    if ok then return v end
    return nil,tostring(v)
end
local function persist()
    local ok,result=pcall(json.dump_file,FILE,P.receipt)
    assert(ok and result~=false,"Loader receipt write failed: "..tostring(result))
end
local function stage(label)
    P.receipt.stage=label
    persist()
    P.status="Inspecting prefab loading API: "..label
end
local function problem(row,err)
    row.error=tostring(err)
    P.receipt.errors=P.receipt.errors+1
end
local function signature(m)
    local params={}
    for _,t in ipairs(m:get_param_types() or {}) do params[#params+1]=t:get_full_name() end
    return {name=m:get_name(),params=params,returns=m:get_return_type():get_full_name(),
        static=m:is_static()==true}
end
local function inspect(name)
    local row={requested=name,chain={}}
    P.receipt.types[#P.receipt.types+1]=row
    local td=sdk.find_type_definition(name)
    row.present=td~=nil
    local seen={}
    for depth=1,8 do
        if not td then break end
        local full=td:get_full_name()
        if seen[full] then problem(row,"Parent type cycle: "..full); break end
        seen[full]=true
        local part={type=full,methods={},fields={}}
        row.chain[#row.chain+1]=part
        part.value_type=td:is_value_type()
        part.resource_holder=td:is_a("via.ResourceHolder")
        if full=="System.Object" then break end
        local fields=td:get_fields() or {}
        if #fields>512 then problem(part,"Field limit exceeded"); break end
        for _,f in ipairs(fields) do
            part.fields[#part.fields+1]={name=f:get_name(),type=f:get_type():get_full_name(),static=f:is_static()==true}
        end
        local methods=td:get_methods() or {}
        if #methods>512 then problem(part,"Method limit exceeded"); break end
        for _,m in ipairs(methods) do part.methods[#part.methods+1]=signature(m) end
        if full=="via.Prefab" then
            part.lookups={}
            for _,key in ipairs({".ctor()","set_Path(System.String)","get_Path()","set_Standby(System.Boolean)"}) do
                local entry={query=key}; part.lookups[#part.lookups+1]=entry
                local m,err=attempt(function() return td:get_method(key) end)
                entry.present=m~=nil; entry.error=err
                if m then entry.signature=signature(m) end
            end
        end
        td=td:get_parent_type()
        if depth==8 and td then problem(row,"Parent depth limit exceeded") end
    end
end
local function finish()
    local out=P.receipt
    out.factory_candidates={}
    out.path_setter_enumerated=false
    out.path_setter_resolved=false
    local seen={}
    for _,row in ipairs(out.types) do
        for _,part in ipairs(row.chain) do
            for _,m in ipairs(part.methods) do
                if part.type=="via.Prefab" and m.name=="set_Path" and #m.params==1
                        and m.params[1]=="System.String" and m.returns=="System.Void" and not m.static then
                    out.path_setter_enumerated=true
                end
                local string_arg=false
                for _,p in ipairs(m.params) do if p=="System.String" then string_arg=true end end
                if m.static and string_arg and m.returns=="via.Prefab" then
                    local key=part.type.."."..m.name.."("..table.concat(m.params,",")..")"
                    if not seen[key] then out.factory_candidates[#out.factory_candidates+1]=key; seen[key]=true end
                end
            end
            for _,lookup in ipairs(part.lookups or {}) do
                local m=lookup.signature
                if lookup.query=="set_Path(System.String)" and m and m.name=="set_Path"
                        and #m.params==1 and m.params[1]=="System.String"
                        and m.returns=="System.Void" and not m.static then out.path_setter_resolved=true end
            end
        end
    end
    out.stage=out.errors==0 and "complete" or "complete_with_errors"
    out.warning="Metadata only: candidates are not validated loaders; no native loading or spawning attempted."
    persist()
    P.state="done"
    P.status=out.errors==0 and "Prefab loading API capture saved (no loading/spawning)."
        or "Prefab loading API capture saved with read errors; see receipt."
end
function P.request()
    if P.state=="queued" or P.state=="running" then return false end
    P.state="queued"; P.status="Prefab loading API capture queued; leave the world unpaused briefly."
    return true
end
function P.tick()
    if P.state~="queued" and P.state~="running" then return end
    local ok,err=pcall(function()
        if P.state=="queued" then
            P.receipt={revision=1,time=os.date("%Y-%m-%d %H:%M:%S"),target=TARGET,
                types={},errors=0,stage="started",mode="metadata_only",
                transform_guard=rawget(_G,"RS32Gate") and _G.RS32Gate.block_xform_setters==true or false}
            persist()
            P.index=1; P.state="running"
            return
        end
        local name=TYPES[P.index]
        if not name then finish(); return end
        stage(name)
        local good,why=pcall(inspect,name)
        if not good then
            local row=P.receipt.types[#P.receipt.types]
            problem(row,why)
        end
        P.index=P.index+1
    end)
    if not ok then
        P.state="failed"; P.status="Prefab loading API capture failed: "..tostring(err)
    end
end
function P.cancel()
    if P.state~="queued" and P.state~="running" then return end
    P.state="cancelled"; P.status="Prefab loading API capture cancelled."
    if P.receipt then
        P.receipt.stage="cancelled"; pcall(persist)
    end
end
return P
