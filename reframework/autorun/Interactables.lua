do local dump = json.dump_file
json.dump_file = function(path, ...)
    if type(path) == "string" and path:match("^ImmersiveInteractables_") then return true end
    return dump(path, ...)
end end
local M = {
    enabled       = true,
    range         = 12.0,
    y_window      = 2.5,
    max_seats     = 8,
    hysteresis    = 1.25,
    donor         = "gm80_257",
    seat_y        = 0.0,
    tall_seat_y   = 0.25,
    dedup_radius  = 0.5,
    per_point     = true,
    max_points    = 4,
    neuter_collision = false,
    scan_secs     = 0.5,
    list_secs     = 30.0,
    list_move     = 30.0,
    budget        = 64,
    position_budget = 48,
    registry_budget = 24,
    registry_slice_secs = 0.10,
    native_chores = true,
    native_beds   = false,
    native_ambient = false,
    unlock_secs   = 1.0,
    follow_game_controls = true,
    interact_bind = "F",
    rest_bind     = "space",
    stop_bind     = "backspace",
    drop_bind     = "backspace",
    stations       = true,
    work_buffs     = true,
    work_hud       = true,
    ending_hud     = true,
    work_hud_x     = 0.98,
    work_hud_y     = 0.62,
    activity_groups = {
        food = true,
        everyday = true,
        household = true,
        outdoors = true,
        trades = true,
    },
    st_off         = {},
    st_cam            = true,
    st_cam_dist       = -1.2,
    anvil_prop = "eqit09_001",
    anvil_upgrade = true,
    keep_tools = true,
    pin_ox = -0.059, pin_oy = 0.016, pin_oz = -0.035,
    pin_rx = -72.371, pin_ry = -24.124, pin_rz = 59.417,
    master = true,
    bed_rest = true,
    bed_rest_anywhere = true,
    tool_grip = {},
    cfg_rev = 0,
}
local CFG  = "Interactables.json"
local CATP = "Interactables/catalog.json"
local function _log() end
local function _logf() end
local function _get_active_interact(mgr, ch)
    if not mgr then return nil end
    if _G.__II_gai == nil then
        local n = -1
        pcall(function()
            local td = sdk.find_type_definition("app.InteractManager")
            local m = td and td:get_method("getActiveInteract")
            if m then n = tonumber(m:get_num_params()) or -1 end
        end)
        _G.__II_gai = n
        _log("getActiveInteract resolved nparams=" .. tostring(n))
    end
    local a
    if _G.__II_gai == 1 then
        pcall(function() a = mgr:call("getActiveInteract(app.Character)", ch) end)
    elseif _G.__II_gai == 0 then
        pcall(function() a = mgr:call("getActiveInteract") end)
    else
        pcall(function() a = mgr:call("getActiveInteract") end)
        if a == nil then pcall(function() a = mgr:call("getActiveInteract(app.Character)", ch) end) end
    end
    return a
end
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
    M.drop_bind = "backspace"
    M.bed_rest_anywhere = false
    M.cfg_rev = 5
end
if (tonumber(M.cfg_rev) or 0) < 6 then
    M.native_beds = true
    M.native_chores = true
    M.cfg_rev = 6
end
if (tonumber(M.cfg_rev) or 0) < 7 then
    M.follow_game_controls = true
    M.interact_bind = "F"
    M.stop_bind = "backspace"
    M.drop_bind = "backspace"
    M.bed_rest_anywhere = true
    M.cfg_rev = 7
end
if (tonumber(M.cfg_rev) or 0) < 8 then
    M.bed_rest = true
    M.bed_rest_anywhere = true
    M.keep_tools = true
    M.cfg_rev = 8
    _save_cfg()
end
if (tonumber(M.cfg_rev) or 0) < 9 then
    M.list_secs = math.max(30.0, tonumber(M.list_secs) or 0)
    M.list_move = math.max(30.0, tonumber(M.list_move) or 0)
    M.position_budget = math.max(16, tonumber(M.position_budget) or 48)
    M.registry_budget = math.max(8, tonumber(M.registry_budget) or 24)
    M.registry_slice_secs = math.max(0.03, tonumber(M.registry_slice_secs) or 0.05)
    M.cfg_rev = 9
    _save_cfg()
end
if (tonumber(M.cfg_rev) or 0) < 10 then
    M.cfg_rev = 10
    _save_cfg()
end
if (tonumber(M.cfg_rev) or 0) < 11 then
    M.activity_groups = M.activity_groups or {}
    if M.stations == false then
        M.activity_groups.food = false
        M.activity_groups.everyday = false
        M.activity_groups.household = false
        M.activity_groups.outdoors = false
        M.activity_groups.trades = false
    end
    M.stations = true
    M.cfg_rev = 11
    _save_cfg()
end
if (tonumber(M.cfg_rev) or 0) < 16 then
    M.tall_seat_y = 0.25
    M.cfg_rev = 16
    _save_cfg()
end
if (tonumber(M.cfg_rev) or 0) < 17 then
    M.registry_slice_secs = math.max(0.10, tonumber(M.registry_slice_secs) or 0.10)
    M.cfg_rev = 17
    _save_cfg()
end
if (tonumber(M.cfg_rev) or 0) < 18 then
    M.native_beds = false
    M.cfg_rev = 18
    _save_cfg()
end
local CAT, cat_n = {}, 0
pcall(function()
    local t = json.load_file(CATP)
    if type(t) == "table" then CAT = t; for _ in pairs(t) do cat_n = cat_n + 1 end end
end)
local STATIONS
local CARRY_KEYS = { gm51_046 = true }
local LOOSE_TOOL_KEYS = {
    gm50_007 = true, gm50_007_01 = true,
    gm50_010_01 = true,
    gm50_013 = true,
    gm50_031 = true, gm50_031_01 = true,
    gm50_096 = true, gm50_096_01 = true,
    gm50_298 = true, gm50_298_01 = true,
    gm51_046 = true,
}
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
local MEMO = { ttl = 0.008, player_at = -1, player = nil, load_at = -1, load = false,
               menu_at = -1, menu = false, pad_at = -1, pad = 0, kb = {}, kb_at = {},
               kb_td = nil, pad_td = nil, tokens = {}, act_at = -1, act = false }
local function _player()
    local now = os.clock()
    if now - MEMO.player_at < MEMO.ttl then return MEMO.player end
    local ch = nil
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        ch = cm and cm:call("get_ManualPlayer")
    end)
    MEMO.player_at, MEMO.player = now, ch
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
local function _human_fsm(human)
    local fsm = nil
    pcall(function()
        local go = human and human:call("get_GameObject")
        fsm = go and go:call("getComponent(System.Type)", sdk.typeof("via.motion.MotionFsm2"))
    end)
    return _managed(fsm) and fsm or nil
end
local function _bed_inn(bed)
    if not _managed(bed) then return nil end
    local ip = nil
    for _, m in ipairs({ "getInnParam", "get_getInnParam", "get_InnParam" }) do
        pcall(function() if not _managed(ip) then ip = bed:call(m) end end)
        if _managed(ip) then return ip end
    end
    pcall(function() ip = bed:get_field("InnParam") end)
    return _managed(ip) and ip or nil
end
local function _bed_set_inn(bed, param)
    if not _managed(bed) then return false end
    for _, m in ipairs({ "setInnParam", "set_setInnParam", "set_InnParam" }) do
        local ok = pcall(function() bed:call(m, param) end)
        if ok then return true end
    end
    return pcall(function() bed:set_field("InnParam", param) end)
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
    local now = os.clock()
    if now - MEMO.load_at < MEMO.ttl then return MEMO.load end
    local l = false
    pcall(function()
        local g = sdk.get_managed_singleton("app.GuiManager")
        l = g and g:call("get_IsLoadGui") == true
    end)
    MEMO.load_at, MEMO.load = now, l
    return l
end
local function _menu_open()
    local now = os.clock()
    if now - MEMO.menu_at < MEMO.ttl then return MEMO.menu end
    local m = false
    pcall(function()
        local gui = sdk.get_managed_singleton("app.GuiManager")
        m = gui and gui:call("isPausedGUI") == true
    end)
    MEMO.menu_at, MEMO.menu = now, m
    return m
end
local CAMP_STATE = {
    manager = nil, checked_at = -1000.0, active = false,
    cook_station_keys = { gm50_020 = true },
}
function CAMP_STATE.is_active(force)
    local now = os.clock()
    if not force and now - (tonumber(CAMP_STATE.checked_at) or -1000.0) < 0.15 then
        return CAMP_STATE.active == true
    end
    CAMP_STATE.checked_at = now
    local manager = CAMP_STATE.manager
    if not _managed(manager) then
        manager = sdk.get_managed_singleton("app.CampManager")
        CAMP_STATE.manager = manager
    end
    if not _managed(manager) then return CAMP_STATE.active == true end
    local ok, active = pcall(function()
        return manager:call("get_IsActiveCamp") == true
    end)
    if ok then CAMP_STATE.active = active == true end
    return CAMP_STATE.active == true
end
function CAMP_STATE.is_fake_cook_station(key)
    local k = tostring(key or ""):lower()
    return CAMP_STATE.cook_station_keys[k] == true or k:match("^gm50_020") ~= nil
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
    local now = os.clock()
    if now - MEMO.pad_at < MEMO.ttl then return MEMO.pad end
    local mask = 0
    pcall(function()
        local gp = sdk.get_native_singleton("via.hid.GamePad")
        local td = MEMO.pad_td or sdk.find_type_definition("via.hid.GamePad")
        MEMO.pad_td = td
        local dev = gp and td and sdk.call_native_func(gp, td, "get_MergedDevice")
        if not dev and gp and td then
            dev = sdk.call_native_func(gp, td, "getMergedDevice(System.UInt32)", 0)
        end
        if not dev and gp and td then
            dev = sdk.call_native_func(gp, td, "get_Device")
        end
        if dev then mask = math.floor(tonumber(dev:call("get_Button")) or 0) end
    end)
    MEMO.pad_at, MEMO.pad = now, mask
    return mask
end
local function _kb_down(vk)
    vk = math.floor(vk)
    local now = os.clock()
    if now - (MEMO.kb_at[vk] or -1) < MEMO.ttl then return MEMO.kb[vk] end
    local down = false
    pcall(function()
        local s = sdk.get_native_singleton("via.hid.Keyboard")
        local td = MEMO.kb_td or sdk.find_type_definition("via.hid.Keyboard")
        MEMO.kb_td = td
        local dev = (s and td) and sdk.call_native_func(s, td, "get_Device")
        if dev then down = dev:call("isDown", vk) == true end
    end)
    if not down then
        pcall(function() down = reframework:is_key_down(vk) == true end)
    end
    MEMO.kb_at[vk], MEMO.kb[vk] = now, down
    return down
end
local function _binding_tokens(text)
    local list = MEMO.tokens[text]
    if list then return list end
    list = {}
    for raw in text:gmatch("[^,]+") do
        local token = raw:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        local pbit = PAD_ALIAS[token]
        if pbit then
            list[#list + 1] = { pbit = pbit }
        else
            local vk = VK_ALIAS[token] or tonumber(token)
            if not vk and token:match("^0x[0-9a-f]+$") then vk = tonumber(token:sub(3), 16) end
            if vk then list[#list + 1] = { vk = vk } end
        end
    end
    MEMO.tokens[text] = list
    return list
end
local function _binding_down(text)
    local list = _binding_tokens(tostring(text or ""))
    local padmask = nil
    for i = 1, #list do
        local t = list[i]
        if t.pbit then
            padmask = padmask or _pad_button_mask()
            local hit = false
            pcall(function() hit = (padmask & t.pbit) ~= 0 end)
            if hit then return true end
        elseif _kb_down(t.vk) then
            return true
        end
    end
    return false
end
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
        if down == true then return true end
    end
    return _binding_down(binding)
end
local function _interact_down()
    return _action_or_binding("Interact", M.interact_bind or "F")
end
local function _stop_down()
    return _action_or_binding("Interact", M.stop_bind or "backspace")
        or _action_or_binding({ "Dash", "KeepDash" }, "shift")
        or _binding_down(M.stop_bind or "backspace")
        or _binding_down("east")
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
local function _io_of(go, depth)
    local io = nil
    depth = depth or 0
    if not go or depth > 6 then return nil end
    pcall(function()
        for _, c in ipairs(_arr(go:call("get_Components"))) do
            local v = nil
            pcall(function() v = c.InteractiveObject end)
            if not v then pcall(function() v = c:get_field("InteractiveObject") end) end
            if v then io = v; return end
        end
    end)
    if io then return io end
    pcall(function()
        local tf = go:call("get_Transform")
        local child = tf and tf:call("get_Child")
        while child do
            local cgo = child:call("get_GameObject")
            if cgo then
                io = _io_of(cgo, depth + 1)
                if io then return end
            end
            child = child:call("get_Next")
        end
    end)
    return io
end
local PLANT_KINDS = { CHAIR = true }
local BED_KEYS = {
    gm51_092 = true,
    gm51_092_01 = true,
    gm51_299 = true,
    gm51_092_02 = true, gm51_100 = true, gm51_115 = true, gm51_115_01 = true,
    gm51_393 = true, gm51_396 = true, gm51_409 = true, gm51_409_01 = true,
    gm51_460 = true, gm51_603 = true, gm51_603_01 = true, gm51_742 = true,
}
local SIT_KEYS = {
    gm51_237 = true,
    gm51_060 = true,
    gm51_074 = true,
    gm50_070 = true,
    gm50_108 = true,
    gm50_108_01 = true,
    gm05_045 = true,
    gm51_752 = true,
}
local TALL_SEAT_KEYS = {
    gm50_108 = true,
    gm50_108_01 = true,
    gm05_045 = true,
}
local FORCED_SEAT_DONOR_KEYS = {}
THRONE = THRONE or { prev = false }
THRONE.request32 = require("II.ThroneRequest32")
THRONE.discovery = require("II.ThroneDiscovery32")
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
    if CAT[key].pc == 1 and not FORCED_SEAT_DONOR_KEYS[key] then
        return false, "the game already offers the player: " .. table.concat(CAT[key].pv or {}, "/")
    end
    return true, nil, key
end
local job, job_seq = nil, 0
local function _gimmick_job(name, path, up, rq)
    job = nil
    _G.__II_spawnfail = _G.__II_spawnfail or {}
    local _sf = _G.__II_spawnfail[tostring(name)]
    if _sf and _sf.until_at and os.clock() < _sf.until_at then return false end
    local ok, build_err = pcall(function()
        local gid
        local fld = sdk.find_type_definition("app.GimmickID"):get_field((name:gsub("^gm", "Gm")))
        if fld then gid = fld:get_data() end
        if not gid then _log("spawn: no app.GimmickID enum for " .. name); return end
        if not (up and rq) then return end
        local gen = sdk.get_managed_singleton("app.GenerateManager")
        local catalog_ctrl = gen and gen:get_field("_CatalogCtrl")
        local gimmick_catalog = catalog_ctrl and catalog_ctrl:get_field("_GimmickCatalog")
        local merged = gimmick_catalog
            and gimmick_catalog:get_field("<MergedCatalog>k__BackingField")
        local item = merged and merged:get_Item(gid)
        local ctrl = item and item:get_Item()
        local prefab = ctrl and ctrl:call("get_Item")
        if not (ctrl and prefab) then
            error("engine gimmick catalogue has no controller for " .. tostring(name))
        end
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
                container = container, catalog = true }
    end)
    if not ok then
        job = nil
        local k = tostring(name)
        local sf = _G.__II_spawnfail[k] or { n = 0 }
        sf.n = sf.n + 1
        sf.until_at = os.clock() + (sf.n >= 3 and 300.0 or 1.5)
        _G.__II_spawnfail[k] = sf
        if sf.n <= 3 then
            _log("spawn: build failed for " .. k .. ": " .. tostring(build_err)
                 .. (sf.n == 3 and " (backing off 5min; 3.2 GenerateInfo API changed)" or ""))
        end
    else
        _G.__II_spawnfail[tostring(name)] = nil
    end
    return job ~= nil
end
local function _spawn_pump()
    if not job then return nil end
    job.f = (job.f or 0) + 1
    if job.stage == "wait" then
        local ready = false
        pcall(function()
            if job.ctrl then
                if job.ctrl:call("get_Ready") == true then ready = true
                elseif not job.catalog then job.ctrl:call("update") end
            end
            if not ready then ready = job.prefab:get_Ready() == true end
        end)
        if ready then
            job_seq = job_seq + 1
            local okr, create_err = pcall(function()
                local gen = sdk.get_managed_singleton("app.GenerateManager")
                if type(rawget(_G, "IRIS_RCI")) == "function" then
                    _G.IRIS_RCI(gen, job.ctrl, job.container,
                        751000 + job_seq, job.inst, nil, nil)
                elseif rawget(_G, "IRIS_RCI_METHOD") then
                    local resolver=rawget(_G,"IRIS_RCI_METHOD")
                    local method=type(resolver)=="function" and resolver("instance") or resolver
                    assert(method,"TU3.2 requestCreateInstance resolver returned no method")
                    method:call(gen, job.ctrl, job.container,
                        751000 + job_seq, job.inst, nil, nil)
                else
                    gen:call("requestCreateInstance(app.PrefabController, app.GenerateInfo.GenerateInfoContainer, System.Int32, app.InstanceInfo, System.Action`2<app.PrefabInstantiateResults,app.DummyArg>, System.Action`2<app.PrefabInstantiateResults,app.DummyArg>)",
                        job.ctrl, job.container, 751000 + job_seq, job.inst, nil, nil)
                end
            end)
            if okr then
                job.stage, job.f = "poll", 0
            else
                job = nil
                _log("spawn: create refused: " .. tostring(create_err))
            end
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
local sc = { list_at = -1e9, at = 0, list = {}, near = {}, sit_list = {}, complete = false,
             last_p = nil, ms = 0, pos_cursor = 1 }
local seats = {}
local pending = nil
local stats = { placed = 0, retired = 0, dedup = 0, failed = 0,
                unlocked = 0, restored = 0, unlock_failed = 0 }
local unlocks = {}
local unlock_at = 0
local _active_native, _st_release, _is_station_active, _st_log
local ST = {
    groups = {
        { key = "food", label = "Food preparation" },
        { key = "everyday", label = "Everyday life" },
        { key = "household", label = "Household chores" },
        { key = "outdoors", label = "Farming and forestry" },
        { key = "trades", label = "Crafts and trades" },
    },
}
ST.native_groups = { gm50_036 = "everyday" }
function ST.native_group(key)
    if not key then return nil end
    return ST.native_groups[key] or ST.native_groups[key:match("^(gm%d+_%d+)") or ""]
end
ST.compat32 = require("II.Compat32")
ST.perf32 = require("II.Perf32")
ST.vocation_loaded,ST.vocation_racks=pcall(require,'II.VocationRack32')
if not ST.vocation_loaded then
    _log('Vocation rack load failed: '..tostring(ST.vocation_racks))
    re.on_draw_ui(function()
        if imgui.tree_node('Vocation Rack Status') then
            imgui.text('Module failed to load: '..tostring(ST.vocation_racks))
            imgui.tree_pop()
        end
    end)
end
_log("TU3.2 repair revision 2026-09-05-buff-grant: reflected buff manager, two-argument camp call, pickup exclusion")
function ST.player_interacting()
    local open = nil
    pcall(function()
        local ch = _player()
        local mgr = ch and sdk.get_managed_singleton("app.InteractManager")
        if ch and mgr then open = mgr:call("isInteracting(app.Character)", ch) == true end
    end)
    return open
end
function ST.group_on(group)
    return M.stations ~= false
        and type(M.activity_groups) == "table"
        and M.activity_groups[group] ~= false
end
function ST.activity_enabled(key)
    local row = STATIONS and STATIONS[key]
    return row ~= nil and ST.group_on(row.group)
        and not (M.st_off or {})[key]
end
function ST.any_activity_enabled()
    local now = os.clock()
    if now - MEMO.act_at < 0.25 then return MEMO.act end
    local any = false
    for key in pairs(STATIONS or {}) do
        if ST.activity_enabled(key) then any = true break end
    end
    MEMO.act_at, MEMO.act = now, any
    return any
end
function ST.seat_key_from_owner(go)
    local found = nil
    pcall(function()
        local tf = go and go:call("get_Transform")
        for _ = 1, 10 do
            if not tf then break end
            local node = tf:call("get_GameObject")
            local name = node and tostring(node:call("get_Name")) or nil
            local key = _norm(name)
            if key and SIT_KEYS[key] then found = key; break end
            tf = tf:call("get_Parent")
        end
    end)
    return found
end
function ST.seat_key_near(point)
    if not point then return nil end
    local best, best_d2 = nil, 4.0
    for _, e in ipairs(sc.sit_list or {}) do
        local pos = e and e._p
        if pos then
            local dx, dy, dz = pos.x - point.x, pos.y - point.y, pos.z - point.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < best_d2 then best, best_d2 = e.nkey, d2 end
        end
    end
    return best
end
function ST.restore_unlock(r)
    if not (r and r.point) then return false end
    return pcall(function()
        r.point:set_field("CharacterType", r.old)
        if r.old_icon ~= nil then r.point:set_field("IconType", r.old_icon) end
    end)
end
function ST.restore_disabled_activities()
    if ST.player_interacting() == true then return end
    for addr, r in pairs(unlocks) do
        local grouped = r.kind == "chore" and ST.native_group(r.prop_key)
        if (r.kind == "station" and not ST.activity_enabled(r.prop_key))
                or (grouped and not ST.group_on(grouped)) then
            local ok = ST.restore_unlock(r)
            if ok then stats.restored = stats.restored + 1 end
            unlocks[addr] = nil
        end
    end
end
local function _unlock_count(kind)
    local n = 0
    for _, r in pairs(unlocks) do if not kind or r.kind == kind then n = n + 1 end end
    return n
end
local function _restore_unlocks(kind, keep)
    if (kind == nil or kind == "seat") and ST.player_interacting() == true then
        sc.restore_seats_when_clear = true
        return
    end
    for k, r in pairs(unlocks) do
        if (not kind or r.kind == kind) and (not keep or not keep(r)) then
            local ok = ST.restore_unlock(r)
            if ok then stats.restored = stats.restored + 1 end
            unlocks[k] = nil
        end
    end
end
function ST.grouped_chore(r) return r.kind == "chore" and ST.native_group(r.prop_key) ~= nil end
function CAMP_STATE.restore_cook_unlocks()
    for k, r in pairs(unlocks) do
        if r.kind == "station" and (CAMP_STATE.is_fake_cook_station(r.prop_key)
                or CAMP_STATE.is_fake_cook_station(r.host)) then
            local ok = ST.restore_unlock(r)
            if ok then stats.restored = stats.restored + 1 end
            unlocks[k] = nil
        end
    end
end
local function _unlock_kind(key)
    if not key then return nil end
    if CAMP_STATE.is_active() and CAMP_STATE.is_fake_cook_station(key) then return nil end
    if key == "gm10_030" then return nil end
    if key == "gm50_022" and not ST.activity_enabled(key) then
        return nil
    end
    if M.enabled and SIT_KEYS[key] then return "seat" end
    if LOOSE_TOOL_KEYS[key] then
        return M.native_chores and "chore" or nil
    end
    if ST.activity_enabled(key) then
        return "station"
    end
    local native_group = ST.native_group(key)
    if native_group then return ST.group_on(native_group) and "chore" or nil end
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
local function _ambient_owner(go)
    if not _managed(go) then return nil end
    local found = nil
    pcall(function()
        for _, comp in ipairs(_arr(go:call("get_Components"))) do
            if _owner_is(comp, "app.GmAIInteract_01") then
                found = comp
                break
            end
        end
    end)
    return found
end
local BED_TYPE = nil
pcall(function() BED_TYPE = sdk.typeof("app.Gm51_115") end)
local function _bed_owner(go)
    if not _managed(go) then return nil end
    local bed = nil
    if BED_TYPE then
        pcall(function() bed = go:call("getComponent(System.Type)", BED_TYPE) end)
        if _managed(bed) then return bed end
    end
    pcall(function()
        for _, comp in ipairs(_arr(go:call("get_Components"))) do
            if _owner_is(comp, "app.Gm51_115") then
                bed = comp
                break
            end
        end
    end)
    return _managed(bed) and bed or nil
end
local function _safe_chore_owner(owner, prop_key)
    if prop_key == "gm50_022" or prop_key == "gm10_030" then
        return false
    end
    if prop_key and prop_key:match("^gm50_036") then return true end
    if _owner_is(owner, "app.GmInteractPickableBase") then return true end
    return false
end
local function _patch_search_point(point, kind, host, source, index, io, owner, prop_key)
    if not point then return false end
    if kind == "chore" and not _safe_chore_owner(owner, prop_key) then return false end
    local key = _addr(point)
    if not key then return false end
    if unlocks[key] then
        local r = unlocks[key]
        if prop_key == 'gm50_097' then
            local allowed=ST.holding_pitchfork and ST.holding_pitchfork()
            pcall(function() point:set_field('CharacterType',r.old+(allowed and 1 or 0)) end)
        end
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
    if kind ~= "seat"
        and (icon ~= 0 and not (kind == "bed" and (icon == 30 or icon == 22))) then
        return false
    end
    if not ct or (kind ~= "seat" and not has_human) or (ct % 2) == 1 then
        return false
    end
    local new_ct = ct + 1
    if prop_key == 'gm50_097' and not (ST.holding_pitchfork and ST.holding_pitchfork()) then
        new_ct=ct
    end
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
    if CAMP_STATE.is_active()
            and CAMP_STATE.is_fake_cook_station(key or (e and e.name)) then return end
    local bed_owner = M.native_beds ~= false and e and _bed_owner(e.go) or nil
    local ambient_owner = M.native_ambient == true and e and _ambient_owner(e.go) or nil
    local kind = bed_owner and "bed" or (ambient_owner and "ambient" or _unlock_kind(key))
    if not kind or not (e and e.go and _valid(e.go)) then return end
    for _, comp in ipairs(_arr(e.go:call("get_Components"))) do
        local allow = kind == "chore" or kind == "station" or kind == "seat"
        if kind == "bed" then
            allow = (bed_owner and _addr(comp) == _addr(bed_owner))
                or _owner_is(comp, "app.Gm51_115")
        elseif kind == "ambient" then
            allow = ambient_owner and _addr(comp) == _addr(ambient_owner)
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
    if kind == "seat" or kind == "chore" or kind == "station" or kind == "bed" then
        local io = _io_of(e.go)
        if io then
            local runtime = nil
            pcall(function() runtime = io:get_field("DataList") end)
            _patch_data_list(runtime, kind, e.name, "runtime-child", io,
                bed_owner or ambient_owner, key)
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
    local player = _player()
    local mgr = player and sdk.get_managed_singleton("app.InteractManager")
    if not mgr then return nil end
    local active = nil
    pcall(function() active = _get_active_interact(mgr, player) end)
    local point = nil
    pcall(function() point = active and active:get_field("Point") end)
    local io, no = nil, nil
    pcall(function() io = point and point:get_field("Object") end)
    pcall(function() no = point and tonumber(point:get_field("PointNo")) end)
    if not io then return nil end
    local rec = _record_for_active(io, no)
    local key, owner_go = nil, nil
    pcall(function() owner_go = io:call("get_Owner") end)
    if not owner_go then
        pcall(function() owner_go = io:get_field("<Owner>k__BackingField") end)
    end
    if owner_go then
        pcall(function()
            local raw = tostring(owner_go:call("get_Name") or ""):lower()
            key = _norm(raw) or raw:match("^(gm%d+_%d+_?%d*)")
        end)
    end
    pcall(function()
        if not rec and M.enabled ~= false and owner_go then
            local seat_key = ST.seat_key_from_owner(owner_go)
            if seat_key then
                key = seat_key
                rec = { kind = "seat", native_player = true,
                        host = seat_key, prop_key = seat_key, io = io,
                        io_addr = _addr(io), index = no }
            end
        end
        if rec and rec.kind == "bed" and not _managed(rec.owner) and owner_go then
            local bed = _bed_owner(owner_go)
            if _managed(bed) then rec.owner = bed end
        end
        if not rec and M.native_beds ~= false and owner_go then
            local bed = _bed_owner(owner_go)
            if _managed(bed) then
                rec = { kind = "bed", native_player = true, owner = bed,
                        host = tostring(key or "Gm51_115"), prop_key = key, io = io,
                        io_addr = _addr(io), index = no }
            end
        end
        if not rec and M.enabled ~= false then
            local q = nil
            pcall(function() q = io:call("getInteractPointPosition", no or 0) end)
            local seat_key = ST.seat_key_near(q)
            if seat_key then
                key = seat_key
                rec = { kind = "seat", native_player = true,
                        host = seat_key, prop_key = seat_key, io = io,
                        io_addr = _addr(io), index = no }
            end
        end
    end)
    return { player = player, mgr = mgr, active = active,
             io = io, point_no = no, rec = rec, key = key, owner_go = owner_go }
end
function ST.sit_ik()
    local ik = nil
    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        local ctrl = human and human:call("get_BodyChangeIKCtrl")
        if not ctrl and human then ctrl = human:get_field("BodyChangeIKCtrl") end
        if not ctrl and human then ctrl = human:get_field("<BodyChangeIKCtrl>k__BackingField") end
        if not ctrl then return end
        ik = ctrl:call("get_AnimSitChairIK")
        if not ik then ik = ctrl:get_field("AnimSitChairIK") end
        if not ik then ik = ctrl:get_field("<AnimSitChairIK>k__BackingField") end
    end)
    return _managed(ik) and ik or nil
