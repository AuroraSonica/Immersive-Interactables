-- InteractablesDye.lua
-- Dye system for Immersive Interactables (v0.1 dev preview).
-- Tier 1: universal BaseColor tint, per region, persisted in the mod's own JSON
-- and quietly re-applied whenever the game rebuilds equipment meshes.

local CFG = "ImmersiveInteractables/dye_profiles.json"

local DYE = {
    records = {},
    dirty = false,
    tick_at = 0,
    walk = {},
    walk_at = 0,
    mat_cache = {},
    cache_n = 0,
    status = "",
    open_piece = nil,
}

-- multiplicative tints; softened so texture detail survives the multiply
local COLORS = {
    { key = "Red",    v = { 0.85, 0.20, 0.20 } },
    { key = "Green",  v = { 0.25, 0.70, 0.30 } },
    { key = "Blue",   v = { 0.25, 0.35, 0.85 } },
    { key = "Yellow", v = { 0.95, 0.85, 0.30 } },
    { key = "Purple", v = { 0.65, 0.30, 0.80 } },
    { key = "Orange", v = { 0.95, 0.55, 0.20 } },
    { key = "Pink",   v = { 0.95, 0.55, 0.70 } },
    { key = "Teal",   v = { 0.25, 0.75, 0.70 } },
    { key = "Brown",  v = { 0.55, 0.40, 0.28 } },
    { key = "Black",  v = { 0.22, 0.22, 0.24 } },
}

-- only real clothing slots are dyeable; everything else is ignored
local SLOT_LABELS = {
    Helm = "Helm", Mantle = "Mantle", Underwear = "Underwear",
    TopsWb = "Top", TopsBt = "Top (under)", TopsBd = "Body", TopsAm = "Arms",
    TopsWbSub = "Top (inner)", TopsBdSub = "Body (inner)", TopsAmSub = "Arms (inner)",
    PantsWl = "Legs", PantsLg = "Leggings", PantsWlSub = "Legs (inner)",
}

-- station-UI grouping, in the game's own equipment order
local SLOT_CATEGORY = {
    Helm = "Head Armour",
    TopsWb = "Body Armour", TopsBt = "Body Armour", TopsBd = "Body Armour",
    TopsAm = "Body Armour", TopsWbSub = "Body Armour", TopsBdSub = "Body Armour",
    TopsAmSub = "Body Armour",
    PantsWl = "Leg Armour", PantsLg = "Leg Armour", PantsWlSub = "Leg Armour",
    Mantle = "Cloaks", Underwear = "Underwear",
}
local CAT_ORDER = { ["Weapons"] = 1, ["Head Armour"] = 2, ["Body Armour"] = 3,
                    ["Leg Armour"] = 4, ["Cloaks"] = 5, ["Underwear"] = 6 }

local function _load()
    pcall(function()
        local t = json.load_file(CFG)
        if type(t) == "table" then
            if type(t.records) == "table" then DYE.records = t.records end
            if type(t.dye_items) == "table" then DYE.item_ids = t.dye_items end
            if t.consume ~= nil then DYE.consume = t.consume end
        end
    end)
end

local function _save()
    pcall(function() json.dump_file(CFG, { version = 1, records = DYE.records,
        dye_items = DYE.item_ids, consume = DYE.consume }) end)
    DYE.dirty = false
end

local function _player_go()
    local go = nil
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local ch = cm and cm:call("get_ManualPlayer")
        go = ch and ch:call("get_GameObject")
    end)
    return go
end

