-- Immersive Interactables
-- Sit, work, sleep and cook anywhere the world lets NPCs do it.

-- settings and defaults
local M = {
    enabled       = true,

    range         = 12.0,
    y_window      = 2.5,

    max_seats     = 8,
    hysteresis    = 1.25,

    donor         = "gm80_257",
    seat_y        = 0.0,
    dedup_radius  = 0.5,

    per_point     = true,
    max_points    = 4,

    neuter_collision = false,

    scan_secs     = 0.5,
    list_secs     = 5.0,
    list_move     = 10.0,
    budget        = 64,

    log           = false,

    native_chores = true,
    native_beds   = true,

    native_discovery = false,

    native_workstations = false,
    native_manager_exit = false,

    dough_end_lab = false,
    unlock_secs   = 1.0,

    follow_game_controls = true,
    interact_bind = "F",
    stop_bind     = "backspace",
    drop_bind     = "backspace",

    stations       = true,
    st_off         = {},

    st_cam            = true,
    st_cam_dist       = -1.2,

    anvil_prop = "eqit09_001",
    keep_tools = true,
    pin_ox = -0.059, pin_oy = 0.016, pin_oz = -0.035,
    pin_rx = -72.371, pin_ry = -24.124, pin_rz = 59.417,
    master = true,
    bed_rest = true,
    bed_rest_anywhere = true,
    tool_grip = {},
    dev = false,

    cfg_rev = 0,
}

local CFG  = "Interactables.json"
local CATP = "Interactables/catalog.json"

local function _log(s)
    if not M.log then return end
    pcall(function()
        local f = io.open("Interactables.log", "a")
        if f then f:write(os.date("[%H:%M:%S] ") .. tostring(s) .. "\n"); f:close() end
    end)
end
local function _logf(...) _log(string.format(...)) end

local function _load_cfg()
    pcall(function()
        local t = json.load_file(CFG)
        if type(t) == "table" then for k, v in pairs(t) do if M[k] ~= nil then M[k] = v end end end
    end)
end
local function _save_cfg()
    pcall(function()
        local out = {}
        for k, v in pairs(M) do out[k] = v end

        out.dough_end_lab = false
        out.native_workstations = false
        out.native_manager_exit = false
        out.native_discovery = false
        out.native_lethal = false
        json.dump_file(CFG, out)
    end)
end
_load_cfg()

if (tonumber(M.cfg_rev) or 0) < 3 then

    M.neuter_collision = true
    M.cfg_rev = 3
end
if (tonumber(M.cfg_rev) or 0) < 4 then

    M.neuter_collision = false
    M.cfg_rev = 4
end
if (tonumber(M.cfg_rev) or 0) < 5 then
    -- the pad bit we guessed for the stick click fires on its own and drops tools
    M.drop_bind = "backspace"
    M.bed_rest_anywhere = false
    M.cfg_rev = 5
end
if (tonumber(M.cfg_rev) or 0) < 6 then
    -- these two shipped switched off, so nobody could sleep or pick up a tool
    M.native_beds = true
    M.native_chores = true
    M.cfg_rev = 6
end
if (tonumber(M.cfg_rev) or 0) < 7 then
    -- Follow the game's CharacterInput action instead of assuming that F is still Interact.
    -- The custom keys are fallbacks for builds where that action cannot be read.
    M.follow_game_controls = true
    M.interact_bind = "F"
    M.stop_bind = "backspace"
    M.drop_bind = "backspace"
    M.bed_rest_anywhere = true
    M.cfg_rev = 7
end

M.dough_end_lab = false
M.native_workstations = false
M.native_manager_exit = false
M.native_discovery = false

M.native_lethal = false
_G.Interactables_dough_hybrid_lab = false

local CAT, cat_n = {}, 0
pcall(function()
    local t = json.load_file(CATP)
    if type(t) == "table" then CAT = t; for _ in pairs(t) do cat_n = cat_n + 1 end end
end)

local STATIONS
-- props you pick up and carry, they belong with the tools not the workstations
local CARRY_KEYS = { gm51_046 = true }

local function _managed(o)
    if not o then return false end
    local ok, yes = pcall(function()
        if type(sdk.is_managed_object) == "function" then
            return sdk.is_managed_object(o) == true
        end
        return true
    end)
    return ok and yes == true
end

local function _valid(go)
    if not _managed(go) then return false end
    local v = false
    pcall(function() v = go:call("get_Valid") == true end)
    return v
end

local function _player()
    local ch = nil
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        ch = cm and cm:call("get_ManualPlayer")
    end)
    return ch
end

local function _char_go(ch)
    if not _managed(ch) then return nil end
    local go = nil
    pcall(function() go = ch:call("get_GameObject") end)
    return _managed(go) and go or nil
end

local function _pos(go)
    local p = nil
    pcall(function() p = go:call("get_Transform"):call("get_Position") end)
    return p
end

local function _upos(go)
    local p = nil
    pcall(function() p = go:call("get_Transform"):call("get_UniversalPosition") end)
    return p
end