end
ST.tall_visual = { key = nil, player_addr = nil, ik = nil, base_offset = nil }
function ST.nullable_vec3(value)
    if value == nil then return nil end
    local function direct(v)
        local x, y, z = nil, nil, nil
        pcall(function() x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z) end)
        if x ~= nil and y ~= nil and z ~= nil then return { x = x, y = y, z = z } end
        return nil
    end
    local row = direct(value)
    if row then return row end
    local has = nil
    pcall(function() has = value:get_field("_HasValue") end)
    if has == nil then pcall(function() has = value:get_field("HasValue") end) end
    if has == nil then pcall(function() has = value:call("get_HasValue") end) end
    if has == false then return nil end
    local inner = nil
    pcall(function() inner = value:get_field("_Value") end)
    if inner == nil then pcall(function() inner = value:get_field("Value") end) end
    if inner == nil then pcall(function() inner = value:call("get_Value") end) end
    return direct(inner)
end
function ST.tall_visual_clear()
    local visual = ST.tall_visual
    if visual.ik and visual.base_offset then
        pcall(function()
            local v = Vector3f.new(visual.base_offset.x,
                visual.base_offset.y, visual.base_offset.z)
            local ok = pcall(function()
                visual.ik:call("set_LocalSitOffset(via.vec3)", v)
            end)
            if not ok then
                visual.ik:set_field("<LocalSitOffset>k__BackingField", v)
            end
        end)
    end
    visual.key, visual.player_addr, visual.ik, visual.base_offset, visual.logged =
        nil, nil, nil, nil, nil
end
function ST.tall_visual_tick()
    if M.master == false or M.enabled == false or _loading() then
        ST.tall_visual_clear()
        return
    end
    local ch = _player()
    local go = _char_go(ch)
    if not go then
        ST.tall_visual_clear()
        return
    end
    local fsm = go:call("getComponent(System.Type)", sdk.typeof("via.motion.MotionFsm2"))
    local node = fsm and tostring(fsm:call("getCurrentNodeName", 0)) or ""
    if not node:find("SitOnChair", 1, true) then
        ST.tall_gate = "waiting: not in a chair-sit animation"
        pcall(function()
            local pp2 = _pos(go)
            local k2 = pp2 and ST.seat_key_near(pp2)
            if k2 and TALL_SEAT_KEYS[k2] and node ~= "" then
                _log("tall seat: seated node = '" .. node .. "' (seat " .. tostring(k2) .. ")")
            end
        end)
        ST.tall_visual_clear()
        return
    end
    local pp = _pos(go)
    local key = ST.seat_key_near(pp)
    if not (key and TALL_SEAT_KEYS[key]) then
        ST.tall_gate = key and "seated: nearest seat is not a tall seat"
            or "seated: no catalogued seat within 2m"
        ST.tall_visual_clear()
        return
    end
    local ik = ST.sit_ik()
    if not ik then ST.tall_gate = "tall seat: sit IK component unreadable" return end
    local pa = _addr(ch)
    local visual = ST.tall_visual
    if visual.key ~= key or visual.player_addr ~= pa or visual.ik ~= ik
            or not visual.base_offset then
        ST.tall_visual_clear()
        local base = nil
        pcall(function() base = ik:call("get_LocalSitOffset") end)
        if not base then ST.tall_gate = "tall seat: LocalSitOffset unreadable" return end
        visual.key, visual.player_addr, visual.ik = key, pa, ik
        visual.base_offset = {
            x = tonumber(base.x) or 0.0,
            y = tonumber(base.y) or 0.0,
            z = tonumber(base.z) or 0.0,
        }
    end
    local base = visual.base_offset
    local lift = math.max(0.0, math.min(0.80, tonumber(M.tall_seat_y) or 0.25))
    local wanted = Vector3f.new(base.x, base.y + lift, base.z)
    local wrote = pcall(function()
        ik:call("set_LocalSitOffset(via.vec3)", wanted)
    end)
    if not wrote then
        wrote = pcall(function()
            ik:set_field("<LocalSitOffset>k__BackingField", wanted)
        end)
    end
    local rb = nil
    pcall(function() rb = ik:call("get_LocalSitOffset") end)
    local stuck = rb and math.abs((tonumber(rb.y) or -999) - (base.y + lift)) < 0.01
    ST.tall_gate = stuck and "native chair IK lift active"
        or "tall seat: LocalSitOffset write did not stick"
    if not visual.logged then
        visual.logged = true
        _log(string.format("tall seat %s: baseY=%.3f targetY=%.3f wrote=%s readY=%s",
            tostring(key), base.y, base.y + lift, tostring(wrote),
            tostring(rb and rb.y)))
    end
end
re.on_application_entry("LateUpdateBehavior", function()
    pcall(ST.tall_visual_tick)
end)
function _is_station_active(a)
    if not a then return false end
    if CAMP_STATE.is_active() and CAMP_STATE.is_fake_cook_station(
            (a.rec and a.rec.prop_key) or a.key) then return false end
    if a.rec and a.rec.kind == "station" then return true end
    if a.rec and a.rec.kind == "bed" then return true end
    if a.key and ST.activity_enabled(a.key) then return true end
    return false
end
local function _unlock_tick()
    local now = os.clock()
    if now - unlock_at < (M.unlock_secs or 1.0) then return end
    unlock_at = now
    local stations_on = ST.any_activity_enabled()
    for _, g in pairs(ST.native_groups) do if ST.group_on(g) then stations_on = true break end end
    local ambient_on = M.native_ambient == true
    if CAMP_STATE.is_active() then CAMP_STATE.restore_cook_unlocks() end
    if not M.enabled and not stations_on and not ambient_on then
        if next(unlocks) then _restore_unlocks() end
        return
    end
    if not M.enabled and next(unlocks) then
        _restore_unlocks("chore"); _restore_unlocks("bed"); _restore_unlocks("seat")
    end
    if not stations_on and _unlock_count("station") > 0 then _restore_unlocks("station") end
    if stations_on then ST.restore_disabled_activities() end
    if not ambient_on and _unlock_count("ambient") > 0 then _restore_unlocks("ambient") end
    if M.enabled then
        if not M.native_chores and _unlock_count("chore") > 0 then _restore_unlocks("chore", ST.grouped_chore) end
        if not M.native_beds and _unlock_count("bed") > 0 then _restore_unlocks("bed") end
    end
    local want_native = M.enabled
    if not want_native and not stations_on and not ambient_on then return end
    if _loading() or _menu_open() then return end
    for _, e in ipairs(sc.near or {}) do
        if now - (tonumber(e.unlock_at) or 0) >= 2.0 then
            e.unlock_at = now
            pcall(_unlock_go, e)
        end
    end
end
local function _seat_count()
    local n = 0
    for _ in pairs(seats) do n = n + 1 end
    return n
end
local function _kill_seat(rec)
    if not (rec and rec.go) then return true end
    if ST.player_interacting() == true then
        rec.retire_when_clear = true
        return false
    end
    pcall(function()
        if _valid(rec.go) then rec.go:call("destroy(via.GameObject)", rec.go) end
    end)
    rec.go = nil
    return true
end
local function _drop_all(destroy)
    if destroy and ST.player_interacting() == true then
        sc.drop_when_clear = true
        return false
    end
    for k, rec in pairs(seats) do
        if destroy then _kill_seat(rec) else rec.go = nil end
        seats[k] = nil
    end
    pending = nil
    return true
