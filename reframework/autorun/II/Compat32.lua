local C = {}
local methods = {}
function C.anvil_gate(q, now, s)
    if not q or q.used or not q.started_at or now-q.started_at>12 then return "cancel" end
    if s.loading==true or s.menu==true or (q.actor and s.actor and q.actor~=s.actor)
            or (q.released and (s.interacting==true or s.jacked==true)) then return "cancel" end
    q.actor=q.actor or s.actor
    if s.interacting==false and s.jacked==false then q.released=true end
    local ready=s.actor~=nil and s.interacting==false and s.jacked==false
        and s.action=="NormalLocomotion" and s.loading==false and s.menu==false
        and s.paused==false and s.pause_requested==false and s.block==0
        and s.menu_type=="none" and s.input_released==true
    if not ready then q.stable_at=nil; q.last_sample=now; return "wait" end
    if q.last_sample and now-q.last_sample>0.3 then q.stable_at=nil end
    q.stable_at=q.stable_at or now
    q.last_sample=now
    return now-q.stable_at>=0.5 and "ready" or "wait"
end
function C.record_event(message)
    if not (message:find("tool ", 1, true) or message:find("bed ", 1, true)
            or message:find("anvil:", 1, true) or message:find("work ", 1, true)
            or message:find("menu state", 1, true)
            or message:find("release:", 1, true) or message:find("exit", 1, true)
            or message:find("update failed", 1, true) or message:find("throne", 1, true)
            or message:find("carry", 1, true) or message:find("chain", 1, true)) then return end
    local path = "ImmersiveInteractables_TU32_events.json"
    if not C.events then
        local ok, saved = pcall(json.load_file, path)
        C.events = ok and type(saved) == "table" and saved or {}
    end
    C.events[#C.events + 1] = { time = os.date("%Y-%m-%d %H:%M:%S"), message = message }
    while #C.events > 100 do table.remove(C.events, 1) end
    json.dump_file(path, C.events)
end
function C.wrap_text(message, limit)
    local lines, line = {}, ""
    for word in tostring(message):gmatch("%S+") do
        if #line > 0 and #line + #word + 1 > limit then
            lines[#lines + 1], line = line, ""
        end
        line = line == "" and word or line .. " " .. word
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end
function C.menu_state(player, gm)
    local values = {}
    local function read(label, obj, method)
        local ok, value = pcall(function() return obj and obj:call(method) end)
        values[#values + 1] = label .. "=" .. (ok and value ~= nil and tostring(value) or "unknown")
    end
    read("jacked", player, "get_IsJacked")
    read("blockMenu", gm, "get_BlockMenu")
    read("loadingGui", gm, "get_IsLoadGui")
    read("pausedGui", gm, "isPausedGUI")
    read("menuVisible", gm, "isDispMenuUI")
    read("sceneLoadPending", gm, "get_IsRequestLoadGUIScene")
    read("sceneUnloadPending", gm, "get_IsRequestUnLoadGUIScene")
    local ok, requested = pcall(function()
        local kind = C.enum("app.GuiDefine.GuiType", "EnhanceEquip2")
        return gm:call("IsRequestGuiType", kind)
    end)
    values[#values + 1] = "enhanceRequested=" .. (ok and requested ~= nil and tostring(requested) or "unknown")
    return table.concat(values, ", ")
end
function C.method(tn, name, types)
    local key = tn .. "." .. name .. "(" .. table.concat(types, ",") .. ")"
    if methods[key] then return methods[key] end
    local td = sdk.find_type_definition(tn)
    for _, m in ipairs(td and td:get_methods() or {}) do
        if m:get_name() == name then
            local ps, same = m:get_param_types() or {}, true
            if #ps == #types then
                for i, pt in ipairs(ps) do
                    if pt:get_full_name() ~= types[i] then same = false; break end
                end
                if same then methods[key] = m; return m end
            end
        end
    end
    error("TU3.2 API unavailable: " .. key)
end
function C.enum(tn, name)
    local td = sdk.find_type_definition(tn)
    local f = td and td:get_field(name)
    local value = f and tonumber(f:get_data(nil))
    if value == nil then error("TU3.2 enum unavailable: " .. tn .. "." .. name) end
    return value
end
function C.new_inn_param()
    local tn = "app.FacilityManager.InnAwakeParam"
    local sn = tn .. ".ObjectSetting"
    local slot_ctor = C.method(sn, ".ctor", { "via.vec3", "via.Quaternion" })
    local ctor = C.method(tn, ".ctor", { sn, sn, sn, sn, sn })
    local slots = {}
    for i = 1, 5 do
        local slot = sdk.create_instance(sn, true)
        if not slot then error("ObjectSetting allocation returned nil") end
        slot:add_ref()
        slot_ctor:call(slot, Vector3f.new(0, 0, 0), Quaternion.new(0, 0, 0, 1))
        slots[i] = slot
    end
    local param = sdk.create_instance(tn, true)
    if not param then error("InnAwakeParam allocation returned nil") end
    param:add_ref()
    ctor:call(param, table.unpack(slots))
    for _, field in ipairs({ "Player", "Camera", "Main", "Sub1", "Sub2" }) do
        if not param:get_field(field) then error("InnAwakeParam missing " .. field) end
    end
    return param
end
C.dialog_types = {
    "System.String", "System.String", "System.String", "System.String", "System.String",
    "System.Boolean", "System.Int32", "System.Boolean", "System.UInt32",
    "System.Int32", "System.Int32", "via.render.TextureResourceHolder",
    "System.Boolean", "System.Boolean", "System.Boolean", "System.Boolean",
    "System.Boolean", "System.Single",
    "System.Boolean", "System.Boolean",
}
function C.open_dialog(gm, prompt, labels)
    local method = C.method("app.GuiManager", "requestDialog", C.dialog_types)
    if gm:call("IsDispDialogGui") == true or gm:call("isPausedGUI") == true then return false, "busy" end
    method:call(gm, prompt, labels[1] or "", labels[2] or "", labels[3] or "",
        labels[4] or "", true, 0, true, 0, -1, 0, nil,
        true, false, false, false, true, 0.35, false, false)
    return true
end
function C.dialog_choice(gm)
    local value = tonumber(gm:call("getDialogState"))
    local tn = "app.ui010101.RetVal"
    if value == C.enum(tn, "Cancel") then return "cancel" end
    for i = 0, 3 do
        if value == C.enum(tn, "Sel" .. i) then return i + 1 end
    end
    return nil
end
function C.cook_page(avail, page)
    local pages = math.max(1, math.ceil(#avail / 3))
    page = ((page or 1) - 1) % pages + 1
    local opts, labels = {}, {}
    for i = (page - 1) * 3 + 1, math.min(page * 3, #avail) do
        local it = avail[i]
        opts[#opts + 1] = it
        labels[#labels + 1] = string.format("%s (%d)", it.m.name, it.count)
    end
    if pages > 1 then
        opts[#opts + 1] = { page = page % pages + 1 }
        labels[#labels + 1] = page < pages and "More..." or "First page..."
    end
    if #labels == 0 then labels[1] = "Cancel" end
    return opts, labels, page
end
function C.current_weapons(equip)
    local data = equip:call("getCloneData")
    return data and data:call("getCurrentArisenWeapon")
end
function C.get_up(bed, player, mode)
    local sheets = bed and bed:get_field("SheetList")
    if bed and not sheets then
        local ok, value = pcall(function()
            return C.method("app.Gm51_115", "get_getSheetList", {}):call(bed)
        end)
        if ok then sheets = value end
    end
    local count = sheets and tonumber(sheets:call("get_Length")) or 0
    local states = {}
    for i = 0, count - 1 do
        local sheet = sheets:get_element(i)
        local target = sheet and sheet:get_field("TargetChara")
        states[#states + 1] = tostring(i) .. ":target=" .. tostring(target and target:get_address())
        if target and target:get_address() == player:get_address() then
            local state = tonumber(sheet:call("get_State"))
            if state ~= C.enum("app.Gm51_115_sheet.InteractState", "Loop") then
                return false, "sheet is entering/exiting, not lying idle"
            end
            if mode == "cancel" then
                C.method("app.Gm51_115_sheet", "setCancel", { "System.Boolean" }):call(sheet, true)
                return true, "sheet cancel flag raised"
            end
            C.method("app.Gm51_115_sheet", "stand", {}):call(sheet)
            return true, "authored sheet stand requested"
        end
    end
    return false, "no owned sheet; count=" .. count .. " " .. table.concat(states, "; ")
end
C.work_aliases = { gm50_007 = "gm50_007_01" }
C.work_pickups = { gm50_010_01=true }
function C.work_group(stations, key)
    if key == "gm50_052_1" or key == "gm50_096" or key == "gm50_096_01"
        or key == "gm50_097" then return nil end
    local row = stations[key] or stations[C.work_aliases[key]]
    return row and row.group
end
function C.station_work_group(stations, key, pickable_owner)
    if C.work_pickups[key] or pickable_owner == true then return nil end
    return C.work_group(stations, key)
end
C.work_seconds = 45
function C.work_sample(w, id, group, now, paused)
    if paused then w.last, w.paused = now, true; return end
    if id and group then
        if w.id ~= id then
            w.id, w.elapsed, w.group, w.last, w.completed = id, 0, group, now, false
            w.notice = nil
        end
        if not w.paused then
            w.elapsed = math.min(C.work_seconds,
                (w.elapsed or 0) + math.max(0, math.min(0.25, now-(w.last or now))))
        end
        w.last, w.paused = now, false
        if w.elapsed >= C.work_seconds and not w.completed then
            w.completed = true
            return group, w.elapsed
        end
        return
    end
    w.id, w.elapsed, w.group, w.paused, w.last = nil, nil, nil, nil, now
    w.completed, w.notice = nil, nil
end
C.camp_names = { [0]="RottenScragOfBeast", [1]="RottenBeastSteak", [2]="DriedSteak",
    [3]="ScragOfBeast", [4]="BeastSteak", [5]="SourScragOfBeast",
    [6]="SourBeastSteak", [7]="ExquisiteDriedMeat" }
function C.camp_effects(camp)
    local param = camp:call("getParam")
    if not param then return "Native meal bonus; stat breakdown unavailable" end
    local parts = {}
    for _, row in ipairs({ {"AttackFactor", "Strength"}, {"DefenceFactor", "Defence"},
            {"StaminaFactor", "stamina use"}, {"MaxHpDamageFactor", "loss-gauge protection"} }) do
        local n = tonumber(param:get_field(row[1]))
        if n and n ~= 0 then parts[#parts + 1] = row[2] end
    end
    if #parts == 0 then return "Native meal bonus; stat breakdown unavailable" end
    return "Meal bonuses: " .. table.concat(parts, ", ")
end
function C.typed_field(owner, wanted)
    local td = owner and owner:get_type_definition()
    for _ = 1, 8 do
        if not td then break end
        for _, field in ipairs(td:get_fields() or {}) do
            if field:get_type():get_full_name() == wanted then
                local value = field:get_data(owner)
                if value then return value end
            end
        end
        td = td:get_parent_type()
    end
end
function C.buff_manager(ch)
    local human
    pcall(function() human = ch and ch:call("get_Human") end)
    if not human then
        pcall(function()
            local go = ch and ch:call("get_GameObject")
            human = go and go:call("getComponent(System.Type)", sdk.typeof("app.Human"))
        end)
    end
    if not human then return nil, "player/party Human unavailable" end
    local manager
    pcall(function() manager = human:call("get_SpecialBuffManager") end)
    if not manager then
        pcall(function() manager = C.typed_field(human, "app.HumanSpecialBuffManager") end)
    end
    return manager, manager and "manager resolved" or "Human has no readable live special-buff manager"
end
function C.camp_state(sb)
    local camp
    pcall(function() camp = sb and sb:get_field("Camp") end)
    if not camp then
        pcall(function() camp = C.typed_field(sb, "app.HumanSpecialBuffManager.CampBuff") end)
    end
    return camp
end
function C.camp_buff(sb, name, protect_meal)
    name = C.camp_names[name] or name
    local id = C.enum("app.HumanSpecialBuffDefine.Camp", name)
    local camp = C.camp_state(sb)
    if not camp then return false, "camp state unavailable" end
    if protect_meal then
        local active = camp:call("get_IsActive")
        if active == true then return false, "existing meal retained" end
        if active ~= false then return false, "camp active state unavailable" end
    end
    C.method("app.HumanSpecialBuffManager", "startBuff",
        { "app.HumanSpecialBuffDefine.Camp", "System.Boolean" }):call(sb, id, false)
    local current = camp:call("get_Type")
    local confirmed = camp:call("get_IsActive") == true and current
        and current:call("get_HasValue") == true and tonumber(current:call("get_Value")) == id
    return confirmed == true, confirmed and ("active " .. name) or ("requested but unconfirmed: " .. name)
end
return C