local function _arr(a)
    local out = {}
    if not a then return out end
    local ok = pcall(function()
        for _, v in ipairs(a:get_elements()) do out[#out + 1] = v end
    end)
    if not ok or #out == 0 then
        pcall(function()
            local n = a:call("get_Count")
            for i = 0, (tonumber(n) or 0) - 1 do out[#out + 1] = a:call("get_Item", i) end
        end)
    end
    return out
end

local function _addr(o)
    if not _managed(o) then return nil end
    local a = nil
    pcall(function() a = o:get_address() end)
    return a and tostring(a) or nil
end

local function _loading()
    local l = false
    pcall(function()
        local g = sdk.get_managed_singleton("app.GuiManager")
        l = g and g:call("get_IsLoadGui") == true
    end)
    return l
end

local function _menu_open()
    local m = false
    pcall(function()
        local gui = sdk.get_managed_singleton("app.GuiManager")
        m = gui and gui:call("isPausedGUI") == true
    end)
    return m
end

local PAD_ALIAS = {
    circle = 0x40080, east = 0x40080,
    cross = 0x20020, south = 0x20020,
    square = 0x40, west = 0x40,
    triangle = 0x10, north = 0x10,
    l1 = 0x100, lb = 0x100, l2 = 0x200, lt = 0x200,
    r1 = 0x400, rb = 0x400, r2 = 0x800, rt = 0x800,
    l3 = 0x1000, r3 = 0x2000,
}
local VK_ALIAS = {
    space = 0x20, enter = 0x0D, tab = 0x09, esc = 0x1B, escape = 0x1B,
    shift = 0x10, ctrl = 0x11, alt = 0x12, backspace = 0x08, delete = 0x2E,
}
for i = 0, 25 do VK_ALIAS[string.char(97 + i)] = 0x41 + i end
for i = 0, 9 do VK_ALIAS[tostring(i)] = 0x30 + i end
for i = 1, 12 do VK_ALIAS["f" .. i] = 0x6F + i end

local function _pad_button_mask()
    local mask = 0
    pcall(function()
        local gp = sdk.get_native_singleton("via.hid.GamePad")
        local td = sdk.find_type_definition("via.hid.GamePad")
        local dev = gp and td and sdk.call_native_func(gp, td, "get_MergedDevice")
        if not dev and gp and td then
            dev = sdk.call_native_func(gp, td, "getMergedDevice(System.UInt32)", 0)
        end

        if not dev and gp and td then
            dev = sdk.call_native_func(gp, td, "get_Device")
        end
        if dev then mask = math.floor(tonumber(dev:call("get_Button")) or 0) end
    end)
    return mask
end

-- reads the keyboard device directly so keys work on every REFramework build
local function _kb_down(vk)
    local down = false
    pcall(function()
        local s = sdk.get_native_singleton("via.hid.Keyboard")
        local td = sdk.find_type_definition("via.hid.Keyboard")
        local dev = (s and td) and sdk.call_native_func(s, td, "get_Device")
        if dev then down = dev:call("isDown", math.floor(vk)) == true end
    end)
    if not down then
        pcall(function() down = reframework:is_key_down(math.floor(vk)) == true end)
    end
    return down
end

local function _binding_down(text)
    text = tostring(text or "")
    local padmask = nil
    for raw in text:gmatch("[^,]+") do
        local token = raw:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        local pbit = PAD_ALIAS[token]
        if pbit then
            padmask = padmask or _pad_button_mask()
            local hit = false
            pcall(function() hit = (padmask & pbit) ~= 0 end)
            if hit then return true end
        else
            local vk = VK_ALIAS[token] or tonumber(token)
            if not vk and token:match("^0x[0-9a-f]+$") then vk = tonumber(token:sub(3), 16) end
            if vk and _kb_down(vk) then return true end
        end
    end
    return false
end

-- Reads the game's own player action flags. This is the same approach used by
-- Brinebound: keyboard/controller remaps reach us through CharacterInput.
local NA = { flags = nil }
local function _native_action_down(names)
    local result = nil
    pcall(function()
        if not NA.flags then
            NA.flags = {}
            local td = sdk.find_type_definition("app.CharacterInput.Flag")
            for _, f in ipairs(td and td:get_fields() or {}) do
                if f:is_static() then
                    local v = tonumber(f:get_data(nil))
                    if v then NA.flags[f:get_name()] = v end
                end
            end
        end
        local ch = _player()
        local input = ch and ch:call("get_Input")
        if not input then return end
        local found = false
        for _, name in ipairs(type(names) == "table" and names or { names }) do
            local flag = NA.flags[name]
            if flag then
                found = true
                if input:call("isButtonOn", flag) == true then result = true; return end
            end
        end
        if found then result = false end
    end)
    return result
end

local function _action_or_binding(actions, binding)
    if M.follow_game_controls ~= false then
        local down = _native_action_down(actions)
        if down ~= nil then return down end
    end
    return _binding_down(binding)
end

local function _interact_down()
    return _action_or_binding("Interact", M.interact_bind or "F")
end

local function _stop_down()
    return _action_or_binding("Interact", M.stop_bind or "backspace")
        or _binding_down(M.stop_bind or "backspace")
end

local L3_MASK = nil
local function _l3_down()
    if not L3_MASK then
        L3_MASK = 0x1000
        pcall(function()
            local td = sdk.find_type_definition("via.hid.GamePadButton")
            local f = td and (td:get_field("LStickPush") or td:get_field("L3"))
            local v = f and tonumber(f:get_data(nil))
            if v and v ~= 0 then L3_MASK = v end
        end)
    end
    local mask = _pad_button_mask()
    return mask ~= 0 and (mask & L3_MASK) ~= 0
end

local function _drop_down()
    return _l3_down() or _binding_down(M.drop_bind or "backspace")
end

local KEY_CAPTURE = { field = nil, after = 0 }
local VK_LABEL = {
    [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x10] = "Shift",
    [0x11] = "Ctrl", [0x12] = "Alt", [0x20] = "Space", [0x2E] = "Delete",
}
for i = 0, 25 do VK_LABEL[0x41 + i] = string.char(65 + i) end
for i = 0, 9 do VK_LABEL[0x30 + i] = tostring(i) end
for i = 1, 12 do VK_LABEL[0x6F + i] = "F" .. tostring(i) end

local function _capture_key()
    if not KEY_CAPTURE.field or os.clock() < (KEY_CAPTURE.after or 0) then return nil end
    if _kb_down(0x1B) then KEY_CAPTURE.field = nil; return nil end
    for vk = 0x08, 0xFE do
        if vk ~= 0x1B and _kb_down(vk) then
            return (VK_LABEL[vk] or tostring(vk)):lower()
        end
    end
    return nil
end

local function _binding_label(text)
    local token = tostring(text or "unbound")
    return token:gsub("^%l", string.upper)
end

local function _io_of(go)
    local io = nil
    pcall(function()
        for _, c in ipairs(_arr(go:call("get_Components"))) do
            local v = nil
            pcall(function() v = c.InteractiveObject end)
            if v then io = v; return end
        end
    end)
    return io
end

local PLANT_KINDS = { CHAIR = true }

-- bed prefabs the game only gives to NPCs
local BED_KEYS = {
    gm51_092 = true,
    gm51_299 = true,
    gm51_092_02 = true, gm51_100 = true, gm51_115 = true, gm51_115_01 = true,
    gm51_393 = true, gm51_396 = true, gm51_409 = true, gm51_409_01 = true,
    gm51_460 = true, gm51_603 = true, gm51_603_01 = true, gm51_742 = true,
}

-- NPC benches, unlocked as plain seats using the game's own sit
local SIT_KEYS = {
    gm51_074 = true,
    gm50_070 = true,
}

-- objects we never touch
local BAN = {
    "gm80_054", "gm81_032",
    "gm05_046", "gm80_021", "gm80_022",
    "gm80_042", "gm80_052",
    "gm80_046", "gm80_048",
    "gm81_031",
    "gm80_105", "gm80_148", "gm80_195",
    "gm02_003", "gm80_205",
    "gm04_013", "gm81_045", "gm80_053",
    "gm81_108", "gm81_042",
    "gm81_117", "gm81_118", "gm81_119", "gm81_120", "gm81_126",
}

-- the hidden seat prefabs
local DONOR_NAMES = { "gm80_065", "gm80_066", "gm80_067", "gm80_068", "gm80_069",
                      "gm80_257", "gm80_166", "gmcamp", "gmseat" }

local GENERIC_RIG = { "gmaiinteract", "gminteractbase", "gmseat", "gmcamp" }

local function _norm(name)
    local n = tostring(name or ""):lower()
    if n == "" then return nil end
    n = n:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*%(%d+%)$", ""):gsub("_?clone$", "")
    if CAT[n] then return n end
    local base = n
    for _ = 1, 3 do
        base = base:gsub("_%d+$", "")
        if base == "" then break end
        if CAT[base] then return base end
    end
    local head = n:match("^(gm%d+_%d+)")
    if head and CAT[head] then return head end
    return nil
end

local function _banned(name)
    local n = tostring(name or ""):lower()
    if n == "" then return "no name" end
    for _, b in ipairs(BAN) do if n:find(b, 1, true) then return b end end
    for _, d in ipairs(DONOR_NAMES) do if n:find(d, 1, true) then return "is itself a seat" end end
    return nil
end

local function _eligible(name)
    local ban = _banned(name)
    if ban then return false, "banned: " .. ban end
    local key = _norm(name)
    if not key then
        local n = tostring(name or ""):lower()
        for _, g in ipairs(GENERIC_RIG) do
            if n:find(g, 1, true) then return false, "shared rig" end
        end
        return false, "not in catalog"
    end
    if CAT[key].pc == 1 then
        return false, "the game already offers the player: " .. table.concat(CAT[key].pv or {}, "/")
    end
    return true, nil, key
end

local job, job_seq = nil, 0

local function _gimmick_job(name, path, up, rq)
    job = nil
    local ok = pcall(function()
        local gid
        local fld = sdk.find_type_definition("app.GimmickID"):get_field((name:gsub("^gm", "Gm")))
        if fld then gid = fld:get_data() end
        if not gid then _log("spawn: no app.GimmickID enum for " .. name); return end
        if not (up and rq) then return end

        local prefab = sdk.create_instance("via.Prefab"):add_ref()
        prefab:set_Path(path)
        pcall(function() prefab:set_Standby(true) end)
        local ctrl = sdk.create_instance("app.PrefabController"):add_ref()
        ctrl._Item = prefab
        pcall(function() ctrl:get_Item():set_Standby(true) end)
        local inst = sdk.create_instance("app.InstanceInfo"):add_ref()
        local container
        pcall(function() container = inst:get_Container() end)
        if not container then
            container = sdk.create_instance("app.GenerateInfo.GenerateInfoContainer"):add_ref()
        end
        local pos = ValueType.new(sdk.find_type_definition("via.Position"))
        pos.x, pos.y, pos.z = up.x, up.y, up.z
        local cat = 5
        pcall(function()
            local f2 = sdk.find_type_definition("app.GeneratorCategory"):get_field("Gimmick")
            if f2 then cat = f2:get_data() end
        end)
        pcall(function() container._CommonInfo._Category = cat end)
        pcall(function() container._CommonInfo._ObjectID._SelectedGimmickID = gid end)
        pcall(function() container._CommonInfo._InitialPosition = pos end)
        pcall(function() container._CommonInfo._ContextPosition = pos end)
        pcall(function() container._CommonInfo:setContextPosition(pos) end)

        pcall(function()
            local rqt = ValueType.new(sdk.find_type_definition("via.Quaternion"))
            rqt.x, rqt.y, rqt.z, rqt.w = rq.x, rq.y, rq.z, rq.w
            container._CommonInfo:setInitialAngle(rqt)
        end)
        pcall(function() container._StatusInfo["<ScaleRate>k__BackingField"] = 1.0 end)
        job = { stage = "wait", f = 0, prefab = prefab, ctrl = ctrl, inst = inst,
                container = container }
    end)
    if not ok then job = nil; _log("spawn: build failed for " .. tostring(name)) end
    return job ~= nil
end

local function _spawn_pump()
    if not job then return nil end
    job.f = (job.f or 0) + 1
    if job.stage == "wait" then
        local ready = false
        pcall(function() ready = job.prefab:get_Ready() == true end)
        if ready then
            job_seq = job_seq + 1
            local okr = pcall(function()
                local gen = sdk.get_managed_singleton("app.GenerateManager")
                gen:call("requestCreateInstance(app.PrefabController, app.GenerateInfo.GenerateInfoContainer, System.Int32, app.InstanceInfo, System.Action`2<app.PrefabInstantiateResults,app.DummyArg>, System.Action`2<app.PrefabInstantiateResults,app.DummyArg>)",
                    job.ctrl, job.container, 751000 + job_seq, job.inst, nil, nil)
            end)
            if okr then job.stage, job.f = "poll", 0 else job = nil; _log("spawn: create refused") end
        elseif job.f > 600 then job = nil; _log("spawn: prefab never became ready") end
        return nil
    end
    if job.stage == "poll" then
        local go
        pcall(function() go = job.inst:get_Instance() end)
        if go then
            job = nil
            return go
        end
        if job.f > 600 then job = nil; _log("spawn: instance never arrived") end
    end
    return nil
end

-- collider on and off helpers
local function _kill_colliders(go, depth, count)
    count = count or { n = 0 }
    if not go or (depth or 0) > 6 then return count.n end
    pcall(function()
        local pc = go:call("getComponent(System.Type)", sdk.typeof("via.physics.Colliders"))
        if pc then pc:call("disable"); count.n = count.n + 1 end
    end)
    pcall(function()
        local tf = go:call("get_Transform"); local child = tf and tf:call("get_Child")
        while child do
            local cgo = child:call("get_GameObject")
            if cgo then _kill_colliders(cgo, (depth or 0) + 1, count) end
            child = child:call("get_Next")
        end
    end)
    return count.n
end

local function _wake_colliders(go, depth, count)
    count = count or { n = 0 }
    if not go or (depth or 0) > 6 then return count.n end
    pcall(function()
        local pc = go:call("getComponent(System.Type)", sdk.typeof("via.physics.Colliders"))
        if pc then pc:call("enable"); count.n = count.n + 1 end
    end)
    pcall(function()
        local tf = go:call("get_Transform"); local child = tf and tf:call("get_Child")
        while child do
            local cgo = child:call("get_GameObject")
            if cgo then _wake_colliders(cgo, (depth or 0) + 1, count) end
            child = child:call("get_Next")
        end
    end)
    return count.n
end

local sc = { list_at = 0, at = 0, list = {}, complete = false, last_p = nil, ms = 0 }
local seats = {}
local pending = nil
local stats = { placed = 0, retired = 0, dedup = 0, failed = 0,
                unlocked = 0, restored = 0, unlock_failed = 0 }

local unlocks = {}
local unlock_at = 0
local native_session = { key = nil }
local native_last = "none yet"

local _active_native, _st_release, _is_station_active, _st_log
local ST = {}

local function _unlock_count(kind)
    local n = 0
    for _, r in pairs(unlocks) do if not kind or r.kind == kind then n = n + 1 end end
    return n
end

local function _restore_unlocks(kind)
    for k, r in pairs(unlocks) do
        if not kind or r.kind == kind then
            local ok = pcall(function()
                r.point:set_field("CharacterType", r.old)
                if r.old_icon ~= nil then r.point:set_field("IconType", r.old_icon) end
            end)
            if ok then stats.restored = stats.restored + 1 end
            unlocks[k] = nil
        end
    end
end

local function _unlock_kind(key)
    if not key then return nil end

    if key == "gm10_030" and M.native_lethal ~= true then
        return nil
    end
    if key == "gm50_022" and M.native_lethal ~= true and not
            (M.stations ~= false and STATIONS and STATIONS[key]) then
        return nil
    end

    if CARRY_KEYS[key] then
        return M.native_chores and "chore" or nil
    end
    if M.stations ~= false and STATIONS and STATIONS[key]
            and not (M.st_off or {})[key] then
        return "station"
    end
    if M.native_discovery then
        local row = CAT[key]
        local search = false
        for _, verb in ipairs((row and row.v) or {}) do
            if tostring(verb) == "Search" then search = true break end
        end
        if search and tonumber(row.pc) == 0 and not _banned(key) then
            return BED_KEYS[key] and "bed" or "chore"
        end
    end
    if M.native_chores and key:match("^gm50_") then return "chore" end
    if M.native_beds and BED_KEYS[key] then return "bed" end
    return nil
end

local function _owner_is(owner, wanted)
    local matched = false
    pcall(function()
        local td = owner and owner:get_type_definition()
        for _ = 1, 16 do
            if not td then break end
            if tostring(td:get_full_name()) == wanted then matched = true; break end
            td = td:get_parent_type()
        end
    end)
    return matched
end

local function _safe_chore_owner(owner, prop_key)
    if (prop_key == "gm50_022" or prop_key == "gm10_030") and M.native_lethal ~= true then
        return false
    end

    if prop_key and prop_key:match("^gm50_036") then return true end

    if _owner_is(owner, "app.GmInteractPickableBase") then return true end

    return M.native_workstations == true or M.native_discovery == true
end

-- lets the player use an NPC only interaction
local function _patch_search_point(point, kind, host, source, index, io, owner, prop_key)
    if not point then return false end
    if kind == "chore" and not _safe_chore_owner(owner, prop_key) then return false end
    local key = _addr(point)
    if not key then return false end

    if unlocks[key] then
        local r = unlocks[key]
        if io then
            r.io, r.io_addr, r.index, r.owner = io, _addr(io), index, owner
            r.prop_key = prop_key or r.prop_key
        end
        return false
    end

    local icon, ct = nil, nil
    pcall(function() icon = tonumber(point:get_field("IconType")) end)
    pcall(function() ct = tonumber(point:get_field("CharacterType")) end)

    local has_human = ct and (math.floor(ct / 8) % 2) == 1

    -- seats keep whatever icon the game authored, other kinds must start unlabeled
    if kind ~= "seat"
        and (icon ~= 0 and not (kind == "bed" and (icon == 30 or icon == 22))) then
        return false
    end
    if not ct or not has_human or (ct % 2) == 1 then return false end

    local new_ct = ct + 1
    local wrote = pcall(function() point:set_field("CharacterType", new_ct) end)
    local readback = nil
    if wrote then pcall(function() readback = tonumber(point:get_field("CharacterType")) end) end
    if readback ~= new_ct then
        stats.unlock_failed = stats.unlock_failed + 1
        _logf("unlock FAILED: %s %s[%d] CharacterType %s -> %s (read %s)",
            tostring(host), tostring(source), tonumber(index) or -1,
            tostring(ct), tostring(new_ct), tostring(readback))
        return false
    end

    local old_icon = nil
    local new_icon = nil
    if kind == "bed" and icon == 0 then
        new_icon = 22
    elseif kind == "chore" and icon == 0
            and _owner_is(owner, "app.GmInteractPickableBase") then
        new_icon = 1
    end
    if new_icon ~= nil then
        local icon_ok = pcall(function() point:set_field("IconType", new_icon) end)
        local icon_read = nil
        if icon_ok then pcall(function() icon_read = tonumber(point:get_field("IconType")) end) end
        if icon_read == new_icon then old_icon = icon end
    end

    unlocks[key] = { point = point, old = ct, old_icon = old_icon,
                     kind = kind, host = host, source = source,
                     io = io, io_addr = _addr(io), index = index, owner = owner,
                     prop_key = prop_key }
    stats.unlocked = stats.unlocked + 1
    _logf("native %s unlocked: %s %s[%d] CharacterType %d -> %d",
        kind, tostring(host), tostring(source), tonumber(index) or -1, ct, new_ct)

    if (kind == "bed" or kind == "station") and _st_log then
        _st_log(string.format("unlocked %s point on %s", kind, tostring(host)))
    end
    return true
end

local function _patch_data_list(list, kind, host, source, io, owner, prop_key)
    if not list then return end
    for i, point in ipairs(_arr(list)) do
        _patch_search_point(point, kind, host, source, i - 1, io, owner, prop_key)
    end
end

local function _unlock_go(e)
    local key = _norm(e and e.name)
    local kind = _unlock_kind(key)
    if not kind or not (e and e.go and _valid(e.go)) then return end

    for _, comp in ipairs(_arr(e.go:call("get_Components"))) do
        local allow = kind == "chore" or kind == "station"
        if kind == "bed" then
            local tn = ""
            pcall(function() tn = tostring(comp:get_type_definition():get_full_name()) end)
            allow = tn == "app.Gm51_115"
        end
        if allow then
            local authored, io = nil, nil
            pcall(function() authored = comp:get_field("InteractiveObjectDataList") end)
            pcall(function() io = comp.InteractiveObject end)
            if not io then pcall(function() io = comp:get_field("InteractiveObject") end) end

            _patch_data_list(authored, kind, e.name, "authored", nil, comp, key)
            if io then
                local runtime = nil
                pcall(function() runtime = io:get_field("DataList") end)
                _patch_data_list(runtime, kind, e.name, "runtime", io, comp, key)
            end
        end
    end
end

local function _record_for_active(io, point_no)
    local ia = _addr(io)
    if not ia then return nil end
    for _, r in pairs(unlocks) do
        if r.io_addr == ia and tonumber(r.index) == tonumber(point_no) then return r end
    end

    for _, r in pairs(unlocks) do
        if r.io_addr == ia then return r end
    end
    return nil
end

function _active_native()
    local out = nil
    pcall(function()
        local player = _player()
        local mgr = player and sdk.get_managed_singleton("app.InteractManager")
        if not mgr then return end
        local active = mgr:call("getActiveInteract(app.Character)", player)
        local point = active and active:get_field("Point")
        local io = point and point:get_field("Object")
        local no = point and tonumber(point:get_field("PointNo"))
        if not io then return end
        local rec = _record_for_active(io, no)

        local key, owner_go = nil, nil
        pcall(function()
            owner_go = io:call("get_Owner")
            if not owner_go then owner_go = io:get_field("<Owner>k__BackingField") end
            if owner_go then
                local raw = tostring(owner_go:call("get_Name") or ""):lower()
                key = _norm(raw) or raw:match("^(gm%d+_%d+_?%d*)")
            end
        end)
        -- Player-authored home/inn beds need no CharacterType patch, so they are not
        -- present in `unlocks`. Still recognise them as bed sessions. This lets us
        -- start the lie-down animation while their own native rest UI remains in charge.
        if not rec and M.native_beds ~= false and key and BED_KEYS[key] then
            local bed = nil
            pcall(function()
                bed = owner_go:call("getComponent(System.Type)", sdk.typeof("app.Gm51_115"))
            end)
            if bed then
                rec = { kind = "bed", native_player = true, owner = bed,
                        host = tostring(key), prop_key = key, io = io,
                        io_addr = _addr(io), index = no }
            end
        end
        out = { player = player, mgr = mgr, active = active,
                io = io, point_no = no, rec = rec, key = key }
    end)
    return out
end

function _is_station_active(a)
    if not a then return false end
    if a.rec and a.rec.kind == "station" then return true end

    if a.rec and a.rec.kind == "bed" then return true end
    if a.key and STATIONS and STATIONS[a.key] and not (M.st_off or {})[a.key] then return true end
    return false
end

local function _native_session_tick()

    if M.native_manager_exit ~= true then
        native_session = { key = nil }
        return
    end
    if not M.enabled or (not M.native_chores and not M.native_beds) or _menu_open() then
        native_session = { key = nil }
        return
    end

    local a = _active_native()
    if not a or not a.rec then
        native_session = { key = nil }
        return
    end
    local skey = tostring(a.rec.io_addr) .. ":" .. tostring(a.point_no)
    local now = os.clock()
    if native_session.key ~= skey then
        native_session = { key = skey, began = now, released = false,
                           notified = false, cancel_requested = false,
                           exit_press_at = nil, force_end_requested = false,
                           io = a.io, point_no = a.point_no, player = a.player,
                           prop_key = a.rec.prop_key, host = a.rec.host }
        native_last = string.format("active %s: %s", tostring(a.rec.kind), tostring(a.rec.host))
        _logf("active native %s: %s point %d",
            tostring(a.rec.kind), tostring(a.rec.host), tonumber(a.point_no) or -1)
    end

    if now - native_session.began < 0.65 then return end

    local down = _stop_down()
    if not native_session.released then

        if not down then
            native_session.released = true
            native_last = string.format("exit armed: %s", tostring(a.rec.host))
        end
        return
    end

    if not native_session.notified then
        local ok = pcall(function()
            a.mgr:call("notifyEnableInputAssginedToSameInputOfInteractOnInteracting")
        end)
        native_session.notified = true
        native_last = string.format("exit input %s: %s", tostring(a.rec.host),
            ok and "enabled" or "failed")
        pcall(function() log.info(string.format(
            "[Interactables] same-input exit enabled for %s: %s",
            tostring(a.rec.host), tostring(ok))) end)
    end

    if down and not native_session.cancel_requested and not native_session.exit_press_at then

        native_session.exit_press_at = now
        pcall(function() log.info(string.format(
            "[Interactables] exit button detected for %s", tostring(a.rec.host))) end)
    end

    if native_session.exit_press_at and not native_session.cancel_requested
            and now - native_session.exit_press_at >= 0.12 then

        native_session.cancel_requested = true
        native_session.cancel_at = now
        local ok, err = pcall(function()
            a.mgr:call("cancelInteract(app.Character)", a.player)
        end)
        native_last = string.format("manager exit %s: %s", tostring(a.rec.host),
            ok and "requested" or "failed")
        pcall(function() log.info(string.format(
            "[Interactables] manager cancelInteract for %s point %d: %s%s",
            tostring(a.rec.host), tonumber(a.point_no) or -1, tostring(ok),
            ok and "" or (" / " .. tostring(err)))) end)
    end

    if native_session.cancel_requested and native_session.cancel_at
            and not native_session.force_end_requested
            and now - native_session.cancel_at >= 6.0 then
        native_session.force_end_requested = true
        local ok, err = pcall(function()
            a.mgr:call("endInteract(app.Character)", a.player)
        end)
        native_last = string.format("manager finalise %s: %s", tostring(a.rec.host),
            ok and "requested" or "failed")
        pcall(function() log.info(string.format(
            "[Interactables] manager endInteract watchdog for %s point %d: %s%s",
            tostring(a.rec.host), tonumber(a.point_no) or -1, tostring(ok),
            ok and "" or (" / " .. tostring(err)))) end)
    end
end

-- rolling unlock pass
local function _unlock_tick()
    local stations_on = M.stations ~= false
    if not M.enabled and not stations_on then
        if next(unlocks) then _restore_unlocks() end
        return
    end
    if not M.enabled and next(unlocks) then
        _restore_unlocks("chore"); _restore_unlocks("bed")
    end
    if not stations_on and _unlock_count("station") > 0 then _restore_unlocks("station") end
    if M.enabled then
        if not M.native_chores and not M.native_discovery
                and _unlock_count("chore") > 0 then _restore_unlocks("chore") end
        if not M.native_beds and not M.native_discovery
                and _unlock_count("bed") > 0 then _restore_unlocks("bed") end
    end
    local want_native = M.enabled
        and (M.native_chores or M.native_beds or M.native_discovery)
    if not want_native and not stations_on then return end
    if _loading() or _menu_open() then return end

    local now = os.clock()
    if now - unlock_at < (M.unlock_secs or 1.0) then return end
    unlock_at = now

    if (not M.enabled or #sc.list == 0)
            and now - (tonumber(sc.list_at) or 0) > (M.list_secs or 5.0) then
        sc.list_at = now
        sc.complete = _refresh_list()
    end
    for _, e in ipairs(sc.list) do pcall(_unlock_go, e) end
end

local function _seat_count()
    local n = 0
    for _ in pairs(seats) do n = n + 1 end
    return n
end

local function _kill_seat(rec)
    if not (rec and rec.go) then return end
    pcall(function()
        if _valid(rec.go) then rec.go:call("destroy(via.GameObject)", rec.go) end
    end)
    rec.go = nil
end

local function _drop_all(destroy)
    for k, rec in pairs(seats) do
        if destroy then _kill_seat(rec) else rec.go = nil end
        seats[k] = nil
    end
    pending = nil
end

local function _refresh_list()
    local built, ok = {}, false
    pcall(function()
        local scene = sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
        if not scene then return end
        local t = sdk.typeof("app.GimmickBase")
        if not t then return end
        for _, comp in ipairs(_arr(scene:call("findComponents(System.Type)", t))) do
            local go = nil
            pcall(function() go = comp:call("get_GameObject") end)
            if go and _valid(go) then
                local nm = nil
                pcall(function() nm = tostring(go:call("get_Name")) end)
                built[#built + 1] = { go = go, name = nm or "?" }
            end
        end
        ok = #built > 0
    end)
    if ok then sc.list = built end
    return ok
end

local function _resolve(e)
    if e.done then return e end
    e.done = true
    e.ok, e.why, e.key = _eligible(e.name)
    if e.ok then
        local sit = false
        for _, v in ipairs((CAT[e.key] or {}).v or {}) do if v == "Sit" then sit = true break end end
        if sit then e.kind = "CHAIR" else e.ok, e.why = false, "no Sit interact authored" end
    end
    return e
end

local function _donor_near(p, radius)
    local r2 = (radius or 0.5) * (radius or 0.5)
    for _, e in ipairs(sc.list) do
        local nm = tostring(e.name or ""):lower()
        for _, d in ipairs(DONOR_NAMES) do
            if nm:find(d, 1, true) and _valid(e.go) then
                local q = _upos(e.go)
                if q then
                    local dx, dy, dz = q.x - p.x, q.y - p.y, q.z - p.z
                    if (dx * dx + dy * dy + dz * dz) < r2 then return true end
                end
                break
            end
        end
    end
    return false
end

local function _tick()
    if not M.enabled then if _seat_count() > 0 then _drop_all(true) end return end
    if _loading() or _menu_open() then return end
    local now = os.clock()

    if pending then
        local go = _spawn_pump()
        if go then
            if M.neuter_collision then _kill_colliders(go) end
            seats[pending.key] = { go = go, host = pending.host,
                                   addr = pending.addr, point = pending.point }
            stats.placed = stats.placed + 1
            _logf("seat placed in %s (%d live)", tostring(pending.host), _seat_count())
            pending = nil
        elseif job == nil then
            stats.failed = stats.failed + 1
            pending = nil
        end
        return
    end
    if job then return end

    local pgo = _char_go(_player())
    local pp = pgo and _pos(pgo)
    if not pp then return end

    local moved = 1e9
    if sc.last_p then
        local dx, dy, dz = pp.x - sc.last_p.x, pp.y - sc.last_p.y, pp.z - sc.last_p.z
        moved = math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    if now - sc.list_at > (M.list_secs or 5.0) or moved > (M.list_move or 10.0) then
        sc.list_at = now
        sc.last_p = { x = pp.x, y = pp.y, z = pp.z }
        local t0 = os.clock()
        sc.complete = _refresh_list()
        sc.ms = (os.clock() - t0) * 1000.0

        do

            sc.colstate = sc.colstate or {}
            local nd, healed = 0, 0
            for _, e in ipairs(sc.list) do
                if _valid(e.go) then
                    local nm = tostring(e.name or ""):lower()
                    local rig = nm:find("gmseat", 1, true) or nm:find("gmcamp", 1, true)
                    local donorish = rig
                    if not donorish then
                        for _, d in ipairs(DONOR_NAMES) do
                            if nm:find(d, 1, true) then donorish = true break end
                        end
                    end
                    if donorish then
                        local a = _addr(e.go)
                        if M.neuter_collision and rig then
                            if a then sc.colstate[a] = "killed" end
                            _kill_colliders(e.go); nd = nd + 1
                        elseif a and sc.colstate[a] ~= "healed" then
                            sc.colstate[a] = "healed"
                            healed = healed + _wake_colliders(e.go)
                        end
                    end
                end
            end
            if nd ~= (sc.neutered or -1) or healed > 0 then
                sc.neutered = nd
                _st_log("collider pass: " .. nd .. " rig seats neutered"
                    .. (healed > 0 and (", " .. healed .. " colliders re-enabled") or ""))
            end
        end
    end
    if now - sc.at < (M.scan_secs or 0.5) then return end
    sc.at = now

    local want, inrange = {}, {}
    local range, yw = (M.range or 12.0), (M.y_window or 2.5)

    local far = range * (M.hysteresis or 1.25)
    local budget, truncated = (M.budget or 64), false
    for _, e in ipairs(sc.list) do
        if budget <= 0 then truncated = true; break end
        if _valid(e.go) then
            local gp = _pos(e.go)
            if gp and math.abs(gp.y - pp.y) <= yw then
                local dx, dz = gp.x - pp.x, gp.z - pp.z
                local d = math.sqrt(dx * dx + dz * dz)
                if d < far then
                    if not e.done then budget = budget - 1 end
                    _resolve(e)
                    local k = nil
                    pcall(function() k = e.go:get_address() end)
                    if k then
                        e._addr, e._d = k, d
                        inrange[#inrange + 1] = e
                    end
                end
            end
        end
    end

    for _, e in ipairs(inrange) do
        if e.ok and (e._d or 1e9) < range and PLANT_KINDS[e.kind or ""] then
            local np = tonumber((CAT[e.key] or {}).n) or 1
            np = math.max(1, math.min(np, M.max_points or 4))
            for p = 0, np - 1 do want[e._addr .. ":" .. p] = { e = e, point = p } end
        end
    end

    if sc.complete and not truncated then
        for k, rec in pairs(seats) do
            local keep = want[k] ~= nil

            if rec.foreign then
                if not keep then seats[k] = nil end
                goto continue
            end
            if not keep then
                for _, e in ipairs(inrange) do
                    if e._addr == rec.addr and (e._d or 1e9) < far then keep = true; break end
                end
            end
            if not keep or not (rec.go and _valid(rec.go)) then
                _kill_seat(rec)
                seats[k] = nil
                stats.retired = stats.retired + 1
            end
            ::continue::
        end
    end

    if _seat_count() >= (M.max_seats or 8) then return end
    local pick, pd = nil, 1e9
    for k, w in pairs(want) do
        if not seats[k] then
            local gp = _pos(w.e.go)
            if gp then
                local dx, dz = gp.x - pp.x, gp.z - pp.z
                local d = dx * dx + dz * dz
                if d < pd then pick, pd = { key = k, e = w.e, point = w.point }, d end
            end
        end
    end
    if not pick then return end

    pcall(function()
        local tf = pick.e.go:call("get_Transform")
        local up, rq = tf:call("get_UniversalPosition"), tf:call("get_Rotation")
        local p = ValueType.new(sdk.find_type_definition("via.Position"))
        p.x, p.y, p.z = up.x, up.y + (M.seat_y or 0.0), up.z

        if M.per_point ~= false then
            local io = _io_of(pick.e.go)
            if io then
                local pt = nil
                pcall(function() pt = io:call("getInteractPointPosition", pick.point or 0) end)
                if pt then
                    local dx, dy, dz = pt.x - up.x, pt.y - up.y, pt.z - up.z
                    if math.sqrt(dx * dx + dy * dy + dz * dz) < 8.0 then
                        p.x, p.y, p.z = pt.x, pt.y + (M.seat_y or 0.0), pt.z
                    end
                end
            end
        end

        if _donor_near(p, M.dedup_radius or 0.5) then
            stats.dedup = stats.dedup + 1
            seats[pick.key] = { go = nil, host = pick.e.name, foreign = true,
                                addr = pick.e._addr, point = pick.point }
            return
        end

        local nm = M.donor or "gm80_257"
        local dp = (CAT[nm] and CAT[nm].p) or ("AppSystem/gimmick/prefab/camp/" .. nm .. ".pfb")
        if _gimmick_job(nm, dp, p, rq) then
            pending = { key = pick.key, host = pick.e.name,
                        addr = pick.e._addr, point = pick.point }
        end
    end)
end

-- every workstation we unlock
STATIONS = {

    gm50_022    = { bank = 8504, path = "appsystem/gimmick/gm50_027/gm50_022_interact_motlist.motlist", label = "Knead dough" },
    gm50_005    = { bank = 8507, path = "appsystem/gimmick/gminteract/gm50_005/gm50_005_interact_motlist.motlist", label = "Drink" },
    gm50_007_01 = { bank = 8509, path = "appsystem/gimmick/gm50_007/gm50_007_01_interact_motlist.motlist", label = "Sweep" },
    gm50_010_01 = { bank = 8510, path = "appsystem/gimmick/gm50_010/gm50_010_interact_motlist.motlist", label = "Work" },

    gm50_132_01 = { bank = 8516, path = "appsystem/gimmick/gm50_016/gm50_016_01_interact_motlist.motlist", label = "Chop food" },
    gm50_011_01 = { bank = 8511, path = "appsystem/gimmick/gm50_011/gm50_011_interact_motlist.motlist", label = "Chop wood" },
    gm50_013    = { bank = 8512, path = "appsystem/gimmick/gm50_013/gm50_013_interact_motlist.motlist", label = "Draw water" },
    gm50_013_01 = { bank = 8513, path = "appsystem/gimmick/gm50_013/gm50_013_01_interact_motlist.motlist", label = "Wipe clean" },
    gm50_013_02 = { bank = 8514, path = "appsystem/gimmick/gm50_013/gm50_013_02_interact_motlist.motlist", label = "Wipe the table" },
    gm50_014_01 = { bank = 8515, path = "appsystem/gimmick/gm50_014/gm50_014_01_interact_motlist.motlist", label = "Wash at the table" },

    gm50_016_01 = { bank = 8516, path = "appsystem/gimmick/gm50_016/gm50_016_01_interact_motlist.motlist", label = "Chop food" },
    gm50_020    = { bank = 8517, path = "appsystem/gimmick/gm50_020/gm50_020_interact_motlist.motlist", label = "Tend the pot" },
    gm50_025    = { bank = 8518, path = "appsystem/gimmick/gminteract/gm50_025/gm50_025_interact_motlist.motlist", label = "Eat" },
    gm50_031    = { bank = 8519, path = "appsystem/gimmick/gm50_031/gm50_031_interact_motlist.motlist", label = "Till the soil" },
    gm50_031_01 = { bank = 8519, path = "appsystem/gimmick/gm50_031/gm50_031_interact_motlist.motlist", label = "Till the soil" },
    gm50_041_01 = { bank = 8521, path = "appsystem/gimmick/gm50_041/gm50_041_01_interact_motlist.motlist", label = "Tend the kiln" },
    gm50_052_1  = { bank = 8522, path = "appsystem/gimmick/gm50_052/gm50_052_1_interact_motlist.motlist", label = "Dye cloth" },
    gm50_053    = { bank = 8523, path = "appsystem/gimmick/gminteract/gm50_053/gm50_053_interact_motlist.motlist", label = "Take notes" },

    gm50_096    = { bank = 8524, path = "appsystem/gimmick/gm50_096/gm50_096_interact_motlist.motlist", label = "Pitch hay", conjure = 41 },
    gm50_096_01 = { bank = 8524, path = "appsystem/gimmick/gm50_096/gm50_096_interact_motlist.motlist", label = "Pitch hay", conjure = 41 },
    gm50_097    = { bank = 8525, path = "appsystem/gimmick/gm50_097/gm50_097_interact_motlist.motlist", label = "Work the hay", conjure = 41 },
    gm50_298    = { bank = 8526, path = "appsystem/gimmick/gm50_298/gm50_298_interact_motlist.motlist", label = "Dig" },
    gm50_298_01 = { bank = 8526, path = "appsystem/gimmick/gm50_298/gm50_298_interact_motlist.motlist", label = "Dig" },
    gm51_041_00 = { bank = 8527, path = "appsystem/gimmick/gm51_041/gm51_041_interact_motlist.motlist", label = "Tend the fire" },
    gm51_045    = { bank = 8528, path = "appsystem/gimmick/gm51_045/gm51_045_interact_motlist.motlist", label = "Polish" },
    gm51_132    = { bank = 8530, path = "appsystem/gimmick/gm51_132/gm51_132_interact_motlist.motlist", label = "Weave" },
    gm51_133    = { bank = 8531, path = "appsystem/gimmick/gm51_133/gm51_133_interact_motlist.motlist", label = "Weave" },
    gm51_188_00 = { bank = 8532, path = "appsystem/gimmick/gm51_188/gm51_188_00_interact_motlist.motlist", label = "Work the forge" },
    gm82_053    = { bank = 8540, path = "appsystem/gimmick/gm82_053/gm82_053_interact_motlist.motlist", label = "Smith", pin = true },
    gm82_053_01 = { bank = 8541, path = "appsystem/gimmick/gm82_053/gm82_053_01_interact_motlist.motlist", label = "Smith", pin = true },

    gm50_045_00 = { label = "Smithy station", pin = true },

    gm51_653    = { label = "Wash clothes" },

    gm50_259_01 = { label = "Chop wood" },
}

ST.prev, ST.kill_prev, ST.session, ST.pending, ST.at = false, false, nil, nil, 0
ST.status = "idle - the game offers its own prompt at each unlocked station"

-- station logging
function _st_log(s)
    pcall(function() log.info("[Interactables:ST] " .. tostring(s)) end)
    _logf("ST %s", tostring(s))
end

local function _st_motion()
    local go = _char_go(_player())
    local m = nil
    pcall(function() m = go:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion")) end)
    return m
end

-- emergency release if the game gets stuck
local function _st_release_hard(reason, rec)
    local ch = _player()
    if not ch then return end
    _st_log("hard: BEGIN (" .. tostring(reason) .. ")")
    local go = _char_go(ch)
    local aj = nil
    pcall(function() aj = go and go:call("getComponent(System.Type)", sdk.typeof("app.AdjustJack")) end)

    local r_rej, r_restart, r_efsm = "no-aj", "no-aj", "no-aj"
    if aj then
        r_rej     = tostring(pcall(function() aj:call("rejectSelf") end))
        r_restart = tostring(pcall(function() aj:call("restartOwnerProcess", true) end))
        r_efsm    = tostring(pcall(function() aj:call("enableOwnerFSM") end))
    end
    _st_log("hard: trio done")

    pcall(function()
        local human = ch:call("get_Human")
        local fsm = human and human.Fsm
        if fsm then fsm:set_Enabled(true) end
        local am = ch:call("get_ActionManager")
        if am then
            am:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",
                0, "Wait", 0)
        end
    end)

    pcall(function() ch:call("setCharacterControllerEnable", true) end)
    _st_log("hard: restores done")

    pcall(function()
        local human = ch:call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        local lent = holder:get_field("PickableObject")
        local eqit = holder:get_field("EquipItem")
        if lent or eqit then
            pcall(function() holder:call("forceReturnEquipItem(System.Boolean)", false) end)
            pcall(function() holder:call("notifyEndInteract") end)
            pcall(function()
                local ctx = holder:get_field("Context")
                if ctx and ctx:call("get_HasEquipItem") then ctx:call("removeEquipItem") end
            end)
        end
    end)

    pcall(function()
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if layer then
            layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
                0, 0, 0.0, 6.0, 1, 1)
        end
    end)

    pcall(function()
        local owner = rec and rec.owner
        if not owner then return end
        local dough = owner:get_field("_Dough")
        local tf = dough and dough:call("get_Transform")
        local sp, sr = owner:get_field("_StartPos"), owner:get_field("_StartRot")
        if tf and sp then tf:call("set_Position", sp) end
        if tf and sr then tf:call("set_Rotation", sr) end
    end)

    _st_log("hard: prop return + owner reset done")
    ST.session = nil

    local interacting = nil
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        if mgr then interacting = mgr:call("isInteracting(app.Character)", ch) end
    end)
    ST.status = string.format("HARD released (%s) aj=[rej=%s restart=%s efsm=%s]%s",
        tostring(reason or "manual"), r_rej, r_restart, r_efsm,
        interacting == true and "  WARNING: MANAGER SESSION STILL OPEN - reload the save; please report this" or "")
    _st_log("hard: END - " .. ST.status)
end

-- stop the current station the safe way
function _st_release(reason)
    local ch = _player()
    if not ch then return end
    local rec = nil
    pcall(function()
        local a = _active_native()
        rec = a and a.rec
    end)
    local flagged = false
    _st_log("release: requesting native abort (" .. tostring(reason) .. ") on "
        .. tostring(rec and rec.host or (ST.session and ST.session.host) or "?"))
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        local a = mgr and mgr:call("getActiveInteract(app.Character)", ch)
        if a then
            a:set_field("IsNeedAbort", true)
            flagged = a:get_field("IsNeedAbort") == true
        end
    end)
    _st_log("release: flag write done (flagged=" .. tostring(flagged)
        .. ") - anything after this line is the GAME's abort processing")
    if flagged then
        ST.pending = { at = os.clock(), reason = tostring(reason or "manual"), rec = rec }
        ST.session = nil
        pcall(function()
            local IP = _G.IrisPrompt
            if IP and type(IP.clear) == "function" then IP.clear("interactables_station") end
        end)
        ST.status = string.format("native abort requested (%s)...", tostring(reason or "manual"))
        _logf("station %s", ST.status)
        return
    end

    _st_release_hard(reason, rec)
end

local function _st_native_busy_read()
    local IP = _G.IrisPrompt
    if IP and type(IP.native_busy) == "function" then
        local b = false
        pcall(function() b = IP.native_busy() == true end)
        return b
    end
    local b = false
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        b = mgr and mgr:call("hasHighestPriorityObjectForPlayer") == true
    end)
    return b
end

-- tools you can use from your hands
local TOOLS = {
    gm50_007 = { verb = "Sweep", finish_verb = "Finish sweeping",
        cands = { { bank = 8509, path = "appsystem/gimmick/gm50_007/gm50_007_01_interact_motlist.motlist" },
                  { bank = 8508, path = "appsystem/gimmick/gm50_007/gm50_007_interact_motlist.motlist" } },
        names = { start  = "ch00_000_rol_sweep_idle_start",
                  loop   = "ch00_000_rol_sweep_idle_loop",
                  finish = "ch00_000_rol_sweep_idle_end" } },
}
local TL = { at = 0, key = nil, act = nil, prev = false, raw = nil,
             mounted = {}, holders = {}, clips = {}, res = {}, probed = {}, rtry = {} }

TL.eqid = {
    [1]="it02_000", [2]="it02_002", [3]="it02_005", [44]="it02_008",
    [4]="it03_000", [5]="it03_004", [6]="it03_005", [7]="it03_006", [8]="it03_007",
    [9]="it09_001", [10]="it10_001", [11]="it10_002", [12]="it10_003", [13]="it10_004",
    [14]="it10_005", [15]="it10_006", [16]="it10_007", [49]="it10_008", [17]="it10_011",
    [18]="it10_030", [19]="it10_031", [20]="it10_032", [21]="it10_033",
    [22]="it50_005", [46]="it50_007", [50]="it50_010_01", [47]="it50_013",
    [23]="it50_029", [45]="it50_031", [24]="it50_032", [25]="it50_033",
    [52]="it50_035_00", [48]="it50_042_01", [26]="it50_044", [27]="it50_055",
    [41]="it50_096_00", [43]="it50_298", [42]="it51_046", [28]="it51_367",
    [29]="it80_161", [30]="it80_162", [31]="it80_163", [55]="it81_010",
    [32]="it81_012", [33]="it81_028", [34]="it81_029", [35]="it81_031",
    [36]="it81_148", [51]="it81_157_00", [53]="it81_178_00", [54]="it81_178_01",
    [37]="it82_052", [38]="it99_002", [39]="it99_003", [40]="it99_600",
}

local function _tl_mount(bank, path)
    if TL.mounted[bank] == path then return true end
    local motion = _st_motion()
    if not motion then return false end
    local holder = nil
    pcall(function()
        local res = sdk.create_resource("via.motion.MotionListResource", path)
        if res then
            res = res:add_ref()
            holder = res:create_holder("via.motion.MotionListResourceHolder"):add_ref()
        end
    end)
    if not holder then return false end
    local ok = pcall(function()
        local n = motion:call("getDynamicMotionBankCount")
        local newBank, idx = nil, n
        for i = 0, n - 1 do
            local b = motion:call("getDynamicMotionBank", i)
            if b and b:call("get_BankID") == bank then newBank, idx = b, i break end
        end
        if not newBank then
            motion:call("setDynamicMotionBankCount", n + 1)
            newBank = sdk.create_instance("via.motion.DynamicMotionBank"):add_ref()
        end
        newBank:call("set_MotionList", holder)
        newBank:call("set_OverwriteBankID", true)
        newBank:call("set_BankID", bank)
        motion:call("setDynamicMotionBank", idx, newBank)
    end)
    if not ok then return false end
    TL.holders[bank], TL.mounted[bank] = holder, path
    _st_log("tool bank " .. bank .. " mounted")
    return true
end

local function _tl_clips(bank)
    if TL.clips[bank] then return TL.clips[bank] end
    local motion = _st_motion()
    if not motion then return nil end
    local map, n = {}, 0
    pcall(function()
        local count = tonumber(motion:call("getMotionCount", bank)) or 0
        for i = 0, count - 1 do
            local info = sdk.create_instance("via.motion.MotionInfo", true)
            if info then
                local got = motion:call(
                    "getMotionInfoByIndex(System.UInt32, System.UInt32, via.motion.MotionInfo)",
                    bank, i, info)
                if got ~= false then
                    local nm = tostring(info:call("get_MotionName") or "")
                    if nm ~= "" then map[nm] = tonumber(info:call("get_MotionID")); n = n + 1 end
                end
            end
        end
    end)
    if n == 0 then return nil end
    TL.clips[bank] = map
    return map
end

local function _tl_resolve(key)
    local cur = TL.res[key]
    if cur then return cur end
    if cur == false then return nil end
    local now = os.clock()
    local rt = TL.rtry[key]
    if rt and now - (rt.last or 0) < 0.5 then return nil end
    if not rt then rt = { first = now }; TL.rtry[key] = rt end
    rt.last = now
    local row = TOOLS[key]
    local readable, total = 0, 0
    for _, c in ipairs(row.cands or {}) do
        total = total + 1
        if _tl_mount(c.bank, c.path) then
            local map = _tl_clips(c.bank)
            if map then
                readable = readable + 1
                local ids = { start = map[row.names.start], loop = map[row.names.loop],
                              finish = map[row.names.finish] }
                if ids.start and ids.loop and ids.finish then
                    TL.res[key] = { bank = c.bank, ids = ids }
                    TL.rtry[key] = nil
                    _st_log(string.format("tool %s resolved: bank %d %d/%d/%d",
                        key, c.bank, ids.start, ids.loop, ids.finish))
                    return TL.res[key]
                end
            end
        end
    end
    if total > 0 and readable >= total then

        TL.res[key] = false
        for _, c in ipairs(row.cands or {}) do
            local map = TL.clips[c.bank]
            if map then
                local names = {}
                for nm in pairs(map) do names[#names + 1] = nm end
                table.sort(names)
                _st_log("tool " .. key .. " bank " .. c.bank .. " actual clips: "
                    .. table.concat(names, " | "))
            end
        end
        _st_log("tool " .. key .. " UNRESOLVED - the names above are the truth, fix the row")
    elseif now - (rt.first or now) > 8.0 then
        TL.res[key] = false
        _st_log("tool " .. key .. " UNRESOLVED - clips never streamed in 8s")
    end
    return nil
end

local function _tl_probe_names(key)
    if not key or TL.probed[key] then return end
    local st = STATIONS[key]
    if not (st and st.bank and st.path) then
        local base = key:match("^(gm%d+_%d+)")
        st = base and STATIONS[base] or nil
    end
    if not (st and st.bank and st.path) then
        TL.probed[key] = true
        _st_log("probe " .. key .. ": no verified motlist on record - nothing mounted")
        return
    end
    if not _tl_mount(st.bank, st.path) then
        TL.probed[key] = true
        _st_log("probe " .. key .. ": motlist mount failed")
        return
    end

    TL.probed[key] = { bank = st.bank, first = os.clock(), last = 0 }
end

local function _tl_probe_pump()
    for key, p in pairs(TL.probed) do
        if type(p) == "table" then
            local now = os.clock()
            if now - (p.last or 0) >= 0.5 then
                p.last = now
                local map = _tl_clips(p.bank)
                if map then
                    local names = {}
                    for nm in pairs(map) do names[#names + 1] = nm end
                    table.sort(names)
                    _st_log("probe " .. key .. " clip names: " .. table.concat(names, " | "))
                    TL.probed[key] = true
                elseif now - (p.first or now) > 8.0 then
                    _st_log("probe " .. key .. ": clips never streamed in 8s")
                    TL.probed[key] = true
                end
            end
        end
    end
end

local function _tl_held_key()
    local key, raw = nil, nil
    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end

        local ctx = holder:get_field("Context")
        if ctx then
            local v = ctx:get_field("EquipItemID")
            local id = tonumber(v)
            if not id and v ~= nil then
                pcall(function() id = tonumber(v:get_field("value__")) end)
            end
            if id and id ~= 0 then raw = TL.eqid[id] or ("eqid:" .. tostring(id)) end
        end

        if not raw then
            local lst = holder:get_field("HoldObjects")
            local n = lst and tonumber(lst:call("get_Count")) or 0
            for i = 0, n - 1 do
                local ok = pcall(function()
                    local info = lst:call("get_Item", i)
                    local gib = info and info:get_field("Object")
                    local nm = gib and tostring(gib:call("get_GameObject"):call("get_Name"))
                    if nm and nm ~= "" and nm ~= "nil" then raw = nm end
                end)
                if ok and raw then break end
            end
        end

        if not raw then
            local gib = holder:get_field("PickableObject")
            if gib then
                pcall(function() raw = tostring(gib:call("get_GameObject"):call("get_Name")) end)
                if raw == "nil" or raw == "" then raw = nil end
            end
        end
        if raw then
            local twin = raw:lower():match("^i?t(%d+_%d+.*)$")
            key = twin and _norm("gm" .. twin) or _norm(raw)
        end
    end)
    if raw ~= TL.raw then
        TL.raw = raw
        if raw then
            _st_log("holding: " .. tostring(raw) .. " -> " .. tostring(key or "?")
                .. ((key and TOOLS[key]) and "" or " (no tool row)"))
            if key and not TOOLS[key] then _tl_probe_names(key) end
        end
    end
    -- a tool we spawned into her hand counts just as much as a native hold
    if not (key and TOOLS[key]) and TL.carry_key and TOOLS[TL.carry_key] then
        return TL.carry_key
    end
    return key and TOOLS[key] and key or nil
end

local function _tl_stop(reason)
    local act = TL.act
    TL.act = nil
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear) == "function" then IP.clear("interactables_tool") end
    end)
    if not act then return end

    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        local fsm = human and human.Fsm
        if fsm then fsm:set_Enabled(true) end
        local am = ch and ch:call("get_ActionManager")
        if am then
            am:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",
                0, "Wait", 0)
        end
    end)
    pcall(function()
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if layer then
            layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
                0, 0, 0.0, 6.0, 1, 1)
        end
    end)
    _st_log("tool drive stopped (" .. tostring(reason) .. ")")