end
local function _catalog_label(key)
    local k = tostring(key or "")
    for _ = 1, 4 do
        local row = CAT[k]
        if row and row.lb and tostring(row.lb) ~= "" then return tostring(row.lb) end
        local shorter = k:gsub("_%d+$", "")
        if shorter == k then break end
        k = shorter
    end
    return ""
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
                built[#built + 1] = { go = go, name = nm or "?", nkey = _norm(nm) }
            end
        end
        ok = #built > 0
    end)
    if ok then
        sc.list = built
        require('II.VocationRack32').refresh(built)
        sc.near = {}
        sc.pos_cursor = 1
        local sits = {}
        for _, e in ipairs(built) do
            if e.nkey and SIT_KEYS[e.nkey] then sits[#sits + 1] = e end
        end
        sc.sit_list = sits
    end
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
    local stations_on = ST.any_activity_enabled()
    local ambient_on = M.native_ambient == true
    local native_on = M.enabled and (M.native_chores or M.native_beds)
    if not M.enabled and not stations_on and not native_on and not ambient_on then
        if _seat_count() > 0 then _drop_all(true) end
        return
    end
    local now = os.clock()
    if not pending and now < (tonumber(sc.tick_at) or 0) then return end
    sc.tick_at = now + 0.05
    if _loading() or _menu_open() then return end
    if sc.drop_when_clear and ST.player_interacting() ~= true then
        sc.drop_when_clear = nil
        _drop_all(true)
        sc.list_at = -1e9
        return
    end
    if sc.restore_seats_when_clear and ST.player_interacting() ~= true then
        sc.restore_seats_when_clear = nil
        _restore_unlocks("seat")
    end
    if sc.rescan_after then
        if now < sc.rescan_after then return end
        sc.rescan_after = nil
        sc.list_at = -1e9
    end
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
    end
    local pgo = _char_go(_player())
    local pp = pgo and _pos(pgo)
    if not pp then return end
    local moved = 1e9
    if sc.last_p then
        local dx, dy, dz = pp.x - sc.last_p.x, pp.y - sc.last_p.y, pp.z - sc.last_p.z
        moved = math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    if now - sc.list_at > (M.list_secs or 30.0) or moved > (M.list_move or 30.0) then
        sc.list_at = now
        sc.last_p = { x = pp.x, y = pp.y, z = pp.z }
        local t0 = os.clock()
        sc.complete = _refresh_list()
        sc.ms = (os.clock() - t0) * 1000.0
        if M.neuter_collision or sc.had_neuter then
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
            sc.had_neuter = M.neuter_collision == true
            if nd ~= (sc.neutered or -1) or healed > 0 then
                sc.neutered = nd
                _st_log("collider pass: " .. nd .. " rig seats neutered"
                    .. (healed > 0 and (", " .. healed .. " colliders re-enabled") or ""))
            end
        end
    end
    local nlist = #sc.list
    if nlist > 0 then
        local left = math.max(8, math.floor(tonumber(M.position_budget) or 48))
        while left > 0 and sc.pos_cursor <= nlist do
            local e = sc.list[sc.pos_cursor]
            sc.pos_cursor = sc.pos_cursor + 1
            left = left - 1
            if e and e.go and _valid(e.go) then
                local gp = _pos(e.go)
                if gp then e._p = { x = gp.x, y = gp.y, z = gp.z } end
            end
        end
    end
    if now - sc.at < (M.scan_secs or 0.5) then return end
    sc.at = now
    local want, inrange = {}, {}
    local range, yw = (M.range or 12.0), (M.y_window or 2.5)
    local far = range * (M.hysteresis or 1.25)
    local budget, truncated = (M.budget or 64), sc.pos_cursor <= #sc.list
    for _, e in ipairs(sc.list) do
        if budget <= 0 then truncated = true; break end
        if e._p then
            local gp = e._p
            if math.abs(gp.y - pp.y) <= yw then
                local dx, dz = gp.x - pp.x, gp.z - pp.z
                local d2 = dx * dx + dz * dz
                if d2 < far * far then
                    if not e.done then budget = budget - 1 end
                    _resolve(e)
                    local k = nil
                    pcall(function() k = e.go:get_address() end)
                    if k then
                        e._addr, e._d2 = k, d2
                        inrange[#inrange + 1] = e
                    end
                end
            end
        end
    end
    sc.near = inrange
    if pending or job then return end
    if not M.enabled then
        if _seat_count() > 0 then _drop_all(true) end
        return
    end
    for _, e in ipairs(inrange) do
        if e.ok and (e._d2 or 1e18) < range * range and PLANT_KINDS[e.kind or ""] then
            if _catalog_label(e.key):lower() ~= "stool" then
                local np = tonumber((CAT[e.key] or {}).n) or 1
                np = math.max(1, math.min(np, M.max_points or 4))
                for p = 0, np - 1 do
                    want[e._addr .. ":" .. p] = { e = e, point = p }
                end
            end
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
                    if e._addr == rec.addr and (e._d2 or 1e18) < far * far then keep = true; break end
                end
            end
            if not keep or not (rec.go and _valid(rec.go)) then
                if _kill_seat(rec) then
                    seats[k] = nil
                    stats.retired = stats.retired + 1
                end
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
                if d < pd then
                    pick, pd = { key = k, e = w.e, point = w.point }, d
                end
            end
        end
    end
    if not pick then return end
    pcall(function()
        local tf = pick.e.go:call("get_Transform")
        local up, rq = tf:call("get_UniversalPosition"), tf:call("get_Rotation")
        local p = ValueType.new(sdk.find_type_definition("via.Position"))
        local lift = M.seat_y or 0.0
        p.x, p.y, p.z = up.x, up.y + lift, up.z
        if M.per_point ~= false then
            local io = _io_of(pick.e.go)
            if io then
                local pt = nil
                pcall(function() pt = io:call("getInteractPointPosition", pick.point or 0) end)
                if pt then
                    local dx, dy, dz = pt.x - up.x, pt.y - up.y, pt.z - up.z
                    if math.sqrt(dx * dx + dy * dy + dz * dz) < 8.0 then
                        p.x, p.y, p.z = pt.x, pt.y + lift, pt.z
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
STATIONS = {
    gm50_022    = { bank = 8504, path = "appsystem/gimmick/gm50_027/gm50_022_interact_motlist.motlist", label = "Knead dough" },
    gm50_005    = { bank = 8507, path = "appsystem/gimmick/gminteract/gm50_005/gm50_005_interact_motlist.motlist", label = "Drink" },
    gm50_007_01 = { bank = 8509, path = "appsystem/gimmick/gm50_007/gm50_007_01_interact_motlist.motlist", label = "Sweep" },
    gm50_010_01 = { bank = 8510, path = "appsystem/gimmick/gm50_010/gm50_010_interact_motlist.motlist", label = "Use the hatchet" },
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
    gm50_096    = { bank = 8524, path = "appsystem/gimmick/gm50_096/gm50_096_interact_motlist.motlist", label = "Pitch hay" },
    gm50_096_01 = { bank = 8524, path = "appsystem/gimmick/gm50_096/gm50_096_interact_motlist.motlist", label = "Pitch hay" },
    gm50_097    = { bank = 8525, path = "appsystem/gimmick/gm50_097/gm50_097_interact_motlist.motlist", label = "Work the hay" },
    gm50_298    = { bank = 8526, path = "appsystem/gimmick/gm50_298/gm50_298_interact_motlist.motlist", label = "Dig" },
    gm50_298_01 = { bank = 8526, path = "appsystem/gimmick/gm50_298/gm50_298_interact_motlist.motlist", label = "Dig" },
    gm51_041_00 = { bank = 8527, path = "appsystem/gimmick/gm51_041/gm51_041_interact_motlist.motlist", label = "Tend the fire" },
    gm51_045    = { bank = 8528, path = "appsystem/gimmick/gm51_045/gm51_045_interact_motlist.motlist", label = "Polish" },
    gm51_046    = { bank = 8529, path = "appsystem/gimmick/gm51_046/gm51_046_interact_motlist.motlist", label = "Carry wooden beams" },
    gm51_132    = { bank = 8530, path = "appsystem/gimmick/gm51_132/gm51_132_interact_motlist.motlist", label = "Weave" },
    gm51_133    = { bank = 8531, path = "appsystem/gimmick/gm51_133/gm51_133_interact_motlist.motlist", label = "Weave" },
    gm51_188_00 = { bank = 8532, path = "appsystem/gimmick/gm51_188/gm51_188_00_interact_motlist.motlist", label = "Work the forge" },
    gm82_053    = { bank = 8540, path = "appsystem/gimmick/gm82_053/gm82_053_interact_motlist.motlist", label = "Smith", pin = true },
    gm82_053_01 = { bank = 8541, path = "appsystem/gimmick/gm82_053/gm82_053_01_interact_motlist.motlist", label = "Smith", pin = true },
    gm50_045_00 = { label = "Smithy station", pin = true },
    gm51_653    = { label = "Wash clothes" },
    gm50_259_01 = { label = "Chop wood" },
}
STATIONS.gm50_022.group = "food"
STATIONS.gm50_132_01.group = "food"
STATIONS.gm50_016_01.group = "food"
STATIONS.gm50_020.group = "food"
STATIONS.gm50_005.group = "everyday"
STATIONS.gm50_025.group = "everyday"
STATIONS.gm50_053.group = "everyday"
STATIONS.gm50_007_01.group = "household"
STATIONS.gm50_013.group = "household"
STATIONS.gm50_013_01.group = "household"
STATIONS.gm50_013_02.group = "household"
STATIONS.gm50_014_01.group = "household"
STATIONS.gm51_041_00.group = "household"
STATIONS.gm51_653.group = "household"
STATIONS.gm50_010_01.group = "outdoors"
STATIONS.gm50_011_01.group = "outdoors"
STATIONS.gm50_031.group = "outdoors"
STATIONS.gm50_031_01.group = "outdoors"
STATIONS.gm50_096.group = "outdoors"
STATIONS.gm50_096_01.group = "outdoors"
STATIONS.gm50_097.group = "outdoors"
STATIONS.gm50_298.group = "outdoors"
STATIONS.gm50_298_01.group = "outdoors"
STATIONS.gm50_259_01.group = "outdoors"
STATIONS.gm50_041_01.group = "trades"
STATIONS.gm50_052_1.group = "trades"
STATIONS.gm51_045.group = "trades"
STATIONS.gm51_046.group = "trades"
STATIONS.gm51_132.group = "trades"
STATIONS.gm51_133.group = "trades"
STATIONS.gm51_188_00.group = "trades"
STATIONS.gm82_053.group = "trades"
STATIONS.gm82_053_01.group = "trades"
STATIONS.gm50_045_00.group = "trades"
ST.prev, ST.kill_prev, ST.jump_prev, ST.session, ST.pending, ST.at =
    false, false, false, nil, nil, 0
ST.status = "idle - the game offers its own prompt at each unlocked station"
function _st_log() end
local function _st_motion()
    local go = _char_go(_player())
    local m = nil
    pcall(function() m = go:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion")) end)
    return m
end
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
        local fsm = _human_fsm(human)
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
local EXIT_RECOVERY = { status = "not run", pending_at = nil }
local function _player_action_name(ch, layer)
    local name = nil
    pcall(function()
        local am = ch and ch:call("get_ActionManager")
        if not am and ch then am = ch:get_field("<ActionManager>k__BackingField") end
        if not am then return end
        local list = am:get_field("CurrentActionList")
        if not list then list = am:call("get_CurrentActionList") end
        local item = list and list:call("get_Item", tonumber(layer) or 0)
        if not item then return end
        name = item:get_field("Name")
        if name == nil then name = item:call("get_Name") end
        if name ~= nil then name = tostring(name) end
    end)
    return name
end
local function _player_fsm_has_node(fragment)
    local found = false
    pcall(function()
        local go = _char_go(_player())
        local fsm = go and go:call("getComponent(System.Type)", sdk.typeof("via.motion.MotionFsm2"))
        if not fsm then return end
        local needle = tostring(fragment or ""):lower()
        for tree = 0, 7 do
            local node = fsm:call("getCurrentNodeName", tree)
            if node and tostring(node):lower():find(needle, 1, true) then
                found = true
                return
            end
        end
    end)
    return found
end
local function _st_restore_player_after_native_exit(reason, reset_motion)
    local ch = _player()
    if not ch then return end
    local before = _player_action_name(ch, 0) or "unknown"
    local requested = false
    local go = _char_go(ch)
    pcall(function()
        local aj = go and go:call("getComponent(System.Type)", sdk.typeof("app.AdjustJack"))
        if aj then
            aj:call("rejectSelf")
            aj:call("restartOwnerProcess", true)
            aj:call("enableOwnerFSM")
        end
    end)
    pcall(function()
        local human = ch:call("get_Human")
        local fsm = _human_fsm(human)
        if fsm then fsm:set_Enabled(true) end
        local am = ch:call("get_ActionManager")
        if am then
            am:call("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)",
                10, "NormalLocomotion", 0)
            requested = true
        end
    end)
    local motion_reset = false
    if reset_motion then
        pcall(function()
            local motion = _st_motion()
            local layer = motion and motion:call("getLayer", 0)
            if layer then
                layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
                    0, 1, 0.0, 6.0, 1, 1)
                motion_reset = true
            end
        end)
    end
    pcall(function() ch:call("setCharacterControllerEnable", true) end)
    EXIT_RECOVERY.reason = tostring(reason or "native")
    EXIT_RECOVERY.before = before
    EXIT_RECOVERY.requested = requested
    EXIT_RECOVERY.motion_reset = motion_reset
    EXIT_RECOVERY.pending_at = os.clock() + 0.35
    EXIT_RECOVERY.status = string.format("%s: %s -> requested=%s motion=%s",
        EXIT_RECOVERY.reason, before, tostring(requested), tostring(motion_reset))
end
local IX = { at = 0, owned = false, kind = nil }
local function _owned_seat_go(go)
    local a = _addr(go)
    if not a then return false end
    for _, rec in pairs(seats) do
        if rec.go and _addr(rec.go) == a then return true end
    end
    return false
end
local function _interaction_cleanup_tick()
    local now = os.clock()
    if now - (tonumber(IX.at) or 0) < 0.15 then return end
    IX.at = now
    if EXIT_RECOVERY.pending_at and now >= EXIT_RECOVERY.pending_at then
        local after = _player_action_name(_player(), 0) or "unknown"
        EXIT_RECOVERY.status = string.format("%s: %s -> %s (requested=%s motion=%s)",
            tostring(EXIT_RECOVERY.reason or "native"),
            tostring(EXIT_RECOVERY.before or "unknown"), after,
            tostring(EXIT_RECOVERY.requested == true),
            tostring(EXIT_RECOVERY.motion_reset == true))
        EXIT_RECOVERY.pending_at = nil
    end
    if M.master == false then
        IX.owned, IX.kind = false, nil
        return
    end
    if _loading() or _menu_open() then return end
    local ch = _player()
    local jacked = nil
    pcall(function() jacked = ch and ch:call("get_IsJacked") == true end)
    if not IX.owned and jacked ~= true then return end
    local a = _active_native()
    local kind = nil
    if a then
        local key = _norm(a.key or (a.rec and a.rec.prop_key))
        if a.rec and a.rec.kind == "station" then
            kind = "station"
        elseif a.rec and a.rec.kind == "seat" then
            kind = "seat"
        elseif a.rec and a.rec.kind == "bed" then
            kind = "bed"
        elseif a.rec and a.rec.kind == "ambient" then
            kind = "ambient"
        elseif key and ST.activity_enabled(key) and not LOOSE_TOOL_KEYS[key] then
            kind = "station"
        elseif _owned_seat_go(a.owner_go) then
            kind = "seat"
        end
    end
    if kind then
        IX.owned, IX.kind = true, kind
        return
    end
    if not IX.owned then return end
    if a then
        IX.owned, IX.kind = false, nil
        return
    end
    local open = nil
    pcall(function()
        local mgr = ch and sdk.get_managed_singleton("app.InteractManager")
        if ch and mgr then open = mgr:call("isInteracting(app.Character)", ch) end
    end)
    if open == false and jacked == false then
        local ended = IX.kind
        IX.owned, IX.kind = false, nil
        _st_log("native " .. tostring(ended) .. " exit confirmed; no forced reset")
    end
end
function _st_release(reason, expected_io)
    local ch = _player()
    if not ch then return end
    local rec = nil
    pcall(function()
        local a = _active_native()
        rec = a and a.rec
    end)
    if rec and rec.kind == "bed" then
        _st_log("release: " .. tostring(reason or "manual")
            .. " ignored for lying bed; native A/Jump is the only safe owner exit")
        return
    end
    local flagged = false
    _st_log("release: requesting native abort (" .. tostring(reason) .. ") on "
        .. tostring(rec and rec.host or (ST.session and ST.session.host) or "?"))
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        local a = _get_active_interact(mgr, ch)
        if a then
            if expected_io then
                local point = a:get_field("Point")
                local io = point and point:get_field("Object")
                if _addr(io) ~= _addr(expected_io) then return end
            end
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
    _st_log("release: no abort target; leaving native exit ownership intact")
end
function ST.is_anvil_session(sess)
    local key = sess and (sess.key or (sess.rec and sess.rec.prop_key))
    return key == "gm82_053" or key == "gm82_053_01" or key == "gm50_045_00"
end
function ST.anvil_context_mark(label)
    pcall(function() require("II.AnvilTrace32").mark(label) end)
end
function ST.read_anvil_state()
    local s={}
    pcall(function()
        local ch=_player()
        local gm=sdk.get_managed_singleton("app.GuiManager")
        local im=sdk.get_managed_singleton("app.InteractManager")
        s.actor=ch and _addr(ch)
        s.loading=_loading()
        s.menu=_menu_open()
        s.input_released=not _stop_down()
        s.interacting=ch and im and im:call("isInteracting(app.Character)",ch)
        s.jacked=ch and ch:call("get_IsJacked")
        s.action=_player_action_name(ch,0)
        s.paused=gm and gm:get_field("IsMenuUIPause")
        s.pause_requested=gm and gm:get_field("IsRequestGUIPause")
        s.block=gm and gm:get_field("_BlockMenu")
        if gm then
            s.menu_type=gm:get_field("MenuUI")==nil and "none" or "present"
        end
    end)
    return s
end
function ST.open_anvil_ui(q)
    ST.anvil_ui_pending=nil
    ST.status="Anvil enhancement disabled following native crashes."
    ST.notice="Anvil upgrades unavailable; use the normal blacksmith."
    _st_log("anvil: "..ST.status)
    return false
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
local TOOLS = {
    gm50_007 = { verb = "Sweep", finish_verb = "Finish sweeping",
        cands = { { bank = 8509, path = "appsystem/gimmick/gm50_007/gm50_007_01_interact_motlist.motlist" },
                  { bank = 8508, path = "appsystem/gimmick/gm50_007/gm50_007_interact_motlist.motlist" } },
        names = { start  = "ch00_000_rol_sweep_idle_start",
                  loop   = "ch00_000_rol_sweep_idle_loop",
                  finish = "ch00_000_rol_sweep_idle_end" } },
    gm50_010_01 = { verb = "Use hatchet", finish_verb = "Finish chopping",
        cands = { { bank = 18510, path = "appsystem/gimmick/gm50_010/gm50_010_interact_motlist.motlist" },
                  { bank = 8510, path = "appsystem/gimmick/gm50_010/gm50_010_interact_motlist.motlist" } },
        names = { start  = "ch00_000_rol_axe_idle_start",
                  loop   = "ch00_000_rol_axe_idle_loop",
                  finish = "ch00_000_rol_axe_idle_end" } },
    gm50_031 = { verb = "Till soil", finish_verb = "Finish tilling",
        cands = { { bank = 8519, path = "appsystem/gimmick/gm50_031/gm50_031_interact_motlist.motlist" } },
        names = { start  = "ch00_000_rol_plow01_start",
                  loop   = "ch00_000_rol_plow01_loop",
                  finish = "ch00_000_rol_plow01_end" } },
    gm50_096 = { verb = "Pitch hay", finish_verb = "Stop pitching",
        cands = { { bank = 8524, path = "appsystem/gimmick/gm50_096/gm50_096_interact_motlist.motlist" } },
        names = { start = "ch00_000_rol_feed01_end" } },
}
local TL = { at = 0, key = nil, act = nil, prev = false, raw = nil,
             mounted = {}, holders = {}, clips = {}, res = {}, rtry = {},
             resources = {}, banks = {}, lookup_errors = {}, api = require("II.ToolMotion32") }
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
    local motion = _st_motion()
    if not motion then return false end
    if TL.motion_addr ~= _addr(motion) then
        TL.motion_addr = _addr(motion)
        TL.mounted, TL.clips, TL.res, TL.rtry, TL.holders = {}, {}, {}, {}, {}
        TL.resources, TL.banks, TL.lookup_errors = {}, {}, {}
    end
    if TL.mounted[bank] == path then return true end
    local holder, resource = nil, nil
    pcall(function()
        local res = sdk.create_resource("via.motion.MotionListResource", path)
        if res then
            res:add_ref()
            resource = res
            holder = res:create_holder("via.motion.MotionListResourceHolder")
            if holder then holder:add_ref() end
        end
    end)
    if not holder then return false end
    local ok, err = pcall(function()
        local n = tonumber(motion:call("getDynamicMotionBankCount"))
        if not n then error("getDynamicMotionBankCount returned nil") end
        local newBank, idx = nil, n
        for i = 0, n - 1 do
            local b = motion:call("getDynamicMotionBank", i)
            if b and b:call("get_BankID") == bank then newBank, idx = b, i break end
        end
        if not newBank then
            newBank = sdk.create_instance("via.motion.DynamicMotionBank")
            if not newBank then newBank = sdk.create_instance("via.motion.DynamicMotionBank", true) end
            if not newBank then error("DynamicMotionBank allocation returned nil") end
            newBank:add_ref()
            motion:call("setDynamicMotionBankCount", n + 1)
        end
        newBank:call("set_MotionList", holder)
        newBank:call("set_OverwriteBankID", true)
        newBank:call("set_BankID", bank)
        motion:call("setDynamicMotionBank", idx, newBank)
        TL.banks[bank] = newBank
    end)
    if not ok then
        if TL.mount_error ~= tostring(err) then
            TL.mount_error = tostring(err)
            _st_log("tool bank mount failed: " .. tostring(err))
        end
        return false
    end
    TL.holders[bank], TL.mounted[bank] = holder, path
    TL.resources[bank] = resource
    _st_log("tool bank " .. bank .. " mounted")
    return true
end
local function _tl_clips(bank, wanted)
    if TL.clips[bank] then return TL.clips[bank] end
    local motion = _st_motion()
    if not motion then return nil end
    local ok, map, reason = pcall(TL.api.read_clips, motion, bank, wanted)
    if not ok then reason, map = tostring(map), nil end
    if not map then
        local message = "tool bank " .. bank .. " lookup: " .. tostring(reason)
        if TL.lookup_errors[bank] ~= message then
            TL.lookup_errors[bank] = message
            _st_log(message)
        end
        return nil
    end
    TL.clips[bank] = map
    return map
end
local function _tl_resolve(key)
    local motion = _st_motion()
    if not motion then return nil end
    if _addr(motion) ~= TL.motion_addr then
        TL.res, TL.clips, TL.rtry = {}, {}, {}
    end
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
            local map = _tl_clips(c.bank, row.names)
            if map then
                readable = readable + 1
                local ids = { start = map[row.names.start],
                              loop = row.names.loop and map[row.names.loop] or nil,
                              finish = row.names.finish and map[row.names.finish] or nil }
                if ids.start and (not row.names.finish or ids.finish)
                        and (not row.names.loop or ids.loop) then
                    TL.res[key] = { bank = c.bank, ids = ids }
                    TL.rtry[key] = nil
                    _st_log(string.format("tool %s resolved: bank %d %s/%s/%s",
                        key, c.bank, tostring(ids.start), tostring(ids.loop or "one-shot"),
                        tostring(ids.finish or "self-finish")))
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
    elseif now - (rt.first or now) > 8.0 and not rt.warned then
        rt.warned = true
        _st_log("tool " .. key .. " still awaiting motion data; retry remains enabled")
    end
    return nil
end
function TL.human()
    local ch=_player()
    local human
    pcall(function() human=ch and ch:call("get_Human") end)
    if not human then
        pcall(function()
            local go=_char_go(ch)
            human=go and go:call("getComponent(System.Type)",sdk.typeof("app.Human"))
        end)
    end
    return human
end
local function _tl_held_key()
    local raw, key
    local ok, err=pcall(function()
        local human=TL.human()
        local holder=human and human:call("get_GimmickHolder")
        if holder then raw=TL.api.held_name(holder,TL.eqid) end
        key=TL.api.key(raw,TOOLS)
    end)
    if not ok and TL.held_error~=tostring(err) then
        TL.held_error=tostring(err)
        _st_log("tool holder lookup failed: "..TL.held_error)
    end
    if raw~=TL.raw then
        TL.raw=raw
        _st_log("tool holding: "..tostring(raw).." -> "..tostring(key))
    end
    return key
end
function TL.near(row, now)
    if not row.near_key and not row.near_water then return true end
    if TL.near_at and now - TL.near_at < 0.5 then return TL.near_ok == true end
    TL.near_at = now
    local ok = false
    if row.near_water then
        pcall(function()
            local ch = _player()
            local det = ch and ch:call("get_WaterSurfaceDetector")
            if not det then det = ch and ch:get_field("<WaterSurfaceDetector>k__BackingField") end
            if det and det:call("get_IsDetected") == true then
                local depth = tonumber(det:call("get_WaterDepth")) or 0
                ok = depth >= 0 and depth <= 1.2
            end
            if ok or not det then return end
            local tf = ch:call("get_Transform")
            local p, fwd = tf:call("get_UniversalPosition"), tf:call("get_AxisZ")
            local probe = ValueType.new(sdk.find_type_definition("via.vec3"))
            probe.x, probe.y, probe.z = p.x + fwd.x * 1.0, p.y + 0.9, p.z + fwd.z * 1.0
            local v = det:call("calcSurfacePositionForEffect", probe)
            local has = v and (v:get_field("_HasValue") or v:get_field("HasValue"))
            if has == false or v == nil then return end
            local val = v:get_field("_Value") or v:get_field("Value")
            local y = val and tonumber(val.y)
            if y and y == y and y >= p.y - 1.0 and y <= p.y + 1.3 then ok = true end
        end)
    end
    if ok or not row.near_key then TL.near_ok = ok; return ok end
    pcall(function()
        local pgo = _char_go(_player())
        local pp = pgo and _pos(pgo)
        if not pp then return end
        local r2 = (tonumber(row.near_m) or 4.0) ^ 2
        for _, e in ipairs(sc.list) do
            local k, p = e.nkey, e._p
            if k and p and k:sub(1, #row.near_key) == row.near_key then
                local dx, dy, dz = p.x - pp.x, p.y - pp.y, p.z - pp.z
                if dx * dx + dy * dy + dz * dz <= r2 then ok = true; return end
            end
        end
    end)
    TL.near_ok = ok
    return ok
end
local function _tl_stop(reason)
    local act = TL.act
    TL.act = nil
    TL.edge_at = nil
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear) == "function" then IP.clear("interactables_tool") end
    end)
    if not act then return end
    pcall(function()
        local ch = _player()
        local human = TL.human()
        local fsm = _human_fsm(human)
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
    local fsm = nil
    pcall(function()
        local ch = _player()
        fsm = _human_fsm(TL.human())
    end)
    if fsm then pcall(function() fsm:set_Enabled(true) end) end
    local ok = pcall(function()
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if not layer then error("no layer 0") end
        layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
            act.res.bank, act.res.ids[phase], 0.0, 6.0, 1, 1)
    end)
    if ok then
        act.phase, act.started = phase, os.clock()
        if fsm then pcall(function() fsm:set_Enabled(false) end) end
    end
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
local function _tl_frame()
    if M.native_chores ~= true then
        if TL.act then _tl_stop("disabled") end
        pcall(function()
            local IP = _G.IrisPrompt
            if IP and type(IP.clear) == "function" then IP.clear("interactables_tool") end
        end)
        TL.key = nil
        return
    end
    local now = os.clock()
    if not TL.act and not TL.key and now - (tonumber(TL.at) or 0) < 0.25 then return end
    if TL.edge_at and now - TL.edge_at > 0.65 then TL.edge_at = nil end
    local down = _stop_down()
    local edge = down and not TL.prev
    TL.prev = down
    if edge then TL.edge_at = now end
    local act = TL.act
    if act then
        if _loading() or _menu_open() then return _tl_stop(_loading() and "loading" or "menu") end
        local row=TOOLS[act.key]
        if row and row.require_held and now>=(act.held_check_at or 0) then
            act.held_check_at=now+0.25
            if _tl_held_key()~=act.key then return _tl_stop("tool no longer held") end
        end
        if _binding_down(M.stop_bind or "backspace") then return _tl_stop("stop binding") end
        if _tl_move_mag() > 0.3 or _binding_down("space, cross") then
            return _tl_stop("movement")
        end
        local action_edge = edge and now >= (act.accept_input_at or 0)
        if action_edge and act.phase ~= "finish" then
            if act.res.ids.finish then
                if not _tl_play("finish") then return _tl_stop("finish clip failed") end
            else
                return _tl_stop("one-shot cancelled")
            end
        elseif action_edge then
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
                    if act.res.ids.loop then
                        if not _tl_play("loop") then _tl_stop("loop clip failed") end
                    elseif act.res.ids.finish and not _tl_play("finish") then
                        _tl_stop("finish clip failed")
                    elseif not act.res.ids.finish then
                        _tl_stop("one-shot finished")
                    end
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
    if not _tl_resolve(TL.key) or not TL.near(row, now) then
        pcall(function()
            if type(IP.clear) == "function" then IP.clear("interactables_tool") end
        end)
        return
    end
    local pgo = _char_go(_player())
    pcall(function()
        IP.set("interactables_tool", tostring(row.verb), 1, 0.4, pgo and _pos(pgo), pgo)
    end)
    local use_edge = edge or (TL.edge_at and now - TL.edge_at <= 0.65)
    if use_edge then
        local w = nil
        pcall(function() w = IP.winner() end)
        if w ~= "interactables_tool" then return end
        local res = _tl_resolve(TL.key)
        if not res then return end
        local ok = pcall(function()
            local ch = _player()
            local human = TL.human()
            local fsm = _human_fsm(human)
            if not fsm then error("no Human.Fsm") end
        end)
        if not ok then return end
        TL.edge_at = nil
        TL.act = { key = TL.key, res = res, accept_input_at = now + 0.8 }
        if not _tl_play("start") then return _tl_stop("start clip failed") end
        _st_log("tool drive started: " .. TL.key .. " (" .. tostring(row.verb) .. ")")
    end
end
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
local CARRY = { id = nil, conjured = false, prev_kill = false, at = 0 }
function ST.holding_pitchfork()
    return CARRY.have==true and CARRY.id==41
end
function ST.hay_gate_tick()
    local held=ST.holding_pitchfork()
    if ST.hay_held==held then return end
    ST.hay_held=held
    for _,r in pairs(unlocks) do
        if r.prop_key=='gm50_097' then
            pcall(function() r.point:set_field('CharacterType',r.old+(held and 1 or 0)) end)
        end
    end
end
CARRY.keep_ids = { [41]=true, [42]=true, [43]=true, [45]=true,
    [46]=true, [47]=true, [50]=true, [51]=true }
CARRY.work_groups = { [42]="trades", [51]="outdoors", [47]="household" }
CARRY.gen_at = {}
function CARRY.ensure_equipment(pick, go, label)
    if not (pick and go) then return false end
    if pick:call("get_HasEquip") == true then return false end
    if pick:get_field("IsJackNow") == true then return false end
    if go:call("get_DrawSelf") ~= true then return false end
    local addr = _addr(pick)
    local now = os.clock()
    if now - (CARRY.gen_at[addr] or -100) < 10 then return false end
    CARRY.gen_at[addr] = now
    local ok, err = pcall(function() pick:call("generateEquipment") end)
    _st_log(string.format("tool equip: generateEquipment requested for %s (%s)", tostring(label), ok and "ok" or tostring(err)))
    return ok
end
CARRY.safe_actions = { NormalLocomotion=true, Wait=true, Idle=true, Walk=true, Run=true, Dash=true }
CARRY.safe_action_families = { "Locomotion", "Dodge", "Walk", "Run", "Turn", "Idle", "Wait", "Dash", "Step", "Strafe", "Sprint" }
CARRY.unsafe_action_families = { "Jack", "Damage", "Blow", "Down", "Dead", "Die", "Climb", "Grab", "Catch", "Ride", "Swim", "Talk" }
function CARRY.action_is_safe(action)
    if CARRY.safe_actions[action] then return true end
    if type(action) ~= "string" then return false end
    local cached = CARRY.safe_cache and CARRY.safe_cache[action]
    if cached ~= nil then return cached end
    local safe = false
    for _, family in ipairs(CARRY.unsafe_action_families) do
        if action:find(family, 1, true) then safe = false goto done end
    end
    for _, family in ipairs(CARRY.safe_action_families) do
        if action:find(family, 1, true) then safe = true break end
    end
    ::done::
    CARRY.safe_cache = CARRY.safe_cache or {}
    CARRY.safe_cache[action] = safe
    return safe
end
CARRY.visibility = require("II.ToolVisibility32")
CARRY.visibility.install(function()
    local human=TL.human()
    return human and human:call("get_GimmickHolder")
end,CARRY.keep_ids,function() return TL.act and TL.act.phase or "idle" end)
function CARRY.keep_native(holder)
    if M.master == false or M.keep_tools == false or M.native_chores ~= true
            or CARRY.allow_drop or ST.pending or ST.conjured then return false end
    local ch = holder and holder:get_field("Chara")
    if not ch or _addr(ch) ~= _addr(_player()) then return false end
    if _drop_down() or _loading() or _menu_open() then return false end
    if ch:call("get_IsDrawedWeapon") == true then return false end
    local pickable = holder:get_field("PickableObject")
    local id = pickable and tonumber(pickable:get_field("EquipID"))
    if not id then
        pcall(function()
            local ctx = holder:get_field("Context")
            id = ctx and tonumber(ctx:get_field("EquipItemID"))
        end)
    end
    if not CARRY.keep_ids[id] then return false end
    local action = _player_action_name(ch, 0)
    if not TL.act and action ~= nil and not CARRY.action_is_safe(action) then
        local why = tostring(id) .. ":" .. tostring(action)
        if CARRY.rejected_action ~= why then
            CARRY.rejected_action = why
            _st_log("carry: native return allowed outside known locomotion (" .. why .. ")")
        end
        return false
    end
    return holder:get_field("EquipItem") ~= nil or pickable ~= nil
end
function CARRY.present_native()
    if ST.session or ST.pending or (TL.act and TL.act.phase == "finish") then return end
    local human = TL.human()
    local holder = human and human:call("get_GimmickHolder")
    if not holder or not CARRY.keep_native(holder) then return end
    local ch = holder:get_field("Chara")
    if ch:call("get_IsJacked") ~= false
            or not CARRY.action_is_safe(_player_action_name(ch, 0)) then return end
    if holder:get_field("IsDrawEquipItem") ~= true then return end
    local ctx = holder:get_field("Context")
    local carry_id = ctx and tonumber(ctx:get_field("EquipItemID"))
    if carry_id == 42 then
        local mesh = holder:get_field("EquipItemMesh")
        if mesh and mesh:call("get_ForceAlphaTest") == true then
            holder:call("setEnableEquipItemForceAlphaTest(System.Boolean)", false)
        end
    end
    local equip = holder:get_field("EquipItem")
    if carry_id == 42 and _managed(equip) then
        holder:call("updateEquipItemHolding()")
        if not CARRY.hold_assist_logged then
            CARRY.hold_assist_logged = true
            _st_log("carry: beam hold assist active (updateEquipItemHolding each update)")
        end
    end
    local go = equip and equip:call("get_GameObject")
    if not _managed(go) then
        local pick = holder:get_field("PickableObject")
        go = pick and pick:get_field("EquipObj")
    end
    if not _managed(go) or go:call("get_DrawSelf") ~= false then return end
    go:call("set_DrawSelf", true)
    if not CARRY.visible_logged then
        CARRY.visible_logged = true
        _st_log("tool visibility: restored DrawSelf on current native equipment")
    end
end
pcall(function()
    local method = ST.compat32.method("app.GimmickHolder", "returnEquipItemOnNotInteracting",
        { "System.Boolean" })
    sdk.hook(method, function(args)
        local ok, keep = pcall(CARRY.keep_native, sdk.to_managed_object(args[2]))
        if ok and keep then
            CARRY.prevented = (CARRY.prevented or 0) + 1
            if CARRY.prevented == 1 then _st_log("carry: native locomotion auto-return suppressed") end
            return sdk.PreHookResult.SKIP_ORIGINAL
        elseif not ok and CARRY.guard_error ~= tostring(keep) then
            CARRY.guard_error = tostring(keep)
            _st_log("carry guard read failed; native return allowed: " .. tostring(keep))
        end
    end, function(retval) return retval end)
end)
CARRY.chain = { broken = 0, hook = "withdrawn" }
CARRY.chain.calls = { cancel = 0, continue_ = 0, is_continue = 0, set_flag = 0 }
CARRY.chain_ids = { [42] = true, [51] = true }
function CARRY.chain_player_carrying(ch, name)
    if ST.session or ST.pending then return false end
    local player = _player()
    if not (ch and player) or _addr(ch) ~= _addr(player) then return false end
    local human = ch:call("get_Human")
    local holder = human and human:call("get_GimmickHolder")
    if not holder or CARRY.keep_native(holder) ~= true then return false end
    local ctx = holder:get_field("Context")
    local id = ctx and tonumber(ctx:get_field("EquipItemID")) or 0
    if not CARRY.chain_ids[id] or not _managed(holder:get_field("EquipItem")) then return false end
    if name == "continueInteract" and ch:call("get_IsJacked") ~= false then return false end
    return true
end
for _, name in ipairs({ "cancelContinueInteract", "continueInteract" }) do
    local ok_hook, hook_err = pcall(function()
        local method = ST.compat32.method("app.InteractManager", name, { "app.Character" })
        sdk.hook(method, function(args)
            if M.master == false or M.keep_tools == false or M.native_chores ~= true then return end
            local ok, mine = pcall(function()
                return CARRY.chain_player_carrying(sdk.to_managed_object(args[3]), name)
            end)
            if ok and mine then
                local key = name == "continueInteract" and "continue_" or "cancel"
                CARRY.chain.calls[key] = CARRY.chain.calls[key] + 1
                if CARRY.chain.calls[key] == 1 then
                    _st_log("carry: chain " .. name .. " suppressed for the carried tool")
                end
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end, function(retval) return retval end)
    end)
    if not ok_hook then _st_log("carry: chain hook " .. name .. " NOT installed: " .. tostring(hook_err)) end
end
for _, name in ipairs({ "forceReturnEquipItem", "returnEquipItem" }) do
    local ok_hook, hook_err = pcall(function()
        local method = ST.compat32.method("app.GimmickHolder", name, { "System.Boolean" })
        sdk.hook(method, function(args)
            if M.master == false or M.keep_tools == false or M.native_chores ~= true then return end
            if (sdk.to_int64(args[3]) & 0xFF) == 0 then return end
            local ok, mine = pcall(function()
                local holder = sdk.to_managed_object(args[2])
                local ch = holder and holder:get_field("Chara")
                return CARRY.chain_player_carrying(ch, name)
            end)
            if ok and mine then
                CARRY.chain.calls[name] = (CARRY.chain.calls[name] or 0) + 1
                if CARRY.chain.calls[name] == 1 then
                    _st_log("carry: holder " .. name .. "(true) suppressed for the carried tool")
                end
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end, function(retval) return retval end)
    end)
    if not ok_hook then _st_log("carry: holder hook " .. name .. " NOT installed: " .. tostring(hook_err)) end
end
function ST.bed_exit_pump()
    if ST.bed_want_end and os.clock() - (tonumber(ST.bed_want_at) or 0) < 2.0 then
        ST.bed_want_end = false
        local ok, err = pcall(function()
            local mgr = sdk.get_managed_singleton("app.InteractManager")
            local ch = _player()
            if mgr and ch and mgr:call("isInteracting(app.Character)", ch) == true then
                mgr:call("cancelInteract(app.Character)", ch)
            end
        end)
        _st_log("bed get-up: cancelInteract issued from the sheet update (" .. tostring(ok and "ok" or err) .. ")")
    end
end
ST.bed_exit_ok, ST.bed_exit_err = pcall(function()
    local method = ST.compat32.method("app.Gm51_115_sheet", "updateInteract", {})
    sdk.hook(method, nil, function(retval) ST.bed_exit_pump(); return retval end)
end)
_st_log("bed get-up: sheet updateInteract hook " .. (ST.bed_exit_ok and "installed" or ("NOT installed: " .. tostring(ST.bed_exit_err))))
pcall(function()
    local method = ST.compat32.method("app.InteractManager", "updateActiveInteracts", {})
    sdk.hook(method, nil, function(retval)
        if false then
            BR.want_end_interact = false
            local ok, err = pcall(function()
                local mgr = sdk.get_managed_singleton("app.InteractManager")
                local ch = _player()
                if mgr and ch and mgr:call("isInteracting(app.Character)", ch) == true then
                    mgr:call("cancelInteract(app.Character)", ch)
                end
            end)
            _st_log("bed get-up: cancelInteract issued from the manager update (" .. tostring(ok and "ok" or err) .. ")")
        end
        return retval
    end)
    ST.bed_exit_hook = "installed"
end)
local CARRY_OWNED_IDS = {}
local CARRY_PFBS = {}
local CARRY_PREFETCHED = false
local function _carry_owned_prefab(id)
    return nil
end
local function _carry_owned_discard()
    local go = CARRY.owned_go or (CARRY.owned_job and CARRY.owned_job.go)
    if _valid(go) then
        pcall(function() go:call("set_DrawSelf", false) end)
        pcall(function() go:call("destroy", go) end)
    end
    CARRY.owned_go, CARRY.owned_job, CARRY.owned_id = nil, nil, nil
    CARRY.owned_equip = false
    CARRY.presented_logged = false
end
local function _carry_owned_prepare(id)
    id = tonumber(id)
    if not CARRY_OWNED_IDS[id] then return end
    if CARRY.owned_id == id and (CARRY.owned_go or CARRY.owned_job) then return end
    if CARRY.owned_go or CARRY.owned_job then _carry_owned_discard() end
    local pfb = _carry_owned_prefab(id)
    if not pfb then return end
    CARRY.owned_id = id
    CARRY.owned_job = { id = id, pfb = pfb, frames = 0 }
end
local function _carry_owned_pump()
end
local function _carry_owned_attach(holder)
    if not (holder and _valid(CARRY.owned_go)) then
        return false, "owned equipment instance was not ready"
    end
    local accepted = false
    local ok, err = pcall(function()
        local ctx = holder:get_field("Context")
        if ctx and ctx:call("get_HasEquipItem") then ctx:call("removeEquipItem") end
        holder:set_field("InteractObject", nil)
        holder:set_field("PickableObject", nil)
        holder:call("setEquipItem(via.GameObject)", CARRY.owned_go)
        accepted = _managed(holder:get_field("EquipItem"))
        if not accepted then error("GimmickHolder rejected owned equipment") end
        CARRY.equip_go = CARRY.owned_go
        CARRY.owned_equip = true
        CARRY.retained = "equipment"
        CARRY.loan_paused = false
        if CARRY.upper_motion ~= nil then
            holder:call("changeEquipItemUpperMotionID(System.UInt32)", CARRY.upper_motion)
        end
        holder:call("setDrawEquipItem(System.Boolean)", true)
        CARRY.owned_go:call("set_DrawSelf", true)
        holder:call("updateEquipItemHolding()")
    end)
    return ok and accepted, ok and nil or tostring(err)
end
local function _carry_owned_present(holder)
    if not (holder and _valid(CARRY.owned_go)) then return false end
    local accepted = false
    local ok = pcall(function()
        holder:call("setEquipItem(via.GameObject)", CARRY.owned_go)
        local eq = holder:get_field("EquipItem")
        accepted = _valid(eq)
        if not accepted then return end
        CARRY.equip_go = CARRY.owned_go
        CARRY.owned_equip = true
        if CARRY.upper_motion ~= nil then
            holder:call("changeEquipItemUpperMotionID(System.UInt32)", CARRY.upper_motion)
        end
        holder:call("setDrawEquipItem(System.Boolean)", true)
        CARRY.owned_go:call("set_DrawSelf", true)
        holder:call("updateEquipItemHolding()")
    end)
    if ok and accepted and not CARRY.presented_logged then
        CARRY.presented_logged = true
        _st_log("carry: supplied missing pitchfork through GimmickHolder")
    end
    return ok and accepted
end
re.on_application_entry("UpdateBehavior", function()
    if M.master == false then return end
    if not CARRY_PREFETCHED then
        CARRY_PREFETCHED = true
        for id in pairs(CARRY_OWNED_IDS) do pcall(function() _carry_owned_prefab(id) end) end
    end
    pcall(_carry_owned_pump)
end)
local function _carry_source_visible(visible)
    local wrote = false
    pcall(function()
        local go = CARRY.source_go
        local mesh = go and go:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
        if mesh then
            mesh:call("set_Enabled", visible == true)
            wrote = true
        end
        if _managed(CARRY.source_obj) then
            pcall(function() CARRY.source_obj:set_field("IsJackNow", visible ~= true) end)
        end
    end)
    if wrote then CARRY.source_hidden = visible ~= true end
    return wrote
end
local function _carry_rebuild_return_context(holder)
    if not (holder and _managed(CARRY.source_obj) and _valid(CARRY.source_go)) then
        return false, "source gimmick expired"
    end
    local ctx = nil
    pcall(function() ctx = holder:get_field("Context") end)
    if not ctx or type(CARRY.context) ~= "table" then
        return false, "borrow context was not captured"
    end
    local linked = pcall(function()
        ctx:call("setEquipItem(app.GmInteractPickableBase)", CARRY.source_obj)
        if CARRY.motion_id ~= nil then
            ctx:call("setEquipItemMotionID(System.UInt32)", CARRY.motion_id)
        end
        holder:set_field("InteractObject", CARRY.source_obj)
        holder:set_field("PickableObject", CARRY.source_obj)
    end)
    if not linked then return false, "source could not be relinked" end
    return true
end
local function _carry_holder_is_empty(holder)
    if not holder then return true end
    local empty = false
    local ok = pcall(function()
        local has = holder:call("get_HasEquipItem") == true
        local pickable = holder:get_field("PickableObject")
        empty = not has and pickable == nil
    end)
    return ok and empty
end
local function _carry_detach_retained(holder)
    if CARRY.retained ~= "equipment" or not holder then return false end
    if CARRY.owned_equip then
        pcall(function() holder:call("setDrawEquipItem(System.Boolean)", false) end)
        pcall(function() holder:set_field("IsPreparingEquipItem", false) end)
        pcall(function() holder:set_field("IsPreparedEquipItem", false) end)
        pcall(function() holder:set_field("ConstraintEquipItem", nil) end)
        pcall(function() holder:set_field("EquipItem", nil) end)
        pcall(function() holder:set_field("InteractObject", nil) end)
        pcall(function() holder:set_field("PickableObject", nil) end)
        pcall(function()
            local ctx = holder:get_field("Context")
            if ctx and ctx:call("get_HasEquipItem") then ctx:call("removeEquipItem") end
        end)
        pcall(function() holder:call("changeEquipItemUpperMotionID(System.UInt32)", 0) end)
        pcall(function() holder:call("updateEquipItemHolding()") end)
        _carry_owned_discard()
        CARRY.detached_cleaned = true
        return _carry_holder_is_empty(holder)
    end
    if CARRY.loan_paused and _managed(CARRY.source_obj) and _valid(CARRY.source_go) then
        pcall(function() CARRY.source_obj:call("set_IsBorrowed(System.Boolean)", true) end)
    end
    local returned = false
    local ready, why = _carry_rebuild_return_context(holder)
    if ready then
        returned = pcall(function()
            holder:call("forceReturnEquipItem(System.Boolean)", false)
        end)
    elseif _managed(CARRY.source_obj) and _valid(CARRY.source_go)
            and _valid(CARRY.equip_go) then
        returned = pcall(function()
            CARRY.source_obj:call("returnEquipItem(via.GameObject)", CARRY.equip_go)
        end)
    end
    pcall(function() holder:call("notifyEndInteract") end)
    pcall(function()
        local ctx = holder:get_field("Context")
        if ctx and ctx:call("get_HasEquipItem") then ctx:call("removeEquipItem") end
    end)
    CARRY.detached_cleaned = true
    local empty = _carry_holder_is_empty(holder)
    return returned and empty
end
local function _carry_release(quiet)
    if CARRY.retained == "equipment" and not CARRY.detached_cleaned then
        pcall(function()
            local human = _player() and _player():call("get_Human")
            local holder = human and human:call("get_GimmickHolder")
            if holder then
                _carry_detach_retained(holder)
            end
        end)
    end
    if CARRY.source_hidden then _carry_source_visible(true) end
    if CARRY.owned_go or CARRY.owned_job then _carry_owned_discard() end
    CARRY.source_go, CARRY.source_obj, CARRY.source_constraint = nil, nil, nil
    CARRY.equip_go, CARRY.context, CARRY.upper_motion, CARRY.motion_id = nil, nil, nil, nil
    CARRY.id, CARRY.conjured, CARRY.native, CARRY.have, CARRY.lost_at = nil, false, false, false, nil
    CARRY.retained, CARRY.source_hidden, CARRY.detached_cleaned = false, false, false
    CARRY.native_managed, CARRY.native_arm_until = false, nil
    CARRY.loan_paused = false
    CARRY.presented_logged = false
    TL.carry_key = nil
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear) == "function" then IP.clear("interactables_carry") end
    end)