local function _walk(tf, depth, out, others)
    if not tf or depth > 6 then return end
    pcall(function()
        local child = tf:call("get_Child")
        while child do
            local go = child:call("get_GameObject")
            if go then
                local nm = "?"
                pcall(function() nm = tostring(go:call("get_Name")) end)
                local mesh = nil
                pcall(function()
                    mesh = go:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
                end)
                if SLOT_LABELS[nm] then
                    if mesh then out[#out + 1] = { slot = nm, mesh = mesh } end
                elseif mesh and nm:match("^wp%d") then
                    local vis = false
                    pcall(function() vis = go:call("get_DrawSelf") == true end)
                    if vis then out[#out + 1] = { slot = nm, mesh = mesh, weapon = true } end
                elseif others and mesh then
                    others[nm] = true
                end
                _walk(child, depth + 1, out, others)
            end
            child = child:call("get_Next")
        end
    end)
end

local function _mesh_path(mesh)
    local path = "?"
    pcall(function()
        local res = mesh:call("getMesh")
        if not res then res = mesh:call("get_Mesh") end
        if res then
            local p = nil
            pcall(function() p = res:call("get_ResourcePath") end)
            if not p then pcall(function() p = res:call("ToString()") end) end
            if p then path = tostring(p) end
        end
    end)
    return path
end

-- material layout per mesh instance, cached by address (re-enumerating every
-- refresh would be exactly the per-frame waste class fixed in 1.0.6)
local function _enrich(e)
    local addr = nil
    pcall(function() addr = e.mesh:get_address() end)
    local hit = addr and DYE.mat_cache[addr]
    if hit then
        e.path, e.mats = hit.path, hit.mats
        return
    end
    e.path = _mesh_path(e.mesh)
    e.mats = {}
    pcall(function()
        local n = tonumber(e.mesh:call("get_MaterialNum")) or 0
        for mi = 0, n - 1 do
            local mn = tostring(e.mesh:call("getMaterialName", mi))
            local vi = nil
            local nv = tonumber(e.mesh:call("getMaterialVariableNum", mi)) or 0
            for k = 0, nv - 1 do
                if tostring(e.mesh:call("getMaterialVariableName", mi, k)) == "BaseColor" then
                    vi = k
                    break
                end
            end
            if vi ~= nil then
                e.mats[#e.mats + 1] = { index = mi, name = mn, var = vi }
            end
        end
    end)
    if addr then
        DYE.cache_n = (tonumber(DYE.cache_n) or 0) + 1
        if DYE.cache_n > 200 then DYE.mat_cache, DYE.cache_n = {}, 1 end
        DYE.mat_cache[addr] = { path = e.path, mats = e.mats }
    end
end

-- refresh the worn-equipment snapshot at most every 0.5s
local function _worn(now)
    if now - (tonumber(DYE.walk_at) or 0) < 0.5 and #DYE.walk > 0 then return DYE.walk end
    local pgo = _player_go()
    local tf = pgo and pgo:call("get_Transform")
    if not tf then return DYE.walk end
    local out, others = {}, {}
    _walk(tf, 0, out, others)
    DYE.unlisted = others
    for _, e in ipairs(out) do _enrich(e) end
    DYE.walk, DYE.walk_at = out, now
    return out
end

-- the equipment menu renders a twin named MockupModel_<player go name>,
-- wearing identical mesh paths (proven by data/DyeResearch/preview_hunt.json)
local function _mockup_worn()
    local out = {}
    pcall(function()
        local pgo = _player_go()
        local nm = pgo and tostring(pgo:call("get_Name"))
        if not nm then return end
        local scene = sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
        local mgo = scene and scene:call("findGameObject(System.String)", "MockupModel_" .. nm)
        if not mgo then return end
        _walk(mgo:call("get_Transform"), 0, out)
        for _, e in ipairs(out) do _enrich(e) end
    end)
    return out
end

-- ═══ STATION MANNEQUIN ═══════════════════════════════════════════════════
-- A CloneBuilder double of the player (bestfriendlynpcclone.pfb: the game's own
-- living-NPC-copy prefab, arrives with motion banks) spawned when the station
-- panel opens and welded to the camera so she reads as part of the UI. Her
-- meshes carry the SAME paths as the player's, so the dye heal + hover preview
-- reach her by the existing slot+path+material keys. Laws (2026-09-01):
-- instantiate WITH a folder (folderless = CTD), wake root DrawSelf/UpdateSelf
-- before any transform write, place via set_UniversalPosition(via.Position
-- DOUBLES), never touch her motion banks. Removed on panel close / script reset.
local MQ = { state = nil, pfb = nil, inst = nil, cb = nil, t0 = 0.0, tick = 0.0,
             walk = {}, walk_at = 0.0, idle_done = false }
local MQ_PFB = "appsystem/clone/prefab/bestfriendlynpcclone.pfb"
local function _mq_log(m) pcall(function() log.info("[DyeMannequin] " .. tostring(m)) end) end

local function _mannequin_worn()
    if not (MQ.state == "done" and MQ.inst) then return {} end
    local now = os.clock()
    if now - (tonumber(MQ.walk_at) or 0) < 0.5 and #MQ.walk > 0 then return MQ.walk end
    local out = {}
    pcall(function()
        _walk(MQ.inst:call("get_Transform"), 0, out)
        for _, e in ipairs(out) do _enrich(e) end
        -- borrow the player's slot label for the same mesh path so the dye
        -- records (keyed slot+path+material) and the hover preview reach her
        local by_path = {}
        for _, pe in ipairs(_worn(now)) do
            if pe.path then by_path[pe.path] = pe.slot end
        end
        for _, e in ipairs(out) do
            if e.path and by_path[e.path] then e.slot = by_path[e.path] end
        end
    end)
    MQ.walk, MQ.walk_at = out, now
    return out
end

local function _mq_signature()
    local paths = {}
    for _, e in ipairs(_worn(os.clock())) do
        if e.path then paths[#paths + 1] = e.path end
    end
    table.sort(paths)
    return table.concat(paths, "|")
end

local function _mq_destroy()
    if MQ.inst then
        pcall(function() MQ.inst:call("destroy", MQ.inst) end)
    end
    MQ.inst, MQ.cb, MQ.pfb = nil, nil, nil
    MQ.state, MQ.walk, MQ.idle_done = nil, {}, false
end

local function _mq_park()
    -- panel closed: keep her built, hide her 30m underground, stop welding
    if MQ.state ~= "done" or not MQ.inst then return end
    MQ.parked = true
    pcall(function()
        local pgo = _player_go()
        local up = pgo and pgo:call("get_Transform"):call("get_UniversalPosition")
        if up then
            local vp = ValueType.new(sdk.find_type_definition("via.Position"))
            vp:set_field("x", up.x); vp:set_field("y", up.y - 30.0); vp:set_field("z", up.z)
            MQ.inst:call("get_Transform"):call("set_UniversalPosition", vp)
        end
    end)
end

local MQ_WARM = nil
pcall(function()
    MQ_WARM = sdk.create_instance("via.Prefab"):add_ref()
    pcall(function() MQ_WARM:add_ref_permanent() end)
    pcall(function() MQ_WARM:call(".ctor()") end)
    MQ_WARM:call("set_Path", MQ_PFB)
    pcall(function() MQ_WARM:call("set_Standby", true) end)
end)

local function _mq_start()
    if MQ.state == "done" and MQ.inst then
        -- already built: reuse instantly unless the outfit changed
        if MQ.sig == _mq_signature() then
            MQ.parked = false
            _mq_log("reusing the built mannequin")
            return
        end
        _mq_log("outfit changed: rebuilding")
        _mq_destroy()
    end
    if MQ.state then return end
    MQ.parked = false
    MQ.sig = _mq_signature()
    local ok = pcall(function()
        MQ.pfb = sdk.create_instance("via.Prefab"):add_ref()
        pcall(function() MQ.pfb:add_ref_permanent() end)
        pcall(function() MQ.pfb:call(".ctor()") end)
        MQ.pfb:call("set_Path", MQ_PFB)
        pcall(function() MQ.pfb:call("set_Standby", true) end)
    end)
    if ok and MQ.pfb then
        MQ.state, MQ.t0 = "loading", os.clock()
        _mq_log("start: loading prefab")
    else
        MQ.pfb = nil
        _mq_log("start FAILED: prefab create")
    end
end

local function _region_label(matname)
    local n = tostring(matname or ""):gsub("_[Mm]at$", "")
    local tail = n:match("([%a]+_?%d*)$") or n
    return (tail:gsub("_", " "))
end

local function _read(mesh, mi, vi)
    local out = nil
    pcall(function()
        local f4 = mesh:call("getMaterialFloat4", mi, vi)
        if f4 then out = { f4.x, f4.y, f4.z, f4.w } end
    end)
    return out
end

local function _write(mesh, mi, vi, c)
    return pcall(function()
        mesh:call("setMaterialFloat4", mi, vi, Vector4f.new(c[1], c[2], c[3], c[4] or 1.0))
    end)
end

local function _rec_key(slot, path, matname)
    return slot .. "|" .. path .. "|" .. matname
end

local function _find_record(slot, path, matname)
    for i, r in ipairs(DYE.records) do
        if r.slot == slot and r.path == path and r.mat == matname then return r, i end
    end
    return nil
end

local function _apply_dye(entry, mat, color_key, color, strength)
    local rec = _find_record(entry.slot, entry.path, mat.name)
    if not rec then
        local orig = _read(entry.mesh, mat.index, mat.var) or { 1, 1, 1, 1 }
        rec = { slot = entry.slot, path = entry.path, mat = mat.name, orig = orig }
        DYE.records[#DYE.records + 1] = rec
    end
    local s = tonumber(strength) or tonumber(DYE.strength) or 1.0
    rec.dye = color_key
    rec.color = { color[1] * s, color[2] * s, color[3] * s, 1.0 }
    _write(entry.mesh, mat.index, mat.var, rec.color)
    local back = _read(entry.mesh, mat.index, mat.var)
    local ok = back and math.abs(back[1] - rec.color[1]) < 0.01
    DYE.status = string.format("%s %s dyed %s x%.1f (%s)", entry.slot, _region_label(mat.name),
        color_key, s, ok and "applied" or "WRITE DID NOT STICK")
    _save()
end

local function _remove_dye(entry, mat)
    local rec, idx = _find_record(entry.slot, entry.path, mat.name)
    if not rec then return end
    _write(entry.mesh, mat.index, mat.var, rec.orig or { 1, 1, 1, 1 })
    table.remove(DYE.records, idx)
    DYE.status = string.format("%s %s back to original", entry.slot, _region_label(mat.name))
    _save()
end

-- the self-healing pass: whatever rebuilt or reloaded, put the dye back
local function _reapply_tick()
    local now = os.clock()
    local fl = DYE.flash
    if fl and now > (tonumber(fl.until_at) or 0) then
        pcall(function() _write(fl.mesh, fl.mat, fl.var, fl.restore) end)
        DYE.flash = nil
        fl = nil
    end
    if #DYE.records == 0 then return end
    if now - (tonumber(DYE.tick_at) or 0) < 0.5 then return end
    DYE.tick_at = now
    -- the station UI's live preview owns its regions; healing them would stomp
    -- the hover colour with the saved record within half a second
    local pv = {}
    pcall(function()
        local sui_prev = rawget(_G, "InteractablesDyePreview")
        if sui_prev then
            for _, p in ipairs(sui_prev) do
                local a = nil
                pcall(function() a = p.mesh:get_address() end)
                if a then pv[tostring(a) .. ":" .. tostring(p.mat)] = true end
            end
        end
    end)
    local function heal(list)
        for _, rec in ipairs(DYE.records) do
            if rec.color then
                for _, e in ipairs(list) do
                    if e.slot == rec.slot and e.path == rec.path then
                        for _, m in ipairs(e.mats) do
                            local ea = nil
                            pcall(function() ea = e.mesh:get_address() end)
                            local previewing = ea and pv[tostring(ea) .. ":" .. tostring(m.index)]
                            if m.name == rec.mat and not previewing
                                and not (fl and fl.slot == e.slot and fl.matname == m.name) then
                                local cur = _read(e.mesh, m.index, m.var)
                                if cur and (math.abs(cur[1] - rec.color[1]) > 0.01
                                        or math.abs(cur[2] - rec.color[2]) > 0.01
                                        or math.abs(cur[3] - rec.color[3]) > 0.01) then
                                    _write(e.mesh, m.index, m.var, rec.color)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    heal(_worn(now))
    heal(_mockup_worn())
    heal(_mannequin_worn())
end

re.on_frame(function()
    pcall(_reapply_tick)
end)

re.on_draw_ui(function()
    if not imgui.tree_node("Immersive Dyes (dev preview)") then return end
    if DYE.status ~= "" then imgui.text(DYE.status) end
    imgui.text(string.format("%d dyed regions saved (they survive reloads)", #DYE.records))
    local c
    c, DYE.strength = imgui.slider_float(
        "dye strength (1 = natural, crank it to brighten dark fabric)",
        tonumber(DYE.strength) or 1.0, 1.0, 6.0)
    c, DYE.consume = imgui.checkbox(
        "station dyeing costs dye bowls", DYE.consume ~= false)
    if c then _save() end

    local worn = _worn(os.clock())
    if #worn == 0 then
        imgui.text("no dyeable equipment found yet - move around a moment and reopen")
    end
    for _, e in ipairs(worn) do
        local label = (SLOT_LABELS[e.slot] or e.slot)
        if imgui.tree_node(label .. "##dye_" .. e.slot) then
            for _, m in ipairs(e.mats) do
                if imgui.small_button("?##flash" .. e.slot .. m.name) then
                    local cur = _read(e.mesh, m.index, m.var) or { 1, 1, 1, 1 }
                    DYE.flash = { mesh = e.mesh, mat = m.index, var = m.var,
                                  slot = e.slot, matname = m.name,
                                  until_at = os.clock() + 1.5, restore = cur }
                    _write(e.mesh, m.index, m.var, { 1.0, 0.0, 1.0, 1.0 })
                    DYE.status = "flashing " .. _region_label(m.name) .. " magenta - look!"
                end
                imgui.same_line()
                imgui.text(_region_label(m.name) .. ":")
                for ci, col in ipairs(COLORS) do
                    imgui.same_line()
                    if imgui.small_button(col.key .. "##" .. e.slot .. m.name) then
                        _apply_dye(e, m, col.key, col.v)
                    end
                    if ci == 5 then
                        imgui.text("      ")
                    end
                end
                imgui.same_line()
                if imgui.small_button("Original##" .. e.slot .. m.name) then
                    _remove_dye(e, m)
                end
            end
            imgui.tree_pop()
        end
    end

    if DYE.unlisted and next(DYE.unlisted) then
        local names = {}
        for k in pairs(DYE.unlisted) do names[#names + 1] = k end
        table.sort(names)
        imgui.text("meshes on you the dye panel does not cover: " .. table.concat(names, ", "))
    end

    if imgui.button("Dev: give 10 of each dye bowl") then
        pcall(function()
            DYE.item_ids = DYE.item_ids or {}
            local names = { Red = true, Green = true, Blue = true,
                            Yellow = true, Purple = true }
            local missing = false
            for b in pairs(names) do if not DYE.item_ids[b] then missing = true end end
            if missing then
                local gb = sdk.find_type_definition("app.GUIBase")
                local getname = gb and gb:get_method("getItemName(System.Int32)")
                if getname then
                    for id = 1, 4000 do
                        local ok, nm = pcall(function() return getname:call(nil, id) end)
                        if ok and nm then
                            local base = tostring(nm):match("^(%a+) Dye$")
                            if base and names[base] and not DYE.item_ids[base] then
                                DYE.item_ids[base] = id
                            end
                        end
                    end
                    _save()
                end
            end
            local im = sdk.get_managed_singleton("app.ItemManager")
            local cm = sdk.get_managed_singleton("app.CharacterManager")
            local ch = cm and cm:call("get_ManualPlayer")
            local given = 0
            for b in pairs(names) do
                local id = DYE.item_ids[b]
                if id and im and ch then
                    local ok = pcall(function()
                        im:call("getItem(System.Int32, System.Int32, app.Character)", id, 10, ch)
                    end)
                    if ok then given = given + 1 end
                end
            end
            DYE.counts_at = 0
            DYE.status = "gave 10 bowls of " .. given .. " colours"
        end)
    end

    if imgui.button("Debug: force unpause (if the world sticks frozen)") then
        pcall(function()
            local pm = sdk.get_managed_singleton("app.PauseManager")
            local td = sdk.find_type_definition("app.PauseManager.PauseType")
            local names = {}
            for _, f in ipairs(td:get_fields()) do
                local n = f:get_name()
                if n ~= "value__" then pcall(function() names[n] = f:get_data(nil) end) end
            end
            local t = names.Menu or names.MENU or names.System or names.SYSTEM
                or names.All or names.ALL or 0
            pm:call("requestPause(System.Boolean, app.PauseManager.PauseType, System.String, System.Action)",
                false, t, "InteractablesDye", nil)
            DYE.status = "force unpause sent"
        end)
    end

    if imgui.tree_node("dev: preview instance hunt") then
        imgui.text("Open the EQUIPMENT menu first, then click - result goes to a file for Iris.")
        if imgui.button("hunt the menu preview mannequin") then
            local report = {}
            pcall(function()
                local scene = sdk.call_native_func(
                    sdk.get_native_singleton("via.SceneManager"),
                    sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
                local t = sdk.typeof("app.PartSwapper")
                if not (scene and t) then return end
                local pgo = _player_go()
                local pa = nil
                pcall(function() pa = pgo and pgo:get_address() end)
                local comps = scene:call("findComponents(System.Type)", t)
                local n = 0
                pcall(function() n = tonumber(comps:call("get_Length")) or 0 end)
                if n == 0 then pcall(function() n = tonumber(comps:call("get_Count")) or 0 end) end
                for i = 0, n - 1 do
                    pcall(function()
                        local comp = comps:call("get_Item", i) or comps:get_element(i)
                        local go = comp and comp:call("get_GameObject")
                        if go then
                            local entry = { name = tostring(go:call("get_Name")),
                                            is_player = pa ~= nil and go:get_address() == pa,
                                            slots = {} }
                            local out = {}
                            _walk(go:call("get_Transform"), 0, out)
                            for _, e in ipairs(out) do
                                entry.slots[#entry.slots + 1] =
                                    { slot = e.slot, path = _mesh_path(e.mesh) }
                            end
                            report[#report + 1] = entry
                        end
                    end)
                end
            end)
            pcall(function() json.dump_file("DyeResearch/preview_hunt.json", report) end)
            DYE.status = string.format("preview hunt: %d PartSwapper owners recorded", #report)
        end
        imgui.tree_pop()
    end

    if #DYE.records > 0 then
        if imgui.button("remove ALL dyes") then
            local worn2 = _worn(os.clock())
            for i = #DYE.records, 1, -1 do
                local rec = DYE.records[i]
                for _, e in ipairs(worn2) do
                    if e.slot == rec.slot and e.path == rec.path then
                        for _, m in ipairs(e.mats) do
                            if m.name == rec.mat then
                                _write(e.mesh, m.index, m.var, rec.orig or { 1, 1, 1, 1 })
                            end
                        end
                    end
                end
                table.remove(DYE.records, i)
            end
            _save()
            DYE.status = "all dyes removed"
        end
    end
    imgui.tree_pop()
end)

_load()

-- ===================== DYE STATION ONSCREEN UI =====================
-- Opens over the native dye-cloth session (gm50_052_1). The world is frozen
-- while open (one balanced PauseManager pair) so navigation cannot bark pawn
-- commands or break the station session. draw.* only - no d2d dependency.
-- draw.* colours are ABGR, not ARGB.

local SUI = {
    open = false, want_pause = false, paused = false, pause_type = nil,
    col = 1, gi = 1, ri = 0, di = 1, si = 2,
    nav_at = 0, nav_dir = nil, prev_btn = {},
    sess_since = nil, preview = nil, prev_target = nil,
}

local SHADES = {
    { key = "Light", mul = 1.0 },
    { key = "Rich",  mul = 2.5 },
    { key = "Vivid", mul = 4.0 },
}

-- dye bowl economy: base colours cost their own bowl, mixes cost both, Vivid doubles
local BOWLS = { "Red", "Green", "Blue", "Yellow", "Purple" }
local RECIPES = {
    Red = { "Red" }, Green = { "Green" }, Blue = { "Blue" },
    Yellow = { "Yellow" }, Purple = { "Purple" },
    Orange = { "Red", "Yellow" }, Pink = { "Red", "Purple" },
    Teal = { "Green", "Blue" }, Brown = { "Red", "Green" },
    Black = { "Blue", "Purple" },
}

local function _player_ch()
    local ch = nil
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        ch = cm and cm:call("get_ManualPlayer")
    end)
    return ch
end

-- one-time item id discovery: match the five bowls by localized name
local function _dye_scan_tick()
    DYE.item_ids = DYE.item_ids or {}
    local missing = false
    for _, b in ipairs(BOWLS) do if not DYE.item_ids[b] then missing = true end end
    if not missing then return end
    if DYE.scan_done then return end
    pcall(function()
        local gb = sdk.find_type_definition("app.GUIBase")
        local getname = gb and gb:get_method("getItemName(System.Int32)")
        if not getname then DYE.scan_done = true return end
        local from = tonumber(DYE.scan_at) or 1
        local to = math.min(from + 299, 4000)
        for id = from, to do
            local ok, nm = pcall(function() return getname:call(nil, id) end)
            if ok and nm then
                local s = tostring(nm)
                local base = s:match("^(%a+) Dye$")
                if base and RECIPES[base] and #RECIPES[base] == 1 then
                    DYE.item_ids[base] = id
                end
            end
        end
        DYE.scan_at = to + 1
        if to >= 4000 then
            DYE.scan_done = true
            _save()
        end
    end)
end

local function _dye_counts()
    local now = os.clock()
    if DYE.counts and now - (tonumber(DYE.counts_at) or 0) < 2.0 then return DYE.counts end
    local out = {}
    pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        local ch = _player_ch()
        if not (im and ch) then return end
        for _, b in ipairs(BOWLS) do
            local id = (DYE.item_ids or {})[b]
            if id then
                local n = 0
                pcall(function()
                    n = tonumber(im:call("getHaveNum(System.Int32, app.Character)", id, ch)) or 0
                end)
                out[b] = n
            end
        end
    end)
    DYE.counts, DYE.counts_at = out, now
    return out
end

local function _dye_cost(color_key, shade)
    local recipe = RECIPES[color_key] or {}
    local mult = (shade and shade.key == "Vivid") and 2 or 1
    local cost = {}
    for _, b in ipairs(recipe) do cost[b] = (cost[b] or 0) + mult end
    return cost
end

local function _dye_affordable(color_key, shade)
    if DYE.consume == false then return true end
    local ids = DYE.item_ids or {}
    local counts = _dye_counts()
    for b, n in pairs(_dye_cost(color_key, shade)) do
        if not ids[b] then return true end -- ids unknown: free mode until scan lands
        if (counts[b] or 0) < n then return false end
    end
    return true
end

local function _dye_consume(color_key, shade)
    if DYE.consume == false then return true end
    local ids = DYE.item_ids or {}
    local im = sdk.get_managed_singleton("app.ItemManager")
    local ch = _player_ch()
    if not (im and ch) then return true end
    for b, n in pairs(_dye_cost(color_key, shade)) do
        if ids[b] then
            local ok = pcall(function()
                im:call("deleteItem(System.Int32, System.Int32, app.Character)", ids[b], n, ch)
            end)
            if not ok then return false end
        end
    end
    DYE.counts_at = 0
    return true
end

local DYE_STATION_KEY = "gm50_052_1"

local PAD = { cross = 0x20020, circle = 0x40080, square = 0x40, l2 = 0x200, r2 = 0x800 }

local function _pad_mask()
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
        if dev then
            mask = math.floor(tonumber(dev:call("get_Button")) or 0)
            local ax = nil
            pcall(function() ax = dev:call("get_AxisL") end)
            if ax then SUI.ax, SUI.ay = tonumber(ax.x) or 0, tonumber(ax.y) or 0 end
        end
    end)
    return mask
end

local function _kb(vk)
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

local function _pause_type_value()
    if SUI.pause_type ~= nil then return SUI.pause_type end
    local best = 0
    pcall(function()
        local td = sdk.find_type_definition("app.PauseManager.PauseType")
        local names = {}
        for _, f in ipairs(td:get_fields()) do
            local n = f:get_name()
            if n ~= "value__" then pcall(function() names[n] = f:get_data(nil) end) end
        end
        for _, want in ipairs({ "Menu", "MENU", "System", "SYSTEM", "All", "ALL" }) do
            if names[want] ~= nil then best = names[want] break end
        end
    end)
    SUI.pause_type = best
    return best
end

-- exactly one balanced pause/unpause per open/close, unique reason, same type
local function _apply_pause()
    if SUI.want_pause == SUI.paused then return end
    local on = SUI.want_pause
    local pm = sdk.get_managed_singleton("app.PauseManager")
    if not pm then return end
    if not SUI.enum_dumped then
        SUI.enum_dumped = true
        pcall(function()
            local td = sdk.find_type_definition("app.PauseManager.PauseType")
            local names = {}
            for _, f in ipairs(td:get_fields()) do
                local n = f:get_name()
                if n ~= "value__" then
                    pcall(function() names[n] = tonumber(f:get_data(nil)) end)
                end
            end
            json.dump_file("DyeResearch/pause_types.json", names)
        end)
    end
    local ok, err = pcall(function()
        pm:call("requestPause(System.Boolean, app.PauseManager.PauseType, System.String, System.Action)",
            on, _pause_type_value(), "InteractablesDye", nil)
    end)
    if not ok then
        local ok2 = pcall(function()
            pm:call("requestPause", on, _pause_type_value(), "InteractablesDye", nil)
        end)
        if ok2 then ok = true end
    end
    if ok then
        SUI.paused = on
        local paused_now = nil
        pcall(function() paused_now = pm:call("isPausedAny") == true end)
        DYE.status = string.format("pause %s type %s -> isPausedAny=%s",
            tostring(on), tostring(_pause_type_value()), tostring(paused_now))
    elseif not SUI.pause_err then
        SUI.pause_err = true
        DYE.status = "requestPause FAILED: " .. tostring(err)
    end
end

local function _sui_preview_revert()
    _G.InteractablesDyePreview = nil
    if not SUI.preview then return end
    for _, p in ipairs(SUI.preview) do
        pcall(function() _write(p.mesh, p.mat, p.var, p.restore) end)
    end
    SUI.preview = nil
    SUI.prev_target = nil
end

-- equipment slot names via ItemManager -> ReadOnlyEquipData -> StorageData._ItemId
-- -> app.GUIBase.getItemName. Read-only: the struct copy never returns to a native.
local EQUIP_GROUPS = {
    { slot = 2, cat = "Head Armour", fallback = "Helm",
      meshes = { Helm = true } },
    { slot = 3, cat = "Body Armour", fallback = "Body Armour",
      meshes = { TopsWb = true, TopsBt = true, TopsBd = true, TopsAm = true,
                 TopsWbSub = true, TopsBdSub = true, TopsAmSub = true } },
    { slot = 4, cat = "Leg Armour", fallback = "Leg Armour",
      meshes = { PantsWl = true, PantsLg = true, PantsWlSub = true } },
    { slot = 5, cat = "Cloaks", fallback = "Mantle",
      meshes = { Mantle = true } },
    { slot = nil, cat = "Underwear", fallback = "Underwear",
      meshes = { Underwear = true } },
}

local function _equip_names()
    local now = os.clock()
    if SUI.names and now - (tonumber(SUI.names_at) or 0) < 3.0 then return SUI.names end
    local out = {}
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local ch = cm and cm:call("get_ManualPlayer")
        local im = sdk.get_managed_singleton("app.ItemManager")
        if not (ch and im) then return end
        local eq = im:call("getEquipData(app.Character)", ch)
        if not eq then return end
        local gb = sdk.find_type_definition("app.GUIBase")
        local getname = gb and gb:get_method("getItemName(System.Int32)")
        for s = 0, 5 do
            pcall(function()
                local sd = eq:call("get(app.EquipData.SlotEnum)", s)
                local id = sd and tonumber(sd:get_field("_ItemId")) or 0
                if id and id > 0 and getname then
                    local nm = getname:call(nil, id)
                    if nm and tostring(nm) ~= "" then out[s] = tostring(nm) end
                end
            end)
        end
    end)
    SUI.names, SUI.names_at = out, now
    return out
end

-- garments = named equipment groups; parts = every dyeable material across
-- that group's part meshes
local function _sui_garments(worn)
    local names = _equip_names()
    local out = {}
    local wn = 0
    for _, e in ipairs(worn) do
        if e.weapon then
            wn = wn + 1
            local parts = {}
            for _, m in ipairs(e.mats) do
                parts[#parts + 1] = { e = e, m = m, from = e.slot }
            end
            if #parts > 0 then
                local label
                if wn == 1 then label = names[0]
                elseif wn == 2 then label = names[1] end
                out[#out + 1] = { cat = "Weapons",
                    label = label or ("Weapon " .. wn), parts = parts }
            end
        end
    end
    for _, grp in ipairs(EQUIP_GROUPS) do
        local parts = {}
        for _, e in ipairs(worn) do
            if grp.meshes[e.slot] then
                for _, m in ipairs(e.mats) do
                    parts[#parts + 1] = { e = e, m = m, from = e.slot }
                end
            end
        end
        if #parts > 0 then
            out[#out + 1] = {
                cat = grp.cat,
                label = (grp.slot and names[grp.slot]) or grp.fallback,
                parts = parts,
            }
        end
    end
    return out
end

local function _sui_targets()
    local g = (SUI.G or {})[SUI.gi]
    if not g then return {} end
    if SUI.ri == 0 then return g.parts end
    local p = g.parts[SUI.ri]
    return p and { p } or {}
end

local function _sui_preview_apply()
    local col = COLORS[SUI.di]
    local shade = SHADES[SUI.si]
    if not (col and shade) then return end
    local target = string.format("%d|%d|%d|%d", SUI.gi, SUI.ri, SUI.di, SUI.si)
    if SUI.prev_target == target then return end
    _sui_preview_revert()
    local snaps = {}
    for _, p in ipairs(_sui_targets()) do
        local before = _read(p.e.mesh, p.m.index, p.m.var)
        if before then
            local c = { col.v[1] * shade.mul, col.v[2] * shade.mul, col.v[3] * shade.mul, 1.0 }
            if _write(p.e.mesh, p.m.index, p.m.var, c) then
                snaps[#snaps + 1] = { mesh = p.e.mesh, mat = p.m.index, var = p.m.var, restore = before }
            end
        end
    end
    -- the mannequin wears the same mesh paths: recolour her twin regions too
    pcall(function()
        local twins = _mannequin_worn()
        if #twins == 0 then return end
        local c = { col.v[1] * shade.mul, col.v[2] * shade.mul, col.v[3] * shade.mul, 1.0 }
        for _, p in ipairs(_sui_targets()) do
            for _, e in ipairs(twins) do
                if e.slot == p.e.slot and e.path == p.e.path then
                    for _, m in ipairs(e.mats) do
                        if m.name == p.m.name then
                            local before = _read(e.mesh, m.index, m.var)
                            if before and _write(e.mesh, m.index, m.var, c) then
                                snaps[#snaps + 1] = { mesh = e.mesh, mat = m.index, var = m.var, restore = before }
                            end
                        end
                    end
                end
            end
        end
    end)
    SUI.preview = snaps
    SUI.prev_target = target
    _G.InteractablesDyePreview = snaps
end

-- native Yes/No confirm (the proven ui010101 recipe: sticky RetVal reset via
-- discovered field, change-from-baseline, RetVal None=0 Cancel=1 YES=2 NO=3)
local DLG_TYPE = 14

local function _dlg_pick()
    local p
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local rv = gm and gm:call("getDialogState")
        if type(rv) == "number" then p = rv
        elseif rv ~= nil then p = sdk.to_int64(rv) & 0xFFFFFFFF end
    end)
    return p
end

local function _dlg_close()
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local dialog = gm and gm:get_field("Dialog")
        if dialog then dialog:call("reqClose") end
        gm:call("requestHideGuiType", DLG_TYPE)
    end)
    SUI.dlg = nil
end

local function _dlg_open(prompt, payload)
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local dialog = gm and gm:get_field("Dialog")
        if not dialog then return end
        if SUI.dlg_field == nil then
            SUI.dlg_field = false
            pcall(function()
                local td = dialog:get_type_definition()
                for _, f in ipairs(td:get_fields() or {}) do
                    local n = tostring(f:get_name() or "")
                    local ln = n:lower()
                    if SUI.dlg_field == false and (ln:find("retval", 1, true)
                            or ln:find("result", 1, true) or ln:find("selectno", 1, true)) then
                        local v = nil
                        pcall(function() v = tonumber(dialog:get_field(n)) end)
                        if v ~= nil then SUI.dlg_field = n end
                    end
                end
            end)
        end
        if SUI.dlg_field and SUI.dlg_field ~= false then
            pcall(function() dialog:set_field(SUI.dlg_field, 0) end)
        end
        gm:call("requestGuiType", DLG_TYPE)
        dialog:call("reqDisp",
            prompt, "Dye it", "Not yet", "", "",
            true, 0, true, 58, 0, -1, nil,
            false, false, false, false, false, false,
            true, 0.0)
        SUI.dlg = { opened_at = os.clock(), baseline = _dlg_pick(), payload = payload }
    end)
end


local function _sui_commit_go(col, shade)
    if not _dye_consume(col.key, shade) then
        DYE.status = "could not consume the dye bowls - nothing applied"
        return
    end
    _sui_preview_revert()
    for _, p in ipairs(_sui_targets()) do
        _apply_dye(p.e, p.m, col.key .. " (" .. shade.key .. ")", col.v, shade.mul)
    end
end

local function _sui_commit()
    local col = COLORS[SUI.di]
    local shade = SHADES[SUI.si]
    if not (col and shade) then return end
    if not _dye_affordable(col.key, shade) then
        DYE.status = "not enough dye bowls for " .. col.key
            .. (shade.key == "Vivid" and " (Vivid costs double)" or "")
        return
    end
    if DYE.consume == false or not next(DYE.item_ids or {}) then
        _sui_commit_go(col, shade)
        return
    end
    local bits = {}
    for b, n in pairs(_dye_cost(col.key, shade)) do
        bits[#bits + 1] = n .. " " .. b .. " Dye"
    end
    table.sort(bits)
    _dlg_open("Use " .. table.concat(bits, " and ") .. "?", { col = col, shade = shade })
end

local function _sui_washout()
    _sui_preview_revert()
    for _, p in ipairs(_sui_targets()) do _remove_dye(p.e, p.m) end
end

local function _sui_close()
    _mq_park()
    if SUI.dlg then _dlg_close() end
    _sui_preview_revert()
    SUI.open = false
    SUI.want_pause = false
end

local function _sui_nav(dir, maxv, cur)
    local v = cur + dir
    if v < 1 then v = maxv elseif v > maxv then v = 1 end
    return v
end

local function _sui_input(worn)
    if SUI.dlg then return end
    local now = os.clock()
    local mask = _pad_mask()
    local ay = tonumber(SUI.ay) or 0
    local ax = tonumber(SUI.ax) or 0

    local up = ay > 0.5 or _kb(0x26)
    local down = ay < -0.5 or _kb(0x28)
    local left = ax < -0.5 or _kb(0x25) or (mask & PAD.l2) ~= 0
    local right = ax > 0.5 or _kb(0x27) or (mask & PAD.r2) ~= 0
    local confirm = (mask & PAD.cross) ~= 0 or _kb(0x0D) or _kb(0x20)
    local back = (mask & PAD.circle) ~= 0 or _kb(0x08)
    local wash = (mask & PAD.square) ~= 0 or _kb(0x58)

    local function edge(name, held, repeatable)
        local p = SUI.prev_btn
        local was = p[name]
        p[name] = held and now or nil
        if held and not was then SUI.nav_at = now + 0.35 return true end
        if held and repeatable and now > SUI.nav_at then SUI.nav_at = now + 0.15 return true end
        return false
    end

    if edge("back", back, false) then _sui_close() return end
    local G = SUI.G or {}
    local g = G[SUI.gi]
    local nregions = g and #g.parts or 0
    local moved = false

    if edge("up", up, true) then
        if SUI.col == 1 then SUI.gi = _sui_nav(-1, math.max(1, #G), SUI.gi); SUI.ri = 0
        elseif SUI.col == 2 then SUI.ri = ((SUI.ri - 1) < 0) and nregions or (SUI.ri - 1)
        else SUI.di = _sui_nav(-1, #COLORS, SUI.di) end
        moved = true
    end
    if edge("down", down, true) then
        if SUI.col == 1 then SUI.gi = _sui_nav(1, math.max(1, #G), SUI.gi); SUI.ri = 0
        elseif SUI.col == 2 then SUI.ri = ((SUI.ri + 1) > nregions) and 0 or (SUI.ri + 1)
        else SUI.di = _sui_nav(1, #COLORS, SUI.di) end
        moved = true
    end
    if edge("left", left, true) then
        if SUI.col == 3 and SUI.si > 1 then SUI.si = SUI.si - 1
        else SUI.col = math.max(1, SUI.col - 1) end
        moved = true
    end
    if edge("right", right, true) then
        if SUI.col == 3 and SUI.si < #SHADES then SUI.si = SUI.si + 1
        else SUI.col = math.min(3, SUI.col + 1) end
        moved = true
    end
    if edge("confirm", confirm, false) and SUI.col == 3 then _sui_commit() end
    if edge("wash", wash, false) then _sui_washout() end

    if SUI.col == 3 then
        _sui_preview_apply()
    elseif moved then
        _sui_preview_revert()
    end
end

local function _abgr(r, g, b, a)
    local R = math.floor(math.max(0, math.min(1, r)) * 255)
    local G = math.floor(math.max(0, math.min(1, g)) * 255)
    local B = math.floor(math.max(0, math.min(1, b)) * 255)
    return ((a or 0xFF) << 24) | (B << 16) | (G << 8) | R
end

pcall(function() SUI.font = imgui.load_font("Sovngarde Light.ttf", 22) end)

local C_BG     = 0xE0100C0A
local C_EDGE   = 0xFF4AA2E8
local C_TEXT   = 0xFFE8E8E8
local C_DIM    = 0xFF9A9A9A
local C_SEL    = 0xFF4AE2FF
local C_SELBG  = 0x50FFFFFF

local function _proper(s)
    return (tostring(s or ""):gsub("(%a)([%w]*)", function(a, b)
        return a:upper() .. b:lower()
    end))
end

local function _sui_draw(worn)
    local sw, sh = 1920.0, 1080.0
    pcall(function()
        local sz = imgui.get_display_size()
        if sz then sw, sh = tonumber(sz.x) or sw, tonumber(sz.y) or sh end
    end)
    if SUI.font then pcall(function() imgui.push_font(SUI.font) end) end
    local W, H = 790, 580
    local X, Y = sw - W - 50, (sh - H) * 0.38
    local ROW = 27
    draw.filled_rect(X, Y, W, H, C_BG)
    draw.outline_rect(X, Y, W, H, C_EDGE)
    draw.text("Dye Clothing", X + 16, Y + 12, C_EDGE)
    -- the mannequin's frame: she stands in the world behind this box, welded
    -- to the camera so she reads as part of the UI (fill kept faint on purpose)
    do
        local FW = 600
        local FX = X - FW - 12
        draw.filled_rect(FX, Y, FW, H, 0x30100C0A)
        draw.outline_rect(FX, Y, FW, H, C_EDGE)
        draw.text("Preview", FX + 16, Y + 12, C_EDGE)
        if MQ.state ~= "done" then
            draw.text(MQ.state and "Preparing your likeness..." or "", FX + 16, Y + H - 34, C_DIM)
        end
    end

    local colx = { X + 16, X + 235, X + 470 }
    local top = Y + 50
    draw.text(SUI.col == 1 and "> GARMENT" or "  GARMENT", colx[1], top, SUI.col == 1 and C_SEL or C_DIM)
    draw.text(SUI.col == 2 and "> REGION" or "  REGION", colx[2], top, SUI.col == 2 and C_SEL or C_DIM)
    draw.text(SUI.col == 3 and "> DYE" or "  DYE", colx[3], top, SUI.col == 3 and C_SEL or C_DIM)
    draw.text("Light Rich Vivid", colx[3] + 105, top, C_DIM)

    local list_top = top + ROW + 4
    local G = SUI.G or {}
    local yy = list_top
    local lastcat = nil
    for i, g in ipairs(G) do
        if yy < Y + H - ROW then
            if g.cat ~= lastcat then
                draw.text("- " .. g.cat .. " -", colx[1], yy, C_EDGE)
                yy = yy + ROW - 3
                lastcat = g.cat
            end
            if i == SUI.gi then draw.filled_rect(colx[1] - 4, yy - 2, 205, ROW - 3, C_SELBG) end
            draw.text(g.label, colx[1], yy, i == SUI.gi and C_TEXT or C_DIM)
            yy = yy + ROW
        end
    end

    local g = G[SUI.gi]
    if g then
        local rows = { { label = "Whole Garment" } }
        for pi, p in ipairs(g.parts) do
            local lbl = _region_label(p.m.name)
            if p.e.weapon or lbl == "" or lbl:match("^%d") or lbl:match("%d %d")
                or #lbl > 16 then lbl = "Part " .. pi end
            rows[#rows + 1] = { label = _proper(lbl), p = p }
        end
        for i, row in ipairs(rows) do
            local ri = i - 1
            local ry = list_top + (i - 1) * ROW
            if ry < Y + H - ROW then
                if ri == SUI.ri then draw.filled_rect(colx[2] - 4, ry - 2, 215, ROW - 3, C_SELBG) end
                local rec = row.p and _find_record(row.p.e.slot, row.p.e.path, row.p.m.name) or nil
                local tc = ri == SUI.ri and C_TEXT or C_DIM
                if rec and rec.color then
                    tc = _abgr(rec.color[1], rec.color[2], rec.color[3])
                end
                draw.text(row.label, colx[2], ry, tc)
            end
        end
    end

    local counts = _dye_counts()
    for i, col in ipairs(COLORS) do
        local cy = list_top + (i - 1) * 36
        if cy < Y + H - ROW then
            if i == SUI.di and SUI.col == 3 then
                draw.filled_rect(colx[3] - 4, cy - 3, 290, 32, C_SELBG)
            end
            for s, shade in ipairs(SHADES) do
                local cx = colx[3] + 105 + (s - 1) * 42
                -- swatch = the HUE getting stronger, never the raw multiplier
                -- (x2.5 / x4 clip to white on screen; on fabric they punch
                -- colour through darkness). Grey dyes ramp by lightness.
                local r, g, b = col.v[1], col.v[2], col.v[3]
                local mx, mn = math.max(r, g, b), math.min(r, g, b)
                local sr, sg, sb
                if mx - mn < 0.1 or mx < 0.01 then
                    sr = math.min(1.0, r * shade.mul)
                    sg = math.min(1.0, g * shade.mul)
                    sb = math.min(1.0, b * shade.mul)
                else
                    local level = (s == 1 and 0.62) or (s == 2 and 0.82) or 1.0
                    local k = level / mx
                    sr, sg, sb = r * k, g * k, b * k
                end
                local c = _abgr(sr, sg, sb)
                draw.filled_rect(cx, cy, 32, 26, c)
                if not _dye_affordable(col.key, shade) then
                    draw.filled_rect(cx, cy, 32, 26, 0xA8000000)
                end
                if i == SUI.di and s == SUI.si and SUI.col == 3 then
                    draw.outline_rect(cx - 3, cy - 3, 38, 32, C_SEL)
                end
            end
            local label = col.key
            if DYE.consume ~= false and next(DYE.item_ids or {}) then
                local n = nil
                for b, need in pairs(_dye_cost(col.key, nil)) do
                    local have = math.floor((counts[b] or 0) / need)
                    if n == nil or have < n then n = have end
                end
                if n ~= nil then label = label .. "  x" .. n end
            end
            draw.text(label, colx[3], cy + 4, i == SUI.di and C_TEXT or C_DIM)
        end
    end
    if SUI.font then pcall(function() imgui.pop_font() end) end
end

-- camera transform, the proven read from Interactables (never written)
local function _mq_cam()
    local pos = nil
    -- app.CameraManager getters take a CameraDefine.Role (0 = the main role)
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CameraManager")
        local cgo = cm and cm:call("getCameraGameObject", 0)
        if not cgo then
            local cam = cm and cm:call("getMainCamera", 0)
            cgo = cam and cam:call("get_GameObject")
        end
        local ctf = cgo and cgo:call("get_Transform")
        local up = ctf and ctf:call("get_UniversalPosition")
        if up then
            pos = { x = up.x, y = up.y, z = up.z }
            pcall(function()
                local az, ay = ctf:call("get_AxisZ"), ctf:call("get_AxisY")
                pos.fx, pos.fy, pos.fz = az.x, az.y, az.z
                pos.ux, pos.uy, pos.uz = ay.x, ay.y, ay.z
                local q = ctf:call("get_Rotation")
                pos.qx, pos.qy, pos.qz, pos.qw = q.x, q.y, q.z, q.w
            end)
        end
    end)
    if pos then return pos end
    -- fallback: the scene's main view -> primary camera
    pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local td = sdk.find_type_definition("via.SceneManager")
        local view = sdk.call_native_func(sm, td, "get_MainView")
        local cam = view and view:call("get_PrimaryCamera")
        local cgo = cam and cam:call("get_GameObject")
        local ctf = cgo and cgo:call("get_Transform")
        local up = ctf and ctf:call("get_UniversalPosition")
        if up then pos = { x = up.x, y = up.y, z = up.z } end
    end)
    return pos
end

local function _mq_position(x, y, z)
    local vp = ValueType.new(sdk.find_type_definition("via.Position"))
    vp:set_field("x", x)
    vp:set_field("y", y)
    vp:set_field("z", z)
    return vp
end

-- weld: stand her on the camera's view ray, left of the panel, facing the lens
local function _mq_weld()
    if not (MQ.state == "done" and MQ.inst) or MQ.parked then return end
    pcall(function()
        local cam = _mq_cam()
        local pgo = _player_go()
        local ptf = pgo and pgo:call("get_Transform")
        local pp = ptf and ptf:call("get_UniversalPosition")
        if not pp then return end
        if not cam then
            -- no camera read: at least stand her in front of the player
            local fwd = ptf:call("get_AxisZ")
            MQ.inst:call("get_Transform"):call("set_UniversalPosition",
                _mq_position(pp.x + fwd.x * 2.2, pp.y, pp.z + fwd.z * 2.2))
            return
        end
        -- view direction = the camera's own Z axis, sign calibrated against the
        -- camera->player line (the player is always in front, horizontally),
        -- so pitching the camera up/down keeps her on screen
        local dx, dy, dz = pp.x - cam.x, (pp.y + 1.0) - cam.y, pp.z - cam.z
        local sgn = 1.0
        if cam.fx then
            sgn = (cam.fx * dx + cam.fz * dz) < 0 and -1.0 or 1.0
            dx, dy, dz = cam.fx * sgn, cam.fy * sgn, cam.fz * sgn
        end
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        if len < 0.01 then return end
        dx, dy, dz = dx / len, dy / len, dz / len
        local hl = math.sqrt(dx * dx + dz * dz)
        local fx = (hl > 0.01) and dx / hl or 0.0
        local fz = (hl > 0.01) and dz / hl or 1.0
        local rx, rz = fz, -fx
        -- her centre sits on the view ray (a touch above it, along camera-up);
        -- her root is half a body below that in WORLD up so she stands straight
        -- she is a UI object: her up is the CAMERA's up, her root sits half a
        -- body below her centre along that up, and she faces the lens
        local dist, side, lift, half = 6.0, 0.60, 0.25, 0.875
        local ux, uy, uz = 0.0, 1.0, 0.0
        if cam.ux then ux, uy, uz = cam.ux, cam.uy, cam.uz end
        local off = lift - half
        local x = cam.x + dx * dist + rx * side + ux * off
        local y = cam.y + dy * dist + uy * off
        local z = cam.z + dz * dist + rz * side + uz * off
        local tf = MQ.inst:call("get_Transform")
        tf:call("set_UniversalPosition", _mq_position(x, y, z))
        local q = ValueType.new(sdk.find_type_definition("via.Quaternion"))
        if cam.qw then
            -- camera rotation, flipped 180 about its up when the camera looks
            -- along +Z (so her +Z forward points back at the lens)
            local x1, y1, z1, w1 = cam.qx, cam.qy, cam.qz, cam.qw
            if sgn > 0 then
                q.x, q.y, q.z, q.w = -z1, w1, x1, -y1
            else
                q.x, q.y, q.z, q.w = x1, y1, z1, w1
            end
        else
            local yaw = math.atan(cam.x - x, cam.z - z)
            q.x, q.y, q.z, q.w = 0.0, math.sin(yaw * 0.5), 0.0, math.cos(yaw * 0.5)
        end
        pcall(function() tf:call("set_Rotation", q) end)
    end)
end

local function _mq_idle()
    if MQ.idle_done then return end
    MQ.idle_done = true
    pcall(function()
        local m = MQ.inst:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion"))
        if not m then return end
        -- bank 0 clip 10 = the standing idle observed on the player's layer 0
        if m:call("hasMotion", 0, 10) ~= true then return end
        local lyr = m:call("getLayer", 0)
        lyr:call(
            "changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
            0, 10, 0.0, 4.0, 1, 1)
    end)
end

local function _mq_tick()
    if not MQ.state or MQ.state == "done" then return end
    local now = os.clock()
    if MQ.state == "loading" then
        pcall(function()
            if MQ.pfb:call("get_Ready") ~= true then
                if now - MQ.t0 > 20.0 then _mq_log("FAILED: prefab never ready") _mq_destroy() end
                return
            end
            local pgo = _player_go()
            local fol = pgo and pgo:call("get_Folder")
            local ptf = pgo and pgo:call("get_Transform")
            local up = ptf and ptf:call("get_UniversalPosition")
            if not (fol and up) then _mq_log("FAILED: no player folder/position") _mq_destroy() return end
            local inst = nil
            pcall(function()
                inst = MQ.pfb:call("instantiate(via.vec3, via.Folder)",
                    Vector3f.new(up.x, up.y, up.z), fol)
            end)
            if not inst then _mq_log("FAILED: instantiate returned nil") _mq_destroy() return end
            pcall(function() inst:add_ref() end)
            MQ.inst = inst
            -- keep her root VISIBLE (children built under a hidden root may be
            -- born hidden); park her 30m underground until she is built
            pcall(function() inst:call("set_DrawSelf", true) end)
            pcall(function() inst:call("set_UpdateSelf", true) end)
            pcall(function()
                inst:call("get_Transform"):call("set_UniversalPosition",
                    _mq_position(up.x, up.y - 30.0, up.z))
            end)
            MQ.state, MQ.t0 = "prebuild", now
            _mq_log("shell spawned, parked underground")
        end)
    elseif MQ.state == "prebuild" then
        if now - MQ.t0 < 0.5 then return end
        local ch = nil
        pcall(function()
            local cm = sdk.get_managed_singleton("app.CharacterManager")
            ch = cm and cm:call("get_ManualPlayer")
        end)
        pcall(function()
            MQ.cb = MQ.inst:call("getComponent(System.Type)", sdk.typeof("app.CloneBuilder"))
        end)
        if not (MQ.cb and ch) then _mq_log("FAILED: no CloneBuilder/player") _mq_destroy() return end
        local ok = pcall(function()
            MQ.cb:call("requestBuild(app.Character, System.Boolean, System.Action`1<via.GameObject>)", ch, false, nil)
        end)
        if not ok then _mq_log("FAILED: requestBuild errored") _mq_destroy() return end
        MQ.state, MQ.t0, MQ.tick = "building", now, 0.0
        _mq_log("build requested")
    elseif MQ.state == "building" then
        if now - MQ.tick < 0.25 then return end
        MQ.tick = now
        pcall(function()
            if MQ.cb:call("get_Completed") == true then
                MQ.state, MQ.t0 = "settle", now
                _mq_log("build complete")
            elseif now - MQ.t0 > 30.0 then
                _mq_log("FAILED: build not complete in 30s")
                _mq_destroy()
            end
        end)
    elseif MQ.state == "settle" then
        if now - MQ.t0 < 0.6 then return end
        pcall(function()
            local pgo = _player_go()
            if pgo then MQ.cb:call("copyEditData", pgo, MQ.inst) end
        end)
        pcall(function() MQ.cb:call("dispAllWeapons", false) end)
        pcall(function() MQ.cb:call("dispLantern", false) end)
        -- a pure visual: switch off every collider on her tree so scenery and
        -- other bodies can't push her hair/cloth about or bump into her capsule
        pcall(function()
            local function strip(go)
                for _, tn in ipairs({ "via.physics.RequestSetCollider",
                                      "app.CollisionShapePreset",
                                      "via.physics.CharacterController" }) do
                    pcall(function()
                        local c = go:call("getComponent(System.Type)", sdk.typeof(tn))
                        if c then c:call("set_Enabled", false) end
                    end)
                end
            end
            local function walk(tf, depth)
                if not tf or depth > 8 then return end
                local child = tf:call("get_Child")
                while child do
                    local cgo = child:call("get_GameObject")
                    if cgo then strip(cgo); walk(child, depth + 1) end
                    child = child:call("get_Next")
                end
            end
            strip(MQ.inst)
            walk(MQ.inst:call("get_Transform"), 0)
        end)
        pcall(function() MQ.inst:call("set_DrawSelf", true) end)
        pcall(function() MQ.inst:call("set_UpdateSelf", true) end)
        MQ.state = "done"
        MQ.walk_at = 0.0
        _mq_idle()
        if MQ.parked then _mq_park() else _mq_weld() end
        pcall(function()
            local up = MQ.inst:call("get_Transform"):call("get_UniversalPosition")
            local walk = _mannequin_worn()
            local hits = 0
            for _, rec in ipairs(DYE.records) do
                for _, e in ipairs(walk) do
                    if e.slot == rec.slot and e.path == rec.path then hits = hits + 1 break end
                end
            end
            _mq_log(string.format("done: welded at %.1f/%.1f/%.1f (cam %s); %d meshes, %d/%d dye records matched",
                up.x, up.y, up.z, _mq_cam() and "ok" or "MISSING", #walk, hits, #DYE.records))
        end)
    end
end

MQ.prebuild_at = os.clock() + 8.0
re.on_application_entry("UpdateBehavior", function()
    pcall(function()
        -- pre-build her once, parked underground, so the first tub visit is instant
        if MQ.prebuild_at and os.clock() > MQ.prebuild_at then
            MQ.prebuild_at = nil
            if not MQ.state and _player_go() then
                MQ.parked = true
                _mq_start()
                MQ.parked = true
                _mq_log("pre-building the mannequin (parked)")
            end
        end
        _mq_tick()
        local key = rawget(_G, "Interactables_session_key")
        local at_station = key == DYE_STATION_KEY
        local now = os.clock()
        if at_station and not SUI.open then
            if not SUI.sess_since then _mq_start(); MQ.parked = true end
            SUI.sess_since = SUI.sess_since or now
            if now - SUI.sess_since > 1.2 then
                SUI.open = true
                SUI.col, SUI.ri = 1, 0
                _mq_start()
                MQ.parked = false
            end
        elseif not at_station then
            SUI.sess_since = nil
            if SUI.open then _sui_close() end
        end
        if SUI.dlg then
            local d = SUI.dlg
            if now - d.opened_at > 0.25 then
                local p = _dlg_pick()
                if p ~= nil and p ~= d.baseline then
                    local payload = d.payload
                    if p == 2 then
                        _dlg_close()
                        if payload then _sui_commit_go(payload.col, payload.shade) end
                    elseif p == 1 or p == 3 then
                        _dlg_close()
                        DYE.status = "kept your bowls"
                    end
                elseif now - d.opened_at > 30.0 then
                    _dlg_close()
                end
            end
        end
        _G.InteractablesDyeUIOpen = SUI.open == true
        _apply_pause()
    end)
end)

re.on_application_entry("LateUpdateBehavior", function()
    pcall(_mq_weld)
    if not SUI.open then return end
    pcall(function()
        local IP = rawget(_G, "IrisPrompt")
        if IP and type(IP.set_slot) == "function" then
            IP.set_slot("interactables_dye", "PNL_R03", "Apply Dye")
            IP.set_slot("interactables_dye", "PNL_R02", "Done")
            IP.set_slot("interactables_dye", "PNL_L03", "Wash Out")
        end
    end)
end)

local function _game_gui_open()
    local now = os.clock()
    if now - (tonumber(SUI.gui_at) or 0) < 0.1 then return SUI.gui_open == true end
    SUI.gui_at = now
    local open = false
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        open = gm and gm:call("isPausedGUI") == true
    end)
    SUI.gui_open = open
    return open
end

re.on_frame(function()
    if not SUI.open then return end
    pcall(function()
        if _game_gui_open() then
            _sui_preview_revert()
            SUI.prev_btn = {}
            return
        end
        _dye_scan_tick()
        local worn = _worn(os.clock())
        if #worn == 0 then return end
        SUI.G = _sui_garments(worn)
        if #SUI.G == 0 then return end
        if SUI.gi > #SUI.G then SUI.gi = 1 end
        _sui_input(worn)
        if SUI.open then _sui_draw(worn) end
    end)
end)

pcall(_dlg_close)   -- softlock guard: a reload orphaning our dialog must not strand it

re.on_script_reset(function()
    pcall(_mq_destroy)
    pcall(_sui_preview_revert)
    pcall(_dlg_close)
    if SUI.paused then
        SUI.want_pause = false
        pcall(function()
            local pm = sdk.get_managed_singleton("app.PauseManager")
            pm:call("requestPause(System.Boolean, app.PauseManager.PauseType, System.String, System.Action)",
                false, _pause_type_value(), "InteractablesDye", nil)
        end)
        SUI.paused = false
    end
    SUI.open = false
end)