end

local function _tl_play(phase)
    local act = TL.act
    if not act then return false end
    local ok = pcall(function()
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if not layer then error("no layer 0") end
        layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
            act.res.bank, act.res.ids[phase], 0.0, 6.0, 1, 1)
    end)
    if ok then act.phase, act.started = phase, os.clock() end
    return ok
end

local function _tl_move_mag()
    local m = 0.0
    pcall(function()
        if _kb_down(0x57) or _kb_down(0x41)
            or _kb_down(0x53) or _kb_down(0x44) then m = 1.0 end
    end)
    if m < 0.3 then
        pcall(function()
            local gp = sdk.get_native_singleton("via.hid.GamePad")
            local td = sdk.find_type_definition("via.hid.GamePad")
            local dev = gp and td and sdk.call_native_func(gp, td, "get_MergedDevice")
            if not dev then return end
            local v = dev:call("get_AxisL")
            if v then
                local x, y = tonumber(v.x) or 0, tonumber(v.y) or 0
                m = math.sqrt(x * x + y * y)
            end
        end)
    end
    return m
end

-- tool prompts and playback
local function _tl_frame()
    if M.stations == false then if TL.act then _tl_stop("disabled") end return end
    _tl_probe_pump()

    local down = _interact_down()
    local edge = down and not TL.prev
    TL.prev = down

    local act = TL.act
    if act then
        if _loading() or _menu_open() then return _tl_stop(_loading() and "loading" or "menu") end
        if _binding_down(M.stop_bind or "backspace") then return _tl_stop("stop binding") end
        if _tl_move_mag() > 0.3 or _binding_down("space, cross") then
            return _tl_stop("movement")
        end
        if edge and act.phase ~= "finish" then
            if not _tl_play("finish") then return _tl_stop("finish clip failed") end
        elseif edge then
            return _tl_stop("second press during finish")
        end

        pcall(function()
            local motion = _st_motion()
            local layer = motion and motion:call("getLayer", 0)
            if not layer then return end
            local elapsed = math.max(0.0, os.clock() - (tonumber(act.started) or 0))
            local ef = tonumber(layer:call("get_EndFrame")) or 0.0
            local raw = elapsed * 60.0
            if act.phase ~= "loop" and ef > 1.0 and raw >= ef - 1.0 then
                if act.phase == "start" then
                    if not _tl_play("loop") then _tl_stop("loop clip failed") end
                else
                    _tl_stop("finished")
                end
                return
            end
            local frame = raw
            if act.phase == "loop" and ef > 1.0 then frame = frame % ef
            elseif ef > 1.0 then frame = math.min(frame, ef - 1.0) end
            layer:call("set_Frame", frame)
        end)
        pcall(function()
            local IP = _G.IrisPrompt
            if IP and type(IP.set) == "function" and TL.act then
                local row = TOOLS[TL.act.key] or {}
                local pgo = _char_go(_player())
                IP.set("interactables_tool",
                    TL.act.phase == "finish" and "Stopping"
                        or (row.finish_verb or "Finish"), 5, 0.05,
                    pgo and _pos(pgo), pgo)
            end
        end)
        return
    end

    local now = os.clock()
    if now - (tonumber(TL.at) or 0) < 0.25 then return end
    TL.at = now
    if _loading() or _menu_open() or ST.session or ST.pending then TL.key = nil; return end
    local jacked = false
    pcall(function()
        local ch = _player()
        jacked = ch and ch:call("get_IsJacked") == true
    end)
    if jacked then TL.key = nil; return end
    TL.key = _tl_held_key()
    if not TL.key then
        pcall(function()
            local IP = _G.IrisPrompt
            if IP and type(IP.clear) == "function" then IP.clear("interactables_tool") end
        end)
        return
    end
    local IP = _G.IrisPrompt
    if not (IP and type(IP.set) == "function") then return end
    local row = TOOLS[TL.key]

    if not _tl_resolve(TL.key) then
        pcall(function()
            if type(IP.clear) == "function" then IP.clear("interactables_tool") end
        end)
        return
    end
    local pgo = _char_go(_player())
    pcall(function()
        IP.set("interactables_tool", tostring(row.verb), 1, 0.4, pgo and _pos(pgo), pgo)
    end)
    if edge then
        local w = nil
        pcall(function() w = IP.winner() end)
        if w ~= "interactables_tool" then return end
        local busy = _st_native_busy_read()
        if busy then return end
        local res = _tl_resolve(TL.key)
        if not res then return end
        local ok = pcall(function()
            local ch = _player()
            local human = ch:call("get_Human")
            local fsm = human and human.Fsm
            if not fsm then error("no Human.Fsm") end
            fsm:set_Enabled(false)
        end)
        if not ok then return end
        TL.act = { key = TL.key, res = res }
        if not _tl_play("start") then _tl_stop("start clip failed") end
        _st_log("tool drive started: " .. TL.key .. " (" .. tostring(row.verb) .. ")")
    end