end
local function _carry_maintain_loan()
    if not CARRY.retained or not _managed(CARRY.source_obj) then return end
    pcall(function()
        local human = _player() and _player():call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        if CARRY.retained ~= "equipment" then
            holder:set_field("InteractObject", CARRY.source_obj)
            holder:set_field("PickableObject", CARRY.source_obj)
        end
        pcall(function() holder:call("setDrawEquipItem(System.Boolean)", true) end)
        pcall(function() holder:call("updateEquipItemHolding()") end)
    end)
end
local function _carry_native_drop()
    local done = false
    pcall(function()
        local ch = _player()
        local oc = ch and ch:call("get_ObjectCarry")
        if oc and oc:call("isPickupCarrying") == true then
            oc:call("putObject")
            done = true
            return
        end
        local human = ch and ch:call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        local lent = holder:get_field("PickableObject")
        local eqit = holder:get_field("EquipItem")
        if not (lent or eqit) then return end
        if CARRY.retained == "equipment" then
            done = _carry_detach_retained(holder)
            if CARRY.source_hidden then _carry_source_visible(true) end
            return
        end
        pcall(function() holder:call("forceReturnEquipItem(System.Boolean)", false) end)
        pcall(function() holder:call("notifyEndInteract") end)
        pcall(function()
            local ctx = holder:get_field("Context")
            if ctx and ctx:call("get_HasEquipItem") then ctx:call("removeEquipItem") end
        end)
        done = _carry_holder_is_empty(holder)
        CARRY.detached_cleaned = true
        if CARRY.source_hidden then _carry_source_visible(true) end
    end)
    return done
end
local function _carry_tick()
    if M.keep_tools == false or M.native_chores ~= true then
        CARRY.allow_drop = true
        _carry_release(); return
    end
    if not CARRY.drop_until then CARRY.allow_drop = false end
    if ST.session or ST.pending or ST.conjured then
        CARRY.stand_down_until = os.clock() + 2.0
        if CARRY.have or CARRY.owned_go or CARRY.owned_job then _carry_release() end
        return
    end
    local now = os.clock()
    if now < (tonumber(CARRY.stand_down_until) or 0) then return end
    if not CARRY.have and now - (tonumber(CARRY.poll_at) or 0) < 0.10 then return end
    CARRY.poll_at = now
    local kill = _drop_down()
    local edge_kill = kill and not CARRY.prev_kill
    CARRY.prev_kill = kill
    local held, id, nm = false, 0, nil
    local unmanaged_native = false
    local source_go, source_obj, equip_go, source_constraint, upper_motion, motion_id = nil, nil, nil, nil, nil, nil
    local holder_ref = nil
    local saved_context = {}
    pcall(function()
        local ch = _player()
        local oc = ch and ch:call("get_ObjectCarry")
        if oc and oc:call("isPickupCarrying") == true then
            local armed = CARRY.native_managed == true
                or now <= (tonumber(CARRY.native_arm_until) or 0)
            if not armed then
                unmanaged_native = true
                return
            end
            CARRY.native_managed = true
            held, CARRY.native = true, true
            source_go = oc:get_field("Object")
            pcall(function() oc:call("set_IsContinue(System.Boolean)", true) end)
            return
        end
        local human = ch and ch:call("get_Human")
        local holder = human and human:call("get_GimmickHolder")
        if not holder then return end
        holder_ref = holder
        local ctx = holder:get_field("Context")
        local v = ctx and ctx:get_field("EquipItemID")
        id = tonumber(v) or 0
        if id == 0 and v ~= nil then
            pcall(function() id = tonumber(v:get_field("value__")) or 0 end)
        end
        if ctx then
            for _, field in ipairs({ "EquipItemID", "EquipItemMotionID",
                    "BollowedGimmickID", "BollowedGimmickPosition" }) do
                pcall(function() saved_context[field] = ctx:get_field(field) end)
            end
            pcall(function() motion_id = tonumber(ctx:get_field("EquipItemMotionID")) end)
        end
        pcall(function() upper_motion = holder:call("get_UpperMotionID") end)
        if id ~= 0 then
            held = true
            pcall(function()
                local eq = holder:get_field("EquipItem")
                equip_go = _valid(eq) and eq:call("get_GameObject") or nil
                nm = equip_go and tostring(equip_go:call("get_Name"))
            end)
        end
        if CARRY.retained == "equipment" then
            local eq = holder:get_field("EquipItem")
            local eg = _valid(eq) and eq:call("get_GameObject") or nil
            if eg then
                held, id, equip_go = true, tonumber(CARRY.id) or id, eg
                nm = tostring(eg:call("get_Name"))
            end
        end
        local lst = holder:get_field("HoldObjects")
        if lst and (tonumber(lst:call("get_Count")) or 0) > 0 then
            held = true
            pcall(function()
                local info = lst:call("get_Item", 0)
                local gib = info and info:get_field("Object")
                local g = _valid(gib) and gib:call("get_GameObject") or nil
                if g then
                    source_obj, source_go = gib, g
                    source_constraint = info:get_field("ConstraintType")
                    nm = tostring(g:call("get_Name"))
                end
            end)
        end
        local gib = holder:get_field("PickableObject")
        if _valid(gib) then
            held = true
            pcall(function()
                local g = gib:call("get_GameObject")
                if g then
                    source_obj, source_go = gib, g
                    nm = tostring(g:call("get_Name"))
                end
            end)
        end
        if _managed(source_obj) then
            pcall(function()
                local candidate = source_obj:get_field("EquipObj")
                if _valid(candidate) then
                    equip_go = candidate
                    if not nm then nm = tostring(candidate:call("get_Name")) end
                end
                local eidv = source_obj:get_field("EquipID")
                local eid = tonumber(eidv)
                if not eid and eidv ~= nil then
                    pcall(function() eid = tonumber(eidv:get_field("value__")) end)
                end
                if eid and eid ~= 0 then id = eid end
                local mid = tonumber(source_obj:call("get_EquipItemMotionID"))
                    or tonumber(source_obj:get_field("<EquipItemMotionID>k__BackingField"))
                if mid then motion_id = mid end
            end)
        end
        if held and nm then
            local best = CARRY.name_ids and CARRY.name_ids[nm]
            if best == nil then
                local low = nm:lower()
                local bl = 0
                best = 0
                if not TL.eqid_digits then
                    TL.eqid_digits = {}
                    for k, v2 in pairs(TL.eqid) do TL.eqid_digits[k] = (v2:gsub("^i?t", "")) end
                end
                for k, digits in pairs(TL.eqid_digits) do
                    if #digits > bl and low:find(digits, 1, true) then best, bl = k, #digits end
                end
                CARRY.name_ids = CARRY.name_ids or {}
                CARRY.name_ids[nm] = best
            end
            id = best
        end
    end)
    if unmanaged_native then
        if CARRY.have then _carry_release(true) end
        CARRY.prev_kill = _drop_down()
        return
    end
    if edge_kill then
        CARRY.allow_drop = true
        pcall(function()
            local ch = _player()
            local human = ch and ch:call("get_Human")
            if human and human:call("get_IsContinueMultipleInteract") == true then
                local mgr = sdk.get_managed_singleton("app.InteractManager")
                if mgr then
                    mgr:call("cancelContinueInteract", ch)
                    _st_log("carry: chain cancelled natively on Drop")
                end
            end
        end)
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
    if held then
        if CARRY.conjured then _carry_release(true) end
        if id ~= 0 then
            CARRY.id = id
            CARRY.visibility.observe_carry(id)
            _carry_owned_prepare(id)
            local eraw = TL.eqid[id]
            local twin = eraw and eraw:lower():match("^i?t(%d+_%d+.*)$")
            local ekey = twin and _norm("gm" .. twin) or nil
            TL.carry_key = ekey and TOOLS[ekey] and ekey or nil
            if id == 41 and not _valid(equip_go) and holder_ref
                    and _valid(CARRY.owned_go) and _carry_owned_present(holder_ref) then
                equip_go = CARRY.owned_go
                nm = tostring(equip_go:call("get_Name"))
            end
        end
        CARRY.nm = nm or CARRY.nm
        CARRY.source_go = source_go or CARRY.source_go
        CARRY.source_obj = source_obj or CARRY.source_obj
        CARRY.equip_go = equip_go or CARRY.equip_go
        if source_constraint ~= nil then CARRY.source_constraint = source_constraint end
        if next(saved_context) then CARRY.context = saved_context end
        CARRY.upper_motion = upper_motion or CARRY.upper_motion
        CARRY.motion_id = motion_id or CARRY.motion_id
        if _G.__II_caplog ~= tostring(id) then
            _G.__II_caplog = tostring(id)
            pcall(function() _st_log(string.format(
                "[II-DIAG] capture id=%s: equip_go=%s source_obj=%s constraint=%s nm=%s",
                tostring(id), tostring(_valid(equip_go)), tostring(_managed(source_obj)),
                tostring(source_constraint ~= nil), tostring(nm))) end)
        end
        if not CARRY.have then CARRY.adopt_at = now end
        CARRY.conjured, CARRY.lost_at, CARRY.lost_run = false, nil, nil
        CARRY.have = true
        if CARRY.retained ~= "equipment" then CARRY.reborrowed = false end
        _carry_maintain_loan()
        return
    end
    if CARRY.have then _carry_release(true) end
end
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
local MC
local function _mc_toast_draw()
    local sw, sh = 1920, 1080
    pcall(function()
        local sz = imgui.get_display_size()
        if sz then
            if sz.x and sz.x > 0 then sw = sz.x end
            if sz.y and sz.y > 0 then sh = sz.y end
        end
    end)
    if MC and MC.open and not MC.native then
        pcall(function()
            local rows = MC.labels or { "Cancel" }
            local w, row_h = 560, 34
            local h = 80 + #rows * row_h
            local x, y = (sw - w) * 0.5, (sh - h) * 0.46
            draw.filled_rect(x, y, w, h, 0xE0100C0A)
            draw.outline_rect(x, y, w, h, 0xFF4AA2E8)
            draw.text(MC.prompt or "Cook what?", x + 20, y + 16, 0xFF4AA2E8)
            for i, label in ipairs(rows) do
                local yy = y + 56 + (i - 1) * row_h
                if i == (MC.sel or 1) then
                    draw.filled_rect(x + 14, yy - 4, w - 28, row_h - 2, 0x50FFFFFF)
                end
                draw.text((i == (MC.sel or 1) and "> " or "  ") .. label,
                    x + 24, yy, i == (MC.sel or 1) and 0xFFE8E8E8 or 0xFF9A9A9A)
            end
        end)
    end
    if not TOAST.txt then return end
    local age = os.clock() - TOAST.at
    if age > 5.0 then TOAST.txt = nil return end
    local a = 1.0
    if age < 0.25 then a = age / 0.25
    elseif age > 4.0 then a = 1.0 - (age - 4.0) end
    local alpha = math.floor(255 * math.max(0, math.min(1, a)))
    pcall(function()
        draw.text(TOAST.txt, 84, sh - 176, alpha * 0x1000000 + 0xB0D8EA)
    end)
end
local MC_POTS = {
    gm80_256 = true, gm51_381 = true, gm51_382 = true, gm51_383 = true,
}
local MC_NATIVE_CAMP = {
    gm80_060 = true, gm80_061 = true, gm80_062 = true,
    gm80_063 = true, gm80_064 = true,
}
MC = { at = 0, near = nil, prev = false, open = false, baseline = nil,
             opened_at = 0, closed_at = 0, opts = nil, more = false, page = 1,
             stir_until = nil, sel = 1, labels = nil, prev_menu = {} }
local function _mc_party()
    local out = {}
    local ch = _player()
    if ch then out[#out + 1] = ch end
    local seen = { [_addr(ch) or 0] = true }
    for _, getter in ipairs({ "get_PartyPawnList", "get_PawnCharacterList" }) do
        local lst
        pcall(function()
            local pm = sdk.get_managed_singleton("app.PawnManager")
            lst = pm and pm:call(getter)
        end)
        local n = 0
        pcall(function() n = tonumber(lst:call("get_Count")) or 0 end)
        for i = 0, n - 1 do
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
    local labels = {}
    for _, label in ipairs({ l1, l2, l3, l4 }) do
        if label and label ~= "" then labels[#labels + 1] = label end
    end
    if #labels == 0 then labels[1] = "Cancel" end
    MC.want = { prompt = prompt, labels = labels, at = os.clock() }
    MC.result, MC.saw_dialog, MC.dialog_closed = nil, false, false
end
local function _mc_close()
    if MC.native and MC.gm and not MC.dialog_closed then
        pcall(function() MC.gm:call("requestHideDialog") end)
    end
    MC.native, MC.gm, MC.want, MC.result = nil, nil, nil, nil
    MC.open = false
    MC.labels, MC.prompt, MC.prev_menu = nil, nil, {}
    MC.closed_at = os.clock()
end
local function _mc_menu(page)
    local avail = _mc_avail()
    local labels
    MC.opts, labels, MC.page = ST.compat32.cook_page(avail, page)
    _mc_show(#avail == 0 and "Nothing to cook - the pot wants meat." or "Cook what?",
        table.unpack(labels))
end
function MC.poll_native()
    if not MC.native or not MC.open or MC.result ~= nil then return end
    if MC.gm:call("IsDispDialogGui") == true then MC.saw_dialog = true end
    if os.clock() - MC.opened_at < 0.35 then return end
    local choice = ST.compat32.dialog_choice(MC.gm)
    if choice ~= nil and MC.saw_dialog then
        MC.result = choice
        MC.gm:call("requestHideDialog")
        MC.dialog_closed = true
    elseif MC.saw_dialog and MC.gm:call("IsDispDialogGui") == false then
        MC.result = "cancel"
        MC.dialog_closed = true
    elseif not MC.saw_dialog and os.clock() - MC.opened_at > 5.0 then
        MC.result = "cancel"
        MC.gm:call("requestHideDialog")
        MC.dialog_closed = true
        _st_log("cook: native dialogue request did not become visible")
    end
end
local function _mc_stop_stir()
    if not MC.stir_until then return end
    MC.stir_until = nil
    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        do local f = _human_fsm(human); if f then f:set_Enabled(true) end end
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
function MC.clear_prompt()
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear) == "function" then IP.clear("interactables_cook") end
    end)
end
function MC.suppress_for_native_camp()
    MC.near, MC.near_key, MC.near_pos = nil, nil, nil
    MC.want = nil
    if MC.open then _mc_close() end
    if MC.stir_until then _mc_stop_stir() end
    MC.clear_prompt()
    MC.prev = _interact_down()
