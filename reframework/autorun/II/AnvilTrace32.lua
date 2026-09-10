local A = {}
function A.mark(label) end
function A.snapshot()
    local result = {}
    local function read(label, fn)
        local ok, value = pcall(fn)
        if ok and (type(value)=="boolean" or type(value)=="number" or type(value)=="string") then
            result[label]=value
        else result[label]="unknown" end
    end
    local function singleton(tn)
        local ok, obj=pcall(sdk.get_managed_singleton,tn)
        return ok and obj or nil
    end
    local gm=singleton("app.GuiManager")
    for _, field in ipairs({"_BlockMenu","IsMenuUIPause","MenuUIObservedCounter","IsRequestGUIPause"}) do
        read(field,function() return gm and gm:get_field(field) end)
    end
    read("menuType",function()
        if not gm then return nil end
        local menu=gm:get_field("MenuUI")
        return menu and menu:get_type_definition():get_full_name() or "none"
    end)
    if result.menuType == "app.ui041101_00" then
        local menu
        pcall(function() menu=gm:get_field("MenuUI") end)
        for _,field in ipairs({"IsInit","FlowNow","FlowReturn","WaitInput",
                "<ShopType>k__BackingField","<IsElf>k__BackingField","<IsResetShop>k__BackingField"}) do
            read("enhance."..field,function() return menu:get_field(field) end)
        end
        read("enhance.MenuFace",function()
            local face=menu:get_field("MenuFace")
            return face and face:get_type_definition():get_full_name() or "none"
        end)
    end
    local cm=singleton("app.CharacterManager")
    local player
    pcall(function() player=cm and cm:call("get_ManualPlayer") end)
    read("jacked",function() return player and player:call("get_IsJacked") end)
    read("interacting",function()
        local im=singleton("app.InteractManager")
        return player and im and im:call("isInteracting(app.Character)",player)
    end)
    read("action0",function()
        local am=player and player:call("get_ActionManager")
        local list=am and am:get_field("CurrentActionList")
        local action=list and list:call("get_Item",0)
        return action and action:get_field("Name")
    end)
    return result