end

-- puts a prop in the free hand
local function _st_conjure(id, draw, quiet)
    local ok = false

    local ran, err = pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        local ctrl = human and human:call("get_EquipItemCtrl")
        if not ctrl then error("EquipItemCtrl is nil") end

        local nv = ValueType.new(sdk.find_type_definition("System.Nullable`1<via.vec3>"))
        local nq = ValueType.new(sdk.find_type_definition("System.Nullable`1<via.Quaternion>"))
        if not (nv and nq) then error("Nullable struct creation failed") end
        ctrl:call("requestExternal", id, draw and true or false, "R_PropA", nv, nq)
        ok = true
    end)
    if not quiet then
        _st_log(string.format("prop %s: eq id %d (%s)",
            draw and "conjure" or "return", tonumber(id) or -1,
            ok and "requested" or ("FAILED: " .. tostring(err or "?"))))
    end
    return ok
end

-- keeps a carried villager tool in hand when running shakes it loose
local CARRY = { id = nil, conjured = false, prev_kill = false, at = 0 }

local function _carry_release(quiet)
    if _valid(CARRY.go) then
        pcall(function()
            local btf = CARRY.go:call("get_Transform")
            btf:call("set_ParentJoint", "")
            btf:call("set_Parent", nil)
        end)
        pcall(function() CARRY.go:call("destroy", CARRY.go) end)
    end
    if CARRY.cook and _valid(CARRY.cook.go) then
        pcall(function() CARRY.cook.go:call("destroy", CARRY.cook.go) end)
    end
    CARRY.go, CARRY.job, CARRY.cook, CARRY.cands, CARRY.ci = nil, nil, nil, nil, nil
    CARRY.warm = nil
    CARRY.id, CARRY.conjured, CARRY.have, CARRY.lost_at = nil, false, false, nil
    TL.carry_key = nil
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear) == "function" then IP.clear("interactables_carry") end
    end)
end

-- the tool is LENT, not taken, so the cleanest keep is to borrow it straight back
local function _carry_reborrow()
    local ok = false
    pcall(function()
        local human = _player() and _player():call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        local td = sdk.find_type_definition("app.GimmickHolder")
        for _, mm in ipairs((td and td:get_methods()) or {}) do
            local nm
            pcall(function() nm = mm:get_name() end)
            if nm == "borrowEquipItem" then
                pcall(function() mm:call(holder); ok = true end)
            end
        end
    end)
    return ok
end

-- ⛔ never hook this subsystem, a log only hook here crashed cooking in the dispatch stub

-- hands the borrowed tool back on purpose
local function _carry_native_drop()
    local done = false
    pcall(function()
        local ch = _player()
        -- Beams, logs and other two-handed scene props use ObjectCarry rather than
        -- GimmickHolder. Keep their native pose and use the game's own put-down.
        local oc = ch and ch:call("get_ObjectCarry")
        if oc and oc:call("isPickupCarrying") == true then
            oc:call("putObject")
            done = true
            return
        end
        local human = ch and ch:call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        local td = sdk.find_type_definition("app.GimmickHolder")
        for _, mm in ipairs((td and td:get_methods()) or {}) do
            local nm
            pcall(function() nm = mm:get_name() end)
            if nm == "returnEquipItem" then
                pcall(function() mm:call(holder, true); done = true end)
            end
        end
    end)
    return done