end
local function _mc_cook(entry)
    local ok = false
    pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        local before = tonumber(im:call("getHaveNum(System.Int32, app.Character)", entry.m.id, entry.holder))
        if not before or before < 1 then return end
        ST.compat32.method("app.HumanSpecialBuffManager", "startBuff",
            { "app.HumanSpecialBuffDefine.Camp", "System.Boolean" })
        ST.compat32.enum("app.HumanSpecialBuffDefine.Camp", ST.compat32.camp_names[entry.m.buff])
        local sb = ST.compat32.buff_manager(_player())
        if not ST.compat32.camp_state(sb) then return end
        im:call(
            "deleteItem(System.Int32, System.Int32, app.Character)",
            entry.m.id, 1, entry.holder)
        local after = tonumber(im:call("getHaveNum(System.Int32, app.Character)", entry.m.id, entry.holder))
        ok = after == before - 1
    end)
    if not ok then
        _mc_toast("Cooking stopped: ingredient removal could not be confirmed.")
        _st_log("cook: ingredient removal not confirmed; no buff requested")
        return
    end
    local party = _mc_party()
    local fed = 0
    for _, ch in ipairs(party) do
        pcall(function()
            local sb, missing = ST.compat32.buff_manager(ch)
            if sb then
                local verified, reason = ST.compat32.camp_buff(sb, entry.m.buff, false)
                if verified then fed = fed + 1 end
                _st_log("cooking buff: " .. tostring(reason))
            else
                _st_log("cooking buff unavailable: " .. tostring(missing))
            end
        end)
    end
    if fed < #party then
        _st_log(string.format("cook: %d of %d party members took the buff", fed, #party))
    end
    _st_log(string.format("cooked %s - party buff on %d member(s)", entry.m.name, fed))
    _mc_toast(fed > 0 and ("Cooked " .. entry.m.name .. "; meal buff confirmed for " .. fed .. " party member(s).")
        or ("Cooked " .. entry.m.name .. ", but the meal buff could not be confirmed."))
    pcall(function()
        local ch = _player()
        local human = ch and ch:call("get_Human")
        local f = _human_fsm(human)
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if layer then
            if f then f:set_Enabled(true) end
            layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
                60, 1104, 0.0, 6.0, 1, 1)
            if f then f:set_Enabled(false) end
            MC.stir_until = os.clock() + 5.0
        end
    end)
end
ST.WORK_BUFFS = {
    food      = { id = 2, name = "Dried Meat", label = "Kitchen work" },
    trades    = { id = 4, name = "Beast Steak", label = "Craftwork" },
    household = { id = 3, name = "Scrag of Beast", label = "Household work" },
    everyday  = { id = 3, name = "Scrag of Beast", label = "Daily work" },
    outdoors  = { id = 6, name = "Aged Beast Steak", label = "Outdoor work" },
}
function ST.notify_work_result(now,text,detail)
    local ok,queued=pcall(function()
        return require('II.TemperDialog32').notify('work:'..tostring(now),
            text..(detail and ('\n'..detail) or ''))
    end)
    if not ok or not queued then _st_log('Work completion dialogue unavailable: '..tostring(queued)) end
end
function ST.work_buff_tick()
    local now = os.clock()
    if M.work_buffs == false or _loading() or not _managed(_player()) then
        ST.wb, ST.work_notice, ST.work_hud_hidden = nil, nil, true
        return
    end
    local w = ST.wb
    if not w then w = {}; ST.wb = w end
    local sess = ST.session
    if ST.is_anvil_session(sess)
            or (TL.act and TOOLS[TL.act.key] and TOOLS[TL.act.key].work_reward == false) then
        ST.wb, ST.work_notice, ST.work_hud_hidden = nil, nil, true
        return
    end
    local active_id, active_key, active_group, haul_idle = nil, nil, nil, false
    if TL.act then
        active_key = TL.act.key
        active_id = "tool:" .. tostring(active_key)
        active_group = ST.compat32.work_group(STATIONS, active_key)
    elseif sess then
        active_key = sess.key or (sess.rec and (sess.rec.prop_key or sess.rec.host))
        active_id = "station:" .. tostring(sess.token or sess.id or active_key)
        active_group = ST.compat32.station_work_group(STATIONS, active_key,
            sess.rec and sess.rec.owner and _owner_is(sess.rec.owner, "app.GmInteractPickableBase"))
    elseif CARRY.have and CARRY.work_groups[CARRY.id] then
        active_id = "hauling:" .. tostring(CARRY.id)
        active_group = CARRY.work_groups[CARRY.id]
        haul_idle = _tl_move_mag() <= 0.3
    end
    local paused = _menu_open() or MC.open or rawget(_G, "InteractablesDyeUIOpen") == true or haul_idle == true
    ST.work_hud_hidden = paused
    local group, dur = ST.compat32.work_sample(w, active_id, active_group, now, paused)
    if w.id ~= ST.work_logged_id then
        ST.work_logged_id = w.id
        if w.id then _st_log("work tracking: " .. tostring(active_key) .. " group=" .. tostring(active_group)) end
    end
    if not group then return end
    if now - (tonumber(ST.wb_last) or -1e9) < 60.0 then
        w.notice = "Work complete - recent work bonus still on cooldown"
        ST.work_notice = { at = now, text = w.notice, detail = "You can stop; no additional bonus granted." }
        ST.notify_work_result(now,'Work Complete','Recent work bonus is still on cooldown. No additional bonus granted.')
        return
    end
    local buff = ST.WORK_BUFFS[group or ""]
    if not buff then return end
    local party = _mc_party()
    local fed, retained, detail = 0, 0, nil
    for _, ch in ipairs(party) do
        local ok, err = pcall(function()
            local sb, missing = ST.compat32.buff_manager(ch)
            if sb then
                local verified, reason = ST.compat32.camp_buff(sb, buff.id, true)
                if verified then
                    fed = fed + 1
                    pcall(function() detail = detail or ST.compat32.camp_effects(ST.compat32.camp_state(sb)) end)
                elseif reason == "existing meal retained" then retained = retained + 1 end
                _st_log("work buff: " .. tostring(reason))
            else
                _st_log("work buff unavailable: " .. tostring(missing))
            end
        end)
        if not ok then _st_log("work buff readback failed: " .. tostring(err)) end
    end
    if fed > 0 then
        ST.wb_last = now
        w.notice = string.format("Work complete - %s bonus (%d party member%s)",
            buff.name, fed, fed == 1 and "" or "s")
        _st_log(string.format("work buff %d granted to %d member(s) after %.0fs of %s",
            buff.id, fed, dur, tostring(group)))
    elseif retained > 0 then
        w.notice = "Work complete - existing meal bonus retained"
        detail = "Work bonuses do not stack with or replace an active meal."
    else
        w.notice = "Work complete - buff could not be confirmed"
        detail = "No reward confirmed; the failure was recorded in the log."
        _st_log("work buff: no confirmed grants after " .. tostring(dur) .. "s; party candidates=" .. #party)
    end
    ST.work_notice = { at = now, text = w.notice,
        detail = detail or "Native meal bonus applied; stat breakdown unavailable." }
    ST.notify_work_result(now,w.notice,ST.work_notice.detail)
end
function ST.work_buff_draw()
    if M.work_buffs == false or M.work_hud == false or ST.work_hud_hidden
            or rawget(_G, "Interactables_rest_transition") == true then return end
    local w, notice = ST.wb, ST.work_notice
    local sz = imgui.get_display_size()
    if not sz then return end
    local x = math.max(16, math.min(sz.x - 436, sz.x * (M.work_hud_x or 0.98) - 420))
    local y = math.max(16, math.min(sz.y - 176, sz.y * (M.work_hud_y or 0.62)))
    if w and w.id and not w.completed then
        local row = ST.WORK_BUFFS[w.group] or {}
        local progress = math.min(1, (w.elapsed or 0) / ST.compat32.work_seconds)
        draw.filled_rect(x, y, 420, 62, 0xA0181410)
        draw.text(string.format("%s: %ds / %ds", row.label or "Working",
                math.floor(w.elapsed or 0), ST.compat32.work_seconds), x + 16, y + 10, 0xFFEAD8B0)
        for i = 1, 32 do
            local a, b = (i-1) * math.pi / 16, (i-0.2) * math.pi / 16
            local colour = i <= progress * 32 and 0xFF80D8A0 or 0xFF60584C
            draw.line(x+385+18*math.sin(a), y+31-18*math.cos(a),
                x+385+18*math.sin(b), y+31-18*math.cos(b), colour, 3)
        end
        draw.text("Keep working to earn a meal bonus",
            x + 16, y + 34, 0xFFD0C8B8)
    end
    if notice and os.clock() - notice.at < 8 then
        local title = ST.compat32.wrap_text(notice.text, 44)
        local detail = ST.compat32.wrap_text(notice.detail, 44)
        local top = y + ((w and w.id and not w.completed) and 68 or 0)
        draw.filled_rect(x, top, 420, 20 + 20 * (#title + #detail), 0xB0181410)
        for i, line in ipairs(title) do draw.text(line, x + 12, top - 10 + i*20, 0xFFB0E8C0) end
        for i, line in ipairs(detail) do draw.text(line, x + 12, top - 10 + (#title+i)*20, 0xFFE0D8C8) end
    end
end
local function _mc_frame()
    if CAMP_STATE.is_active() then
        if MC.camp_suppressed ~= true then
            MC.camp_suppressed = true
            _st_log("cook: synthetic interactions suppressed while Capcom camp is active")
        end
        MC.suppress_for_native_camp()
        return
    elseif MC.camp_suppressed == true then
        MC.camp_suppressed = false
        _st_log("cook: native camp ended; town cooking interactions available again")
    end
    if not ST.group_on("food") then
        if MC.open or MC.want then _mc_close() end
        MC.clear_prompt()
        return
    end
    if rawget(_G, "InteractablesRestDialogActive") == true then return end
    local now = os.clock()
    if MC.stir_until and (now >= MC.stir_until or _tl_move_mag() > 0.3) then
        _mc_stop_stir()
    end
    if MC.open then
        MC.clear_prompt()
        MC.poll_native()
        if MC.result ~= nil then
            local picked = (MC.opts or {})[MC.result]
            _mc_close()
            if picked and picked.page then _mc_menu(picked.page)
            elseif picked then _mc_cook(picked) end
        end
        return
    end
    if MC.want and not MC.open then
        local w = MC.want
        if now - (tonumber(w.at) or 0) > 8.0 then
            MC.want = nil
            _mc_toast("Cooking dialogue unavailable; nothing was consumed.")
            _st_log("cook dialog: native GUI unavailable or busy")
        else
            local ok, opened = pcall(function()
                local gm = sdk.get_managed_singleton("app.GuiManager")
                if not gm then return false end
                if not ST.compat32.open_dialog(gm, w.prompt, w.labels) then return false end
                MC.gm, MC.native = gm, true
                return true
            end)
            if not ok then
                MC.want = nil
                _mc_toast("Cooking dialogue unavailable; nothing was consumed.")
                _st_log("cook dialog: " .. tostring(opened))
            elseif opened then
                MC.open, MC.opened_at, MC.want = true, now, nil
                _st_log("cook: native dialogue requested with pause enabled")
            end
        end
        return
    end
    if not MC.near or now - (tonumber(MC.near) or 0) >= 1.0 then
        local pgo = _char_go(_player())
        local pu = pgo and _upos(pgo)
        if pu then
            local best, best_d2, best_key, best_pos = nil, 6.76, nil, nil
            for _, e in ipairs(sc.near or {}) do
                local raw = tostring(e.nkey or e.name or ""):lower()
                local base = raw:match("^(gm%d+_%d+)") or raw
                local q = e._p
                if q and MC_POTS[base] and not MC_NATIVE_CAMP[base] then
                    local dx, dy, dz = q.x - pu.x, q.y - pu.y, q.z - pu.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < best_d2 then
                        best, best_d2, best_key, best_pos = e, d2, base, q
                    end
                end
            end
            if best then
                MC.near, MC.near_key = now, best_key
                MC.near_pos = { x = best_pos.x, y = best_pos.y, z = best_pos.z }
            end
        end
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
    if now - (tonumber(MC.closed_at) or 0) < 0.4 then return end
    if not near or MC.stir_until then
        MC.prev = false
        MC.clear_prompt()
        return
    end
    local down = _stop_down()
    local edge = down and not MC.prev
    MC.prev = down
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
local PIN = { pfb = nil, job = nil, go = nil, id = nil }
local function _pin_despawn()
    if _valid(PIN.go) then
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
    PIN.grip = nil
    PIN.bmc, PIN.rebind = nil, nil
end
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
local function _pin_apply_local()
    if not (PIN.go and PIN.jname) then return end
    if not _valid(PIN.go) then
        PIN.go, PIN.id, PIN.jname, PIN.grip = nil, nil, nil, nil
        return
    end
    pcall(function()
        local g = PIN.grip
        local ox = g and g.ox or M.pin_ox or 0
        local oy = g and g.oy or M.pin_oy or 0
        local oz = g and g.oz or M.pin_oz or 0
        local rx = g and g.rx or M.pin_rx or 0
        local ry = g and g.ry or M.pin_ry or 0
        local rz = g and g.rz or M.pin_rz or 0
        local btf = PIN.go:call("get_Transform")
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
local function _pin_spawn(id, grip)
    if PIN.blocked_id ~= id then
        PIN.blocked_id = id
        _st_log("workpiece unavailable: unsafe TU3.2 prefab loader disabled (" .. tostring(id) .. ")")
    end
end
local function _pin_frame()
    local key = ST.session and ST.session.key
    local row = key and STATIONS[key]
    local prop, grip = nil, nil
    if row and row.prop then
        prop = tostring(row.prop)
        grip = row.grip or { ox = 0, oy = 0, oz = 0, rx = 0, ry = 0, rz = 0 }
    elseif row and row.pin and tostring(M.anvil_prop or "") ~= "" then
        prop = tostring(M.anvil_prop)
    end
    local want = prop ~= nil and prop ~= ""
    if want and PIN.id and PIN.id ~= prop then _pin_despawn() end
    if want and not PIN.go and not PIN.job and not PIN.cook then
        _pin_spawn(prop, grip)
    elseif not want and (PIN.go or PIN.job or PIN.cook) then
        _pin_despawn()
    end
    _pin_apply_local()
end
local BF = { at = 0, u = 0, i = 0, cycle = 0, bed_probe = {}, cls = {} }
local function _registry_bed_owner(io, owner_go, now)
    local ia = _addr(io)
    local cached = ia and BF.bed_probe[ia]
    if cached and now < (tonumber(cached.until_at) or 0) then
        if cached.is_bed ~= true then return nil end
        if _managed(cached.owner) then return cached.owner end
    end
    if not owner_go then
        pcall(function() owner_go = io:call("get_Owner") end)
    end
    local bed = _bed_owner(owner_go)
    if ia then
        BF.bed_probe[ia] = {
            is_bed = _managed(bed),
            owner = _managed(bed) and bed or nil,
            until_at = now + 120.0,
        }
    end
    return bed
end
local function _registry_process(io, now, pp)
    if not io then return end
    local ia = _addr(io)
    local cls = ia and BF.cls[ia]
    if not (cls and now < (tonumber(cls.until_at) or 0)) then
        local nm, owner_go
        pcall(function()
            owner_go = io:call("get_Owner")
            if not owner_go then owner_go = io:get_field("<Owner>k__BackingField") end
            nm = owner_go and tostring(owner_go:call("get_Name")) or nil
        end)
        if not nm then
            if ia then BF.cls[ia] = { dead = true, until_at = now + 120.0 } end
            return
        end
        local low = nm:lower()
        local base = low:match("^(gm%d+_%d+)") or low
        cls = {
            nm = nm, low = low, base = base,
            key = _norm(low) or _norm(base) or base,
            sk = ST.seat_key_from_owner(owner_go),
            until_at = now + 120.0,
        }
        if ia then BF.cls[ia] = cls end
    end
    if cls.dead then return end
    local nm, low, base, key = cls.nm, cls.low, cls.base, cls.key
    local named_bed = BED_KEYS[low] or BED_KEYS[base]
    local bed_owner = nil
    if M.native_beds ~= false
            and (not named_bed or not (M.st_off or {})[BED_KEYS[low] and low or base]) then
        bed_owner = _registry_bed_owner(io, nil, now)
    end
    local isbed = M.native_beds ~= false
        and ((named_bed and not (M.st_off or {})[BED_KEYS[low] and low or base])
            or _managed(bed_owner))
    local seat_key = M.enabled ~= false and cls.sk or nil
    local isseat = M.enabled ~= false and (SIT_KEYS[low] or SIT_KEYS[base] or seat_key ~= nil)
    local ispot = not CAMP_STATE.is_active() and MC_POTS[base] == true
    local np = tonumber(io:call("getNumInteractPoint")) or 0
    local bd, bq, bi = nil, nil, nil
    for p = 0, np - 1 do
        local q = io:call("getInteractPointPosition", p)
        if q then
            local dx, dy, dz = q.x - pp.x, q.y - pp.y, q.z - pp.z
            local d2 = dx * dx + dy * dy + dz * dz
            if not bd or d2 < bd then bd, bq, bi = d2, q, p end
        end
    end
    if not bd then return end
    if bd<256 and ST.is_anvil_session({key=key}) and ST.any_activity_enabled() then
        _G.Interactables_near_anvil={at=now,key=key}
    end
    if not isseat and M.enabled ~= false and bd < 100.0 then
        seat_key = ST.seat_key_near(bq)
        isseat = seat_key ~= nil
    end
    local kind = isbed and "bed" or (isseat and "seat" or _unlock_kind(key))
    if not (kind or ispot) then return end
    if ispot and bd < 5.29 then
        MC.near = now
        MC.near_pos = { x = bq.x, y = bq.y, z = bq.z }
        if MC.near_key ~= base then
            MC.near_key = base
            _st_log("cook pot in range: " .. tostring(base))
        end
    end
    if kind and bd < 100.0 then
        local dl = io:get_field("DataList")
        local ndl = dl and tonumber(dl:call("get_Count")) or 0
        local prop_key = isbed and (BED_KEYS[low] and low or (BED_KEYS[base] and base or key))
            or (isseat and (seat_key or (SIT_KEYS[low] and low or base)) or key)
        for d = 0, ndl - 1 do
            local pt = dl:call("get_Item", d)
            if pt then
                local okp = _patch_search_point(pt, kind, nm,
                    "registry", d, io, bed_owner, prop_key)
                if okp then
                    _st_log("registry unlocked " .. kind .. " "
                        .. tostring(prop_key) .. "[" .. d .. "]")
                end
            end
        end
    end
end
local function _registry_tick()
    if not ST.any_activity_enabled() and M.native_beds == false
            and M.native_chores == false and M.enabled == false
            and M.native_ambient ~= true then return end
    local now = os.clock()
    if now - (tonumber(BF.at) or 0) < (tonumber(M.registry_slice_secs) or 0.05) then return end
    BF.at = now
    if _loading() or _menu_open() or rawget(_G,"InteractablesDyeUIOpen")==true then return end
    local pgo = _char_go(_player())
    local pp = pgo and _upos(pgo)
    if not pp then return end
    pcall(CARRY.unlock_near, now, pp)
    pcall(function()
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        local ups = mgr and mgr:get_field("InteractiveObjectUpdaters")
        if not ups then return end
        local nu = tonumber(ups:call("get_Length")) or 0
        if nu <= 0 then BF.u, BF.i = 0, 0; return end
        local budget = math.max(8, math.floor(tonumber(M.registry_budget) or 24))
        local processed, hops = 0, 0
        while processed < budget and hops < budget + nu + 2 do
            hops = hops + 1
            if BF.u >= nu then
                BF.u, BF.i = 0, 0
                BF.cycle = (BF.cycle or 0) + 1
                break
            end
            local lst
            pcall(function()
                local upd = ups:get_element(BF.u)
                lst = upd and upd:get_field("InteractiveObjectList")
            end)
            local n = lst and tonumber(lst:call("get_Count")) or 0
            if BF.i >= n then
                BF.u, BF.i = BF.u + 1, 0
            else
                local i = BF.i
                BF.i = BF.i + 1
                processed = processed + 1
                local io = nil
                pcall(function() io = lst:call("get_Item", i) end)
                pcall(_registry_process, io, now, pp)
            end
        end
    end)
end
function CARRY.unlock_near(now, pp)
    if M.master == false or M.enabled == false or M.native_chores ~= true
            or _loading() or _menu_open() then return end
    if now < (CARRY.unlock_at or 0) then return end
    CARRY.unlock_at = now + 1.0
    local sm = sdk.get_native_singleton("via.SceneManager")
    local td = sdk.find_type_definition("via.SceneManager")
    local scene = sm and td and sdk.call_native_func(sm, td, "get_CurrentScene")
    local arr = scene and scene:call("findComponents(System.Type)", sdk.typeof("app.GmInteractPickableBase"))
    local count = arr and tonumber(arr:call("get_Length")) or 0
    local start = (CARRY.unlock_cursor or 0) % math.max(1, count)
    for offset = 0, math.min(count, 64) - 1 do
        pcall(function()
            local item = arr:get_element((start + offset) % count)
            local id = item and tonumber(item:get_field("EquipID"))
            if not CARRY.keep_ids[id] then return end
            local go = item:call("get_GameObject")
            local pos = go and _upos(go)
            if not pos or (pos.x-pp.x)^2+(pos.y-pp.y)^2+(pos.z-pp.z)^2 > 100 then return end
            _unlock_go({go=go, name=tostring(go:call("get_Name"))})
            CARRY.ensure_equipment(item, go, go:call("get_Name"))
        end)
    end
    CARRY.unlock_cursor = start + math.min(count, 64)
end
function THRONE.scan(now)
    if now < (THRONE.scan_at or 0) then return end
    THRONE.scan_at = now + 0.5
    THRONE.seen = nil
    local c = THRONE.discovery.find(now)
    if not c then return end
    local pp = _char_go(_player())
    pp = pp and _upos(pp)
    if not pp then return end
    pp = { x=pp.x, y=pp.y, z=pp.z }
    local anchor = _upos(c.go)
    if not anchor then return end
    anchor = { x=anchor.x, y=anchor.y, z=anchor.z }
    if (anchor.x-pp.x)^2+(anchor.y-pp.y)^2+(anchor.z-pp.z)^2 >= 16 then return end
    local io, chair = c.io, c.owner
    if THRONE.patched_io ~= io then
        _patch_data_list(chair:get_field("InteractiveObjectDataList"), "seat",
            "gm51_752", "throne component", io, chair, "gm51_752")
        THRONE.patched_io = io
    end
    local ready, registration = THRONE.request32.ensure_registered(io, c.go, now)
    if THRONE.registration_status ~= registration then
        THRONE.registration_status = registration
        _st_log("throne: " .. registration)
        pcall(THRONE.request32.capture, chair, io, _player(), registration)
    end
    if not ready then return end
    local n = tonumber(io:call("getNumInteractPoint")) or 0
    if n <= 0 then return end
    THRONE.io, THRONE.owner, THRONE.point = io, chair, 0
    THRONE.pos, THRONE.seen = anchor, now
end
function THRONE.refresh(now)
    if now < (THRONE.check_at or 0) then return end
    THRONE.check_at = now + 0.1
    THRONE.near, THRONE.available, THRONE.occupied = false, false, false
    THRONE.ch, THRONE.render_pos = nil, nil
    if M.enabled == false then THRONE.seen=nil; THRONE.patched_io=nil; return end
    if _loading() then
        THRONE.seen, THRONE.patched_io, THRONE.scan_at = nil, nil, 0
        THRONE.discovery.reset()
        return
    end
    if _menu_open() then THRONE.seen=nil; return end
    THRONE.scan(now)
    if not (THRONE.seen and now-THRONE.seen < 1.0 and _managed(THRONE.io) and THRONE.pos) then return end
    local ch = _player()
    local go = _char_go(ch)
    local pp = go and _upos(go)
    if not pp then return end
    local d2 = (THRONE.pos.x-pp.x)^2+(THRONE.pos.y-pp.y)^2+(THRONE.pos.z-pp.z)^2
    if d2 >= 9.0 then return end
    THRONE.near, THRONE.ch, THRONE.distance = true, ch, math.sqrt(d2)
    local ok, occupant = pcall(function()
        return THRONE.owner:call("getInteractChara(System.UInt32)", tonumber(THRONE.point) or 0)
    end)
    THRONE.occupied = not ok or occupant ~= nil
    local ready, enabled = pcall(function()
        return THRONE.io:call("isInteractEnable(System.UInt32, app.Character)",
            tonumber(THRONE.point) or 0, ch) == true
    end)
    THRONE.available = ready and enabled
    local c = THRONE.discovery.candidate
    local pos = c and _pos(c.go)
    if pos then THRONE.render_pos = Vector3f.new(pos.x, pos.y+1.0, pos.z) end
end
function THRONE.tick()
    local now = os.clock()
    if THRONE.request then
        local q = THRONE.request
        local status = THRONE.request32.poll(q, now)
        if status then
            THRONE.request = nil
            THRONE.retry_at = now + 1.0
            _st_log("throne processed request: " .. status)
            local ok, err = pcall(THRONE.request32.capture, q.owner, q.io, q.ch, status)
            if not ok then _st_log("throne request capture failed: " .. tostring(err)) end
        end
    end
    THRONE.refresh(now)
    local near, available, occupied = THRONE.near, THRONE.available, THRONE.occupied
    local ch = THRONE.ch
    if not near or not available or occupied or THRONE.request or ST.session or ST.pending or (TL and TL.act) then
        if THRONE.offer_status ~= "suppressed" then
            THRONE.offer_status = "suppressed"
            _st_log("throne prompt suppressed: near=" .. tostring(near)
                .. " available=" .. tostring(available) .. " occupied=" .. tostring(occupied))
        end
        THRONE.prev = near and _stop_down() or false
        pcall(function()
            local IP = _G.IrisPrompt
            if IP and type(IP.clear) == "function" then IP.clear("interactables_throne") end
        end)
        return
    end
    local offered, offer_error = pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.set) == "function" then
            local c = THRONE.discovery.candidate
            IP.set("interactables_throne", "Sit", 14, THRONE.distance,
                THRONE.render_pos, c and c.go)
        else
            error("shared prompt API unavailable")
        end
    end)
    local status = offered and tostring(_G.IrisPrompt.winner()) or tostring(offer_error)
    if THRONE.offer_status ~= status then
        THRONE.offer_status = status
        _st_log("throne prompt: " .. status)
    end
    local down = _stop_down()
    local edge = down and not THRONE.prev
    THRONE.prev = down
    if not edge then return end
    if THRONE.request or now < (THRONE.retry_at or 0) then return end
    local winner = nil
    pcall(function() winner = _G.IrisPrompt and _G.IrisPrompt.winner() end)
    if winner ~= "interactables_throne" or _st_native_busy_read() then return end
    if _loading() or _menu_open() then return end
    local ok, err = pcall(function()
        local no = tonumber(THRONE.point) or 0
        ch = _player()
        if not ch or THRONE.io:call("isInteractEnable(System.UInt32, app.Character)", no, ch) ~= true then
            error("seat no longer available")
        end
        if THRONE.owner and THRONE.owner:call("getInteractChara(System.UInt32)", no) then
            error("seat is occupied")
        end
        local mgr = sdk.get_managed_singleton("app.InteractManager")
        if not mgr then error("InteractManager unavailable") end
        local result = mgr:call("requestInteractFromAI(app.InteractiveObject, System.UInt32, app.Character)",
            THRONE.io, no, ch)
        if not result then error("native request returned nil") end
        result:add_ref()
        THRONE.request = { result=result, started=now, io=THRONE.io, owner=THRONE.owner, ch=ch }
        _st_log("throne request queued; checking the processed result")
    end)
    _st_log(ok and "throne: native interaction requested; awaiting session confirmation"
        or ("throne: live start failed: " .. tostring(err)))
end
local function _st_cam_tick()
    local dye_open = rawget(_G, "InteractablesDyeUIOpen") == true
    if M.st_cam == false and ST.cam_base == nil and not dye_open then return end
    local want = (M.st_cam ~= false or dye_open)
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
        if dye_open then target = (ST.cam_base or 0.0) + 1.4 end
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
local BR = {
    open = false,
    home_override = rawget(_G, "InteractablesHomeBedOverrideV2"),
    transition = rawget(_G, "InteractablesNativeBedRestV3"),
    wake_guard = rawget(_G, "InteractablesBedWakeGuardV1"),
}
_G.Interactables_rest_transition = BR.transition ~= nil
_G.InteractablesBedAuthoredGetUpV1 = nil
_G.InteractablesBedAuthoredGetUpConsumedV1 = nil
local function _br_progress_draw()
    local until_at = tonumber(BR.wake_mask_until)
    local now = os.clock()
    if until_at and now >= until_at then
        BR.wake_mask_until = nil
        BR.wake_mask_fade_at = nil
        until_at = nil
    end
    if until_at then pcall(function()
        local sz = imgui.get_display_size()
        local w = sz and tonumber(sz.x) or 1920.0
        local h = sz and tonumber(sz.y) or 1080.0
        local alpha = 255
        local fade_at = tonumber(BR.wake_mask_fade_at)
        if fade_at and until_at > fade_at then
            alpha = math.max(0, math.min(255,
                math.floor(255.0 * (until_at - now) / (until_at - fade_at))))
        end
        draw.filled_rect(0.0, 0.0, w, h, (alpha << 24))
    end) end
    local tr = BR.transition
    if tr and tr.phase == "generic_dialog" then
        pcall(function()
            local sz = imgui.get_display_size()
            local sw = sz and tonumber(sz.x) or 1920.0
            local sh = sz and tonumber(sz.y) or 1080.0
            local w, h, row_h = 540, 190, 38
            local x, y = (sw - w) * 0.5, (sh - h) * 0.48
            draw.filled_rect(x, y, w, h, 0xE8100C0A)
            draw.outline_rect(x, y, w, h, 0xFF4AA2E8)
            draw.text("Rest until when?", x + 22, y + 16, 0xFF4AA2E8)
            for i, label in ipairs({ "Morning", "Nightfall", "Cancel" }) do
                local yy = y + 58 + (i - 1) * row_h
                if i == (tr.dialog_sel or 1) then
                    draw.filled_rect(x + 16, yy - 4, w - 32, row_h - 2, 0x50FFFFFF)
                end
                draw.text((i == (tr.dialog_sel or 1) and "> " or "  ") .. label,
                    x + 26, yy, i == (tr.dialog_sel or 1) and 0xFFE8E8E8 or 0xFF9A9A9A)
            end
        end)
    end
end
local function _br_native_state(bed)
    local row = {}
    for _, field in ipairs({ "Group", "Order", "GroupMyRooml", "OrderMyRoom",
            "IsUseMyRoom", "NowMyRoomState", "TmpInteractSheetNum", "IsAwakeMorning" }) do
        pcall(function()
            local v = bed:get_field(field)
            local raw = nil
            pcall(function() raw = v and v:get_field("value__") end)
            row[field] = tostring(raw ~= nil and raw or v)
        end)
    end
    return row
end
_G.InteractablesHomeBedSheetOnStartV2 = function(bed, interact_no, character)
    if M.master == false or M.native_beds == false or M.bed_rest == false then return end
    if BR.native_calling or not _managed(bed) or not _managed(character) then return end
    local pa, ca = _addr(_player()), _addr(character)
    if not (pa and ca and pa == ca) then return end
    local inn = _bed_inn(bed)
    if not _managed(inn) then return end
    local now, ba = os.clock(), _addr(bed)
    if BR.native_last_addr == ba
            and now - (tonumber(BR.native_last_at) or 0) < 0.75 then return end
    BR.native_last_addr, BR.native_last_at = ba, now
    local trace = {
        at = now, bed = tostring(ba), interact_no = tostring(interact_no),
        before = _br_native_state(bed),
    }
    _G.InteractablesHomeBedTrace = trace
    local is_home = false
    pcall(function() is_home = bed:get_field("IsUseMyRoom") == true end)
    if not is_home then
        trace.route = "native non-home Gm51_115"
        return
    end
    local switched, err = pcall(function() bed:set_field("IsUseMyRoom", false) end)
    trace.route = "ordinary sheet branch"
    trace.after_switch = _br_native_state(bed)
    trace.call_ok, trace.call_error = tostring(switched), tostring(err)
    if switched then
        BR.home_override = { bed = bed, value = true, at = now, saw_open = false }
        _G.InteractablesHomeBedOverrideV2 = BR.home_override
        BR.home_stage_addr, BR.home_stage_at = ba, now
        _G.Interactables_bed_active = true
        _st_log("home bed: ordinary native lie-down staged; home flag held until authored exit")
    else
        _st_log("home bed: FAILED to stage native lie-down: " .. tostring(err))
    end
end
if not _G.InteractablesHomeBedSheetHooksV2 then
    _G.InteractablesHomeBedSheetHooksV2 = true
    pcall(function()
        local td = sdk.find_type_definition("app.Gm51_115")
        local mm = td and td:get_method(
            "onStartInteractBase(System.UInt32, app.Character)")
        if not mm then error("Gm51_115.onStartInteractBase was not found") end
        sdk.hook(mm, function(args)
            pcall(function()
                local f = rawget(_G, "InteractablesHomeBedSheetOnStartV2")
                if type(f) == "function" then
                    f(sdk.to_managed_object(args[2]), sdk.to_int64(args[3]),
                      sdk.to_managed_object(args[4]))
                end
            end)
            return sdk.PreHookResult.CALL_ORIGINAL
        end, function(retval) return retval end)
        _st_log("home bed: pre-rest sheet hook installed")
    end)
end
local function _br_clear_rest_prompt()
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear_slot) == "function" then
            IP.clear_slot("interactables_bed_rest", "PNL_R02")
            IP.clear_slot("interactables_bed_exit", "PNL_R03")
        end
    end)
end
local function _br_dialog_close()
    _G.InteractablesRestDialogActive = nil
end
local function _br_dialog_show(transition)
    transition.dialog_opened_at = os.clock()
    transition.dialog_block_until = transition.dialog_opened_at + 0.35
    transition.dialog_sel = 1
    transition.dialog_prev = {}
    _G.InteractablesRestDialogActive = true
    return true
end
local function _br_dialog_choice(transition, now)
    if not transition or not transition.dialog_opened_at
            or now - transition.dialog_opened_at < 0.3 then return nil end
    if now < (tonumber(transition.dialog_block_until) or 0) then return nil end
    local mask = _pad_button_mask()
    local up = _kb_down(0x26)
    local down = _kb_down(0x28)
    pcall(function()
        local gp = sdk.get_native_singleton("via.hid.GamePad")
        local td = sdk.find_type_definition("via.hid.GamePad")
        local dev = gp and td and sdk.call_native_func(gp, td, "get_MergedDevice")
        local axis = dev and dev:call("get_AxisL")
        local ay = axis and tonumber(axis.y) or 0.0
        up, down = up or ay > 0.55, down or ay < -0.55
    end)
    local held = {
        up = up, down = down,
        confirm = (mask & PAD_ALIAS.south) ~= 0 or _kb_down(0x0D) or _kb_down(0x20),
        cancel = (mask & PAD_ALIAS.east) ~= 0 or _kb_down(0x46) or _kb_down(0x08),
    }
    local function edge(name)
        local prev = transition.dialog_prev or {}
        transition.dialog_prev = prev
        local hit = held[name] and not prev[name]
        prev[name] = held[name]
        return hit
    end
    if edge("up") then transition.dialog_sel = ((transition.dialog_sel or 1) - 2) % 3 + 1 end
    if edge("down") then transition.dialog_sel = (transition.dialog_sel or 1) % 3 + 1 end
    if edge("cancel") then return "cancel" end
    if edge("confirm") then
        if transition.dialog_sel == 1 then return true end
        if transition.dialog_sel == 2 then return false end
        return "cancel"
    end
    return nil
end
local function _br_set_rest_prompt(a_text, b_text)
    pcall(function()
        local IP = _G.IrisPrompt
        if not (IP and type(IP.set_slot) == "function") then return end
        if a_text ~= nil then
            IP.set_slot("interactables_bed_exit", "PNL_R03", a_text, 101)
        end
        if b_text ~= nil then
            IP.set_slot("interactables_bed_rest", "PNL_R02", b_text, 100)
        elseif type(IP.clear_slot) == "function" then
            IP.clear_slot("interactables_bed_rest", "PNL_R02")
        end
    end)
end
local function _br_donor_param()
    local found, space, fallback
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
                local ip = _bed_inn(bed)
                if _managed(ip) and not fallback then fallback = ip end
                local slot = ip and ip:get_field("Player")
                local p = slot and slot:get_field("_Pos")
                if not (p and p.x) then return end
                local tf = bed:call("get_GameObject"):call("get_Transform")
                local u = tf and tf:call("get_UniversalPosition")
                local r = tf and tf:call("get_Position")
                if not (u and r) then return end
                local du = math.sqrt((p.x - u.x) ^ 2 + (p.z - u.z) ^ 2)
                local dr = math.sqrt((p.x - r.x) ^ 2 + (p.z - r.z) ^ 2)
                if du < 30.0 and du <= dr then found, space = ip, "universal"
                elseif dr < 30.0 and dr < du then found, space = ip, "render" end
            end)
        end
    end)
    if not found and _managed(fallback) then
        found, space = fallback, "universal"
        _st_log("bed rest: using streamed inn settings as clone template")
    end
    if found then _st_log("bed rest: borrowed inn settings, coords are " .. tostring(space)) end
    return found, space
end
local function _br_atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then
        if y >= 0 then return math.atan(y / x) + math.pi end
        return math.atan(y / x) - math.pi
    end
    if y > 0 then return math.pi * 0.5 end
    if y < 0 then return math.pi * -0.5 end
    return 0.0
end
local function _br_aim_param(param, io, space, reverse_player)
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
            yaw = _br_atan2(2.0 * (rot.w * rot.y + rot.x * rot.z),
                1.0 - 2.0 * (rot.y * rot.y + rot.x * rot.x))
        end)
        local fx, fz = math.sin(yaw), math.cos(yaw)
        local rx, rz = math.cos(yaw), -math.sin(yaw)
        local q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
        q.x, q.y, q.z, q.w = 0, math.sin(yaw * 0.5), 0, math.cos(yaw * 0.5)
        local player_q = q
        if reverse_player == true then
            local player_yaw = yaw + math.pi
            player_q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
            player_q.x, player_q.y, player_q.z, player_q.w = 0,
                math.sin(player_yaw * 0.5), 0, math.cos(player_yaw * 0.5)
        end
        local function stamp(field, px, py, pz, qr)
            local slot = param:get_field(field)
            if not slot then error("missing wake slot " .. field) end
            slot:set_field("_Pos", Vector3f.new(px, py, pz))
            slot:set_field("_Rot", qr or q)
            local check = slot:call("get_Pos")
            if not check or math.abs(check.x-px) > 0.1 or math.abs(check.y-py) > 0.1
                    or math.abs(check.z-pz) > 0.1 then
                error("wake position read-back failed: " .. field)
            end
        end
        local pp, cp, cq = nil, nil, nil
        pcall(function()
            local ptf = _char_go(_player()):call("get_Transform")
            pp = (space == "render") and ptf:call("get_Position")
                or ptf:call("get_UniversalPosition")
            local dx, dz = pp.x - p.x, pp.z - p.z
            if dx * dx + dz * dz > 36.0 then pp = nil end
        end)
        pcall(function()
            local cm = sdk.get_managed_singleton("app.CameraManager")
            local cgo = cm and cm:call("getCameraGameObject")
            if not cgo then
                local cam = cm and cm:call("getMainCamera")
                cgo = cam and cam:call("get_GameObject")
            end
            local ctf = cgo and cgo:call("get_Transform")
            cp = (space == "render") and ctf:call("get_Position")
                or ctf:call("get_UniversalPosition")
            cq = ctf:call("get_Rotation")
        end)
        if pp and reverse_player == true then
            local pyaw = yaw + math.pi * 0.5
            player_q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
            player_q.x, player_q.y, player_q.z, player_q.w = 0,
                math.sin(pyaw * 0.5), 0, math.cos(pyaw * 0.5)
            local side = (pp.x - p.x) * rx + (pp.z - p.z) * rz
            stamp("Player", pp.x - rx * side + fx * 0.55,
                pp.y, pp.z - rz * side + fz * 0.55, player_q)
        elseif pp then stamp("Player", pp.x, pp.y, pp.z, player_q)
        else stamp("Player", p.x, p.y, p.z, player_q) end
        stamp("Main",   p.x + rx * 1.8 + fx * 1.1, p.y, p.z + rz * 1.8 + fz * 1.1)
        stamp("Sub1",   p.x + rx * 1.8,            p.y, p.z + rz * 1.8)
        stamp("Sub2",   p.x + rx * 1.8 - fx * 1.1, p.y, p.z + rz * 1.8 - fz * 1.1)
        if cp then stamp("Camera", cp.x, cp.y, cp.z, cq)
        else stamp("Camera", p.x + rx * 0.9 - fx * 1.6,
            p.y + 1.4, p.z + rz * 0.9 - fz * 1.6) end
        ok = true
    end)
    return ok