end
local GUI = "app.GuiDefine.GuiType"
local SCENES = "System.Collections.Generic.List`1<app.GuiDefine.GUISceneType>"
local CALLBACK = "System.Action`1<app.GUIBase>"
local specs = {
    {"requestEnhanceEquip2", {"app.EnhanceType", "System.Boolean", "System.Boolean"}},
    {"requestEnhanceEquipReset", {}},
    {"requestGuiType", {GUI}},
    {"setLoadGuiType", {GUI, "System.Boolean", "System.Boolean"}},
    {"removeLoadGuiType", {GUI}},
    {"requestHideGuiType", {GUI}},
    {"requestLoadScene", {SCENES}},
    {"requestMenuUI", {GUI, "System.Boolean", CALLBACK, "System.Boolean"}, "System.Boolean"},
    {"requestGUIPause", {"System.Boolean"}},
    {"endMenuUI", {}},
    {"clearMenuUI", {}},
}
function A.install()
    local path = "ImmersiveInteractables_AnvilNativeTrace.json"
    local state = {revision=4, started=os.date("%Y-%m-%d %H:%M:%S"), methods={}, enums={}, events={}, contexts={}}
    state.previous = {}
    pcall(function()
        local old = json.load_file(path)
        if type(old) ~= "table" then return end
        for _, capture in ipairs(old.previous or {}) do state.previous[#state.previous + 1] = capture end
        state.previous[#state.previous + 1] = {started=old.started, methods=old.methods,
            enums=old.enums, events=old.events, contexts=old.contexts, enhancement_seen=old.enhancement_seen}
        while #state.previous > 3 do table.remove(state.previous, 1) end
    end)
    local enabled, dirty, until_at, last_save, seq = A.default_capture==true, true, nil, 0, 0
    local context_queue={}
    A.mark=function(label)
        if not enabled then return end
        for _, delay in ipairs({0,0.5,2}) do
            context_queue[#context_queue+1]={label=tostring(label),at=os.clock()+delay,delay=delay}
        end
        while #context_queue>24 do table.remove(context_queue,1) end
    end
    re.on_application_entry("LateUpdateBehavior",function()
        if not enabled then return end
        local now=os.clock()
        for i=#context_queue,1,-1 do
            local q=context_queue[i]
            if now>=q.at then
                table.remove(context_queue,i)
                local ok, sample=pcall(A.snapshot)
                state.contexts[#state.contexts+1]={label=q.label,delay=q.delay,clock=now,
                    time=os.date("%Y-%m-%d %H:%M:%S"),values=ok and sample or {error=tostring(sample)}}
                while #state.contexts>96 do table.remove(state.contexts,1) end
                dirty=true
            end
        end
    end)
    local function push(name, data)
        if not enabled then return end
        local last=state.events[#state.events]
        if name=="requestGUIPause" and last and last.event==name and last.args[1]==data[1] then
            last.repeats=(last.repeats or 1)+1; last.last_clock=os.clock(); dirty=true
            return
        end
        seq = seq + 1
        state.events[#state.events + 1] = {sequence=seq, time=os.date("%Y-%m-%d %H:%M:%S"),
            event=name, args=data, clock=os.clock()}
        while #state.events > 256 do table.remove(state.events, 1) end
        dirty = true
    end
    local function integer(raw)
        local v = sdk.to_int64(raw) & 0xFFFFFFFF
        return v >= 0x80000000 and v - 0x100000000 or v
    end
    local td = sdk.find_type_definition("app.GuiManager")
    for _, spec in ipairs(specs) do
        local entry = {name=spec[1], params=spec[2], installed=false}
        state.methods[#state.methods + 1] = entry
        local ok, err = pcall(function()
            local selected
            for _, m in ipairs(td and td:get_methods() or {}) do
                if m:get_name() == spec[1] then
                    local pts, same = m:get_param_types() or {}, true
                    if #pts == #spec[2] then
                        for i, p in ipairs(pts) do
                            if p:get_full_name() ~= spec[2][i] then same = false; break end
                        end
                        if same then
                            assert(not selected, "Ambiguous signature")
                            assert(m:is_static() == false, "Expected instance method")
                            assert(m:get_return_type():get_full_name() == (spec[3] or "System.Void"), "Unexpected return type")
                            selected = m
                        end
                    end
                end
            end
            assert(selected, "Signature absent on this build")
            sdk.hook(selected, function(args)
                if not enabled then return end
                local decoded = {}
                local decoded_ok, decoded_err = pcall(function()
                    for i, kind in ipairs(spec[2]) do
                        local raw = args[i + 2]
                        if kind == "System.Boolean" then
                            decoded[i] = (sdk.to_int64(raw) & 0xFF) ~= 0
                        elseif kind == CALLBACK then
                            decoded[i] = {present=sdk.to_int64(raw) ~= 0}
                        elseif kind == SCENES then
                            local list = sdk.to_managed_object(raw)
                            local scene_ids = {}
                            if list then
                                local n = tonumber(list:call("get_Count"))
                                assert(n and n >= 0 and n <= 32, "Invalid scene-list count")
                                for k = 0, n - 1 do scene_ids[#scene_ids + 1] = tonumber(list:call("get_Item", k)) end
                            end
                            decoded[i] = scene_ids
                        else decoded[i] = integer(raw) end
                    end
                end)
                if not decoded_ok then decoded = {decode_error=tostring(decoded_err)} end
                pcall(function()
                    push(spec[1], decoded)
                    if spec[1] == "requestEnhanceEquip2" then
                        until_at = os.clock() + 90
                        state.enhancement_seen = true
                        A.mark("native enhancement entry")
                    elseif spec[1] == "endMenuUI" then
                        A.mark("native endMenuUI")
                    end
                end)
                return nil
            end, function(retval)
                if spec[1] == "requestMenuUI" then
                    pcall(function() push("requestMenuUI return", {(sdk.to_int64(retval) & 0xFF) ~= 0}) end)
                end
                return retval
            end)
            entry.installed = true
        end)
        if not ok then entry.error = tostring(err) end
    end
    for _, tn in ipairs({GUI, "app.GuiDefine.GUISceneType", "app.EnhanceType"}) do
        local map = {}; state.enums[tn] = map
        pcall(function()
            local et = sdk.find_type_definition(tn)
            for _, f in ipairs(et and et:get_fields() or {}) do
                if f:is_static() then
                    local ok, value = pcall(function() return tonumber(f:get_data(nil)) end)
                    if ok and value ~= nil then map[f:get_name()] = value end
                end
            end
        end)
    end
    re.on_frame(function()
        if enabled and until_at and os.clock() >= until_at then enabled=false; dirty=true end
        if dirty and os.clock() - last_save >= 1 then
            last_save = os.clock()
            state.capturing = enabled
            local ok, err = pcall(json.dump_file, path, state)
            if ok then dirty=false else state.save_error=tostring(err) end
        end
    end)
    re.on_draw_ui(function()
        if imgui.tree_node("Anvil native-menu trace (diagnostic)") then
            imgui.text(enabled and "Capturing GUI requests; visit a normal blacksmith." or "Capture stopped; evidence saved.")
            imgui.text("Open Enhance Equipment, then back out. No purchase/upgrade needed.")
            for _, entry in ipairs(state.methods) do
                if not entry.installed then imgui.text(entry.name .. ": " .. tostring(entry.error)) end
            end
            if imgui.button("Start a fresh capture") then
                state.events, state.contexts, state.enhancement_seen = {}, {}, nil
                context_queue={}
                state.started = os.date("%Y-%m-%d %H:%M:%S")
                enabled, until_at, dirty, seq = true, nil, true, 0
            end
            if imgui.button("Capture idle comparison") then A.mark("manual idle") end
            if imgui.button("Stop capture") then enabled=false; dirty=true end
            imgui.tree_pop()
        end
    end)
    re.on_script_reset(function()
        pcall(function() push("script reset", {}); state.capturing=false; json.dump_file(path, state) end)
    end)
    return state
end
return A