end

-- every tool prefab has its own origin, so each needs its own hand offset
local function _carry_grip(id)
    local g = (M.tool_grip or {})[tostring(id)]
    if type(g) ~= "table" then return 0, 0, 0, 0, 0, 0 end
    return tonumber(g[1]) or 0, tonumber(g[2]) or 0, tonumber(g[3]) or 0,
           tonumber(g[4]) or 0, tonumber(g[5]) or 0, tonumber(g[6]) or 0
end

local function _carry_apply_grip()
    if not (CARRY.go and CARRY.id) then return end
    local ox, oy, oz, rx, ry, rz = _carry_grip(CARRY.id)
    pcall(function()
        local btf = CARRY.go:call("get_Transform")
        btf:call("set_LocalPosition", Vector3f.new(ox, oy, oz))
        local d = math.pi / 360
        local cx, sx = math.cos(rx * d), math.sin(rx * d)
        local cy, sy = math.cos(ry * d), math.sin(ry * d)
        local cz, sz = math.cos(rz * d), math.sin(rz * d)
        local q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
        q.w = cy * cx * cz + sy * sx * sz
        q.x = cy * sx * cz + sy * cx * sz
        q.y = sy * cx * cz - cy * sx * sz
        q.z = cy * cx * sz - sy * sx * cz
        btf:call("set_LocalRotation", q)
    end)
end

-- prefabs are kept once loaded, so the second pickup of a tool is instant
local PFB_CACHE = {}
local function _carry_pfb(name)
    if PFB_CACHE[name] then return PFB_CACHE[name] end
    local pfb
    local ok = pcall(function()
        pfb = sdk.create_instance("via.Prefab"):add_ref()
        pcall(function() pfb:add_ref_permanent() end)
        pcall(function() pfb:call(".ctor()") end)
        pfb:call("set_Path", "AppSystem/Equipment/eqit/" .. name .. ".pfb")
        pcall(function() pfb:call("set_Standby", true) end)
    end)
    if ok and pfb then PFB_CACHE[name] = pfb end
    return PFB_CACHE[name]
end

local function _carry_names(id)
    local base = TL.eqid[id]
    if not base then return nil end
    return { "eq" .. base, "eq" .. base .. "_00", base }
end

-- start the prefab loading the moment she picks a tool up, not when it falls
local function _carry_warm(id)
    if CARRY.warm == id then return end
    local names = _carry_names(id)
    if not names then return end
    CARRY.warm = id
    _carry_pfb(names[1])
end

-- spawns a copy of the tool prefab, the same recipe as the anvil workpiece
local _carry_try_next
_carry_try_next = function()
    CARRY.ci = (CARRY.ci or 0) + 1
    local name = CARRY.cands and CARRY.cands[CARRY.ci]
    if not name then
        _st_log("carry: no equip prefab found for this tool")
        return
    end
    local pfb = _carry_pfb(name)
    if pfb then CARRY.job = { pfb = pfb, f = 0, name = name } end
end

local function _carry_spawn(id)
    local names = _carry_names(id)
    if not names then _st_log("carry: unknown eq id " .. tostring(id)); return end
    CARRY.cands = names
    CARRY.ci = 0
    _carry_try_next()
end

local function _carry_tick()
    if M.keep_tools == false or M.native_chores ~= true then
        CARRY.allow_drop = true
        _carry_release(); return
    end
    if ST.session or ST.conjured then _carry_release(); return end
    local now = os.clock()

    local kill = _drop_down()
    local edge_kill = kill and not CARRY.prev_kill
    CARRY.prev_kill = kill

    -- the hold can live in any of three fields, a bare Context read misses a plain carry
    local held, id, nm = false, 0, nil
    pcall(function()
        local human = _player() and _player():call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        local ctx = holder:get_field("Context")
        local v = ctx and ctx:get_field("EquipItemID")
        id = tonumber(v) or 0
        if id == 0 and v ~= nil then
            pcall(function() id = tonumber(v:get_field("value__")) or 0 end)
        end
        if id ~= 0 then held = true; return end
        local lst = holder:get_field("HoldObjects")
        if lst and (tonumber(lst:call("get_Count")) or 0) > 0 then
            held = true
            pcall(function()
                local info = lst:call("get_Item", 0)
                local gib = info and info:get_field("Object")
                nm = gib and tostring(gib:call("get_GameObject"):call("get_Name"))
            end)
        end
        if not held then
            local gib = holder:get_field("PickableObject")
            if gib then
                held = true
                pcall(function() nm = tostring(gib:call("get_GameObject"):call("get_Name")) end)
            end
        end
        if held and nm then
            -- match by digit core so gimmick names (gm50_007) still map to equip ids (it50_007)
            local low = nm:lower()
            local best, bl = 0, 0
            for k, v2 in pairs(TL.eqid) do
                local digits = v2:gsub("^i?t", "")
                if #digits > bl and low:find(digits, 1, true) then best, bl = k, #digits end
            end
            id = best
        end
    end)

    if edge_kill then
        -- let the game take its own tool back, then clear anything we spawned
        CARRY.allow_drop = true
        local gave = _carry_native_drop()
        CARRY.kept_logged = false
        if CARRY.id or gave then _st_log("carry: put down") end
        _carry_release(false)
        CARRY.drop_until = now + 1.0
        return
    end
    if CARRY.drop_until and now > CARRY.drop_until then
        CARRY.allow_drop, CARRY.drop_until = false, nil
    end

    -- B belongs to the world and to the tool's own verb, dropping lives on its own bind

    if held then
        if CARRY.conjured then _carry_release(true) end
        if id ~= 0 and CARRY.id ~= id and M.dev then
            _st_log(string.format("carry: holding eq id %d (%s)", id, tostring(nm or "Context")))
        end
        if id ~= 0 then CARRY.id = id; _carry_warm(id) end
        CARRY.nm = nm or CARRY.nm
        if not CARRY.have then CARRY.adopt_at = now end
        CARRY.conjured, CARRY.lost_at, CARRY.lost_run = false, nil, nil
        CARRY.have, CARRY.reborrowed = true, false
        return
    end

    if not (CARRY.have and CARRY.id) then
        if CARRY.have and M.dev then
            _st_log("carry: hold ended but no eq id was captured (name="
                .. tostring(CARRY.nm) .. ") - cannot keep it")
        end
        CARRY.have = false
        return
    end

    if CARRY.conjured then
        if CARRY.go then _carry_apply_grip() end
        return
    end

    -- only re-take the tool once the hold has been gone a beat, never on a flicker
    if not CARRY.lost_at then CARRY.lost_at = now; return end
    if now - CARRY.lost_at < 0.15 then return end

    -- a put-down runs through an interaction, a run-drop does not
    local interacting = false
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        interacting = mgr and mgr:call("isInteracting(app.Character)", _player()) == true
    end)
    if interacting then
        if M.dev then _st_log("carry: set down through an interaction - released") end
        CARRY.id, CARRY.have, CARRY.lost_at = nil, false, nil
        return
    end
    -- ask for the loan back first, that keeps the game's own pose and prop
    if not CARRY.reborrowed then
        CARRY.reborrowed = true
        if _carry_reborrow() then
            CARRY.lost_at = nil
            _st_log("carry: borrowed the tool back")
            return
        end
    end
    CARRY.conjured, CARRY.at = true, now
    _carry_spawn(CARRY.id)
    _st_log(string.format("carry: hold died %.1fs after pickup - spawning %s (L3/BACKSPACE lets go)",
        now - (tonumber(CARRY.adopt_at) or now), tostring(TL.eqid[CARRY.id] or CARRY.id)))
end

-- builds the spawned tool and glues it to the hand, same recipe as the workpiece
local function _carry_build()
    if CARRY.cook then
        local ck = CARRY.cook
        ck.f = ck.f + 1
        if ck.f >= 10 then
            CARRY.go = ck.go
            CARRY.cook = nil
            pcall(function()
                local pgo = _char_go(_player())
                local ptf = pgo and pgo:call("get_Transform")
                local btf = CARRY.go:call("get_Transform")
                if not (ptf and btf) then return end
                local ok = pcall(function() btf:call("setParent", ptf, true) end)
                if not ok then pcall(function() btf:call("set_Parent", ptf) end) end
                pcall(function() btf:call("set_ParentJoint", "R_PropA") end)
                _carry_apply_grip()
                -- tell the tool system it is holding this, so sweeping still works
                local base = TL.eqid[CARRY.id]
                local twin = base and base:lower():match("^i?t(%d+_%d+.*)$")
                local raw = twin and ("gm" .. twin)
                if raw then
                    TL.carry_key = TOOLS[raw] and raw or _norm(raw)
                end
                _st_log("carry: tool in hand (" .. tostring(TL.carry_key or "no tool row") .. ")")
            end)
        end
        return
    end
    if not CARRY.job then return end
    local q = CARRY.job
    pcall(function()
        q.f = q.f + 1
        if q.pfb:call("get_Ready") == true then
            local inst
            local pgo = _char_go(_player())
            local p = pgo and _pos(pgo)
            pcall(function()
                inst = q.pfb:call("instantiate(via.vec3)",
                    Vector3f.new(p and p.x or 0, (p and p.y or 0) + 1.0, p and p.z or 0))
            end)
            if not inst then
                pcall(function()
                    inst = q.pfb:call("instantiate", Vector3f.new(p and p.x or 0,
                        (p and p.y or 0) + 1.0, p and p.z or 0))
                end)
            end
            CARRY.job = nil
            if inst then
                CARRY.cook = { go = inst, f = 0 }
                _st_log("carry: spawned " .. tostring(q.name))
            else
                _st_log("carry: " .. tostring(q.name) .. " would not instantiate")
                _carry_try_next()
            end
        elseif q.f > 300 then
            CARRY.job = nil
            _st_log("carry: " .. tostring(q.name) .. " never became ready")
            _carry_try_next()
        end
    end)
end

local BP = { at = 0 }
-- bed diagnostics
local function _bed_probe_tick()
    if M.dev ~= true then return end
    local now = os.clock()
    if now - (tonumber(BP.at) or 0) < 5.0 then return end
    BP.at = now
    local pgo = _char_go(_player())

    local pp = pgo and _upos(pgo)
    if not pp then return end
    local seen = {}
    local nrec, nio, best = 0, 0, nil
    for _, r in pairs(unlocks) do

        local rio = r.io
        if r.kind == "bed" and not rio and r.owner then
            pcall(function() rio = r.owner:get_field("InteractiveObject") end)
        end
        if r.kind == "bed" then
            nrec = nrec + 1
            if rio then nio = nio + 1 end
        end
        local rio_addr = r.io_addr or (rio and _addr(rio)) or 0
        if r.kind == "bed" and rio and not seen[rio_addr] then
            seen[rio_addr] = true
            pcall(function()
                local io = rio
                local n = tonumber(io:call("getNumInteractPoint")) or 0
                local near = false
                for i = 0, n - 1 do
                    local q = io:call("getInteractPointPosition", i)
                    if q then
                        local dx, dy, dz = q.x - pp.x, q.y - pp.y, q.z - pp.z
                        local d2 = dx * dx + dy * dy + dz * dz
                        if not best or d2 < best then best = d2 end
                        if d2 < 16.0 then near = true break end
                    end
                end
                if not near then return end
                BP.hit = true
                local works = io:get_field("Works")
                for i = 0, n - 1 do
                    local w = works and works:call("get_Item", i)
                    if w then
                        local en, ia, cp, da = "?", "?", "?", nil
                        pcall(function() en = tostring(w:get_field("_IsInteractEnable")) end)
                        pcall(function() ia = tostring(w:get_field("_IsInteracted")) end)
                        pcall(function() cp = tostring(w:get_field("_canPlayerInteract")) end)
                        pcall(function() da = _addr(w:get_field("_Data")) end)
                        local icon = "?"
                        pcall(function() icon = tostring(io:call("hasIcon", i)) end)
                        _st_log(string.format(
                            "BEDPROBE %s[%d] enable=%s interacted=%s canPlayer=%s hasIcon=%s patched=%s",
                            tostring(r.host), i, en, ia, cp, icon,
                            tostring(da ~= nil and da == _addr(r.point))))
                    end
                end
                pcall(function()
                    local mgr = sdk.get_managed_singleton("app.InteractManager")
                    if mgr then
                        _st_log("BEDPROBE manager hasHighest="
                            .. tostring(mgr:call("hasHighestPriorityObjectForPlayer")))
                    end
                end)
            end)
        end
    end

    if not BP.hit then
        if now - (tonumber(BP.idle_at) or 0) > 15.0 then
            BP.idle_at = now
            if nrec == 0 then
                _st_log("BEDPROBE: zero bed unlock records exist right now")
            else
                _st_log(string.format("BEDPROBE idle: %d bed records (%d with io), nearest point %s",
                    nrec, nio, best and string.format("%.1fm", math.sqrt(best)) or "unknown"))
            end

            pcall(function()
                local mgr = sdk.get_managed_singleton("app.InteractManager")
                local ups = mgr and mgr:get_field("InteractiveObjectUpdaters")
                if not ups then _st_log("ENGINESCAN: no updaters array") return end
                local found = 0
                local nu = tonumber(ups:call("get_Length")) or 0
                for u = 0, nu - 1 do
                    local lst = nil
                    pcall(function()
                        local upd = ups:get_element(u)
                        lst = upd and upd:get_field("InteractiveObjectList")
                    end)
                    local n = lst and tonumber(lst:call("get_Count")) or 0
                    for i = 0, n - 1 do
                        pcall(function()
                            local io = lst:call("get_Item", i)
                            if not io then return end
                            local np = tonumber(io:call("getNumInteractPoint")) or 0
                            local bd, bi = nil, nil
                            for p = 0, np - 1 do
                                local q = io:call("getInteractPointPosition", p)
                                if q then
                                    local dx, dy, dz = q.x - pp.x, q.y - pp.y, q.z - pp.z
                                    local d2 = dx * dx + dy * dy + dz * dz
                                    if not bd or d2 < bd then bd, bi = d2, p end
                                end
                            end
                            if bd and bd < 36.0 then
                                found = found + 1
                                local nm = "?"
                                pcall(function()
                                    local og = io:call("get_Owner")
                                    nm = tostring(og:call("get_Name"))
                                end)
                                local ct, icon = "?", "?"
                                pcall(function() ct = tostring(io:call("getTargetCharacterType", bi)) end)
                                pcall(function() icon = tostring(io:call("hasIcon", bi)) end)
                                _st_log(string.format("ENGINESCAN %.1fm %s pts=%d ct[%d]=%s icon=%s",
                                    math.sqrt(bd), nm, np, bi, ct, icon))

                            end
                        end)
                    end
                end
                _st_log("ENGINESCAN done: " .. found .. " registered interactables within 6m")
            end)
        end
    end
    BP.hit = nil
end

-- cooking list and messages
local MEATS = {
    { id = 25,  buff = 3, name = "Scrag of Beast",
      toast = "You cooked a Scrag of Beast - a hearty meal! Party Strength, Defense & Stamina up." },
    { id = 26,  buff = 5, name = "Aged Scrag of Beast",
      toast = "You cooked an Aged Scrag of Beast - pungent, but it fills bellies. Party buffed." },
    { id = 27,  buff = 0, name = "Rotten Scrag of Beast",
      toast = "You cooked a Rotten Scrag of Beast... a dubious meal. The party may regret this." },
    { id = 28,  buff = 4, name = "Beast-Steak",
      toast = "You cooked a Beast-Steak - a fine meal! Party Strength, Defense & Stamina up." },
    { id = 29,  buff = 6, name = "Aged Beast-Steak",
      toast = "You cooked an Aged Beast-Steak - sharp on the tongue. Party buffed." },
    { id = 30,  buff = 1, name = "Rotten Beast-Steak",
      toast = "You cooked a Rotten Beast-Steak... a dubious meal. The party may regret this." },
    { id = 41,  buff = 2, name = "Dried Meat",
      toast = "You cooked Dried Meat - travel fare done right. Party buffed." },
    { id = 114, buff = 7, name = "Exquisite Dried Meat",
      toast = "You cooked Exquisite Dried Meat - a feast! The party eats like royalty." },
}

local TOAST = { txt = nil, at = 0 }
local function _mc_toast(s) TOAST.txt, TOAST.at = s, os.clock() end

-- ⛔ no d2d here. It registers a draw callback at load, which stays live even when
-- the mod is switched off, and it is a suspect in the camp cooking crash.
local function _mc_toast_draw()
    if not TOAST.txt then return end
    local age = os.clock() - TOAST.at
    if age > 5.0 then TOAST.txt = nil return end
    local a = 1.0
    if age < 0.25 then a = age / 0.25
    elseif age > 4.0 then a = 1.0 - (age - 4.0) end
    local alpha = math.floor(255 * math.max(0, math.min(1, a)))
    local sh = 1080
    pcall(function()
        local sz = imgui.get_display_size()
        if sz and sz.y and sz.y > 0 then sh = sz.y end
    end)
    pcall(function()
        draw.text(TOAST.txt, 84, sh - 176, alpha * 0x1000000 + 0xB0D8EA)
    end)
end