end
local BR_PARAM_FIELDS = { "Camera", "Player", "Main", "Sub1", "Sub2" }
local function _br_memberwise_clone(obj)
    if not _managed(obj) then return nil end
    local clone = nil
    pcall(function() clone = obj:call("MemberwiseClone") end)
    if not clone then
        pcall(function()
            local td = sdk.find_type_definition("System.Object")
            local mm = td and td:get_method("MemberwiseClone()")
            clone = mm and mm:call(obj)
        end)
    end
    if _managed(clone) then
        pcall(function() clone:add_ref_permanent() end)
        return clone
    end
    return nil
end
local function _br_clone_param(donor)
    local param = _br_memberwise_clone(donor)
    if not param then return nil end
    for _, field in ipairs(BR_PARAM_FIELDS) do
        local source = nil
        pcall(function() source = donor:get_field(field) end)
        local slot = _br_memberwise_clone(source)
        if not slot then return nil end
        local wrote = pcall(function() param:set_field(field, slot) end)
        if not wrote then return nil end
    end
    return param
end
local function _br_new_param()
    local param = nil
    local ok, err = pcall(function()
        param = ST.compat32.new_inn_param()
    end)
    if not ok or not _managed(param) then
        _st_log("bed rest: could not construct TU3.2 InnAwakeParam: " .. tostring(err))
        return nil
    end
    param:add_ref_permanent()
    return param