-- town cauldrons only, camps keep the game's own cooking
local MC_POTS = {
    gm80_256 = true, gm51_381 = true, gm51_382 = true, gm51_383 = true,
}
-- These are the native camp stew sequence. Never prompt, open a dialog or consume
-- its input near them: the game is already handling the same Interact press.
local MC_NATIVE_CAMP = {
    gm80_060 = true, gm80_061 = true, gm80_062 = true,
    gm80_063 = true, gm80_064 = true,
}
local MC = { at = 0, near = nil, prev = false, open = false, baseline = nil,
             opened_at = 0, closed_at = 0, opts = nil, more = false, page = 1,
             stir_until = nil }

local function _mc_party()
    local out = {}
    local ch = _player()
    if ch then out[#out + 1] = ch end
    local seen = { [_addr(ch) or 0] = true }
    -- the party list and the world list answer to different getters, so try both
    for _, getter in ipairs({ "get_PartyPawnList", "get_PawnCharacterList" }) do
        local lst
        pcall(function()
            local pm = sdk.get_managed_singleton("app.PawnManager")
            lst = pm and pm:call(getter)
        end)
        local n = 0
        pcall(function() n = tonumber(lst:call("get_Count")) or 0 end)
        for i = 0, n - 1 do
            -- one pcall per pawn, a bad entry must not end the whole sweep
            pcall(function()
                local pawn
                pcall(function() pawn = lst[i] end)
                if not pawn then pcall(function() pawn = lst:call("get_Item", i) end) end
                local c = pawn
                pcall(function() c = pawn:call("get_CachedCharacter") or pawn end)
                local a = c and _addr(c)
                if c and a and not seen[a] then
                    seen[a] = true
                    out[#out + 1] = c
                end
            end)
        end
        if #out > 1 then break end
    end
    return out
end

local function _mc_avail()
    local t, party = {}, _mc_party()
    local im = sdk.get_managed_singleton("app.ItemManager")
    if not im then return t end
    for _, m in ipairs(MEATS) do
        local total, holder = 0, nil
        for _, ch in ipairs(party) do
            local n = 0
            pcall(function()
                n = tonumber(im:call("getHaveNum(System.Int32, app.Character)", m.id, ch)) or 0
            end)
            if n > 0 and not holder then holder = ch end
            total = total + n
        end
        if total > 0 then t[#t + 1] = { m = m, count = total, holder = holder } end
    end
    return t
end

local function _mc_pick()
    local p
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local rv = gm and gm:call("getDialogState")
        if rv == nil then return end
        if type(rv) == "number" then p = rv
        else pcall(function() p = sdk.to_int64(rv) & 0xFFFFFFFF end) end
    end)
    return p
end

-- never draw a dialog whose gui has not finished loading, that is a hard crash
local function _gui_dialog_ready()
    local ready, dialog = false, nil
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        if not gm then return end
        gm:call("requestGuiType", 14)
        local loaded = gm:call("IsLoadGuiType", 14)
        dialog = gm:get_field("Dialog")
        ready = (loaded ~= false) and dialog ~= nil
    end)
    return ready, dialog
end

local function _mc_show(prompt, l1, l2, l3, l4)
    local ready, dialog = _gui_dialog_ready()
    if not ready then
        MC.want = { prompt, l1, l2, l3, l4, at = os.clock() }
        _st_log("cook dialog: gui not loaded yet, waiting")
        return
    end
    MC.want = nil
    local ok = pcall(function()
        dialog:call("reqDisp", prompt, l1 or "", l2 or "", l3 or "", l4 or "",
            true, 0, true, 58, 0, -1, nil,
            false, false, false, false, false, false, true, 0.0)
        MC.open, MC.opened_at, MC.baseline = true, os.clock(), _mc_pick()
    end)
    if not ok then _st_log("cook dialog reqDisp FAILED") end
end

local function _mc_close()
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local dialog = gm and gm:get_field("Dialog")
        if dialog then dialog:call("reqClose") end
        gm:call("requestHideGuiType", 14)
    end)
    MC.open = false
    MC.closed_at = os.clock()
end

local function _mc_menu(page)
    local avail = _mc_avail()
    if #avail == 0 then
        MC.opts, MC.more = {}, false
        _mc_show("Nothing to cook - the pot wants meat.", "Ah well.")
        return
    end

    local per = (#avail > 3) and 2 or 3
    local start = (page - 1) * per
    local opts, labels = {}, {}
    for i = 1, per do
        local it = avail[start + i]
        if it then
            opts[#opts + 1] = it
            labels[#labels + 1] = string.format("%s (%d)", it.m.name, it.count)
        end
    end
    MC.more = (start + per) < #avail
    if MC.more then labels[#labels + 1] = "More..." end
    labels[#labels + 1] = "Cancel"
    MC.opts, MC.page = opts, page
    _mc_show("Cook what?", labels[1], labels[2], labels[3], labels[4])
end

local function _mc_stop_stir()
    if not MC.stir_until then return end
    MC.stir_until = nil

    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        if human and human.Fsm then human.Fsm:set_Enabled(true) end
        local am = ch and ch:call("get_ActionManager")
        if am then
            am:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",
                0, "Wait", 0)
        end
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if layer then
            layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
                0, 0, 0.0, 6.0, 1, 1)
        end
    end)
end

local function _mc_cook(entry)
    local ok = false
    pcall(function()
        sdk.get_managed_singleton("app.ItemManager"):call(
            "deleteItem(System.Int32, System.Int32, app.Character)",
            entry.m.id, 1, entry.holder)
        ok = true
    end)
    if not ok then _st_log("cook: deleteItem failed - nothing consumed, no buff") return end
    local party = _mc_party()
    local fed = 0
    for _, ch in ipairs(party) do
        pcall(function()
            local human = ch:call("get_Human")
            local sb = human and human:call("get_SpecialBuffManager")
            if sb then sb:call("startBuff", entry.m.buff); fed = fed + 1 end
        end)
    end
    if fed < #party then
        _st_log(string.format("cook: %d of %d party members took the buff", fed, #party))
    end
    _st_log(string.format("cooked %s - party buff on %d member(s)", entry.m.name, fed))
    _mc_toast(entry.m.toast or ("You cooked a " .. entry.m.name .. "."))

    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        if human and human.Fsm then human.Fsm:set_Enabled(false) end
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if layer then
            layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
                60, 1104, 0.0, 6.0, 1, 1)
            MC.stir_until = os.clock() + 5.0
        end
    end)
end

-- cook prompt and menu
local function _mc_frame()
    if M.stations == false then return end
    local now = os.clock()

    if MC.stir_until and (now >= MC.stir_until or _tl_move_mag() > 0.3) then
        _mc_stop_stir()
    end

    if MC.open then
        local p = _mc_pick()
        if p and p ~= 0 and p ~= (MC.baseline or 0) and now - MC.opened_at > 0.3 then
            local opts, more, page = MC.opts or {}, MC.more, MC.page or 1
            _mc_close()
            local sel = tonumber(p) or 0
            if sel == 5 then return end
            if sel >= 1 and sel <= #opts then
                _mc_cook(opts[sel])
            elseif more and sel == #opts + 1 then
                _mc_menu(page + 1)
            end
        end
        return
    end

    -- the gui was still loading when the menu was asked for, try again for a moment
    if MC.want and not MC.open then
        local w = MC.want
        if now - (tonumber(w.at) or 0) > 3.0 then
            MC.want = nil
            _st_log("cook dialog: gui never loaded, giving up")
        else
            _mc_show(w[1], w[2], w[3], w[4], w[5])
        end
        return
    end

    local near = false
    if MC.near and MC_POTS[MC.near_key] == true
            and not MC_NATIVE_CAMP[MC.near_key]
            and now - (tonumber(MC.near) or 0) < 6.0 and MC.near_pos then
        local pgo2 = _char_go(_player())
        local pu = pgo2 and _upos(pgo2)
        if pu then
            local dx = MC.near_pos.x - pu.x
            local dy = MC.near_pos.y - pu.y
            local dz = MC.near_pos.z - pu.z
            near = dx * dx + dy * dy + dz * dz < 6.76
        end
    end
    if near and (ST.session or ST.pending or TL.act) then near = false end

    local down = _interact_down()
    local edge = down and not MC.prev
    MC.prev = down
    if now - (tonumber(MC.closed_at) or 0) < 0.4 then return end
    if not near or MC.stir_until then
        pcall(function()
            local IP = _G.IrisPrompt
            if IP and type(IP.clear) == "function" then IP.clear("interactables_cook") end
        end)
        return
    end
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.set) == "function" then
            local pgo = _char_go(_player())
            IP.set("interactables_cook", "Cook", 1, 0.4, pgo and _pos(pgo), pgo)
        end
    end)
    if edge then
        local w
        pcall(function() w = _G.IrisPrompt and _G.IrisPrompt.winner() end)
        if w ~= "interactables_cook" then return end
        if _st_native_busy_read() then return end
        _mc_menu(1)
    end
end

-- holds a spawned workpiece against the free hand while smithing
local PIN = { pfb = nil, job = nil, go = nil, id = nil }

local function _pin_despawn()
    if _valid(PIN.go) then
        -- detach from the hand before destroying
        pcall(function()
            local btf = PIN.go:call("get_Transform")
            btf:call("set_ParentJoint", "")
            btf:call("set_Parent", nil)
        end)
        pcall(function() PIN.go:call("destroy", PIN.go) end)
    end
    if _valid(PIN.donor) then pcall(function() PIN.donor:call("destroy", PIN.donor) end) end
    if PIN.cook and _valid(PIN.cook.go) then
        pcall(function() PIN.cook.go:call("destroy", PIN.cook.go) end)
    end
    PIN.go, PIN.job, PIN.id, PIN.jname, PIN.cook, PIN.donor = nil, nil, nil, nil, nil, nil
    PIN.bmc, PIN.rebind = nil, nil
end

-- finds the mesh component on a prop or its children
local function _pin_find_mesh(go, depth)
    if not go or (depth or 0) > 4 then return nil end
    local mc
    pcall(function()
        mc = go:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
    end)
    if mc then return mc end
    local found
    pcall(function()
        local tf = go:call("get_Transform")
        local child = tf and tf:call("get_Child")
        while child and not found do
            local cgo = child:call("get_GameObject")
            if cgo then found = _pin_find_mesh(cgo, (depth or 0) + 1) end
            child = child:call("get_Next")
        end
    end)
    return found
end

-- applies the grip offset and rotation sliders to the held workpiece
local function _pin_apply_local()
    if not (PIN.go and PIN.jname) then return end
    pcall(function()
        local btf = PIN.go:call("get_Transform")
        btf:call("set_LocalPosition",
            Vector3f.new(M.pin_ox or 0, M.pin_oy or 0, M.pin_oz or 0))
        local d = math.pi / 360
        local cx, sx = math.cos((M.pin_rx or 0) * d), math.sin((M.pin_rx or 0) * d)
        local cy, sy = math.cos((M.pin_ry or 0) * d), math.sin((M.pin_ry or 0) * d)
        local cz, sz = math.cos((M.pin_rz or 0) * d), math.sin((M.pin_rz or 0) * d)
        local q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
        q.w = cy * cx * cz + sy * sx * sz
        q.x = cy * sx * cz + sy * cx * sz
        q.y = sy * cx * cz - cy * sx * sz
        q.z = cy * cx * sz - sy * sx * cz
        btf:call("set_LocalRotation", q)
    end)
end

local function _pin_spawn(id)
    if PIN.go or PIN.job then return end
    local pgo = _char_go(_player())
    local p = pgo and _pos(pgo)
    if not p then return end
    -- props only accept placement at spawn, so lay the workpiece on the anvil in front
    local fx, fz = 0, 1
    pcall(function()
        local az = pgo:call("get_Transform"):call("get_AxisZ")
        fx, fz = az.x, az.z
    end)
    p = { x = p.x + fx * 0.75, y = p.y + 1.02, z = p.z + fz * 0.75 }
    local pfb
    local ok = pcall(function()
        pfb = sdk.create_instance("via.Prefab"):add_ref()
        pcall(function() pfb:add_ref_permanent() end)
        pcall(function() pfb:call(".ctor()") end)
        pfb:call("set_Path", "AppSystem/Equipment/eqit/" .. id .. ".pfb")
        pcall(function() pfb:call("set_Standby", true) end)
    end)
    if not (ok and pfb) then return end
    PIN.job = { pfb = pfb, f = 0, x = p.x, y = p.y + 1.0, z = p.z }
    PIN.id = id
end

-- follows the current work session, spawning and pinning the prop to the hand
local function _pin_frame()
    local key = ST.session and ST.session.key
    local row = key and STATIONS[key]
    local want = row and row.pin and tostring(M.anvil_prop or "") ~= ""
    if want and not PIN.go and not PIN.job and not PIN.cook then
        _pin_spawn(tostring(M.anvil_prop))
    elseif not want and (PIN.go or PIN.job or PIN.cook) then
        _pin_despawn()
    end
    _pin_apply_local()
end

local CK = { req = false, open = false }
re.on_application_entry("UpdateBehavior", function()
    if M.master == false then return end
    pcall(_carry_build)
    -- give the freshly spawned prop a few frames to finish building, then use it directly
    if PIN.cook then
        local ck2 = PIN.cook
        ck2.f = ck2.f + 1
        if ck2.f >= 10 then
            PIN.go = ck2.go
            PIN.cook = nil
            -- glue the prop to the hand bone, the engine then carries it with zero lag
            pcall(function()
                local pgo = _char_go(_player())
                local ptf = pgo and pgo:call("get_Transform")
                local btf = PIN.go:call("get_Transform")
                if ptf and btf then
                    local jname = "R_PropA"
                    pcall(function()
                        local mot = pgo:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion"))
                        if mot and not mot:call("getJointByName", jname) then jname = "R_Arm_Hand" end
                    end)
                    local ok = pcall(function() btf:call("setParent", ptf, true) end)
                    if not ok then pcall(function() btf:call("set_Parent", ptf) end) end
                    pcall(function() btf:call("set_ParentJoint", jname) end)
                    PIN.jname = jname
                    _pin_apply_local()
                    _st_log("PIN: workpiece parented to " .. jname)
                end
            end)
        end
    end
    -- workpiece prefab loader
    if PIN.job then
        local q = PIN.job
        pcall(function()
            q.f = q.f + 1
            if q.pfb:call("get_Ready") == true then
                local inst
                -- try to lay it flat with the rotation overload, upright otherwise
                pcall(function()
                    local rq = ValueType.new(sdk.find_type_definition("via.Quaternion"))
                    rq.x, rq.y, rq.z, rq.w = 0.7071, 0, 0, 0.7071
                    inst = q.pfb:call("instantiate(via.vec3, via.Quaternion)",
                        Vector3f.new(q.x, q.y, q.z), rq)
                end)
                if not inst then
                    pcall(function()
                        inst = q.pfb:call("instantiate(via.vec3)", Vector3f.new(q.x, q.y, q.z))
                    end)
                end
                if not inst then
                    pcall(function()
                        inst = q.pfb:call("instantiate", Vector3f.new(q.x, q.y, q.z))
                    end)
                end
                if inst then
                    -- the prop's insides build over the next frames, steal after a wait
                    PIN.cook = { go = inst, f = 0 }
                end
                PIN.job = nil
            elseif q.f > 300 then
                PIN.job = nil
            end
        end)
    end
    if CK.inst_req then
        CK.inst_req = false

        _st_log("COOKPROBE: town route disabled - requestInstantiate is crash-proven; "
            .. "waiting on the requestLoadScene decode")
    elseif CK.inst_wait then
        pcall(function()
            local gm = sdk.get_managed_singleton("app.GuiManager")
            if gm and gm:call("IsLoadGuiType", 45) then
                CK.inst_wait = false
                _st_log("COOKPROBE: cook GUI registered - opening the native menu")
                CK.req = true
            elseif os.clock() - (tonumber(CK.inst_at) or 0) > 6.0 then
                CK.inst_wait = false
                _st_log("COOKPROBE: instantiate never registered (6s) - parent/folder needs decoding")
            end
        end)
    elseif CK.req then
        CK.req = false
        pcall(function()
            local gm = sdk.get_managed_singleton("app.GuiManager")
            local cm = sdk.get_managed_singleton("app.CampManager")
            local dm = sdk.get_managed_singleton("app.DemoMediator")
            if not gm then _st_log("COOKPROBE: no GuiManager") return end
            local loaded, prefab, buffdef, allowed = "?", "?", "?", "?"
            pcall(function() loaded = tostring(gm:call("IsLoadGuiType", 45)) end)
            pcall(function() prefab = tostring(gm:call("getPrefab", 45) ~= nil) end)
            pcall(function() buffdef = tostring(cm ~= nil
                and cm:get_field("CampBuffDefineUserData") ~= nil) end)
            pcall(function() allowed = tostring(dm and dm:call("get_IsRequestAllowed")) end)
            _st_log(string.format(
                "COOKPROBE preflight: gui45loaded=%s prefab=%s buffdef=%s demoAllowed=%s",
                loaded, prefab, buffdef, allowed))

            pcall(function()
                local ic = gm:get_field("InstCtrl")
                local cl = ic and ic:get_field("CtrlList")
                local il = ic and ic:get_field("InstList")
                _st_log(string.format("COOKPROBE instctrl: ctrls=%s pending=%s",
                    tostring(cl and cl:call("get_Count")), tostring(il and il:call("get_Count"))))
            end)
            if buffdef ~= "true" then
                _st_log("COOKPROBE refused: CampBuffDefineUserData nil - opening would AV")
                return
            end

            if loaded ~= "true" then
                _st_log("COOKPROBE refused: GuiType 45 not loaded here (camp-only so far) - "
                    .. "opening would crash. Needs the setLoadGuiType route decoded first.")
                return
            end
            gm:call("requestCampMeatSelect")
            CK.open = true
            _st_log("COOKPROBE: native meat-select requested - choose or cancel; nothing is consumed")
        end)
    elseif CK.open then
        pcall(function()
            local gm = sdk.get_managed_singleton("app.GuiManager")
            if gm and gm:call("isEndMenuUI") then
                CK.open = false
                local r = nil
                pcall(function() r = tonumber(gm:call("get_MenuUIResult")) end)
                _st_log("COOKPROBE result: " .. tostring(r)
                    .. " (-1 = cancelled; 25-30/41/114 = chosen meat ItemID - not consumed)")
            end
        end)
    end
end)