end
local function _br_inn_param(io, reverse_player)
    if M.bed_rest_anywhere == false and reverse_player == true then return nil, false end
    local donor, space = _br_donor_param()
    if not donor then
        local fresh = _br_new_param()
        if fresh and _br_aim_param(fresh, io, "universal", reverse_player) then
            _st_log("bed rest: constructed and aimed a fresh TU3.2 inn parameter")
            return fresh, true
        end
        _st_log("bed rest: no live inn parameter exists and fresh construction failed")
        if not _G.__II_innprobe then
            _G.__II_innprobe = true
            pcall(function()
                local td = sdk.find_type_definition("app.Gm51_115")
                local inn = {}
                if td then
                    for _, m in ipairs(td:get_methods() or {}) do
                        local nm = tostring(m:get_name() or "")
                        if nm:lower():find("inn", 1, true) then inn[#inn + 1] = nm end
                    end
                end
                _log("bed rest: Gm51_115 Inn* methods = [" .. table.concat(inn, ", ") .. "]")
            end)
            for _, t in ipairs({ "app.InnManager", "app.GameInnManager",
                    "app.InnParamManager", "app.RestManager" }) do
                local ok = false
                pcall(function() ok = sdk.get_managed_singleton(t) ~= nil end)
                if ok then _log("bed rest: singleton present -> " .. t) end
            end
        end
        return nil, false
    end
    local param = _br_clone_param(donor)
    if not param then
        _st_log("bed rest: could not clone the inn parameter graph")
        return nil, false
    end
    if _br_aim_param(param, io, space, reverse_player) then return param, false end
    _st_log("bed rest: cloned parameter could not be aimed at this bed")
    return nil, false
end
local function _br_session_param(sess)
    local bed = sess and sess.rec and sess.rec.owner
    local override = BR.home_override or rawget(_G, "InteractablesHomeBedOverrideV2")
    if _managed(bed) and override and override.value == true
            and _addr(override.bed) == _addr(bed) then
        local native = _bed_inn(bed)
        if _managed(native) then
            _st_log("bed rest: retaining this home bed's authored wake and camera settings")
            return native, false
        end
    end
    return _br_inn_param(sess and sess.io,
        sess and sess.rec and sess.rec.native_player ~= true)
end
local function _br_tsm_running()
    local running = false
    pcall(function()
        local tsm = sdk.get_managed_singleton("app.TimeSkipManager")
        running = tsm and tsm:call("get_IsExecute") == true or false
    end)
    return running
end
local function _br_inn_state(fm)
    local state = nil
    pcall(function()
        local v = fm and fm:call("get_NowInnState")
        state = tonumber(v)
        if state == nil and v then state = tonumber(v:get_field("value__")) end
    end)
    return state
end
local function _br_inn_ended(fm)
    local ended = false
    pcall(function() ended = fm and fm:call("IsInnStateEnd") == true or false end)
    return ended
end
local function _br_bed_state(bed)
    local state = nil
    pcall(function()
        local v = bed and bed:get_field("NowMyRoomState")
        state = tonumber(v)
        if state == nil and v then state = tonumber(v:get_field("value__")) end
    end)
    return state
end
local function _br_restore_transition_fields(transition)
    if not (transition and transition.fields_applied and _managed(transition.bed)) then
        return true
    end
    local restored, failure = pcall(function()
        if transition.restore_param then
            if not _bed_set_inn(transition.bed, transition.original_param) then
                error("InnParam setter unavailable")
            end
        end
        if transition.original_use ~= nil then
            transition.bed:set_field("IsUseMyRoom", transition.original_use == true)
        end
    end)
    if restored then
        transition.fields_applied = false
        transition.fields_restored = true
    else
        _st_log("bed rest: native bed fields could not be restored: " .. tostring(failure))
    end
    return restored
end
local function _br_clear_transition(message)
    local transition = BR.transition
    if transition and (transition.phase == "generic_dialog"
            or transition.phase == "generic_dialog_pending") then
        _br_dialog_close()
    end
    _br_restore_transition_fields(transition)
    BR.transition = nil
    _G.InteractablesNativeBedRestV3 = nil
    BR.param, BR.own = nil, nil
    _G.Interactables_rest_transition = false
    local still_lying = transition and transition.keep_lie_on_clear == true
    _G.Interactables_bed_active = still_lying == true
    if still_lying and ST.session and ST.session.rec and ST.session.rec.kind == "bed" then
        ST.session.rest_ready = false
        ST.session.rest_asked = false
    end
    _br_clear_rest_prompt()
    if message then _st_log(message) end
end
local function _br_interacting()
    local open = nil
    pcall(function()
        local ch = _player()
        local mgr = ch and sdk.get_managed_singleton("app.InteractManager")
        if ch and mgr then open = mgr:call("isInteracting(app.Character)", ch) == true end
    end)
    return open
end
function BR.request_get_up(reason, bed, point_no)
    if BR.native_exit_pending then return true end
    local active = nil
    pcall(function()
        local ch = _player()
        local mgr = ch and sdk.get_managed_singleton("app.InteractManager")
        active = _get_active_interact(mgr, ch)
    end)
    if not active then
        _st_log("bed: authored get-up could not reach the live bed interaction")
        return false
    end
    BR.native_exit_pending = {
        reason = tostring(reason or "keyboard fallback"),
        bed = bed,
        point_no = tonumber(point_no) or 0,
        queued_at = os.clock(),
    }
    BR.getup_requested_at = os.clock()
    ST.status = "Getting up through the bed's authored exit..."
    _br_clear_rest_prompt()
    _st_log("bed: authored get-up queued by " .. tostring(reason or "keyboard fallback"))
    return true
end
function BR.clear_wake_guard(message)
    BR.wake_guard = nil
    if BR.wake_mask_until then
        BR.wake_mask_fade_at = os.clock()
        BR.wake_mask_until = BR.wake_mask_fade_at + 0.35
    else
        BR.wake_mask_fade_at = nil
    end
    _G.InteractablesBedWakeGuardV1 = nil
    if message then _st_log(message) end
end
function BR.arm_wake_guard(transition, now, committed)
    local time_skip = _br_tsm_running()
    local guard = {
        at = now,
        fm = transition and transition.fm or nil,
        bed = transition and transition.bed or nil,
        point_no = transition and transition.point_no or 0,
        initial_state = transition and transition.initial_state or nil,
        initial_bed_state = transition and transition.initial_bed_state or nil,
        committed = committed == true,
        committed_at = committed == true and now or nil,
        saw_busy = time_skip,
        last_busy_at = time_skip and now or nil,
        saw_complete = false,
        attempts = 0,
        last_attempt_at = nil,
    }
    BR.wake_guard = guard
    _G.InteractablesBedWakeGuardV1 = guard
    _st_log("bed rest: independent post-rest wake guard armed"
        .. (guard.committed and " (rest accepted)" or " (awaiting rest choice)"))
end
function BR.wake_guard_tick()
    local guard = BR.wake_guard or rawget(_G, "InteractablesBedWakeGuardV1")
    if type(guard) ~= "table" then return end
    BR.wake_guard = guard
    local now = os.clock()
    if now - (tonumber(guard.at) or now) > 300.0 then
        BR.clear_wake_guard("bed rest: stale post-rest wake guard expired")
        return
    end
    local loading = _loading()
    local time_skip = _br_tsm_running()
    local busy_now = time_skip
    local menu = _menu_open()
    local interacting = _br_interacting()
    local wait_end = _player_fsm_has_node("WaitEndJack")
    local jacked = nil
    pcall(function()
        local ch = _player()
        if ch then jacked = ch:call("get_IsJacked") == true end
    end)
    local motion_bank, motion_id = nil, nil
    pcall(function()
        local motion = _st_motion()
        local layer = motion and motion:call("getLayer", 0)
        if layer then
            motion_bank = tonumber(layer:call("get_MotionBankID"))
            motion_id = tonumber(layer:call("get_MotionID"))
        end
    end)
    local state = _br_inn_state(guard.fm)
    local bed_state = _br_bed_state(guard.bed)
    local transition = BR.transition
    if busy_now then
        guard.saw_busy = true
        guard.last_busy_at = now
        BR.wake_mask_fade_at = nil
        BR.wake_mask_until = math.max(tonumber(BR.wake_mask_until) or 0, now + 20.0)
    end
    if state == 26 then guard.saw_complete = true end
    local committed = guard.committed == true
        or busy_now or state == 26 or bed_state == 3
        or (transition and (transition.saw_sleep == true
            or transition.saw_inn_progress == true))
    if committed and guard.committed ~= true then
        guard.committed = true
        guard.committed_at = now
        _st_log("bed rest: post-rest wake guard observed the native rest cycle")
    end
    if guard.committed ~= true then
        if not transition and interacting == false and not menu
                and _player_fsm_has_node("NormalLocomotion")
                and now - (tonumber(guard.at) or now) >= 1.5 then
            BR.clear_wake_guard("bed rest: wake guard released after cancelled rest")
        end
        return
    end
    if busy_now or loading or menu then return end
    local post_busy = guard.saw_busy == true and guard.last_busy_at ~= nil
        and now - (tonumber(guard.last_busy_at) or now) >= 0.35
    local wake_window = post_busy
    if wake_window then
        if interacting ~= false then return end
        if guard.recovery_started ~= true then
            guard.recovery_started = true
            guard.recovery_at = now
            guard.attempts = 0
            guard.last_attempt_at = nil
            guard.normal_since = nil
            BR.native_exit_pending = nil
            BR.native_exit_active = nil
            BR.wake_mask_fade_at = nil
            BR.wake_mask_until = now + 8.25
        end
        local recovery_age = now - (tonumber(guard.recovery_at) or now)
        local normal = jacked == false and not wait_end
            and motion_bank == 0 and motion_id == 1
            and _player_fsm_has_node("NormalLocomotion")
        if normal then
            guard.normal_since = guard.normal_since or now
            if now - (tonumber(guard.normal_since) or now) >= 0.35 then
                if BR.transition then
                    BR.transition.keep_lie_on_clear = false
                    _br_clear_transition("bed rest: isolated wake recovery completed")
                end
                BR.clear_wake_guard("bed rest: player returned stably to normal locomotion")
                return
            end
        else
            guard.normal_since = nil
        end
        local stuck = jacked == true or wait_end
        if stuck and (tonumber(guard.attempts) or 0) < 4
                and (not guard.last_attempt_at
                or now - (tonumber(guard.last_attempt_at) or 0) >= 0.5) then
            guard.last_attempt_at = now
            guard.attempts = (tonumber(guard.attempts) or 0) + 1
            _st_restore_player_after_native_exit(
                "bed rest isolated wake attempt " .. tostring(guard.attempts),
                jacked == true)
        end
        if recovery_age >= 8.0 then
            if BR.transition then
                BR.transition.keep_lie_on_clear = false
                _br_clear_transition("bed rest: isolated wake recovery timed out safely")
            end
            _st_restore_player_after_native_exit("bed rest final isolated wake attempt",
                jacked == true)
            BR.clear_wake_guard("bed rest: wake mask released at the safe timeout")
        end
        return
    end
    if now - (tonumber(guard.committed_at or guard.at) or now) > 45.0 then
        BR.clear_wake_guard("bed rest: post-rest wake guard ended without a completed native time-skip")
    end
end
local function _br_restore_home(reason)
    local override = BR.home_override or rawget(_G, "InteractablesHomeBedOverrideV2")
    if not override then return true end
    local restored, err = pcall(function()
        override.bed:set_field("IsUseMyRoom", override.value == true)
    end)
    if restored then
        BR.home_override = nil
        _G.InteractablesHomeBedOverrideV2 = nil
    end
    local trace = rawget(_G, "InteractablesHomeBedTrace")
    if type(trace) == "table" then
        trace.after_exit = _br_native_state(override.bed)
        trace.restore_ok, trace.restore_error = tostring(restored), tostring(err)
    end
    _st_log("home bed: home flag " .. (restored and "restored after "
        .. tostring(reason or "authored exit") or ("restore FAILED: " .. tostring(err))))
    return restored
end
local function _br_arm_native_rest(sess, now)
    local bed = sess and sess.rec and sess.rec.owner
    local io = sess and sess.io
    local param = BR.param
    local player = _player()
    if not _managed(param) then
        local own
        param, own = _br_session_param(sess)
        BR.param, BR.own = param, own
        if _managed(param) then
            _st_log("bed rest: rebuilt wake parameter at hand-off")
        end
    end
    if not _managed(bed) and _managed(io) then
        pcall(function()
            local go = io:call("get_Owner")
            if not go then go = io:get_field("<Owner>k__BackingField") end
            bed = go and go:call("getComponent(System.Type)", sdk.typeof("app.Gm51_115"))
        end)
        if _managed(bed) and sess and sess.rec then sess.rec.owner = bed end
    end
    if not _managed(io) or not _managed(param) or not _managed(player) then
        _st_log(string.format(
            "bed rest: hand-off refused (owner=%s interaction=%s player=%s wake=%s)",
            tostring(_managed(bed)), tostring(_managed(io)), tostring(_managed(player)),
            tostring(_managed(param))))
        return false
    end
    local original_param, original_use = nil, nil
    local my_room_capable = false
    if _managed(bed) then
        original_param = _bed_inn(bed)
        pcall(function() original_use = bed:get_field("IsUseMyRoom") == true end)
        pcall(function()
            local td = bed:get_type_definition()
            if td and tostring(td:get_full_name()) == "app.Gm51_115" then
                my_room_capable = true
            elseif td then
                for _, method in ipairs(td:get_methods() or {}) do
                    if method:get_name() == "setMyRoomState" then
                        my_room_capable = true
                        break
                    end
                end
            end
        end)
    end
    local fm = sdk.get_managed_singleton("app.FacilityManager")
    if not _managed(fm) then
        _st_log("bed rest: FacilityManager was unavailable; still lying normally")
        return false
    end
    if not my_room_capable then
        _st_log("bed rest: this sheet has no Gm51_115 state machine; native rest refused safely")
        return false
    end
    local promoted = not _managed(original_param)
    if promoted then
        _st_log("bed rest: promoting parameterless Gm51_115 through its native My Room cycle")
    end
    local override = BR.home_override or rawget(_G, "InteractablesHomeBedOverrideV2")
    if override and _addr(override.bed) == _addr(bed) then
        original_use = override.value == true
    end
    if my_room_capable then
        _st_log("bed rest: settled lying position retained; wake heading aligned to bed transform")
    end
    BR.transition = {
        phase = "native_state_pending", at = now, until_at = now + 240.0,
        fm = fm, bed = bed, io = io,
        point_no = sess and sess.point_no or 0,
        original_param = original_param, original_use = original_use,
        param = param, restore_param = true, fields_applied = false,
        promoted = promoted,
        initial_state = _br_inn_state(fm),
        initial_bed_state = _br_bed_state(bed),
        saw_open = true, saw_state = false, saw_menu = false, saw_busy = false,
        keep_lie_on_clear = true,
    }
    _G.InteractablesNativeBedRestV3 = BR.transition
    BR.handoff_until = now + 1.5
    _G.Interactables_rest_transition = true
    _G.Interactables_bed_active = true
    _br_clear_rest_prompt()
    _st_log("bed rest: native My Room menu state queued on the live lying interaction")
    return true
end
local function _br_tick()
    local now = os.clock()
    if not BR.bootstrap_checked then
        local player_ready = _managed(_player())
        local inherited = nil
        pcall(function()
            local a = _active_native()
            if a and a.rec and a.rec.kind == "bed" then inherited = a end
        end)
        if inherited then
            BR.bootstrap_checked = true
            _G.Interactables_bed_active = true
            _st_log("bed: inherited lying session adopted after script reload")
        elseif player_ready then
            BR.bootstrap_checked = true
        end
    end
    local override = BR.home_override or rawget(_G, "InteractablesHomeBedOverrideV2")
    local transition = BR.transition
    if BR.bootstrap_checked and not override and not transition then return end
    local open = _br_interacting()
    if override then
        BR.home_override = override
        if open == true then override.saw_open = true end
    end
    if override and override.saw_open and open == false then
        _br_restore_home("authored A get-up")
        _G.Interactables_bed_active = false
    end
    if transition then
        if transition.phase == "generic_dialog_pending" then
            if now - (tonumber(transition.at) or now) >= 3.0 then
                _br_clear_transition("bed rest: native dialog did not load; still lying normally")
            end
            return
        end
        if transition.phase == "generic_dialog" then
            local choice = _br_dialog_choice(transition, now)
            if choice == "cancel" then
                _br_dialog_close()
                _br_clear_transition("bed rest: Morning/Nightfall choice cancelled")
            elseif choice ~= nil then
                _br_dialog_close()
                transition.chosen_morning = choice == true
                transition.phase = "generic_start_pending"
                transition.at = now
                _st_log("bed rest: " .. (choice and "Morning" or "Nightfall")
                    .. " chosen; native facility rest queued")
            elseif now - (tonumber(transition.dialog_opened_at) or now) >= 60.0 then
                _br_clear_transition("bed rest: Morning/Nightfall dialog timed out")
            end
            return
        end
        if transition.phase == "generic_start_pending" then
            if now - (tonumber(transition.at) or now) >= 2.0 then
                _br_clear_transition("bed rest: native FacilityManager request never ran; still lying normally")
            end
            return
        end
        if transition.phase == "native_state_pending" then
            if now - (tonumber(transition.at) or now) >= 2.0 then
                _br_clear_transition("bed rest: native menu request never reached the game update thread; still lying normally")
            end
            return
        end
        if transition.phase == "native_menu" then
            local tsm_running = _br_tsm_running()
            local loading = _loading()
            local menu = _menu_open()
            local busy = tsm_running or loading or menu
            if menu then transition.saw_menu = true end
            if tsm_running then
                transition.saw_busy = true
                transition.quiet_at = nil
            end
            local state = _br_inn_state(transition.fm)
            if state ~= transition.initial_state then transition.saw_state = true end
            if state ~= nil and state ~= 0 and state ~= transition.initial_state then
                transition.saw_inn_progress = true
            end
            if state ~= transition.last_inn_state then
                transition.last_inn_state = state
                _st_log("bed rest: native inn state " .. tostring(state))
            end
            if transition.saw_inn_progress and state == 0 then
                _br_restore_transition_fields(transition)
            end
            local bed_state = _br_bed_state(transition.bed)
            if bed_state ~= transition.initial_bed_state then transition.saw_state = true end
            if bed_state == 2 then transition.saw_menu_state = true end
            if bed_state == 3 then transition.saw_sleep = true end
            local wake = BR.wake_guard or rawget(_G, "InteractablesBedWakeGuardV1")
            if type(wake) == "table" and wake.recovery_started == true then
                return
            end
            local facility_started = transition.saw_sleep or transition.saw_busy
                or transition.saw_inn_progress
            if not facility_started and (transition.saw_menu or transition.saw_menu_state)
                    and not menu and open == false then
                transition.cancel_quiet_at = transition.cancel_quiet_at or (now + 0.75)
            else
                transition.cancel_quiet_at = nil
            end
            if transition.cancel_quiet_at and now >= transition.cancel_quiet_at then
                _br_clear_transition("bed rest: native rest menu cancelled")
                return
            end
            local facility_complete = _br_inn_ended(transition.fm)
                or state == 26
                or (transition.saw_inn_progress and state == 0)
            local returned_idle = transition.saw_state and state == 0 and open == false
                and not menu and now - (tonumber(transition.entry_at) or now) >= 3.0
            local returned_from_busy = transition.saw_busy and not busy and open == false
                and not menu and now - (tonumber(transition.entry_at) or now) >= 3.0
            if transition.saw_busy and not busy and facility_complete then
                transition.quiet_at = transition.quiet_at or (now + 1.5)
            elseif transition.saw_busy and (returned_idle or returned_from_busy) then
                transition.quiet_at = transition.quiet_at or (now + 1.5)
            elseif busy or not facility_complete then
                transition.quiet_at = nil
            end
            if transition.quiet_at and now >= transition.quiet_at then
                transition.keep_lie_on_clear = false
                _br_clear_transition("bed rest: native FacilityManager rest completed cleanly")
                _st_restore_player_after_native_exit("bed rest", true)
                return
            end
            if now >= (tonumber(transition.until_at) or (now + 1.0)) then
                transition.keep_lie_on_clear = false
                _br_clear_transition("bed rest: native facility flow timed out; transition guard released")
                _st_restore_player_after_native_exit("bed rest timeout", true)
                return
            end
            return
        end
        _br_clear_transition("bed rest: unknown transition state discarded")
        return
    end
end
local BR_START_INN_METHOD = nil
local function _br_start_inn_method()
    if BR_START_INN_METHOD then return BR_START_INN_METHOD end
    pcall(function()
        local td = sdk.find_type_definition("app.FacilityManager")
        for _, method in ipairs(td and td:get_methods() or {}) do
            if method:get_name() == "startInn" and method:get_num_params() == 6 then
                BR_START_INN_METHOD = method
                break
            end
        end
    end)
    return BR_START_INN_METHOD
end
local function _install_inn_hook()
    if _G.__II_innhook then return end
    local m = _br_start_inn_method()
    if not m then return end
    _G.__II_innhook = true
    pcall(function()
        sdk.hook(m,
            function(args)
                pcall(function()
                    _st_log("[II-DIAG] NATIVE FacilityManager.startInn CALLED (home-bed sleep)")
                    for i = 2, 7 do
                        local a = args[i]
                        local desc = tostring(a)
                        pcall(function()
                            if a ~= nil then
                                local mo = sdk.to_managed_object(a)
                                if mo and mo.get_type_definition then
                                    desc = tostring(mo:get_type_definition():get_full_name())
                                end
                            end
                        end)
                        _st_log("  startInn arg" .. i .. " = " .. desc)
                    end
                    pcall(function()
                        local ip = sdk.to_managed_object(args[5])
                        if ip and ip.add_ref then
                            _G.__II_innawake = ip:add_ref()
                            local td = ip:get_type_definition()
                            _st_log("[II-DIAG] captured InnAwakeParam type=" ..
                                tostring(td and td:get_full_name()))
                            if td then
                                for _, f in ipairs(td:get_fields() or {}) do
                                    local nm = tostring(f:get_name())
                                    local val = "?"
                                    pcall(function() val = tostring(ip:get_field(nm)) end)
                                    _st_log("    InnAwakeParam." .. nm .. " = " .. val)
                                end
                            end
                        end
                    end)
                end)
            end,
            function(ret) return ret end)
        _st_log("[II-DIAG] startInn hook installed (waiting for a home-bed sleep)")
    end)
end
local function _dump_catalogs()
    if _G.__II_catdump then return end
    _G.__II_catdump = true
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GenerateManager")
        local ctrl = gm and gm:get_field("_CatalogCtrl")
        if not ctrl then _st_log("[II-DIAG] catalogs: _CatalogCtrl nil") return end
        local td = ctrl:get_type_definition()
        _st_log("[II-DIAG] catalogs: _CatalogCtrl type=" .. tostring(td and td:get_full_name()))
        for _, f in ipairs(td and td:get_fields() or {}) do
            local nm = tostring(f:get_name())
            local ty = "?"
            pcall(function() ty = tostring(f:get_type():get_full_name()) end)
            local cnt = "n/a"
            pcall(function()
                local cat = ctrl:get_field(nm)
                local dict = cat and cat:get_field("<MergedCatalog>k__BackingField")
                if dict then cnt = tostring(dict:call("get_Count")) end
            end)
            _st_log("[II-DIAG]   catalog field " .. nm .. " : " .. ty .. "  merged=" .. cnt)
        end
    end)