local BF = { at = 0, log = {} }
-- finds beds and cookpots near you
local function _registry_tick()
    if M.stations == false and M.native_beds == false then return end
    local now = os.clock()
    if now - (tonumber(BF.at) or 0) < 2.5 then return end
    BF.at = now
    local pgo = _char_go(_player())
    local pp = pgo and _upos(pgo)
    if not pp then return end
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        local ups = mgr and mgr:get_field("InteractiveObjectUpdaters")
        if not ups then return end
        local nu = tonumber(ups:call("get_Length")) or 0
        for u = 0, nu - 1 do
            local lst
            pcall(function()
                local upd = ups:get_element(u)
                lst = upd and upd:get_field("InteractiveObjectList")
            end)
            local n = lst and tonumber(lst:call("get_Count")) or 0
            for i = 0, n - 1 do
                pcall(function()
                    local io = lst:call("get_Item", i)
                    if not io then return end
                    local nm
                    pcall(function() nm = tostring(io:call("get_Owner"):call("get_Name")) end)
                    if not nm then return end
                    local low = nm:lower()
                    local base = low:match("^(gm%d+_%d+)") or low
                    local isbed = M.native_beds ~= false
                        and (BED_KEYS[low] or BED_KEYS[base])
                        and not (M.st_off or {})[BED_KEYS[low] and low or base]
                    local isseat = M.enabled ~= false
                        and (SIT_KEYS[low] or SIT_KEYS[base])
                    local ispot = MC_POTS[base] == true
                    if not (isbed or isseat or ispot) then return end
                    local np = tonumber(io:call("getNumInteractPoint")) or 0
                    local bd, bq = nil, nil
                    for p = 0, np - 1 do
                        local q = io:call("getInteractPointPosition", p)
                        if q then
                            local dx, dy, dz = q.x - pp.x, q.y - pp.y, q.z - pp.z
                            local d2 = dx * dx + dy * dy + dz * dz
                            if not bd or d2 < bd then bd, bq = d2, q end
                        end
                    end
                    if not bd then return end
                    if ispot and bd < 5.29 then
                        MC.near = now
                        MC.near_pos = { x = bq.x, y = bq.y, z = bq.z }
                        if MC.near_key ~= base then
                            MC.near_key = base
                            _st_log("cook pot in range: " .. tostring(base))
                        end
                    end
                    if (isbed or isseat) and bd < 100.0 then
                        local kind = isbed and "bed" or "seat"
                        local key = isbed and (BED_KEYS[low] and low or base)
                            or (SIT_KEYS[low] and low or base)
                        local dl = io:get_field("DataList")
                        local ndl = dl and tonumber(dl:call("get_Count")) or 0
                        for d = 0, ndl - 1 do
                            local pt = dl:call("get_Item", d)
                            if pt then
                                local okp = _patch_search_point(pt, kind, nm,
                                    "bedfeed", d, io, nil, key)
                                if okp then
                                    _st_log("BEDFEED unlocked " .. kind .. " " .. key .. "[" .. d .. "]")
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end

-- close up working camera
local function _st_cam_tick()
    local want = M.st_cam ~= false and M.stations ~= false
        and (ST.session ~= nil or ST.pending ~= nil or (TL and TL.act ~= nil))
    local cm = sdk.get_managed_singleton("app.CameraManager")
    if not cm then return end
    local now = os.clock()
    local dt = math.min(0.1, now - (tonumber(ST.cam_t) or now))
    ST.cam_t = now
    if want then
        if ST.cam_base == nil then
            local b = nil
            pcall(function() b = tonumber(cm:call("get_DistanceOffset")) end)
            ST.cam_base = b or 0.0
            _st_log(string.format("camera engaged (base offset %.2f, target %+.2f)",
                ST.cam_base, tonumber(M.st_cam_dist) or -1.2))
        end
        local target = (ST.cam_base or 0.0) + (tonumber(M.st_cam_dist) or -1.2)
        pcall(function()
            local cur = tonumber(cm:call("get_DistanceOffset")) or 0.0
            cm:call("set_DistanceOffset", cur + (target - cur) * math.min(1.0, dt * 3.0))
        end)
    elseif ST.cam_base ~= nil then
        local done = false
        pcall(function()
            local cur = tonumber(cm:call("get_DistanceOffset")) or 0.0
            local target = ST.cam_base or 0.0
            if math.abs(target - cur) < 0.02 then
                cm:call("set_DistanceOffset", target)
                done = true
            else
                cm:call("set_DistanceOffset", cur + (target - cur) * math.min(1.0, dt * 3.0))
            end
        end)
        if done then
            ST.cam_base = nil
            _st_log("camera restored")
        end
    end
end

-- the rest choice, offered once she is properly lying down
local BR = { open = false }

local function _br_close()
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local dlg = gm and gm:get_field("Dialog")
        if dlg then dlg:call("reqClose") end
        if gm then gm:call("requestHideGuiType", 14) end
    end)
    BR.open = false
    BR.want = nil
end

local function _br_show(io)
    local ready, dialog = _gui_dialog_ready()
    if not ready then
        BR.want = BR.want or { io = io, at = os.clock() }
        return
    end
    BR.want = nil
    local ok = pcall(function()
        dialog:call("reqDisp", "Rest until...", "Morning", "Nightfall", "Just lie here", "",
            true, 0, true, 58, 0, -1, nil,
            false, false, false, false, false, false, true, 0.0)
        BR.open, BR.at, BR.baseline, BR.io = true, os.clock(), _mc_pick(), io
    end)
    if not ok then _st_log("bed rest dialog FAILED") end
end

-- borrow a real inn bed's settings, and learn which space its coordinates speak.
-- guessing that wrong is how you wake up in the sea.
local function _br_donor_param()
    local found, space
    pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local smt = sdk.find_type_definition("via.SceneManager")
        local scene = sm and smt and sdk.call_native_func(sm, smt, "get_CurrentScene")
        local comps = scene and scene:call("findComponents(System.Type)",
            sdk.typeof("app.Gm51_115"))
        local n = comps and tonumber(comps:call("get_Length")) or 0
        for i = 0, n - 1 do
            if found then break end
            pcall(function()
                local bed = comps:call("get_Item", i)
                local ip = bed and bed:get_field("InnParam")
                local slot = ip and ip:get_field("Player")
                local p = slot and slot:get_field("_Pos")
                if not (p and p.x) then return end
                local tf = bed:call("get_GameObject"):call("get_Transform")
                local u = tf and tf:call("get_UniversalPosition")
                local r = tf and tf:call("get_Position")
                if not (u and r) then return end
                local du = math.sqrt((p.x - u.x) ^ 2 + (p.z - u.z) ^ 2)
                local dr = math.sqrt((p.x - r.x) ^ 2 + (p.z - r.z) ^ 2)
                -- the authored wake spot sits beside its own bed, so the nearer space wins
                if du < 30.0 and du <= dr then found, space = ip, "universal"
                elseif dr < 30.0 and dr < du then found, space = ip, "render" end
            end)
        end
    end)
    if found then _st_log("bed rest: borrowed inn settings, coords are " .. tostring(space)) end
    return found, space
end

-- point the five wake spots at this bed, so she wakes where she slept
local function _br_aim_param(param, io, space)
    local ok = false
    pcall(function()
        local go = io and io:call("get_Owner")
        if not go then go = io and io:get_field("<Owner>k__BackingField") end
        local tf = go and go:call("get_Transform")
        local p = (space == "render") and tf:call("get_Position")
            or tf:call("get_UniversalPosition")
        local rot = tf and tf:call("get_Rotation")
        if not p then return end
        local yaw = 0.0
        pcall(function()
            yaw = math.atan2(2.0 * (rot.w * rot.y + rot.x * rot.z),
                1.0 - 2.0 * (rot.y * rot.y + rot.x * rot.x))
        end)
        local fx, fz = math.sin(yaw), math.cos(yaw)
        local rx, rz = math.cos(yaw), -math.sin(yaw)
        local q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
        q.x, q.y, q.z, q.w = 0, math.sin(yaw * 0.5), 0, math.cos(yaw * 0.5)
        local function stamp(field, px, py, pz)
            local slot = param:get_field(field)
            if not slot then return end
            pcall(function() slot:set_field("_Pos", Vector3f.new(px, py, pz)) end)
            pcall(function() slot:set_field("_Rot", q) end)
        end
        stamp("Player", p.x + rx * 0.9, p.y, p.z + rz * 0.9)
        stamp("Main",   p.x + rx * 1.8 + fx * 1.1, p.y, p.z + rz * 1.8 + fz * 1.1)
        stamp("Sub1",   p.x + rx * 1.8,            p.y, p.z + rz * 1.8)
        stamp("Sub2",   p.x + rx * 1.8 - fx * 1.1, p.y, p.z + rz * 1.8 - fz * 1.1)
        stamp("Camera", p.x + rx * 0.9 - fx * 1.6, p.y + 1.4, p.z + rz * 0.9 - fz * 1.6)
        ok = true
    end)
    return ok
end

-- Construct a private InnAwakeParam. Borrowing a live inn's parameter and rewriting it
-- changes that real bed for the rest of the session and can leave FacilityManager holding
-- stale scene data. These six tiny objects live for the script lifetime and are reused.
local function _br_new_param()
    if _managed(BR.work_param) then return BR.work_param end
    local param = nil
    local ok = pcall(function()
        param = sdk.create_instance("app.FacilityManager.InnAwakeParam")
        if not param then error("InnAwakeParam unavailable") end
        pcall(function() param:call(".ctor()") end)
        pcall(function() param:add_ref_permanent() end)
        for _, field in ipairs({ "Camera", "Player", "Main", "Sub1", "Sub2" }) do
            local slot = sdk.create_instance(
                "app.FacilityManager.InnAwakeParam.ObjectSetting")
            if not slot then error("ObjectSetting unavailable: " .. field) end
            pcall(function() slot:call(".ctor()") end)
            pcall(function() slot:add_ref_permanent() end)
            param:set_field(field, slot)
        end
    end)
    if not (ok and _managed(param)) then
        _st_log("bed rest: could not construct a private InnAwakeParam")
        return nil
    end
    BR.work_param = param
    return param
end

-- Every non-native bed gets private settings aimed at its current transform.
local function _br_inn_param(io)
    if M.bed_rest_anywhere == false then return nil, false end
    local param = _br_new_param()
    if not param then return nil, false end
    local _, space = _br_donor_param()
    space = space or "universal"
    if _br_aim_param(param, io, space) then return param, false end
    return nil, false
end

-- hands the sleep to the game, using the bed's own inn settings
local function _br_sleep(morning)
    -- use the settings captured when the menu opened, looking again would find a
    -- donor we already re-aimed and reject it
    local param = BR.param
    _st_log(string.format("bed rest: innParam=%s (%s)",
        tostring(param ~= nil), BR.own and "the bed's own" or "borrowed"))

    local fm = sdk.get_managed_singleton("app.FacilityManager")
    local done = false
    if fm and param then
        local td = sdk.find_type_definition("app.FacilityManager")
        for _, mm in ipairs((td and td:get_methods()) or {}) do
            if done then break end
            local nm
            pcall(function() nm = mm:get_name() end)
            if nm == "startInn" or nm == "startInnNoLock" then
                local r, err
                local ran = pcall(function()
                    r = mm:call(fm, morning and true or false, 0, param, 0, nil, 0)
                end)
                if not ran then
                    pcall(function()
                        local ok2, e2 = pcall(function()
                            r = mm:call(fm, morning and true or false, 0, param)
                        end)
                        err = ok2 and "3 args" or tostring(e2)
                    end)
                end
                _st_log(string.format("bed rest: %s returned %s %s",
                    nm, tostring(r), tostring(err or "")))
                if r == true then done = true end
            end
        end
    end
    _st_log("bed rest: " .. (morning and "morning" or "night")
        .. (done and " - startInn accepted" or " - startInn refused"))
    return done
end

local function _br_tick()
    if BR.want and not BR.open then
        local w = BR.want
        if os.clock() - (tonumber(w.at) or 0) > 3.0 then
            BR.want = nil
            _st_log("bed rest: gui never loaded, giving up")
        else
            _br_show(w.io)
        end
        return
    end
    if not BR.open then return end
    local sel = _mc_pick()
    if sel == nil or sel == BR.baseline then
        if os.clock() - (tonumber(BR.at) or 0) > 90.0 then _br_close() end
        return
    end
    _br_close()
    if sel == 1 or sel == 2 then
        -- Do not abort the interaction first: that was ending the lie-down and
        -- invalidating the bed state before FacilityManager could accept the rest.
        local done = _br_sleep(sel == 1)
        BR.handoff_until = os.clock() + (done and 3.0 or 0.5)
        if done and ST.session then ST.session.rest_started = true end
    end
end

-- watches the current work session
local function _st_frame()
    pcall(_st_cam_tick)
    if M.stations == false and M.native_beds == false then
        ST.session, ST.pending = nil, nil
        return
    end
    local now = os.clock()

    local down = _stop_down()
    local kill = _binding_down(M.stop_bind or "backspace")
    local edge_btn  = down and not ST.prev
    local edge_kill = kill and not ST.kill_prev
    ST.prev, ST.kill_prev = down, kill

    -- Confirming the rest dialog uses the same action as Interact. Consume it here;
    -- otherwise the confirmation also aborts the bed on this very frame.
    if BR.open or BR.want or now < (tonumber(BR.handoff_until) or 0) then return end

    local pend = ST.pending
    if pend then
        local age = now - (tonumber(pend.at) or 0)
        if age >= 0.3 then
            local open = nil
            pcall(function()
                local ch = _player()
                local mgr = sdk.get_managed_singleton("app.InteractManager")
                if ch and mgr then open = mgr:call("isInteracting(app.Character)", ch) end
            end)
            if open == false then
                ST.pending = nil
                local jacked = false
                pcall(function()
                    local ch = _player()
                    jacked = ch and ch:call("get_IsJacked") == true
                end)
                if jacked then
                    _st_release_hard(pend.reason .. " (jack survived the abort)", pend.rec)
                else
                    ST.status = string.format("released natively (%s) - session closed clean",
                        tostring(pend.reason))
                    _st_log(ST.status)
                end
            elseif age > 3.0 then

                ST.pending = nil
                ST.status = "WARNING: native abort IGNORED - do not retry; use the panel or reload the save"
                _st_log("abort ignored after " .. string.format("%.1f", age)
                    .. "s - NOT escalating (hang guard); manual button only")
            end
        end
        return
    end

    if now - (tonumber(ST.at) or 0) >= 0.25 then
        ST.at = now
        local a = _active_native()
        if _is_station_active(a) then
            local id = _addr(a.io) or tostring(a.key)
            if not ST.session or ST.session.id ~= id then
                ST.session = { id = id, rec = a.rec, key = a.key, io = a.io,
                               host = tostring((a.rec and a.rec.host) or a.key or "?"),
                               since = now }
                local nice = (a.key and STATIONS[a.key] and STATIONS[a.key].label)
                    or ST.session.host
                ST.status = string.format("Working: %s - press Interact (or BACKSPACE) to stop",
                    tostring(nice))
                _logf("station native session begun: %s", ST.session.host)

                -- Vanilla player beds jump straight to the rest UI. Ask the bed to
                -- begin its own sleep clip once; the native UI and FacilityManager
                -- remain untouched and continue to own the actual rest.
                if a.rec and a.rec.kind == "bed" and a.rec.native_player
                        and _managed(a.rec.owner) then
                    local animated = pcall(function() a.rec.owner:call("execSleep") end)
                    ST.session.native_rest = true
                    ST.session.sleep_started = animated
                    _st_log("native bed lie-down animation: "
                        .. (animated and "requested" or "unavailable"))
                end

                local strow = a.key and STATIONS[a.key]
                if strow then strow = { conjure = strow.conjure, label = strow.label } end
                if strow and strow.conjure and not ST.conjured then
                    local heldid = 0
                    pcall(function()
                        local ch = _player()
                        local human = ch and ch:call("get_Human")
                        local holder = human and human:call("get_GimmickHolder")
                        local ctx = holder and holder:get_field("Context")
                        heldid = (ctx and tonumber(ctx:get_field("EquipItemID"))) or 0
                    end)
                    if heldid == 0 and _st_conjure(strow.conjure, true) then
                        ST.conjured = strow.conjure
                        ST.conj_at, ST.conj_probed = now, false
                    end
                end
            end
        else
            ST.session = nil
        end
    end

    if ST.conjured and not ST.session and not ST.pending then
        _st_conjure(ST.conjured, false, true)
        ST.conjured, ST.conj_at, ST.conj_probed, ST.conj_restage = nil, nil, nil, nil
    end

    -- the game clears the prop slot every frame, so claim it back every frame too,
    -- re-claiming a slot that already holds our item is a cheap update, not a respawn
    if ST.conjured and ST.session then
        local held = false
        pcall(function()
            local ch = _player()
            local human = ch and ch:call("get_Human")
            local ctrl = human and human:call("get_EquipItemCtrl")
            local arr = ctrl and ctrl:get_field("Controllers")
            local n = arr and tonumber(arr:call("get_Length")) or 0
            for i = 0, n - 1 do
                local c
                pcall(function() c = arr:get_element(i) end)
                if c and tonumber(c:get_field("<ItemID>k__BackingField")) == ST.conjured then
                    held = true
                    break
                end
            end
        end)
        if not held then _st_conjure(ST.conjured, true, true) end
    end

    if M.dev == true and ST.conjured and ST.session and ST.conj_at and not ST.conj_probed
        and os.clock() - ST.conj_at > 1.5 then
        ST.conj_probed = true
        pcall(function()
            local ch = _player()
            local human = ch and ch:call("get_Human")
            local ctrl = human and human:call("get_EquipItemCtrl")
            if not ctrl then _st_log("CONJPROBE: no EquipItemCtrl") return end
            local en = "?"
            pcall(function() en = tostring(ctrl:call("get_IsEnable")) end)
            local arr = ctrl:get_field("Controllers")
            local n = 0
            pcall(function() n = tonumber(arr:call("get_Length")) or 0 end)
            if n == 0 then pcall(function() n = tonumber(arr:get_size()) or 0 end) end
            local hits, readable = 0, 0
            for i = 0, n - 1 do
                local c = nil
                pcall(function() c = arr:get_element(i) end)
                if c then
                    readable = readable + 1
                    local act, item, joint, draw, created = "?", -1, "?", "?", "?"
                    pcall(function() act = tostring(c:call("get_IsActive")) end)
                    pcall(function() item = tonumber(c:get_field("<ItemID>k__BackingField")) or -1 end)
                    pcall(function() joint = tostring(c:get_field("ParentJoint")) end)
                    pcall(function() draw = tostring(c:get_field("IsDraw")) end)
                    pcall(function() created = tostring(c:get_field("IsItemCreated")) end)

                    local igo = "nil"
                    pcall(function()
                        local g = c:get_field("Item")
                        if g then igo = tostring(g:call("get_Name")) end
                    end)
                    if act == "true" or (item and item > 0) then
                        hits = hits + 1
                        _st_log(string.format(
                            "CONJPROBE slot %d: active=%s item=%d joint=%s draw=%s created=%s itemGO=%s",
                            i, act, item, joint, draw, created, igo))
                    end
                end
            end

            _st_log(string.format("CONJPROBE done: enable=%s slots=%d readable=%d active/holding=%d",
                en, n, readable, hits))
        end)
    end

    local sess = ST.session
    if not sess then

        if edge_kill then
            local open = false
            pcall(function()
                local ch = _player()
                local mgr = sdk.get_managed_singleton("app.InteractManager")
                open = ch and mgr and mgr:call("isInteracting(app.Character)", ch) == true
            end)
            if open then _st_release("backspace (unclassified interaction)") end
        end
        return
    end

    pcall(function()
        local IP = _G.IrisPrompt
        if not (IP and type(IP.set) == "function") then return end
        local pgo = _char_go(_player())
        local p = pgo and _pos(pgo)
        IP.set("interactables_station", "Stop", 5, 0.05, p, pgo)
    end)

    if edge_kill then return _st_release("backspace") end

    -- once she has settled into the bed, ask how long she wants to sleep
    if M.bed_rest ~= false and not BR.open and sess.rec and sess.rec.kind == "bed"
            and not sess.rec.native_player
            and not sess.rest_asked then
        local settled = false
        pcall(function()
            local motion = _st_motion()
            local layer = motion and motion:call("getLayer", 0)
            if not layer then return end
            local f  = tonumber(layer:call("get_Frame")) or 0
            local ef = tonumber(layer:call("get_EndFrame")) or 0
            if ef > 1.0 and f >= ef - 2.0 then settled = true end
        end)
        if settled or now - (tonumber(sess.since) or 0) > 6.0 then
            sess.rest_asked = true
            local param, own = _br_inn_param(sess.io)
            if param then
                BR.param, BR.own = param, own
                _br_show(sess.io)
            elseif M.dev then
                _st_log("bed rest: no inn settings available for this bed - no menu")
            end
        end
    end

    if edge_btn and now - (tonumber(sess.since) or 0) > 1.2 then
        -- the native abort plays its own wind-out, no staged stop needed
        return _st_release("button")
    end
end

local function _publish()
    _G.Interactables_dough_hybrid_lab = false

    _G.DD2NativeSeats = { owner = "Interactables", version = 1,
                          prefab = M.donor or "gm80_257",
                          chores = M.native_chores == true,
                          beds = M.native_beds == true,
                          t = os.clock() }

    _G.Interactables_stations_live = M.stations ~= false
end

-- main loop
re.on_frame(function()
    if M.master == false then
        ST.player_addr = nil
        _G.DD2NativeSeats = nil
        _G.Interactables_stations_live = false
        return
    end
    pcall(_mc_toast_draw)
    _publish()
    pcall(_tick)
    pcall(_unlock_tick)
    pcall(_native_session_tick)
    pcall(_st_frame)
    pcall(_br_tick)
    pcall(_tl_frame)
    pcall(_carry_tick)
    pcall(_bed_probe_tick)
    pcall(_registry_tick)
    pcall(_mc_frame)
    pcall(_pin_frame)
end)

-- put everything back on script reset
re.on_script_reset(function()
    _G.Interactables_dough_hybrid_lab = false

    pcall(function() _tl_stop("script reset") end)
    pcall(function() _mc_stop_stir() end)
    pcall(function() if MC.open then _mc_close() end end)
    pcall(function() _pin_despawn() end)
    pcall(function() _carry_release() end)
    pcall(function()
        if ST.conjured then _st_conjure(ST.conjured, false); ST.conjured = nil end
    end)

    pcall(function()
        if ST.cam_base ~= nil then
            local cm = sdk.get_managed_singleton("app.CameraManager")
            if cm then cm:call("set_DistanceOffset", ST.cam_base) end
            ST.cam_base = nil
        end
    end)

    pcall(function() _drop_all(false) end)

    pcall(function() _restore_unlocks() end)
    pcall(_save_cfg)
end)

-- the settings panel
re.on_draw_ui(function()
    if not imgui.tree_node("Immersive Interactables") then return end
    local c

    c, M.master = imgui.checkbox("Enabled", M.master ~= false)
    if c then
        _save_cfg()
        if M.master == false then
            pcall(function() if ST.session then _st_release("master off") end end)
            pcall(function() _tl_stop("master off") end)
            pcall(function() _mc_stop_stir() end)
            pcall(function() if MC.open then _mc_close() end end)
            pcall(_pin_despawn)
            pcall(function() _drop_all(true) end)
            pcall(function() _restore_unlocks() end)
            pcall(function()
                if ST.cam_base ~= nil then
                    local cm = sdk.get_managed_singleton("app.CameraManager")
                    if cm then cm:call("set_DistanceOffset", ST.cam_base) end
                    ST.cam_base = nil
                end
            end)
        end
    end

    if M.master ~= false then
        imgui.text("Interact with:")

        c, M.enabled = imgui.checkbox("Chairs, stools and benches", M.enabled)
        if c then
            _save_cfg()
            if not M.enabled then _drop_all(true); _restore_unlocks("seat") end
        end

        c, M.native_beds = imgui.checkbox("Beds", M.native_beds)
        if c then
            if not M.native_beds then _restore_unlocks("bed") end
            _save_cfg()
        end

        c, M.stations = imgui.checkbox("Workstations - knead, smith, sweep, weave, cook and more",
            M.stations ~= false)
        if c then
            _save_cfg()
            if not M.stations then _restore_unlocks("station") end
        end

        c, M.native_chores = imgui.checkbox("Loose tools - carry brooms and pitchforks",
            M.native_chores)
        if c then
            if not M.native_chores then _restore_unlocks("chore") end
            _save_cfg()
        end

        imgui.text("Your DD2 Interact control uses things; Interact or BACKSPACE stops")
        if M.native_chores and M.keep_tools ~= false then
            imgui.text("carrying a tool - click the left stick (or BACKSPACE) to put it down")
        end

        if imgui.tree_node("Controls") then
            imgui.text("Keyboard controls follow your DD2 bindings; custom keys are optional.")
            c, M.follow_game_controls = imgui.checkbox(
                "Follow DD2 Interact binding automatically", M.follow_game_controls ~= false)
            if c then _save_cfg() end

            local function binding_row(field, label, fixed)
                local armed = KEY_CAPTURE.field == field
                if imgui.button((armed and "Press a key..." or _binding_label(M[field]))
                        .. "##interactables_" .. field) then
                    KEY_CAPTURE.field = armed and nil or field
                    KEY_CAPTURE.after = os.clock() + 0.3
                end
                imgui.same_line()
                imgui.text(label .. (fixed and ("  (plus " .. fixed .. ")") or ""))
            end

            binding_row("interact_bind", "Use fallback")
            binding_row("stop_bind", "Stop / get up", "DD2 Interact")
            binding_row("drop_bind", "Put carried object down", "L3")
            imgui.text("Escape cancels key assignment.")
            local got = _capture_key()
            if got and KEY_CAPTURE.field then
                M[KEY_CAPTURE.field] = got
                KEY_CAPTURE.field = nil
                _save_cfg()
            end
            imgui.tree_pop()
        end
    end

    if M.master ~= false and ST.session then
        imgui.text(tostring(ST.status or ""))
        if imgui.button("Stop now") then _st_release("panel") end
    elseif ST.pending then
        imgui.text("stopping...")
        imgui.same_line()
        if imgui.button("force it") then
            local p = ST.pending; ST.pending = nil
            _st_release_hard("panel escalation", p and p.rec)
        end
    end
    if cat_n == 0 then
        imgui.text("catalog missing - data/Interactables/catalog.json did not load")
    end

    if M.master ~= false and imgui.tree_node("Advanced") then
        c, M.st_cam = imgui.checkbox("Close-up camera while working", M.st_cam ~= false)
        if c then _save_cfg() end
        if M.st_cam ~= false then
            c, M.st_cam_dist = imgui.slider_float(
                "camera closeness (drag the other way if it zooms out)",
                M.st_cam_dist or -1.2, -3.0, 3.0)
            if c then _save_cfg() end
        end

        c, M.seat_y = imgui.slider_float(
            "sitting height (raise or lower yourself on seats)",
            M.seat_y or 0.0, -0.8, 0.8)
        if c then _save_cfg() end

        c, M.bed_rest = imgui.checkbox(
            "ask how long to sleep once you lie down", M.bed_rest ~= false)
        if c then _save_cfg() end

        c, M.keep_tools = imgui.checkbox(
            "keep hold of tools when you walk away",
            M.keep_tools ~= false)
        if c then
            if M.keep_tools == false then pcall(_carry_release) end
            _save_cfg()
        end
        if M.keep_tools ~= false then
            imgui.text("Carried-object drop: L3 plus the key selected under Controls")
        end

        if M.dev and CARRY.go and CARRY.id then
            if imgui.tree_node("Carried tool grip (live)") then
                local key = tostring(CARRY.id)
                M.tool_grip = M.tool_grip or {}
                local g = M.tool_grip[key]
                if type(g) ~= "table" then g = { 0, 0, 0, 0, 0, 0 }; M.tool_grip[key] = g end
                imgui.text(string.format("holding %s (eq id %s)",
                    tostring(TL.eqid[CARRY.id] or "?"), key))
                c, g[1] = imgui.slider_float("offset X", g[1] or 0, -0.6, 0.6)
                c, g[2] = imgui.slider_float("offset Y", g[2] or 0, -0.6, 0.6)
                c, g[3] = imgui.slider_float("offset Z", g[3] or 0, -0.6, 0.6)
                c, g[4] = imgui.slider_float("rotate X", g[4] or 0, -180.0, 180.0)
                c, g[5] = imgui.slider_float("rotate Y", g[5] or 0, -180.0, 180.0)
                c, g[6] = imgui.slider_float("rotate Z", g[6] or 0, -180.0, 180.0)
                if imgui.button("Save this grip") then
                    _save_cfg()
                    _st_log(string.format("GRIP %s = { %.3f, %.3f, %.3f, %.2f, %.2f, %.2f }",
                        tostring(TL.eqid[CARRY.id]), g[1], g[2], g[3], g[4], g[5], g[6]))
                end
                imgui.tree_pop()
            end
        end

        if M.dev then
        local ca
        ca, M.anvil_prop = imgui.input_text(
            "smithing workpiece (blank = empty hands)", tostring(M.anvil_prop or ""))
        if ca then _save_cfg() end
        imgui.text("      the item held while smithing, eqit09_001 is a sword")
        if imgui.tree_node("Workpiece grip (adjust live while smithing)") then
            c, M.pin_ox = imgui.slider_float("offset X (m)", M.pin_ox or 0.0, -0.5, 0.5)
            c, M.pin_oy = imgui.slider_float("offset Y (m)", M.pin_oy or 0.0, -0.5, 0.5)
            c, M.pin_oz = imgui.slider_float("offset Z (m)", M.pin_oz or 0.0, -0.5, 0.5)
            c, M.pin_rx = imgui.slider_float("rotate X (deg)", M.pin_rx or 0.0, -180.0, 180.0)
            c, M.pin_ry = imgui.slider_float("rotate Y (deg)", M.pin_ry or 0.0, -180.0, 180.0)
            c, M.pin_rz = imgui.slider_float("rotate Z (deg)", M.pin_rz or 0.0, -180.0, 180.0)
            if imgui.button("Reset grip") then
                M.pin_ox, M.pin_oy, M.pin_oz = -0.059, 0.016, -0.035
                M.pin_rx, M.pin_ry, M.pin_rz = -72.371, -24.124, 59.417
            end
            imgui.same_line()
            if imgui.button("Save grip") then _save_cfg() end
            imgui.tree_pop()
        end
        end

        if imgui.tree_node("Workstation list (untick to turn one off)") then
            local keys = {}
            for k in pairs(STATIONS) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local on = not (M.st_off or {})[k]
                c, on = imgui.checkbox(string.format("%s - %s", k, tostring(STATIONS[k].label)), on)
                if c then
                    M.st_off = M.st_off or {}
                    M.st_off[k] = (not on) and true or nil
                    if not on then
                        for addr, r in pairs(unlocks) do
                            if r.kind == "station" and r.prop_key == k then
                                pcall(function()
                                    r.point:set_field("CharacterType", r.old)
                                    if r.old_icon ~= nil then r.point:set_field("IconType", r.old_icon) end
                                end)
                                unlocks[addr] = nil
                            end
                        end
                    end
                    _save_cfg()
                end
            end
            imgui.tree_pop()
        end

        -- dev mode has no public switch, set dev true in Interactables.json to get it back
        if M.dev then
            c, M.dev = imgui.checkbox("show developer tools", M.dev == true)
            if c then _save_cfg() end
            c, M.log = imgui.checkbox("write Interactables.log", M.log)
            if c then _save_cfg() end
        end

        if M.dev and imgui.tree_node("Research (dev only)") then
            imgui.text("Session-only switches, never saved. Work loops entered through")
            imgui.text("discovery have no safe native exit - BACKSPACE only.")
            if imgui.button("Probe native cook menu (nothing is consumed)") then
                CK.req = true
            end
            c, M.native_discovery = imgui.checkbox(
                "SESSION ONLY: discover ALL Human-only world props", M.native_discovery)
            if c and not M.native_discovery then
                _restore_unlocks("chore")
                if not M.native_beds then _restore_unlocks("bed") end
            end
            c, M.native_lethal = imgui.checkbox(
                "SESSION ONLY: ALSO the proven-crash drum (gm10_030)", M.native_lethal)
            if c and not M.native_lethal then _restore_unlocks("chore") end
            imgui.text("Last native event: " .. tostring(native_last))
            imgui.text(string.format("%d chore + %d bed point(s) changed live, %d failed writes",
                _unlock_count("chore"), _unlock_count("bed"), stats.unlock_failed or 0))
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end

    imgui.tree_pop()
end)