end
local function _install_interact_end_probe()
    if _G.__II_endprobe then return end
    _G.__II_endprobe = true
    local names = { endInteract = true, continueInteract = true,
        endInteractForSystem = true }
    for _, tname in ipairs({ "app.InteractManager", "app.InteractiveObject" }) do
        pcall(function()
            local td = sdk.find_type_definition(tname)
            for _, m in ipairs(td and td:get_methods() or {}) do
                local nm = tostring(m:get_name() or "")
                if names[nm] then
                    local np = 0
                    pcall(function() np = tonumber(m:get_num_params()) or 0 end)
                    local ptypes = {}
                    pcall(function()
                        for _, p in ipairs(m:get_param_types() or {}) do
                            ptypes[#ptypes + 1] = tostring(p:get_full_name())
                        end
                    end)
                    local label = tname .. "." .. nm .. "(" .. table.concat(ptypes, ",") .. ")"
                    if tname == "app.InteractManager" and nm == "endInteract" and not _G.__II_endm then
                        _G.__II_endm, _G.__II_endm_t = m, ptypes[1] or ""
                    end
                    if tname == "app.InteractiveObject" and nm == "endInteractForSystem"
                            and not _G.__II_endfs then
                        _G.__II_endfs, _G.__II_endfs_t = m, ptypes
                    end
                    local is_cont = (tname == "app.InteractManager" and nm == "continueInteract")
                    if is_cont then pcall(function()
                        sdk.hook(m, nil,
                            function(ret)
                                if is_cont and BR.want_end_interact and _G.__II_endm then
                                    BR.want_end_interact = false
                                    pcall(function()
                                        local io = ST.session and ST.session.io
                                        local pt = (ST.session and tonumber(ST.session.point_no)) or 0
                                        if _G.__II_endfs and io then
                                            local ok1, r1 = pcall(function()
                                                return _G.__II_endfs:call(io, pt, nil)
                                            end)
                                            _st_log("[II-DIAG] GETUP: io.endInteractForSystem(" .. pt
                                                .. ", nil) -> ok=" .. tostring(ok1) .. " ret=" .. tostring(r1))
                                        else
                                            _st_log("[II-DIAG] GETUP: no endInteractForSystem/io available")
                                        end
                                        local mgr = sdk.get_managed_singleton("app.InteractManager")
                                        local ok, r = pcall(function() return _G.__II_endm:call(mgr, nil) end)
                                        _st_log("[II-DIAG] GETUP: mgr.endInteract(nil) -> ok=" .. tostring(ok)
                                            .. " ret=" .. tostring(r))
                                    end)
                                    BR.want_end_at = nil
                                end
                                return ret
                            end)
                        _st_log("[Interactables] keyboard bed-exit bridge hooked " .. label)
                    end) end
                end
            end
        end)
    end
end
re.on_application_entry("UpdateBehavior", function()
    if M.master == false then return end
    pcall(_install_inn_hook)
    pcall(_dump_catalogs)
    local native_exit = BR.native_exit_pending
    if native_exit then
        BR.native_exit_pending = nil
        local player = _player()
        local mgr = _managed(player) and sdk.get_managed_singleton("app.InteractManager") or nil
        local active = nil
        pcall(function()
            active = _get_active_interact(mgr, player)
        end)
        local ran, result, route = false, nil, "unavailable"
        if _managed(active) then
            route = "AdjustJack.release"
            ran = pcall(function() _st_release_hard("bed authored get-up", nil) end)
            result = ran
        end
        native_exit.ran_at = os.clock()
        native_exit.ok = ran == true
        native_exit.route = route
        native_exit.result = result
        BR.native_exit_active = native_exit
    end
    local transition = BR.transition
    if not transition then return end
    local phase = transition.phase
    if phase ~= "native_state_pending" and phase ~= "generic_dialog_pending"
            and phase ~= "generic_start_pending" then return end
    local player = _player()
    local mgr = _managed(player) and sdk.get_managed_singleton("app.InteractManager") or nil
    local exact_bed, interacting = false, false
    pcall(function()
        interacting = mgr:call("isInteracting(app.Character)", player) == true
        local active = _get_active_interact(mgr, player)
        local point = active and active:get_field("Point")
        local active_io = point and point:get_field("Object")
        exact_bed = active_io and _addr(active_io) == _addr(transition.io) or false
    end)
    local target_ok = transition.generic == true
        or _managed(transition.bed)
    if not (interacting and exact_bed and target_ok and _managed(transition.param)) then
        _br_clear_transition("bed rest: live-bed revalidation refused the target; still lying normally")
        return
    end
    if phase == "generic_dialog_pending" then
        if not _br_dialog_show(transition) then return end
        transition.phase = "generic_dialog"
        transition.entry_at = os.clock()
        transition.saw_menu = true
        _G.Interactables_bed_active = true
        _br_clear_rest_prompt()
        _st_log("bed rest: ordinary-bed Morning/Nightfall dialog opened")
        return
    end
    if phase == "generic_start_pending" then
        local method = _br_start_inn_method()
        if not method or not _managed(transition.fm) then
            _br_clear_transition("bed rest: native FacilityManager.startInn was unavailable; still lying normally")
            return
        end
        local ran, accepted = pcall(function()
            return method:call(transition.fm, transition.chosen_morning == true, 0,
                transition.param, 1857826560, nil, 1)
        end)
        local accepted_ok = accepted == true or tonumber(accepted) == 1
        if not ran or not accepted_ok then
            local failure = ran and ("startInn returned " .. tostring(accepted))
                or tostring(accepted)
            _br_clear_transition("bed rest: native FacilityManager rejected ordinary-bed rest: "
                .. tostring(failure))
            return
        end
        local now = os.clock()
        transition.phase = "native_menu"
        transition.entry_at = now
        transition.until_at = now + 240.0
        transition.keep_lie_on_clear = true
        local state = _br_inn_state(transition.fm)
        transition.saw_state = state ~= transition.initial_state
        transition.saw_inn_progress = state ~= nil and state ~= 0
            and state ~= transition.initial_state
        transition.saw_busy = _br_tsm_running()
        transition.saw_menu = true
        _G.Interactables_bed_active = true
        BR.arm_wake_guard(transition, now, true)
        _st_log("bed rest: ordinary bed entered native FacilityManager rest")
        return
    end
    local ran, failure = pcall(function()
        transition.fields_applied = true
        if not _bed_set_inn(transition.bed, transition.param) then
            error("InnParam setter unavailable")
        end
        transition.bed:set_field("IsUseMyRoom", true)
        transition.bed:call("setMyRoomState(app.Gm51_115.MyRoomStateKind)", 2)
    end)
    if not ran then
        _br_clear_transition("bed rest: native Morning/Nightfall menu FAILED safely: "
            .. tostring(failure))
        return
    end
    local now = os.clock()
    transition.phase = "native_menu"
    transition.entry_at = now
    transition.until_at = now + 240.0
    transition.keep_lie_on_clear = transition.promoted == true
    transition.saw_state = _br_bed_state(transition.bed) ~= transition.initial_bed_state
    transition.saw_menu_state = _br_bed_state(transition.bed) == 2
    transition.saw_menu = _menu_open()
    transition.saw_busy = _br_tsm_running()
    _G.Interactables_bed_active = true
    _br_clear_rest_prompt()
    BR.arm_wake_guard(transition, now, false)
    _st_log("bed rest: native Morning/Nightfall menu requested on the live lying interaction")
end)
local function _st_frame()
    if ST.session or ST.pending or (TL and TL.act) or ST.cam_base ~= nil
            or rawget(_G, "InteractablesDyeUIOpen") == true then
        pcall(_st_cam_tick)
    end
    if not ST.any_activity_enabled() and M.native_beds == false then
        ST.session, ST.pending = nil, nil
        return
    end
    local now = os.clock()
    if now - (tonumber(ST.jack_watch_at) or 0) >= 0.5 then
        ST.jack_watch_at = now
        local jacked = false
        pcall(function() jacked = _player():call("get_IsJacked") == true end)
        if jacked and not ST.jack_was then
            local a = nil; pcall(function() a = _active_native() end)
            local tl = TL and TL.act and TL.act.key or nil
            _st_log(string.format("tool jack watch: jacked; active=%s kind=%s session=%s toolDrive=%s",
                tostring(a and a.key), tostring(a and a.rec and a.rec.kind),
                tostring(ST.session and ST.session.key), tostring(tl)))
            if not ST.holder_probe then ST.holder_probe = { at = now + 1.5, key = (a and a.key) or tl or "jack" } end
        elseif not jacked and ST.jack_was then
            _st_log("tool jack watch: released")
        end
        ST.jack_was = jacked
    end
    if ST.holder_probe and now >= ST.holder_probe.at then
        local hp = ST.holder_probe; ST.holder_probe = nil
        pcall(function()
            local ch = _player()
            local human = ch and ch:call("get_Human")
            local holder = human and human:call("get_GimmickHolder")
            if not holder then _st_log("tool holder probe " .. tostring(hp.key) .. ": no GimmickHolder") return end
            local pick = holder:get_field("PickableObject")
            local eq = holder:get_field("EquipItem")
            local ctx = holder:get_field("Context")
            local pid = pick and tonumber(pick:get_field("EquipID"))
            local cid = ctx and tonumber(ctx:get_field("EquipItemID"))
            local drawn = holder:get_field("IsDrawEquipItem")
            local self_draw = nil
            pcall(function() self_draw = eq and eq:call("get_DrawSelf") end)
            pcall(function()
                local parts = {}
                local function f(name, fn) local ok, v = pcall(fn); parts[#parts + 1] = name .. "=" .. tostring(ok and v or ("ERR")) end
                f("HasEquipItem", function() return holder:call("get_HasEquipItem") end)
                f("Preparing", function() return holder:get_field("IsPreparingEquipItem") end)
                f("Prepared", function() return holder:get_field("IsPreparedEquipItem") end)
                f("HoldObjects", function() local l = holder:get_field("HoldObjects"); return l and l:call("get_Count") end)
                if pick then
                    f("pick.name", function() return pick:call("get_GameObject"):call("get_Name") end)
                    f("pick.EquipObj", function() local e = pick:get_field("EquipObj"); return e and _valid(e) and e:call("get_Name") or tostring(e) end)
                    f("pick.IsJackNow", function() return pick:get_field("IsJackNow") end)
                    f("pick.MotionID", function() return pick:call("get_EquipItemMotionID") end)
                    f("pick.type", function() return pick:get_type_definition():get_full_name() end)
                    for _, fld in ipairs({ "_HasEquip", "IsPlayer", "Droppable", "Group", "Order", "ActStart", "ActEnd",
                            "StartActName", "EndActName", "IsEnableConstraint", "_UseDrawCheck", "IsAutoEndInteract",
                            "<IsSwitchGameObjectDraw>k__BackingField", "<IsInfinity>k__BackingField" }) do
                        f("pick." .. fld:gsub("[<>]", ""):gsub("k__BackingField", ""), function() return pick:get_field(fld) end)
                    end
                    f("pick.TargetChara", function() return pick:get_field("TargetChara") ~= nil end)
                end
                _st_log("tool holder detail " .. tostring(hp.key) .. ": " .. table.concat(parts, " "))
                if pick and not _G.__II_pickfields then
                    _G.__II_pickfields = true
                    local names = {}
                    local td = pick:get_type_definition()
                    while td and #names < 80 do
                        for _, fl in ipairs(td:get_fields() or {}) do names[#names + 1] = fl:get_name() end
                        td = td:get_parent_type()
                        if td and td:get_full_name():find("^via%.") then break end
                    end
                    _st_log("tool pickable fields: " .. table.concat(names, ","))
                end
            end)
            _st_log(string.format("tool holder probe %s: pickable=%s pickEquipID=%s equipItem=%s ctxEquipItemID=%s IsDrawEquipItem=%s DrawSelf=%s jacked=%s",
                tostring(hp.key), tostring(pick ~= nil), tostring(pid), tostring(eq ~= nil), tostring(cid),
                tostring(drawn), tostring(self_draw), tostring(ch:call("get_IsJacked"))))
        end)
    end
    if ST.dye_exit_watch and now >= ST.dye_exit_watch.at then
        local q = ST.dye_exit_watch
        q.samples = q.samples + 1
        q.at = now + 3
        pcall(function()
            _st_log("menu state after dye #" .. q.samples .. ": " .. ST.compat32.menu_state(
                _player(), sdk.get_managed_singleton("app.GuiManager")))
        end)
        if q.samples >= 3 then ST.dye_exit_watch = nil end
    end
    local lying = ST.session and ST.session.rec and ST.session.rec.kind == "bed"
    local down
    if lying then
        down = _interact_down() or _binding_down("east") or _action_or_binding({ "Dash", "KeepDash" }, "shift")
    else
        down = _stop_down()
    end
    local kill = _binding_down(M.stop_bind or "backspace")
    local jump = _action_or_binding("Jump", M.rest_bind or "space")
    if lying then
        jump = jump or _binding_down(M.rest_bind or "space") or _binding_down("cross")
        if ST.bed_input_reset ~= ST.session then ST.bed_input_reset = ST.session; ST.jump_prev = false end
    end
    local edge_btn  = down and not ST.prev
    local edge_kill = kill and not ST.kill_prev
    local edge_jump = jump and not ST.jump_prev
    ST.prev, ST.kill_prev, ST.jump_prev = down, kill, jump
    if ST.anvil_ui_pending and (edge_kill or M.anvil_upgrade==false or M.master==false
            or now-ST.anvil_ui_pending.started_at>12) then
        ST.anvil_ui_pending=nil
        ST.notice="Enhancement cancelled; normal movement was not ready or request was cancelled."
        _st_log("anvil: pending enhancement cancelled")
    end
    if BR.transition or now < (tonumber(BR.handoff_until) or 0) then return end
    if edge_btn and not edge_kill and not ST.pending and not ST.anvil_ui_pending
            and M.anvil_upgrade ~= false and ST.is_anvil_session(ST.session)
            and now - (tonumber(ST.session.since) or now) > 1.2 then
        if ST.anvil_context_mark then ST.anvil_context_mark("anvil exit requested") end
        _st_log("anvil: Stop captured; enhancement disabled, no request queued")
        _st_release("button", ST.session.io)
        return
    end
    if rawget(_G,"InteractablesTemperExitRequest") then
        local request=_G.InteractablesTemperExitRequest
        _G.InteractablesTemperExitRequest=nil
        if ST.session and ST.session.token==request.token
                and ST.is_anvil_session(ST.session) and now-request.at<2 then
            _st_release("tempering cancelled",ST.session.io)
            return
        end
    end
    if rawget(_G, "InteractablesDyeExitRequest") then
        local request = _G.InteractablesDyeExitRequest
        _G.InteractablesDyeExitRequest = nil
        if ST.session and ST.session.token == request.token
                and ST.session.key == "gm50_052_1" and now - request.at < 2 then
            ST.last_dye_at = now
            pcall(function()
                _st_log("menu state at dye Done: " .. ST.compat32.menu_state(
                    _player(), sdk.get_managed_singleton("app.GuiManager")))
            end)
            ST.dye_exit_watch = { at = now + 0.5, samples = 0 }
            _st_release("dye Done", ST.session.io)
            return
        end
    end
    if ST.anvil_ui_pending and not ST.pending and not ST.session
            and now >= (tonumber(ST.anvil_ui_pending.at) or 0) then
        local q=ST.anvil_ui_pending
        local s=ST.read_anvil_state()
        local result=ST.compat32.anvil_gate(q,now,s)
        if q.last_action~=s.action then
            q.last_action=s.action
            _st_log("anvil: waiting gate action="..tostring(s.action))
        end
        if result=="ready" then
            ST.anvil_ui_pending = nil
            ST.open_anvil_ui(q)
        elseif result=="cancel" then
            ST.anvil_ui_pending=nil
            ST.notice="Enhancement cancelled because player/menu state changed."
            _st_log("anvil: gate cancelled pending enhancement")
        else
            q.at=now+0.1
        end
        return
    end
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
                local jacked = nil
                pcall(function()
                    local ch = _player()
                    jacked = ch and ch:call("get_IsJacked")
                end)
                if jacked == false then
                    ST.pending = nil
                    ST.status = string.format("native interaction/jack released (%s); menu availability not verified",
                        tostring(pend.reason))
                    _st_log(ST.status)
                elseif age > 3.0 then
                    ST.pending = nil
                    ST.status = "Native exit has not released input; no forced jack reset attempted"
                    _st_log(ST.status .. " (" .. tostring(pend.reason) .. ")")
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
        if a and a.key and LOOSE_TOOL_KEYS[a.key] and not ST.session then
            local jacked = false
            pcall(function() jacked = _player():call("get_IsJacked") == true end)
            if not jacked then
                pcall(function()
                    local pick = a.owner_go and a.owner_go:call("getComponent(System.Type)",
                        sdk.typeof("app.GmInteractPickableBase"))
                    if pick then CARRY.ensure_equipment(pick, a.owner_go, a.key) end
                end)
                a = nil
            end
        end
        if _is_station_active(a) then
            local id = _addr(a.io) or tostring(a.key)
            if not ST.session or ST.session.id ~= id then
                local session_key = a.key or (a.rec and (a.rec.prop_key or a.rec.host))
                ST.session = { id = id, rec = a.rec, key = session_key, io = a.io,
                               point_no = a.point_no,
                               host = tostring((a.rec and a.rec.host) or session_key or "?"),
                               since = now }
                ST.session.token = tostring(id) .. ":" .. tostring(now)
                if ST.is_anvil_session(ST.session) then
                    pcall(function()
                        local owner=a.owner_go
                        local p=owner and _upos(owner)
                        local player_pos=_upos(_char_go(_player()))
                        if p and player_pos and (p.x-player_pos.x)^2+(p.y-player_pos.y)^2+(p.z-player_pos.z)^2<9 then
                            ST.session.anvil_anchor={x=p.x,y=p.y,z=p.z}
                        end
                    end)
                end
                if session_key == "gm50_052_1" then
                    ST.last_dye_at = now
                    pcall(function()
                        _st_log("menu state at dye entry: " .. ST.compat32.menu_state(
                            _player(), sdk.get_managed_singleton("app.GuiManager")))
                    end)
                end
                local carry_key = _norm(session_key)
                if carry_key and CARRY_KEYS[carry_key] then
                    CARRY.native_arm_until = now + 3.0
                end
                if a.rec and a.rec.kind == "bed" then
                    _G.Interactables_bed_active = true
                end
                local nice = (session_key and STATIONS[session_key]
                    and STATIONS[session_key].label)
                    or ST.session.host
                if a.rec and a.rec.kind == "bed" then
                    ST.status = "Lying down - A/Jump gets up; B/Interact opens native rest"
                else
                    ST.status = string.format("Working: %s - press Interact (or BACKSPACE) to stop",
                        tostring(nice))
                end
                _logf("station native session begun: %s", ST.session.host)
                _st_log("tool session begun: key=" .. tostring(session_key) .. " host=" .. tostring(ST.session.host))
                ST.holder_probe = { at = now + 1.5, key = session_key }
                local strow = session_key and STATIONS[session_key]
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
                    end
                end
            end
        else
            if ST.session and ST.session.rec and ST.session.rec.kind == "bed"
                    and not BR.transition then
                _G.Interactables_bed_active = false
            end
            ST.session = nil
        end
    end
    if ST.conjured and not ST.session and not ST.pending then
        _st_conjure(ST.conjured, false, true)
        ST.conjured, ST.conj_restage = nil, nil
    end
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
    local sess = ST.session
    if not sess then
        BR.want_end_interact, BR.want_end_at = false, nil
        _br_clear_rest_prompt()
        if edge_kill then
            local open = false
            local active_kind = nil
            pcall(function()
                local ch = _player()
                local mgr = sdk.get_managed_singleton("app.InteractManager")
                open = ch and mgr and mgr:call("isInteracting(app.Character)", ch) == true
                local a = _active_native()
                active_kind = a and a.rec and a.rec.kind
            end)
            if open and active_kind ~= "bed" then
                _st_release("backspace (unclassified interaction)")
            elseif open then
                _st_log("backspace ignored for unclassified lying bed - native owner must exit it")
            end
        end
        return
    end
    pcall(function()
        local IP = _G.IrisPrompt
        if not IP then return end
        local pgo = _char_go(_player())
        local p = pgo and _pos(pgo)
        local bed = sess.rec and sess.rec.kind == "bed"
        if not bed and type(IP.set) == "function" then
            local label = "Stop"
            IP.set("interactables_station", label, 5, 0.05, p, pgo)
        end
        if bed then
            _br_set_rest_prompt("Get Up", sess.rest_ready and "Rest" or nil)
            pcall(function()
                local fsm = pgo and pgo:call("getComponent(System.Type)",
                    sdk.typeof("via.motion.MotionFsm2"))
                local nn = fsm and tostring(fsm:call("getCurrentNodeName", 0))
                if nn and _G.__II_fsmnode ~= nn then
                    _G.__II_fsmnode = nn
                    pcall(function() _st_log("[II-DIAG] bed FSM node: '" .. nn .. "'") end)
                end
                local an = _player_action_name(_player(), 0)
                if an and _G.__II_actname ~= tostring(an) then
                    _G.__II_actname = tostring(an)
                    pcall(function() _st_log("[II-DIAG] bed action: '" .. tostring(an) .. "'") end)
                end
            end)
        end
    end)
    if edge_kill then
        if rawget(_G,"InteractablesTemperUIOpen")==true and ST.is_anvil_session(sess) then return end
        if sess.key == "gm50_052_1" and rawget(_G, "InteractablesDyeUIOpen") == true then
            return
        end
        if sess.rec and sess.rec.kind == "bed" then
            if sess.rest_ready then
                _br_arm_native_rest(sess, now)
            else
                _st_log("bed rest: not ready (wake parameter unavailable or entry still in progress)")
            end
            return
        end
        return _st_release("backspace")
    end
    if sess.rec and sess.rec.kind == "bed" and ST.bed_getup_at and now - ST.bed_getup_at > 1.5 then
        ST.bed_getup_at = nil
        local ok, requested, reason = pcall(ST.compat32.get_up, sess.rec.owner, _player())
        _st_log("bed get-up fallback: " .. tostring(ok and reason or requested)
            .. " (requested=" .. tostring(ok and requested) .. ")")
    end
    if edge_jump and sess.rec and sess.rec.kind == "bed" then
        ST.bed_getup_at = now
        ST.bed_want_end, ST.bed_want_at = true, now
        _st_log("bed get-up: keyboard exit queued for the manager update (pad A trace 01:16 = InteractManager.cancelInteract)")
        return
    end
    if M.bed_rest ~= false and sess.rec and sess.rec.kind == "bed"
            and not sess.rest_asked then
        local lie_age = now - (tonumber(sess.since) or now)
        if lie_age >= 2.0
                and now >= (tonumber(sess.rest_retry_at) or 0) then
            local param, own = _br_session_param(sess)
            if param then
                sess.rest_asked = true
                BR.param, BR.own = param, own
                sess.rest_ready = true
                _st_log("bed rest: sleeper settled; B/Interact or Backspace opens native rest")
            else
                sess.rest_retry_at = now + 5.0
            end
        end
    end
    if edge_btn and now - (tonumber(sess.since) or 0) > 1.2 then
        if rawget(_G,"InteractablesTemperUIOpen")==true and ST.is_anvil_session(sess) then return end
        if sess.key == "gm50_052_1" and rawget(_G, "InteractablesDyeUIOpen") == true then
            return
        end
        if sess.rec and sess.rec.kind == "bed" then
            if sess.rest_ready then
                _br_arm_native_rest(sess, now)
            else
                _st_log("bed rest: not ready (wake parameter unavailable or entry still in progress)")
            end
            return
        end
        return _st_release("button")
    end
end
local publish_at = 0
local function _publish()
    local now = os.clock()
    if now - publish_at < 1.0 then return end
    publish_at = now
    if M.enabled then
        _G.DD2NativeSeats = { owner = "Interactables", version = 1,
                              prefab = M.donor or "gm80_257",
                              chores = M.native_chores == true,
                              beds = M.native_beds == true,
                              t = now }
    else
        _G.DD2NativeSeats = nil
    end
    _G.Interactables_stations_live = ST.any_activity_enabled()
end
local DEFER = {}
local function _defer(fn) DEFER[#DEFER + 1] = fn end
ST.ending_hud32=require("II.EndingNotice32")
ST.ending_notice=ST.ending_hud32.new()
function ST.ending_sample()
    local ch=_player()
    if not ch then return {} end
    local mgr=sdk.get_managed_singleton("app.InteractManager")
    return {actor=_addr(ch),jacked=ch:call("get_IsJacked"),
        interacting=mgr and mgr:call("isInteracting(app.Character)",ch),
        action=_player_action_name(ch,0)}
end
re.on_application_entry("LateUpdateBehavior",function()
    local exit=BR.native_exit_pending or BR.native_exit_active
    local signal=ST.pending and ST.pending.at or (exit and exit.queued_at)
    ST.ending_hud32.tick(ST.ending_notice,os.clock(),M.master~=false and M.ending_hud~=false,
        signal,ST.session~=nil or ST.pending~=nil or (THRONE.near==true and THRONE.occupied==true)
            or _G.Interactables_bed_active==true,
        TL.act~=nil and TL.act.phase=="finish",ST.ending_sample)
end)
re.on_frame(function()
    if M.master == false then return end
    if M.ending_hud~=false then pcall(ST.ending_hud32.draw,ST.ending_notice) end
    pcall(MC.poll_native)
    pcall(_mc_toast_draw)
    pcall(_br_progress_draw)
    do
        local ok, err = pcall(ST.work_buff_draw)
        if not ok and ST.work_draw_error ~= tostring(err) then
            ST.work_draw_error = tostring(err)
            _st_log("work HUD failed: " .. tostring(err))
        end
    end
end)
re.on_application_entry("LateUpdateBehavior", function()
    if #DEFER > 0 then
        local q = DEFER; DEFER = {}
        for _, fn in ipairs(q) do pcall(fn) end
    end
    if M.master == false then
        ST.player_addr = nil
        _G.DD2NativeSeats = nil
        _G.Interactables_stations_live = false
        return
    end
    _publish()
    pcall(BR.wake_guard_tick)
    ST.perf32.call("core._br_tick",_br_tick)
    if BR.transition then return end
    ST.perf32.call("core._tick",_tick)
    ST.perf32.call("core._unlock_tick",_unlock_tick)
    do
        local ok, err = ST.perf32.call("core._st_frame",_st_frame)
        if not ok and ST.frame_error ~= tostring(err) then
            ST.frame_error = tostring(err)
            _st_log("station update failed: " .. tostring(err))
        end
    end
    if ST.notice then _mc_toast(ST.notice); ST.notice = nil end
    do
        local ok, err = ST.perf32.call("core.ST.work_buff_tick",ST.work_buff_tick)
        if not ok and ST.work_tick_error ~= tostring(err) then
            ST.work_tick_error = tostring(err)
            _st_log("work update failed: " .. tostring(err))
        end
    end
    ST.perf32.call("core._interaction_cleanup_tick",_interaction_cleanup_tick)
    do
        local ok, err = ST.perf32.call("core._tl_frame",_tl_frame)
        if not ok and TL.frame_error ~= tostring(err) then
            TL.frame_error = tostring(err)
            _st_log("tool update failed: " .. tostring(err))
        end
    end
    ST.perf32.call("core._carry_tick",_carry_tick)
    ST.hay_gate_tick()
    do
        local ok, err = ST.perf32.call("core.CARRY.present_native",CARRY.present_native)
        if not ok and CARRY.visibility_error ~= tostring(err) then
            CARRY.visibility_error = tostring(err)
            _st_log("tool visibility update failed: " .. tostring(err))
        end
    end
    ST.perf32.call("core._registry_tick",_registry_tick)
    do
    local rack_ok,rack_error=ST.perf32.call("core.vocation_racks",function()
        require('II.VocationRack32').tick({
            down=_stop_down,
            discover_allowed=function()
                return M.enabled~=false and not _loading() and not _menu_open()
            end,
            allowed=function()
                if M.enabled==false then return false,'Interactables disabled' end
                if _loading() then return false,'Game loading' end
                if _menu_open() then return false,'Native menu open' end
                if ST.session or ST.pending then return false,'Another station interaction active' end
                if TL and TL.act then return false,'Work tool action active' end
                if _st_native_busy_read() then return false,'Native interaction has priority' end
                return true
            end,
            overlay=function() return reframework:is_drawing_ui() end,
            player_pos=function() local go=_char_go(_player()); return go and _upos(go) end,
            valid=_valid,pos=_upos,
            anchor_render_pos=function(p)
                local go=_char_go(_player())
                local up,rp=go and _upos(go),go and _pos(go)
                if up and rp then return Vector3f.new(p.x-up.x+rp.x,p.y-up.y+rp.y+1.0,p.z-up.z+rp.z) end
            end,
            render_pos=function(go)
                local p=_pos(go); return p and Vector3f.new(p.x,p.y+1.0,p.z)
            end,
            notice=function(message) ST.notice=tostring(message) end,
        })
    end)
    if not rack_ok and ST.vocation_error~=tostring(rack_error) then
        ST.vocation_error=tostring(rack_error)
        _log('Vocation rack update failed: '..ST.vocation_error)
        if ST.vocation_loaded then ST.vocation_racks.status='Update failed: '..ST.vocation_error end
    end
    end
    do
        local ok, err = ST.perf32.call("core.THRONE.tick",THRONE.tick)
        if not ok and THRONE.error ~= tostring(err) then
            THRONE.error = tostring(err)
            _st_log("throne update failed: " .. tostring(err))
        end
    end
    ST.perf32.call("core._mc_frame",_mc_frame)
    ST.perf32.call("core._pin_frame",_pin_frame)
    _G.Interactables_session_key = ST.session and ST.session.key or nil
    _G.Interactables_session_token = ST.session and ST.session.token or nil
    _G.Interactables_anvil_anchor = ST.session and ST.session.anvil_anchor and
        {token=ST.session.token,position=ST.session.anvil_anchor} or nil
end)
re.on_script_reset(function()
    if THRONE then
        if THRONE.discovery then THRONE.discovery.reset() end
        THRONE.patched_io, THRONE.near, THRONE.ch, THRONE.render_pos = nil, false, nil, nil
        THRONE.io, THRONE.owner, THRONE.seen, THRONE.request = nil, nil, nil, nil
        THRONE.check_at, THRONE.scan_at = 0, 0
    end
    if ST.session or ST.pending or TL.act or MC.stir_until or BR.transition
            or (ST.last_dye_at and os.clock() - ST.last_dye_at < 180) then
        _st_log("script reset: active/recent interaction; actor cleanup skipped outside game update")
        pcall(_save_cfg)
        return
    end
    _G.Interactables_rest_transition = false
    EXIT_RECOVERY.status, EXIT_RECOVERY.pending_at = "not run", nil
    _br_clear_rest_prompt()
    pcall(function()
        local IP = _G.IrisPrompt
        if IP and type(IP.clear) == "function" then IP.clear("interactables_throne") end
    end)
    THRONE.io, THRONE.pos, THRONE.seen, THRONE.prev = nil, nil, nil, false
    THRONE.request = nil
    pcall(function() _tl_stop("script reset") end)
    pcall(function() _mc_stop_stir() end)
    pcall(_mc_close)
    pcall(function() _pin_despawn() end)
    pcall(function() _carry_release() end)
    pcall(ST.tall_visual_clear)
    ST.anvil_ui_pending = nil
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
    pcall(function() _drop_all(true) end)
    pcall(function() _restore_unlocks() end)
    pcall(_save_cfg)
end)
re.on_draw_ui(function()
    if not imgui.tree_node("Immersive Interactables") then return end
    local c
    c, M.master = imgui.checkbox("Enabled", M.master ~= false)
    if c then
        _save_cfg()
        if M.master == false then
            _defer(function() if ST.session then _st_release("master off") end end)
            _defer(function() _tl_stop("master off") end)
            pcall(function() _mc_stop_stir() end)
            pcall(_mc_close)
            ST.wb = nil
            _defer(_pin_despawn)
            _defer(function() _drop_all(true) end)
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
        c, M.ending_hud = imgui.checkbox("Show ending-animation notice (top left)", M.ending_hud ~= false)
        if c then _save_cfg() end
        imgui.text("Interact with:")
        c, M.enabled = imgui.checkbox("Seats - chairs, benches and stools", M.enabled)
        if c then
            _save_cfg()
            if not M.enabled then _defer(function() _drop_all(true) end); _restore_unlocks("seat") end
        end
        M.activity_groups = M.activity_groups or {}
        for _, group in ipairs(ST.groups) do
            local on = M.activity_groups[group.key] ~= false
            c, on = imgui.checkbox(group.label, on)
            if c then
                M.activity_groups[group.key] = on
                ST.restore_disabled_activities()
                _save_cfg()
            end
        end
        c, M.native_chores = imgui.checkbox("Loose tools - carry brooms and pitchforks",
            M.native_chores)
        if c then
            if not M.native_chores then
                _defer(function() _tl_stop("loose tools disabled") end)
                _defer(_carry_release)
                _restore_unlocks("chore", ST.grouped_chore)
            end
            _save_cfg()
        end
        c, M.native_ambient = imgui.checkbox("Ambient actions - lean at tables",
            M.native_ambient == true)
        if c then
            if not M.native_ambient then _restore_unlocks("ambient") end
            _save_cfg()
        end
        imgui.text("Your DD2 Interact control uses things; BACKSPACE is the keyboard fallback")
        if M.native_chores and M.keep_tools ~= false then
            imgui.text("carrying a tool - click the left stick (or BACKSPACE) to put it down")
        end
        if imgui.tree_node("Controls") then
            imgui.text("Keyboard controls follow your DD2 bindings; custom keys are optional.")
            c, M.follow_game_controls = imgui.checkbox(
                "Follow DD2 Interact / Jump bindings automatically", M.follow_game_controls ~= false)
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
            binding_row("stop_bind", "Open rest menu while lying down", "DD2 B / Dash action")
            binding_row("rest_bind", "Get up while lying down", "DD2 Jump / A")
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
        if imgui.button("Stop now") then _defer(function() _st_release("panel") end) end
    elseif ST.pending then
        imgui.text("stopping...")
        imgui.same_line()
        if imgui.button("force it") then
            local p = ST.pending; ST.pending = nil
            _defer(function() _st_release_hard("panel escalation", p and p.rec) end)
        end
    end
    if cat_n == 0 then
        imgui.text("catalog missing - data/Interactables/catalog.json did not load")
    end
    if M.master ~= false and imgui.tree_node("Advanced") then
        if THRONE.discovery then
            imgui.text(string.format("Throne cache: %d scene searches, %d cached checks",
                THRONE.discovery.searches, THRONE.discovery.cache_hits))
        end
        c, M.st_cam = imgui.checkbox("Close-up camera while working", M.st_cam ~= false)
        if c then _save_cfg() end
        if M.st_cam ~= false then
            c, M.st_cam_dist = imgui.slider_float(
                "camera closeness (drag the other way if it zooms out)",
                M.st_cam_dist or -1.2, -3.0, 3.0)
            if c then _save_cfg() end
        end
        if _br_interacting() == true then
            imgui.text("Seat height controls are locked while sitting")
        else
            c, M.seat_y = imgui.slider_float(
                "sitting height (standard seats only)",
                M.seat_y or 0.0, -0.8, 0.8)
            if c then _defer(function() _drop_all(true) end); _save_cfg() end
            local c2
            c2, M.tall_seat_y = imgui.slider_float("tall stool lift (bar stools)", M.tall_seat_y or 0.25, 0.0, 0.8)
            if c2 then _save_cfg() end
        end
        imgui.text("Tall seat: " .. tostring(ST.tall_gate or "idle"))
        c, M.keep_tools = imgui.checkbox(
            "keep hold of tools when you walk away",
            M.keep_tools ~= false)
        if c then
            if M.keep_tools == false then _defer(_carry_release) end
            _save_cfg()
        end
        c, M.work_buffs = imgui.checkbox(
            "45 seconds of active work earns a meal bonus (dyeing excluded)",
            M.work_buffs ~= false)
        if c then _save_cfg() end
        c, M.work_hud = imgui.checkbox("Show work progress and buff messages", M.work_hud ~= false)
        if c then _save_cfg() end
        imgui.text("Hiding this display does not disable buffs. Results disappear after 8 seconds.")
        if M.work_hud ~= false and imgui.tree_node("Work display position") then
            c, M.work_hud_x = imgui.slider_float("Right edge (screen fraction)", M.work_hud_x or 0.98, 0.0, 1.0)
            if c then _save_cfg() end
            c, M.work_hud_y = imgui.slider_float("Top edge (screen fraction)", M.work_hud_y or 0.62, 0.0, 1.0)
            if c then _save_cfg() end
            imgui.tree_pop()
        end
        imgui.text("Anvil upgrades disabled after native crashes. Smithing work/buffs remain available.")
        if M.keep_tools ~= false then
            imgui.text("Carried-object drop: L3 plus the key selected under Controls")
        end
        if imgui.tree_node("Individual activities (untick to turn one off)") then
            for _, group in ipairs(ST.groups) do
                if imgui.tree_node(group.label .. "##activity_list_" .. group.key) then
                    local keys = {}
                    for k, row in pairs(STATIONS) do
                        if row.group == group.key then keys[#keys + 1] = k end
                    end
                    table.sort(keys)
                    for _, k in ipairs(keys) do
                        local on = not (M.st_off or {})[k]
                        c, on = imgui.checkbox(
                            string.format("%s - %s", k, tostring(STATIONS[k].label)), on)
                        if c then
                            M.st_off = M.st_off or {}
                            M.st_off[k] = (not on) and true or nil
                            if not on then
                                ST.restore_disabled_activities()
                            end
                            _save_cfg()
                        end
                    end
                    imgui.tree_pop()
                end
            end
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
    if M.master ~= false and imgui.tree_node("(Experimental)") then
        imgui.text("Off by default. Beds interfere with the game's own rest on some setups.")
        c, M.native_beds = imgui.checkbox("Beds - lie down and rest from the bed", M.native_beds == true)
        if c then
            if not M.native_beds then _restore_unlocks("bed") end
            _save_cfg()
        end
        if M.native_beds == true then
            c, M.bed_rest = imgui.checkbox(
                "offer the native rest menu once you lie down", M.bed_rest ~= false)
            if c then _save_cfg() end
            if M.bed_rest ~= false then
                c, M.bed_rest_anywhere = imgui.checkbox(
                    "Allow resting in non-home beds", M.bed_rest_anywhere ~= false)
                if c then _save_cfg() end
            end
        end
        imgui.tree_pop()
    end
    imgui.tree_pop()
end)
