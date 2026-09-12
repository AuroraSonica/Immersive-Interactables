local CFG = "ImmersiveInteractables/dye_profiles.json"
local Compat32 = require("II.Compat32")
local preview_probe_ok, PreviewProbe32 = pcall(require, "II.MannequinPreflight32")
local preview_load_ok, PreviewLoad32 = pcall(require, "II.PreviewResource32")
local preview_inspect_ok, PreviewInspect32 = pcall(require, "II.NativePreviewInspect32")
local bestfriend_source_ok, BestfriendSource32 = pcall(require, "II.BestfriendSource32")
local prefab_loader_ok, PrefabLoaderInspect32 = pcall(require, "II.PrefabLoaderInspect32")
local dialogue_load_ok, DialogueCloneLoad32 = pcall(require, "II.DialogueCloneLoad32")
local dialogue_instance_ok, DialogueCloneInstance32 = pcall(require, "II.DialogueCloneInstance32")
local dye_preview_ok, DyePreview32 = pcall(require,"II.DyePreview32")
local PreviewFrame32 = require("II.PreviewFrame32")
local DyeCamera32 = require("II.DyeCamera32")
local DyePlan32 = require("II.DyePlan32")
local Perf32 = require("II.Perf32")
local TemperVisual32 = require("II.TemperVisual32")
local TemperWeaponKey32 = require("II.TemperWeaponKey32")
local TemperFinish32 = require('II.TemperFinish32')
local DaggerWorkpiece32 = require('II.DaggerWorkpiece32')
local ParagliderDye32 = require('II.ParagliderDye32')
local temper_dialog=require('II.TemperDialog32')
local AnvilWorkpiece32 = require("II.AnvilWorkpiece32")
local prepare_workpiece
local temper_preview=require("II.TemperPreview32")
local temper_menu=require("II.TemperMenu32")
temper_menu.count=#TemperVisual32.finishes
local temper_comparison=require("II.TemperComparison32")
local temper_proposed=temper_comparison.new('proposed')
local GliderPreview32=require('II.GliderPreview32')
local glider_preview=GliderPreview32
glider_preview.scale=.1
local temper_combat_probe=require('II.TemperCombatProbe32')
local temper_damage_test=require('II.TemperDamageTest32')
local temper_stamina_probe=require('II.TemperStaminaProbe32')
local temper_secondary_test=require('II.TemperSecondaryTest32')
local temper_climb=require('II.TemperClimb32')
local _game_gui_open
local workpiece_visibility=require("II.WorkpieceVisibility32").new()
local workpiece_sources={}
local workpiece_hidden=false
local workpiece_auto_at=0
local workpiece_exit=require("II.WorkpieceExit32").new()
local workpiece_display_token,workpiece_exiting,workpiece_wait_since
local TEMPER
local DYE = {
    cost_mode = "gold",
    gold_per_item = 1000,
    preview_enabled = true,
    lock_vertical_camera = true,
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
local SLOT_LABELS = {
    Helm = "Helm", Mantle = "Mantle", Underwear = "Underwear",
    TopsWb = "Top", TopsBt = "Top (under)", TopsBd = "Body", TopsAm = "Arms",
    TopsWbSub = "Top (inner)", TopsBdSub = "Body (inner)", TopsAmSub = "Arms (inner)",
    PantsWl = "Legs", PantsLg = "Leggings", PantsWlSub = "Legs (inner)",
}
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
            if t.cost_mode == "gold" or t.cost_mode == "bowls" or t.cost_mode == "free" then
                DYE.cost_mode = t.cost_mode
            end
            if tonumber(t.gold_per_item) and tonumber(t.gold_per_item) >= 0 then
                DYE.gold_per_item = math.floor(tonumber(t.gold_per_item))
            end
            if type(t.preview_enabled)=="boolean" then DYE.preview_enabled=t.preview_enabled end
            if type(t.lock_vertical_camera)=="boolean" then DYE.lock_vertical_camera=t.lock_vertical_camera end
        end
    end)
end
local function _save()
    DYE.record_index=nil
    if DYE.batch_saving then DYE.dirty=true; return end
    local ok,result=pcall(function() return json.dump_file(CFG, { version = 1, records = DYE.records,
        dye_items = DYE.item_ids, consume = DYE.consume, cost_mode = DYE.cost_mode,
        gold_per_item = DYE.gold_per_item, preview_enabled=DYE.preview_enabled,
        lock_vertical_camera=DYE.lock_vertical_camera }) end)
    DYE.dirty = not ok or result==false
    return not DYE.dirty
end
local function _player_go()
    local go = nil
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local ch = cm and cm:call("get_ManualPlayer")
        go = ch and ch:call("get_GameObject")
    end)
    local valid = false
    pcall(function() valid = go and go:call("get_Valid") == true end)
    return valid and go or nil
end
local function _go_valid(go)
    local valid = false
    pcall(function() valid = go and go:call("get_Valid") == true end)
    return valid
end
local function _walk(tf, depth, out, others, budget)
    if not tf or depth > 10 then return end
    pcall(function()
        local child = tf:call("get_Child")
        while child do
            if budget then
                if budget.left<=0 then return end
                budget.left=budget.left-1
            end
            local go = child:call("get_GameObject")
            if _go_valid(go) then
                local nm = "?"
                pcall(function() nm = tostring(go:call("get_Name")) end)
                local mesh = nil
                pcall(function()
                    mesh = go:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
                end)
                if SLOT_LABELS[nm] or (budget and budget.all_meshes) then
                    if mesh then out[#out + 1] = { slot = nm, mesh = mesh } end
                elseif others and mesh then
                    others[nm] = true
                end
                _walk(child, depth + 1, out, others, budget)
            end
            child = child:call("get_Next")
        end
    end)
end
local function _walk_weapon_go(go, depth, out, slot, seen)
    if not _go_valid(go) or depth > 10 then return end
    pcall(function()
        local mesh = go:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
        if mesh then
            local addr = nil
            pcall(function() addr = mesh:get_address() end)
            local key = addr and tostring(addr) or tostring(mesh)
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = { slot = slot, mesh = mesh, weapon = true }
            end
        end
        local tf = go:call("get_Transform")
        local child = tf and tf:call("get_Child")
        while child do
            local cgo = child:call("get_GameObject")
            if cgo then _walk_weapon_go(cgo, depth + 1, out, slot, seen) end
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
local function _worn(now)
    if now - (tonumber(DYE.walk_at) or -1) < 0.5 then return DYE.walk end
    local pgo = _player_go()
    local tf = pgo and pgo:call("get_Transform")
    if not tf then DYE.walk={}; DYE.walk_at=now; return DYE.walk end
    local out, others = {}, {}
    _walk(tf, 0, out, others)
    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local ch = cm and cm:call("get_ManualPlayer")
        if not ch then return end
        local seen = {}
        local holder
        pcall(function() holder = ch:call("get_WeaponAndItemHolder") end)
        for _, spec in ipairs({
            { getter = "get_RightWeapon", slot = "WeaponMain" },
            { getter = "get_LeftWeapon",  slot = "WeaponSub" },
        }) do
            local weapon = nil
            pcall(function() weapon = ch:call(spec.getter) end)
            if not weapon and holder then
                pcall(function()
                    local ws = holder:call(spec.getter)
                    weapon = ws and ws:call("get_Weapon")
                end)
            end
            pcall(function()
                local mesh = weapon and weapon:get_field("Mesh")
                if mesh then
                    local key = tostring(mesh:get_address())
                    if not seen[key] then
                        seen[key] = true
                        out[#out + 1] = { slot = spec.slot, mesh = mesh, weapon = true }
                    end
                end
            end)
            local wgo = nil
            pcall(function() wgo = weapon and weapon:call("get_GameObject") end)
            if wgo then _walk_weapon_go(wgo, 0, out, spec.slot, seen) end
        end
    end)
    DYE.unlisted = others
    pcall(function()
        local ch=sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer')
        local entries=ParagliderDye32.entries(rawget(_G,'PARAGLIDER_RUNTIME'),ch and ch:get_address(),_go_valid)
        for _,e in ipairs(entries) do
            if e.mesh:call('get_MaterialReady')==true then
                _enrich(e)
                if ParagliderDye32.accept(e.path) then out[#out+1]=e end
            end
        end
    end)
    for _, e in ipairs(out) do _enrich(e) end
    pcall(function()
        local bits = {}
        for _, e in ipairs(out) do
            if e.weapon then
                bits[#bits + 1] = tostring(e.slot) .. "=" .. tostring(e.path)
                    .. "[" .. tostring(#(e.mats or {})) .. "]"
            end
        end
        table.sort(bits)
        local sig = table.concat(bits, "; ")
        if sig ~= DYE.weapon_diag_sig then
            DYE.weapon_diag_sig = sig
            log.info("[DyeEquipment32] weapon meshes: " .. (sig ~= "" and sig or "NONE"))
        end
    end)
    DYE.walk, DYE.walk_at = out, now
    return out
end
local function _mockup_worn()
    local out = {}
    pcall(function()
        local gm=sdk.get_managed_singleton("app.GuiManager")
        if not gm or gm:call("isPausedGUI")~=true then return end
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
local MQ = { state = nil, pfb = nil, inst = nil, cb = nil, t0 = 0.0, tick = 0.0,
             walk = {}, walk_at = 0.0, idle_done = false }
local MQ_PFB = "appsystem/clone/prefab/bestfriendlynpcclone.pfb"
local function _mq_log(m) pcall(function() log.info("[DyeMannequin] " .. tostring(m)) end) end
local preview_walk={owner=nil,entries={},at=-1}
local function _mannequin_worn()
    if dye_preview_ok then
        local go=DyePreview32.object()
        if not go or not _go_valid(go) then
            preview_walk={owner=nil,entries={},at=-1}; return {}
        end
        local owner=go:get_address()
        local now=os.clock()
        if preview_walk.owner==owner and now-preview_walk.at<0.5 then return preview_walk.entries end
        local out,players,paths={},{},{}
        for _,e in ipairs(_worn(now)) do
            players[e.mesh:get_address()]=true
            if e.path and e.path~="?" then
                local old=paths[e.path]
                if old==nil then paths[e.path]={slot=e.slot,weapon=e.weapon}
                elseif old and old.slot~=e.slot then paths[e.path]=false end
            end
        end
        _walk(go:call("get_Transform"),0,out,nil,{left=512,all_meshes=true})
        local valid={}
        for _,e in ipairs(out) do
            local addr=e.mesh:get_address()
            if not players[addr] then
                local cached=DYE.mat_cache[addr]
                if preview_walk.owner~=owner or (cached and #cached.mats==0) then DYE.mat_cache[addr]=nil; cached=nil end
                local path=cached and cached.path or _mesh_path(e.mesh)
                local match=paths[path]
                if match then
                    _enrich(e)
                    e.slot=match.slot; e.weapon=match.weapon; valid[#valid+1]=e
                end
            end
        end
        if preview_walk.owner~=owner or #preview_walk.entries~=#valid then
            local weapons={}
            for _,e in ipairs(valid) do if e.weapon then weapons[#weapons+1]={slot=e.slot,path=e.path,materials=#e.mats} end end
            pcall(json.dump_file,"ImmersiveInteractables_PreviewMaterials32.json",
                {time=os.date("%Y-%m-%d %H:%M:%S"),owner=owner,scanned=#out,matched=#valid,weapons=weapons})
        end
        preview_walk={owner=owner,entries=valid,at=now}
        return valid
    end
    if MQ.state == "done" and not _go_valid(MQ.inst) then
        MQ.inst, MQ.cb, MQ.pfb, MQ.ctrl = nil, nil, nil, nil
        MQ.state, MQ.walk, MQ.idle_done = nil, {}, false
        _mq_log("streamed mannequin expired; rebuilding on the next station visit")
    end
    if not (MQ.state == "done" and _go_valid(MQ.inst)) then return {} end
    local now = os.clock()
    if now - (tonumber(MQ.walk_at) or 0) < 0.5 and #MQ.walk > 0 then return MQ.walk end
    local out = {}
    pcall(function()
        _walk(MQ.inst:call("get_Transform"), 0, out)
        for _, e in ipairs(out) do _enrich(e) end
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
    MQ.inst, MQ.cb, MQ.pfb, MQ.ctrl = nil, nil, nil, nil
    MQ.state, MQ.walk, MQ.idle_done = nil, {}, false
end
local function _mq_park()
    if MQ.state ~= "done" or not _go_valid(MQ.inst) then return end
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
local function _mq_start()
    if dye_preview_ok then return end
    if MQ.state == "done" and not _go_valid(MQ.inst) then _mq_destroy() end
    if MQ.state == "done" and _go_valid(MQ.inst) then
        if MQ.sig == _mq_signature() then
            MQ.parked = false
            _mq_log("reusing the built mannequin")
            return
        end
        _mq_log("outfit changed: rebuilding")
        _mq_destroy()
    end
    if MQ.state then return end
    do
        local ok, err = pcall(function()
            if not preview_probe_ok then error(PreviewProbe32) end
            return PreviewProbe32.capture()
        end)
        if not ok then
            _mq_log("preview diagnostic failed: " .. tostring(err))
            pcall(function() Compat32.record_event("menu state mannequin diagnostic failed: " .. tostring(err)) end)
        end
    end
    MQ.parked = false
    MQ.sig = _mq_signature()
    local count, matched, ready_count = 0, 0, 0
    local ok, scan_error = pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local td = sdk.find_type_definition("via.SceneManager")
        local scene = sm and td and sdk.call_native_func(sm, td, "get_CurrentScene")
        local arr = scene and scene:call("findComponents(System.Type)",
            sdk.typeof("app.BestFriendlyNPCCloneGenerator"))
        if arr then arr:add_ref() end
        count = arr and tonumber(arr:call("get_Length")) or 0
        for i = 0, count - 1 do
            local gen = arr:get_element(i)
            local prefab = gen and gen:get_field("NPCClonePrefab")
            if prefab and tostring(prefab:call("get_Path")):lower() == MQ_PFB then
                matched = matched + 1
                if prefab:call("get_Ready") == true then
                    ready_count = ready_count + 1
                    prefab:add_ref()
                    MQ.pfb = prefab
                    break
                end
            end
        end
    end)
    MQ.ctrl = nil
    if ok and MQ.pfb and rawget(_G, "RS32Gate") and _G.RS32Gate.block_xform_setters == true then
        MQ.pfb = nil
        MQ.failure = "Preview unavailable: positioning safety guard is active."
        _mq_log(MQ.failure)
    elseif ok and MQ.pfb then
        MQ.failure = nil
        MQ.state, MQ.t0 = "loading", os.clock()
        _mq_log("start: loading prefab")
    else
        MQ.pfb = nil
        MQ.failure = "Preview unavailable: clone prefab is not loaded."
        _mq_log(MQ.failure .. " generators=" .. count .. " matching=" .. matched
            .. " ready=" .. ready_count .. (ok and "" or (" read error=" .. tostring(scan_error))))
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
local function _mirror_colour(entry,mat,colour)
    if entry.paraglider then
        for _,p in ipairs(glider_preview.parts or {}) do
            if p.name==mat.name then _write(p.mesh,p.mat,p.var,colour) end
        end
    end
    for _,e in ipairs(_mannequin_worn()) do
        if e.slot==entry.slot and e.path==entry.path then
            for _,m in ipairs(e.mats) do
                if m.name==mat.name then _write(e.mesh,m.index,m.var,colour) end
            end
        end
    end
end
local function _rec_key(slot, path, matname)
    return slot .. "|" .. path .. "|" .. matname
end
local function _find_record(slot, path, matname)
    if not DYE.record_index then
        DYE.record_index={}
        for i,r in ipairs(DYE.records) do
            DYE.record_index[_rec_key(r.slot,r.path,r.mat)]={rec=r,index=i}
        end
    end
    local hit=DYE.record_index[_rec_key(slot,path,matname)]
    if hit then return hit.rec,hit.index end
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
    pcall(_mirror_colour,entry,mat,rec.color)
    local back = _read(entry.mesh, mat.index, mat.var)
    local ok = back and math.abs(back[1] - rec.color[1]) < 0.01
        and math.abs(back[2]-rec.color[2])<0.01 and math.abs(back[3]-rec.color[3])<0.01
    DYE.status = string.format("%s %s dyed %s x%.1f (%s)", entry.slot, _region_label(mat.name),
        color_key, s, ok and "applied" or "WRITE DID NOT STICK")
    pcall(function() log.info("[InteractablesDye] " .. DYE.status) end)
    _save()
    return ok
end
local function _remove_dye(entry, mat)
    local rec, idx = _find_record(entry.slot, entry.path, mat.name)
    if not rec then return end
    _write(entry.mesh, mat.index, mat.var, rec.orig or { 1, 1, 1, 1 })
    pcall(_mirror_colour,entry,mat,rec.orig or {1,1,1,1})
    table.remove(DYE.records, idx)
    DYE.status = string.format("%s %s back to original", entry.slot, _region_label(mat.name))
    _save()
end
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
    local index={}
    for _,rec in ipairs(DYE.records) do
        if rec.color then index[_rec_key(rec.slot,rec.path,rec.mat)]=rec end
    end
    local function heal(list)
        for _,e in ipairs(list) do
            local addr=tostring(e.mesh:get_address())
            for _,m in ipairs(e.mats) do
                local rec=index[_rec_key(e.slot,e.path,m.name)]
                if rec and not pv[addr..":"..m.index]
                    and not (fl and fl.slot==e.slot and fl.matname==m.name) then
                    local cur=_read(e.mesh,m.index,m.var)
                    if cur and (math.abs(cur[1]-rec.color[1])>0.01 or math.abs(cur[2]-rec.color[2])>0.01
                        or math.abs(cur[3]-rec.color[3])>0.01) then _write(e.mesh,m.index,m.var,rec.color) end
                end
            end
        end
    end
    heal(_worn(now))
    heal(_mockup_worn())
    heal(_mannequin_worn())
end
re.on_draw_ui(function()
    if not imgui.tree_node("Immersive Dyes (dev preview)") then return end
    if DYE.status ~= "" then imgui.text(DYE.status) end
    if dye_preview_ok then
        local changed,value=imgui.checkbox("Camera-anchored dye mannequin (TU3.2 test)",DYE.preview_enabled)
        if changed then DYE.preview_enabled=value; _save() end
        imgui.text(DyePreview32.status)
        if DyePreview32.idle_status then imgui.text(DyePreview32.idle_status) end
    end
    local camera_changed,camera_value=imgui.checkbox("Lock camera movement while dyeing",DYE.lock_vertical_camera)
    if camera_changed then DYE.lock_vertical_camera=camera_value; _save() end
    imgui.text(DyeCamera32.status)
    if DyeCamera32.frame_status then imgui.text(DyeCamera32.frame_status) end
    if dialogue_instance_ok then
        imgui.text(DialogueCloneInstance32.status)
        if DialogueCloneInstance32.state=="idle" and not (dye_preview_ok and DyePreview32.active()) and (not dialogue_load_ok
            or (DialogueCloneLoad32.state~="queued" and DialogueCloneLoad32.state~="loading"
                and DialogueCloneLoad32.state~="cleanup_failed")) then
            if imgui.button("Test separate player mannequin (20 seconds)") then DialogueCloneInstance32.request() end
        elseif DialogueCloneInstance32.active() then
            if imgui.button("Remove test mannequin / cancel") then DialogueCloneInstance32.request_stop() end
        end
    else imgui.text("Clone test module unavailable: "..tostring(DialogueCloneInstance32)) end
    if dialogue_load_ok then
        imgui.text(DialogueCloneLoad32.status)
        if DialogueCloneLoad32.state=="idle" and not (dye_preview_ok and DyePreview32.active()) and (not dialogue_instance_ok or
            (not DialogueCloneInstance32.active() and DialogueCloneInstance32.state~="cleanup_failed")) then
            if imgui.button("Test dialogue clone loading (no spawn)") then DialogueCloneLoad32.request() end
        elseif DialogueCloneLoad32.state=="loading" or DialogueCloneLoad32.state=="queued" then
            if imgui.button("Cancel dialogue clone load test") then DialogueCloneLoad32.request_cancel() end
        end
    end
    if prefab_loader_ok then
        imgui.text(PrefabLoaderInspect32.status)
        if imgui.button("Capture prefab loading API (no spawn)") then
            PrefabLoaderInspect32.request()
        end
    end
    if bestfriend_source_ok then
        imgui.text(BestfriendSource32.status)
        if imgui.button("Capture bestfriend sources (read-only)") then
            BestfriendSource32.request()
        end
    end
    if preview_inspect_ok then
        imgui.text(PreviewInspect32.status)
        if imgui.button("Capture native equipment preview (read-only)") then
            local ok, err = pcall(PreviewInspect32.capture)
            if not ok then PreviewInspect32.status = "Snapshot failed: " .. tostring(err) end
        end
    end
    if preview_load_ok then
        imgui.text("Mannequin resource test: " .. PreviewLoad32.status)
        if PreviewLoad32.state == "idle" and imgui.button("Prepare native preview resource (no spawn)") then
            PreviewLoad32.request()
        end
    end
    imgui.text(string.format("%d dyed regions saved (they survive reloads)", #DYE.records))
    local c
    c, DYE.strength = imgui.slider_float(
        "dye strength (1 = natural, crank it to brighten dark fabric)",
        tonumber(DYE.strength) or 1.0, 1.0, 6.0)
    local modes = { "gold", "bowls", "free" }
    local mode_i = 1
    for i, m in ipairs(modes) do if DYE.cost_mode == m then mode_i = i end end
    c, mode_i = imgui.combo("station dyeing cost", mode_i,
        { "gold (default)", "dye bowls (vanilla has ~1 of each)", "free" })
    if c then DYE.cost_mode = modes[mode_i]; DYE.consume = (DYE.cost_mode ~= "free"); _save() end
    if DYE.cost_mode == "gold" then
        c, DYE.gold_per_item = imgui.slider_int(
            "gold per equipment piece (any number of colours)", tonumber(DYE.gold_per_item) or 1000, 0, 10000)
        if c then _save() end
    end
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
local SUI = {
    plan = DyePlan32.new(),
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
        local to = math.min(from + 31, 4000)
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
local function _gold()
    local g = nil
    pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        g = im and tonumber(im:get_field("_Version"))
    end)
    return g
end
local function _gold_items(rows)
    local seen, n = {}, 0
    for _, r in ipairs(rows or {}) do
        local k = r.choice and r.choice.item
        if k ~= nil and not seen[k] then seen[k] = true; n = n + 1 end
    end
    return n
end
local function _gold_price(rows)
    return _gold_items(rows) * (tonumber(DYE.gold_per_item) or 1000)
end
local function _try_pay_gold(amount)
    if amount <= 0 then return true end
    local paid = false
    pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        if not im then return end
        local cur = tonumber(im:get_field("_Version"))
        if cur == nil then return end
        if cur < amount then paid = "poor"; return end
        local ok = pcall(function() im:set_field("_Version", cur - amount) end)
        if ok and tonumber(im:get_field("_Version")) == cur - amount then paid = true end
    end)
    return paid
end
local function _dye_affordable(color_key, shade)
    if DYE.cost_mode == "free" or DYE.consume == false then return true end
    if DYE.cost_mode == "gold" then
        local g = _gold()
        if g == nil then return true end
        return g >= (tonumber(DYE.gold_per_item) or 1000)
    end
    local ids = DYE.item_ids or {}
    local counts = _dye_counts()
    for b, n in pairs(_dye_cost(color_key, shade)) do
        if not ids[b] then return true end
        if (counts[b] or 0) < n then return false end
    end
    return true
end
local function _dye_consume(color_key, shade)
    if DYE.cost_mode == "free" or DYE.consume == false then return true end
    if DYE.cost_mode == "gold" then return _try_pay_gold(tonumber(DYE.gold_per_item) or 1000) == true end
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
SUI.dpad = require("II.DyeInput32")
local function _pad_mask()
    local mask = 0
    SUI.ax, SUI.ay = 0, 0
    SUI.rx=0
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
            pcall(function() local r=dev:call("get_AxisR"); SUI.rx=r and tonumber(r.x) or 0 end)
        end
    end)
    return mask
end
local function _kb(vk)
    local down = false
    pcall(function()
        local dev=SUI.keyboard
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
if dye_preview_ok then
    DyePreview32.before_detach=function()
        _sui_preview_revert()
        for _,e in ipairs(preview_walk.entries) do DYE.mat_cache[e.mesh:get_address()]=nil end
        preview_walk={owner=nil,entries={},at=-1}
    end
end
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
        local function read_name(sd)
            local id = 0
            pcall(function() id = tonumber(sd and sd:call("get_ItemId")) or 0 end)
            if id <= 0 then
            pcall(function() id = tonumber(sd and sd:get_field("_ItemId")) or 0 end)
            end
            if id <= 0 or not getname then return nil end
            local nm = getname:call(nil, id)
            return nm and tostring(nm) ~= "" and tostring(nm) or nil
        end
        pcall(function()
            local aw = Compat32.current_weapons(eq)
            if not aw then return end
            local main, sub = nil, nil
            pcall(function() main = aw:get_field("Main") end)
            pcall(function() sub = aw:get_field("Sub") end)
            out[0], out[1] = read_name(main), read_name(sub)
        end)
        for s = 2, 5 do
            pcall(function()
                local sd = eq:call("get(app.EquipData.SlotEnum)", s)
                out[s] = read_name(sd)
            end)
        end
    end)
    SUI.names, SUI.names_at = out, now
    return out
end
local function _sui_garments(worn)
    local names = _equip_names()
    local out = {}
    local weapon_groups = { WeaponMain = {}, WeaponSub = {} }
    for _, e in ipairs(worn) do
        local parts = e.weapon and weapon_groups[e.slot] or nil
        if parts then
            for _, m in ipairs(e.mats) do
                parts[#parts + 1] = { e = e, m = m, from = e.slot }
            end
        end
    end
    for wn, slot in ipairs({ "WeaponMain", "WeaponSub" }) do
        local parts = weapon_groups[slot]
        if #parts > 0 then
            out[#out + 1] = { cat = "Weapons",
                label = names[wn - 1] or ("Weapon " .. wn), parts = parts }
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
    local glider_parts={}
    for _,e in ipairs(worn) do
        if e.paraglider then
            for _,m in ipairs(e.mats) do glider_parts[#glider_parts+1]={e=e,m=m,from=e.slot} end
        end
    end
    if #glider_parts>0 then out[#out+1]={cat='Equipment',label='Paraglider',parts=glider_parts} end
    for _,g in ipairs(out) do
        g.regions=DyePlan32.regions(g.parts)
        g.id=g.cat.."|"..g.parts[1].e.slot.."|"..g.parts[1].e.path
        g.whole=g.label=='Paraglider' and 'Whole Paraglider' or g.cat=="Weapons" and "Whole Weapon" or "Whole Garment"
    end
    return out
end
local function _sui_targets()
    local g = (SUI.G or {})[SUI.gi]
    if not g then return {} end
    if SUI.ri == 0 then return g.parts end
    local r = g.regions[SUI.ri]
    return r and r.parts or {}
end
local function _sui_preview_apply()
    local rows,err=DyePlan32.resolve(SUI.plan,SUI.G or {})
    if not rows then _sui_preview_revert(); SUI.plan=DyePlan32.new(); DYE.status=err; return end
    local twins=_mannequin_worn()
    local target=table.concat({SUI.col,SUI.gi,SUI.ri,SUI.di,SUI.si,SUI.plan.revision,SUI.model_rev or 0},"|")
    for _,e in ipairs(twins) do target=target.."|"..tostring(e.mesh:get_address()) end
    if target==SUI.prev_target then return end
    _sui_preview_revert()
    local selected={}
    for _,r in ipairs(rows) do selected[DyePlan32.key(r.part)]=r end
    if SUI.col==3 then
        local col,shade=COLORS[SUI.di],SHADES[SUI.si]
        for _,p in ipairs(_sui_targets()) do selected[DyePlan32.key(p)]={part=p,choice={col=col,shade=shade}} end
    end
    local snaps,seen={},{}
    local function tint(mesh,mi,vi,c,restore)
        local k=tostring(mesh:get_address())..":"..mi
        if seen[k] then return end
        local before=restore or _read(mesh,mi,vi)
        if before and _write(mesh,mi,vi,c) then
            snaps[#snaps+1]={mesh=mesh,mat=mi,var=vi,restore=before}; seen[k]=true
        end
    end
    for _,r in pairs(selected) do
        local p,c=r.part,r.choice
        local colour={c.col.v[1]*c.shade.mul,c.col.v[2]*c.shade.mul,c.col.v[3]*c.shade.mul,1}
        local before=_read(p.e.mesh,p.m.index,p.m.var)
        if before then
            tint(p.e.mesh,p.m.index,p.m.var,colour,before)
            for _,e in ipairs(twins) do
                if e.slot==p.e.slot and e.path==p.e.path then
                    for _,m in ipairs(e.mats) do
                        if m.name==p.m.name then tint(e.mesh,m.index,m.var,colour,before) end
                    end
                end
            end
        end
    end
    SUI.preview=snaps; SUI.prev_target=target; _G.InteractablesDyePreview=snaps
end
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
    if not SUI.dlg then return end
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GuiManager")
        if gm then gm:call("requestHideDialog") end
    end)
    SUI.dlg = nil
end
local function _sui_stage()
    local g=(SUI.G or {})[SUI.gi]
    if not g then return end
    DyePlan32.stage(SUI.plan,_sui_targets(),g.id,COLORS[SUI.di],SHADES[SUI.si])
    SUI.col=2
    DYE.status="Colour selected. Choose another material, or Confirm and Dye."
end
local function _batch_ready()
    if SUI.batch_failed then return nil,"Previous payment/apply failed; close dyeing before retrying." end
    DYE.walk_at=-1
    SUI.G=_sui_garments(_worn(os.clock()))
    local rows,err=DyePlan32.resolve(SUI.plan,SUI.G or {})
    if not rows then return nil,err end
    if #rows==0 then return nil,"Select a colour with A / Enter first." end
    for _,r in ipairs(rows) do
        if not _read(r.part.e.mesh,r.part.m.index,r.part.m.var) then return nil,"Equipment unavailable; nothing charged." end
    end
    local cost=DyePlan32.cost(rows,_dye_cost)
    if DYE.cost_mode=="gold" then
        local g=_gold()
        if g==nil then return nil,"Wallet unreadable; nothing charged." end
        local price=_gold_price(rows)
        if g<price then return nil,"Not enough gold (need "..price.." G, have "..g.." G)." end
    elseif DYE.cost_mode~="free" and DYE.consume~=false then
        DYE.counts_at=nil; DYE.counts=nil
        local counts=_dye_counts()
        for b,n in pairs(cost) do
            if not (DYE.item_ids or {})[b] then return nil,"Dye bowl discovery incomplete; nothing charged." end
            if (counts[b] or 0)<n then return nil,"Not enough "..b.." dye (need "..n..")." end
        end
    end
    return rows,cost
end
local function _sui_commit_go()
    local rows,cost=_batch_ready()
    if not rows then DYE.status=cost; return end
    local group_count=DyePlan32.group_count(SUI.plan)
    if DYE.cost_mode=="gold" then
        local price=_gold_price(rows)
        local paid=_try_pay_gold(price)
        if paid~=true then
            SUI.batch_failed=(paid~="poor")
            DYE.status=(paid=="poor") and ("Not enough gold (need "..price.." G).")
                or "Payment unconfirmed; nothing applied. Close dyeing."
            if paid~="poor" then pcall(function() log.error("[DyeBatch] gold write unconfirmed") end) end
            return
        end
    elseif DYE.cost_mode~="free" and DYE.consume~=false then
        local ok,err=pcall(function()
            local im=assert(sdk.get_managed_singleton("app.ItemManager"))
            local ch=assert(_player_ch())
            for b,n in pairs(cost) do
                local id=DYE.item_ids[b]
                assert(tonumber(im:call("getHaveNum(System.Int32, app.Character)",id,ch))>=n,"Inventory changed")
            end
            for _,b in ipairs(BOWLS) do
                local n=cost[b]
                if n then
                    local id=DYE.item_ids[b]
                    local before=tonumber(im:call("getHaveNum(System.Int32, app.Character)",id,ch))
                    im:call("deleteItem(System.Int32, System.Int32, app.Character)",id,n,ch)
                    local after=tonumber(im:call("getHaveNum(System.Int32, app.Character)",id,ch))
                    assert(after==before-n,"Could not verify bowl consumption")
                end
            end
        end)
        DYE.counts=nil
        if not ok then
            SUI.batch_failed=true
            DYE.status="Payment unconfirmed; some bowls may be consumed. Close dyeing."
            pcall(function() log.error("[DyeBatch] "..tostring(err)) end)
            return
        end
    end
    _sui_preview_revert()
    DYE.batch_saving=true
    local applied=0
    local ok,err=pcall(function()
        for _,r in ipairs(rows) do
            local c,p=r.choice,r.part
            assert(_apply_dye(p.e,p.m,c.col.key.." ("..c.shade.key..")",c.col.v,c.shade.mul),"Material write unconfirmed")
            applied=applied+1
        end
    end)
    DYE.batch_saving=false
    local saved=_save()
    SUI.plan=DyePlan32.new(); SUI.col=2
    SUI.batch_failed=not ok
    DYE.status=ok and ("Dyed "..group_count.." material groups.")
        or ("Dye application incomplete ("..applied.." surfaces); bowls may be spent. Close dyeing.")
    if not ok then pcall(function() log.error("[DyeBatch] "..tostring(err)) end) end
    if saved==false then
        SUI.batch_failed=true
        DYE.status="Dyes may be applied, but saving failed. Do not pay again; check the log."
        pcall(function() log.error("[DyeBatch] Profile save failed after application") end)
    end
    return ok and saved~=false
end
local function _sui_commit()
    local rows,cost=_batch_ready()
    if not rows then DYE.status=cost; SUI.confirm={kind='notice',text=cost}; return end
    local bits={}
    if DYE.cost_mode=="gold" then
        local n=_gold_items(rows)
        SUI.confirm={text="Pay ".._gold_price(rows).." G to dye "..n..(n==1 and " piece?" or " pieces?")}
        SUI.block_until=os.clock()+0.3
        return
    elseif DYE.cost_mode~="free" and DYE.consume~=false then
        for b,n in pairs(cost) do bits[#bits+1]=n.." "..b end
        table.sort(bits)
    end
    SUI.confirm={text=#bits>0 and ("Use "..table.concat(bits,", ").." dye?") or "Confirm all selected colours?"}
    SUI.block_until=os.clock()+0.3
end
local function _sui_washout()
    _sui_preview_revert()
    DyePlan32.remove(SUI.plan,_sui_targets())
    DYE.batch_saving=true
    local ok,err=pcall(function() for _,p in ipairs(_sui_targets()) do _remove_dye(p.e,p.m) end end)
    DYE.batch_saving=false; _save()
    if not ok then DYE.status="Wash-out incomplete: "..tostring(err) end
end
local function _sui_close(request_exit)
    MQ.parked = true
    MQ.want_park = true
    SUI.confirm = nil
    SUI.native_pending=nil
    SUI.plan=DyePlan32.new(); SUI.batch_failed=nil
    SUI.dismissed = SUI.session_token
    SUI.open = false
    SUI.worn = nil
    SUI.want_pause = false
    _G.InteractablesDyeUIOpen = false
    if request_exit and SUI.session_token then
        _G.InteractablesDyeExitRequest = { token = SUI.session_token, at = os.clock() }
    end
    pcall(_sui_preview_revert)
    DyeCamera32.release()
    pcall(_apply_pause)
end
local function _sui_nav(dir, maxv, cur)
    local v = cur + dir
    if v < 1 then v = maxv elseif v > maxv then v = 1 end
    return v
end
local function _sui_input(worn)
    local now = os.clock()
    if now < (tonumber(SUI.block_until) or 0) then return end
    SUI.keyboard=nil
    pcall(function()
        DYE.keyboard_type=DYE.keyboard_type or sdk.find_type_definition("via.hid.Keyboard")
        local kb=sdk.get_native_singleton("via.hid.Keyboard")
        if kb and DYE.keyboard_type then SUI.keyboard=sdk.call_native_func(kb,DYE.keyboard_type,"get_Device") end
    end)
    local mask = _pad_mask()
    local ay = tonumber(SUI.ay) or 0
    local ax = tonumber(SUI.ax) or 0
    local dp = SUI.dpad.directions(mask)
    local up = ay > 0.5 or _kb(0x26) or dp.up
    local down = ay < -0.5 or _kb(0x28) or dp.down
    local left = ax < -0.5 or _kb(0x25) or (mask & PAD.l2) ~= 0 or dp.left
    local right = ax > 0.5 or _kb(0x27) or (mask & PAD.r2) ~= 0 or dp.right
    local confirm = (mask & PAD.cross) ~= 0 or _kb(0x0D) or _kb(0x20)
    local back = (mask & PAD.circle) ~= 0 or _kb(0x08) or _kb(0x10)
    local wash = (mask & PAD.square) ~= 0 or _kb(0x58)
    local review = _kb(0x09)
    if dye_preview_ok then
        local rotate=tonumber(SUI.rx) or 0
        if _kb(0x51) then rotate=-1 elseif _kb(0x45) then rotate=1 end
        DyePreview32.rotate(rotate,now)
        GliderPreview32.spin=GliderPreview32.spin+math.max(-1,math.min(1,rotate))*.025
    end
    local function edge(name, held, repeatable)
        local p = SUI.prev_btn
        local was = p[name]
        p[name] = held and now or nil
        if held and not was then SUI.nav_at = now + 0.35 return true end
        if held and repeatable and now > SUI.nav_at then SUI.nav_at = now + 0.15 return true end
        return false
    end
    if SUI.confirm or SUI.native_pending then return end
    if edge("back", back, false) then
        SUI.confirm={kind="exit",text="Exit dyeing and discard unconfirmed colours?"}
        SUI.block_until=now+0.25
        return
    end
    local G = SUI.G or {}
    local g = G[SUI.gi]
    local nregions = g and #g.regions or 0
    local moved = false
    if edge("up", up, true) then
        if SUI.col == 1 then SUI.gi = _sui_nav(-1, math.max(1, #G), SUI.gi); SUI.ri = 0
        elseif SUI.col == 2 then SUI.ri = ((SUI.ri - 1) < 0) and nregions or (SUI.ri - 1)
        elseif SUI.col == 4 then SUI.col=2; SUI.ri=nregions
        elseif SUI.col==3 then SUI.di = _sui_nav(-1, #COLORS, SUI.di) end
        moved = true
    end
    if edge("down", down, true) then
        if SUI.col == 1 then
            if SUI.gi>=#G then SUI.col=4 else SUI.gi=SUI.gi+1; SUI.ri=0 end
        elseif SUI.col == 2 then
            if SUI.ri>=nregions then SUI.col=4 else SUI.ri=SUI.ri+1 end
        elseif SUI.col==3 then
            if SUI.di==#COLORS then SUI.col=4 else SUI.di=SUI.di+1 end
        elseif SUI.col==4 then SUI.col=2; SUI.ri=0 end
        moved = true
    end
    if edge("left", left, true) then
        if SUI.col == 3 and SUI.si > 1 then SUI.si = SUI.si - 1
        else SUI.col = math.max(1, SUI.col - 1) end
        moved = true
    end
    if edge("right", right, true) then
        if SUI.col == 3 and SUI.si < #SHADES then SUI.si = SUI.si + 1
        else SUI.col = math.min(4, SUI.col + 1) end
        moved = true
    end
    if edge("review",review,false) then SUI.col=4 end
    if edge("confirm",confirm,false) then
        if SUI.col==3 then _sui_stage()
        elseif SUI.col==4 then _sui_commit()
        else SUI.col=math.min(3,SUI.col+1) end
    end
    if edge("wash", wash, false) then
        if SUI.col==4 then _sui_preview_revert(); SUI.plan=DyePlan32.new(); DYE.status="Selected colours cleared."
        else SUI.confirm={kind='wash',text='Wash out this region and restore its original appearance?'} end
    end
    _sui_preview_apply()
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
    if dye_preview_ok then DyePreview32.screen(sw,sh) end
    if SUI.font then pcall(function() imgui.push_font(SUI.font) end) end
    local W, H = 790, 580
    local X, Y = sw - W - 50, (sh - H) * 0.38
    local ROW = 27
    draw.filled_rect(X, Y, W, H, C_BG)
    draw.outline_rect(X, Y, W, H, C_EDGE)
    draw.text("Dye Equipment", X + 16, Y + 12, C_EDGE)
    draw.text(SUI.dpad.ready and "D-pad / left stick / arrows: navigate"
        or "Left stick / arrows: navigate (D-pad guard unavailable)",
        X + 16, Y + H - 26, C_DIM)
    do
        local frame=PreviewFrame32.layout(sw,sh)
        local FW,FX=frame.w,frame.x
        draw.filled_rect(FX, Y, FW, H, 0x30100C0A)
        draw.outline_rect(FX, Y, FW, H, C_EDGE)
        local selected=(SUI.G or {})[SUI.gi]
        local is_glider=selected and selected.label=='Paraglider'
        draw.text(is_glider and 'Paraglider Preview' or 'Preview', FX + 16, Y + 12, C_EDGE)
        draw.text("Right stick / Q,E: rotate",FX+16,Y+H-60,C_DIM)
        if not is_glider and (dye_preview_ok or MQ.state ~= "done") then
            draw.text(dye_preview_ok and DyePreview32.status or MQ.failure or (MQ.state and "Preparing your likeness..." or ""),
                FX + 16, Y + H - 34, C_DIM)
        end
        if is_glider then
            draw.text(glider_preview.status,FX+16,Y+H-34,C_DIM)
            GliderPreview32.screen={w=sw,h=sh}
        end
    end
    local colx = { X + 16, X + 235, X + 470 }
    local top = Y + 50
    draw.text(SUI.col == 1 and "> EQUIPMENT" or "  EQUIPMENT", colx[1], top, SUI.col == 1 and C_SEL or C_DIM)
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
        local rows={{label=g.whole,parts=g.parts}}
        for _,r in ipairs(g.regions) do rows[#rows+1]=r end
        local first=math.max(1,SUI.ri+1-11)
        for i=first,math.min(#rows,first+11) do
            local row=rows[i]
            local ry=list_top+(i-first)*ROW
            if i-1==SUI.ri then draw.filled_rect(colx[2]-4,ry-2,215,ROW-3,C_SELBG) end
            local picked,total=0,#row.parts
            local choice,mixed=nil,false
            for _,p in ipairs(row.parts) do if SUI.plan.choices[DyePlan32.key(p)] then picked=picked+1 end end
            for _,p in ipairs(row.parts) do
                local c=SUI.plan.choices[DyePlan32.key(p)]
                if c then
                    if choice and (choice.col.key~=c.col.key or choice.shade.key~=c.shade.key) then mixed=true end
                    choice=choice or c
                end
            end
            local label=row.label
            if picked>0 then label=label..(picked==total and " *" or " +") end
            local tc=i-1==SUI.ri and C_TEXT or C_DIM
            if choice and not mixed then tc=_abgr(choice.col.v[1],choice.col.v[2],choice.col.v[3]) end
            draw.text(label,colx[2],ry,tc)
            if i-1==SUI.ri and choice then
                draw.text(mixed and "Selected: mixed colours" or ("Selected: "..choice.col.key.." / "..choice.shade.key),X+16,Y+H-144,C_TEXT)
            end
        end
    end
    local pending=DyePlan32.group_count(SUI.plan)
    local fy=Y+H-112
    if SUI.col==4 then draw.filled_rect(X+12,fy-3,420,30,C_SELBG) end
    local confirm_label="Confirm and Dye ("..pending.." groups)"
    if DYE.cost_mode=="gold" then
        local ok_rows,rows=pcall(DyePlan32.resolve,SUI.plan,SUI.G or {})
        if not (ok_rows and type(rows)=="table") then rows={} end
        local n=_gold_items(rows)
        confirm_label="Confirm and Dye ("..pending.." groups, "..n..(n==1 and " piece" or " pieces")..")  ".._gold_price(rows).." G"
    end
    draw.text((SUI.col==4 and "> " or "")..confirm_label,X+16,fy,C_EDGE)
    draw.text("A: select   Down past any list / Tab: confirm",X+16,fy+28,C_DIM)
    local status=tostring(DYE.status or "")
    if #status>88 then status=status:sub(1,85).."..." end
    draw.text(status,X+16,fy+54,C_DIM)
    local counts = DYE.counts or {}
    for i, col in ipairs(COLORS) do
        local cy = list_top + (i - 1) * 36
        if cy < Y + H - ROW then
            if i == SUI.di and SUI.col == 3 then
                draw.filled_rect(colx[3] - 4, cy - 3, 290, 32, C_SELBG)
            end
            for s, shade in ipairs(SHADES) do
                local cx = colx[3] + 105 + (s - 1) * 42
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
                if SUI.affordable and SUI.affordable[i] and not SUI.affordable[i][s] then
                    draw.filled_rect(cx, cy, 32, 26, 0xA8000000)
                end
                if i == SUI.di and s == SUI.si and SUI.col == 3 then
                    draw.outline_rect(cx - 3, cy - 3, 38, 32, C_SEL)
                end
            end
            local label = col.key
            if DYE.cost_mode == "gold" then
            elseif DYE.cost_mode ~= "free" and DYE.consume ~= false and next(DYE.item_ids or {}) then
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
local function _mq_cam()
    local pos = nil
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
local function _mq_weld()
    if not (MQ.state == "done" and _go_valid(MQ.inst)) or MQ.parked then return end
    pcall(function()
        local cam = _mq_cam()
        local pgo = _player_go()
        local ptf = pgo and pgo:call("get_Transform")
        local pp = ptf and ptf:call("get_UniversalPosition")
        if not pp then return end
        if not cam then
            local fwd = ptf:call("get_AxisZ")
            MQ.inst:call("get_Transform"):call("set_UniversalPosition",
                _mq_position(pp.x + fwd.x * 2.2, pp.y, pp.z + fwd.z * 2.2))
            return
        end
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
        if m:call("hasMotion", 0, 10) ~= true then return end
        local lyr = m:call("getLayer", 0)
        lyr:call(
            "changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)",
            0, 10, 0.0, 4.0, 1, 1)
    end)
end
local function _mq_tick()
    if not MQ.state or MQ.state == "done" then return end
    if MQ.state ~= "loading" and MQ.inst and not _go_valid(MQ.inst) then
        _mq_log("mannequin shell expired during build")
        _mq_destroy()
        return
    end
    local now = os.clock()
    if MQ.state == "loading" then
        pcall(function()
            local ready = false
            if MQ.pfb then ready = MQ.pfb:call("get_Ready") == true end
            if not ready then
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
                inst = MQ.pfb:call("instantiate(via.Position, via.Folder)",
                    _mq_position(up.x, up.y - 30.0, up.z), fol)
            end)
            if not inst then _mq_log("FAILED: instantiate returned nil") _mq_destroy() return end
            pcall(function() inst:add_ref() end)
            MQ.inst = inst
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
        local ok, accepted = pcall(function()
            local method = Compat32.method("app.CloneBuilder", "requestBuild", {
                "app.Character", "System.Boolean", "app.CharacterEditManager.BuildCompletedHandler" })
            assert(method:get_return_type():get_full_name() == "System.Boolean", "unexpected requestBuild return type")
            return method:call(MQ.cb, ch, false, nil)
        end)
        if not ok or accepted ~= true then
            _mq_log("FAILED: requestBuild rejected: " .. tostring(accepted))
            _mq_destroy()
            MQ.failure = "Preview unavailable: likeness build was not accepted."
            return
        end
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
re.on_pre_application_entry("UpdateBehavior", function()
    temper_combat_probe.tick()
    temper_damage_test.tick()
    temper_stamina_probe.tick()
    temper_secondary_test.tick()
    temper_climb.tick()
    if dialogue_load_ok then DialogueCloneLoad32.tick() end
    if dialogue_instance_ok then DialogueCloneInstance32.tick() end
    local workkey=rawget(_G,"Interactables_session_key")
    local worktoken=TemperVisual32.is_anvil(workkey) and rawget(_G,"Interactables_session_token") or nil
    local other_preview=(dye_preview_ok and DyePreview32.active()) or
        (dialogue_instance_ok and DialogueCloneInstance32.active()) or
        (dialogue_load_ok and (DialogueCloneLoad32.state=="loading" or DialogueCloneLoad32.state=="queued"))
    local safe=not SUI.open and not other_preview and (not rawget(_G,"Interactables_session_token") or worktoken~=nil)
    local state
    if worktoken or workpiece_display_token then
        pcall(function()
            local cm=sdk.get_managed_singleton("app.CharacterManager")
            local ch=cm and cm:call("get_ManualPlayer")
            local gm=sdk.get_managed_singleton("app.GuiManager")
            local im=sdk.get_managed_singleton("app.InteractManager")
            state={owner=tostring(ch:get_address()),loading=gm:call("get_IsLoadGui"),
                jacked=ch:call("get_IsJacked"),interacting=im:call("isInteracting(app.Character)",ch)}
            state.paused=gm:call('isPausedGUI')==true
            state.owned_dialog=temper_dialog.owns(worktoken)
            pcall(function()
                local am=ch:call("get_ActionManager") or ch:get_field("<ActionManager>k__BackingField")
                local list=am:get_field("CurrentActionList") or am:call("get_CurrentActionList")
                local action=list:call("get_Item",0)
                local name=action:get_field("Name") or action:call("get_Name")
                state.action=name~=nil and tostring(name) or nil
            end)
        end)
    end
    local previous_display=workpiece_display_token
    workpiece_display_token,workpiece_exiting=workpiece_exit.tick(os.clock(),worktoken,state,safe)
    temper_menu.sync(workpiece_display_token,workpiece_exiting,os.clock())
    temper_preview.open=temper_menu.open
    temper_preview.session_token=workpiece_display_token
    pcall(temper_menu.prompts,rawget(_G,'IrisPrompt'))
    _G.InteractablesTemperUIOpen=temper_menu.open
    if previous_display and not workpiece_display_token then
        pcall(json.dump_file,"ImmersiveInteractables_WorkpieceExit32.json",{
            reason=workpiece_exit.reason,state=state,safe=safe,session=worktoken,clock=os.clock()})
    end
    local nearby=rawget(_G,"Interactables_near_anvil")
    local now=os.clock()
    if not worktoken and not rawget(_G,"Interactables_session_token") and not SUI.open and not other_preview
        and not _game_gui_open() and AnvilWorkpiece32.auto_prepare~=false
        and nearby and now-nearby.at<3 and now>=workpiece_auto_at
        and not workpiece_display_token and not AnvilWorkpiece32.active() and not AnvilWorkpiece32.warming and not temper_comparison.active() and not temper_proposed.active() then
        if AnvilWorkpiece32.prewarm() then workpiece_auto_at=now+5 end
    end
    AnvilWorkpiece32.tick(workpiece_display_token,(workpiece_display_token~=nil or AnvilWorkpiece32.warming==true) and safe
        and (AnvilWorkpiece32.active() or (not temper_comparison.active() and not temper_proposed.active())),prepare_workpiece)
    temper_comparison.tick(temper_menu.open and safe and workpiece_display_token or nil,
        AnvilWorkpiece32.parts and AnvilWorkpiece32.comparison_owner() or nil,prepare_workpiece)
    temper_proposed.tick(temper_menu.open and safe and workpiece_display_token or nil,
        temper_comparison.ready and AnvilWorkpiece32.comparison_owner() or nil,prepare_workpiece)
    if dye_preview_ok then
        local busy=(dialogue_instance_ok and DialogueCloneInstance32.active()) or
            (dialogue_load_ok and (DialogueCloneLoad32.state=="loading" or DialogueCloneLoad32.state=="queued")) or AnvilWorkpiece32.active() or temper_comparison.active() or temper_proposed.active()
        DyePreview32.tick(SUI.session_token,DYE.preview_enabled and SUI.open==true and not busy)
    end
    DyeCamera32.tick(temper_menu.open and workpiece_display_token or SUI.session_token,
        temper_menu.open or (DYE.lock_vertical_camera and SUI.open==true and not SUI.gui_open))
end)
re.on_pre_application_entry('UpdateBehavior',function()
    local g=SUI.G and SUI.G[SUI.gi]
    local wanted=SUI.open and not SUI.gui_open and not SUI.confirm and not SUI.native_pending
        and g and g.label=='Paraglider' and GliderPreview32.screen
    glider_preview.tick(wanted and SUI.session_token or nil,
        dye_preview_ok and DyePreview32.token())
    if dye_preview_ok then DyePreview32.set_hidden(wanted and glider_preview.ready or false) end
end)
re.on_application_entry("LateUpdateBehavior", function()
    glider_preview.prepare()
    if glider_preview.mesh and not glider_preview.parts then
        pcall(function()
            local e={mesh=glider_preview.mesh,slot='Paraglider'}
            DYE.mat_cache[e.mesh:get_address()]=nil; _enrich(e)
            local parts={}
            for _,m in ipairs(e.mats) do
                local c=_read(e.mesh,m.index,m.var)
                if c then parts[#parts+1]={mesh=e.mesh,mat=m.index,var=m.var,name=m.name,original=c} end
            end
            if #parts>0 then glider_preview.parts=parts end
        end)
    end
    if glider_preview.parts then
        pcall(function()
            local g=SUI.G and SUI.G[SUI.gi]
            if not g or g.label~='Paraglider' then return end
            for _,p in ipairs(g.parts) do
                local c=_read(p.e.mesh,p.m.index,p.m.var)
                if c then
                    for _,q in ipairs(glider_preview.parts or {}) do
                        if q.name==p.m.name then _write(q.mesh,q.mat,q.var,c) end
                    end
                end
            end
        end)
    end
    if prefab_loader_ok then PrefabLoaderInspect32.tick() end
    if bestfriend_source_ok then BestfriendSource32.tick() end
    if preview_load_ok then PreviewLoad32.tick() end
    pcall(function()
        if MQ.want_park then MQ.want_park = nil; _mq_park() end
        if MQ.prebuild_at and os.clock() > MQ.prebuild_at then
            MQ.prebuild_at = nil
            if not MQ.state and _player_go() then
                MQ.parked = true
                _mq_start()
                MQ.parked = true
                if MQ.state then _mq_log("pre-building the mannequin (parked)") end
            end
        end
        _mq_tick()
        local key = rawget(_G, "Interactables_session_key")
        local at_station = key == DYE_STATION_KEY
        local token = at_station and rawget(_G, "Interactables_session_token") or nil
        local now = os.clock()
        if token ~= SUI.session_token then
            if SUI.open then _sui_close(false) end
            SUI.session_token, SUI.sess_since, SUI.dismissed = token, nil, nil
        end
        if at_station and token and SUI.dismissed ~= token and not SUI.open then
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
            if SUI.open then _sui_close(false) end
        end
        _G.InteractablesDyeUIOpen = SUI.open == true
        _apply_pause()
    end)
end)
re.on_application_entry("LateUpdateBehavior", function()
    Perf32.call("dye.material_heal",_reapply_tick)
    pcall(_mq_weld)
    if not SUI.open then return end
    pcall(function()
        local IP = rawget(_G, "IrisPrompt")
        if IP and type(IP.set_slot) == "function" then
            IP.set_slot("interactables_dye", "PNL_R03", SUI.col==4 and "Confirm and Dye" or "Select Colour")
            IP.set_slot("interactables_dye", "PNL_R02", "Done")
            IP.set_slot("interactables_dye", "PNL_L03", "Wash Out")
        end
    end)
end)
_game_gui_open=function()
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
prepare_workpiece=function(go,comparison_only)
    if not comparison_only then workpiece_sources={} end
    local sources,player_meshes,finish_parts={},{},{}
    local worn=_worn(os.clock())
    local substitute
    for _,e in ipairs(worn) do
        if e.weapon and DaggerWorkpiece32.required(e.path) then substitute=DaggerWorkpiece32.family(e.path); break end
    end
    for _,e in ipairs(worn) do
        player_meshes[tostring(e.mesh:get_address())]=true
        if e.weapon and e.path~='?' and ((substitute and DaggerWorkpiece32.family(e.path)==substitute)
            or (not substitute and e.slot=='WeaponMain')) then
            if not comparison_only then workpiece_sources[#workpiece_sources+1]=e.mesh end
            local row={}
            for _,m in ipairs(e.mats) do
                local c=_read(e.mesh,m.index,m.var); row[m.name]=c
                if c and TemperVisual32.eligible(DyePlan32.material(m.name)) then
                    finish_parts[#finish_parts+1]={slot=e.slot,path=e.path,name=m.name,original=c}
                end
            end
            sources[e.path]=row
        end
    end
    assert(next(sources),"Equipped weapon resources unavailable")
    local parts,first,visited,count={},nil,{},0
    local dagger_mesh,dagger_tf,waiting
    local function walk(tf,depth)
        assert(depth<=16,"Workpiece hierarchy too deep")
        local addr=tostring(tf:get_address()); assert(not visited[addr],"Cyclic clone hierarchy")
        visited[addr]=true; count=count+1; assert(count<=512,"Workpiece hierarchy too large")
        local childgo=tf:call("get_GameObject")
        local mesh=childgo:call("getComponent(System.Type)",sdk.typeof("via.render.Mesh"))
        if mesh then
            assert(not player_meshes[tostring(mesh:get_address())],"Refusing player mesh alias")
            local path=_mesh_path(mesh)
            local single_weapon=comparison_only or DaggerWorkpiece32.family(path)=='wp03'
            local source=temper_comparison.select_source(sources[path],first,tf,single_weapon)
            local dagger_path=path:lower()==DaggerWorkpiece32.path
            if substitute and not comparison_only and (source or dagger_path) then
                mesh:call('set_Enabled',false)
                if not dagger_mesh then dagger_mesh,dagger_tf=mesh,tf end
                source=nil
            end
            mesh:call("set_Enabled",source~=nil)
            if source then
                first=first or tf
                local e={mesh=mesh,slot="WeaponMain",weapon=true}; _enrich(e)
                for _,m in ipairs(e.mats) do
                    local colour=source[m.name]
                    if colour then _write(mesh,m.index,m.var,colour) end
                    if colour and TemperVisual32.eligible(DyePlan32.material(m.name)) then
                        parts[#parts+1]={mesh=mesh,mat=m.index,var=m.var,path=path,name=m.name,
                            original={colour[1],colour[2],colour[3],colour[4]},address=tostring(mesh:get_address())}
                    end
                end
            end
        end
        local child=tf:call("get_Child")
        while child do walk(child,depth+1); child=child:call("get_Next") end
    end
    walk(go:call("get_Transform"),0)
    if substitute and not comparison_only then
        if not dagger_mesh then
            workpiece_wait_since=workpiece_wait_since or os.clock()
            assert(os.clock()-workpiece_wait_since<20,'No owned weapon mesh for dagger replacement')
            return nil,nil,nil,'Preparing weapon copy...'
        end
        workpiece_wait_since=nil
        if not DaggerWorkpiece32.bind(dagger_mesh,go,player_meshes) then return nil,nil,nil,'Preparing dagger tool...' end
        DYE.mat_cache[dagger_mesh:get_address()]=nil
        local e={mesh=dagger_mesh,slot='WeaponMain',weapon=true}; _enrich(e)
        assert(e.path:lower()==DaggerWorkpiece32.path,'Dagger mesh readback mismatch')
        for _,m in ipairs(e.mats) do
            local c=_read(e.mesh,m.index,m.var)
            if c then parts[#parts+1]={mesh=e.mesh,mat=m.index,var=m.var,path=e.path,name=m.name,original=c} end
        end
        assert(#parts>0 and #finish_parts>0,'Dagger or equipped finish materials unavailable')
        first=dagger_tf; dagger_mesh:call('set_Enabled',true)
        DaggerWorkpiece32.forget(go)
    end
    assert(first and #parts>0,"Clone has no matching dyeable main weapon")
    return parts,first,finish_parts
end
local function temper_weapon_key()
    local ch=assert(_player_ch())
    local im=assert(sdk.get_managed_singleton('app.ItemManager'))
    local eq=assert(im:call('getEquipData(app.Character)',ch))
    return TemperWeaponKey32.resolve(ch,eq,Compat32)
end
local temper_flow=require('II.TemperFlow32').new({
    weapon=temper_weapon_key,
    active=function() return temper_damage_test.until_at or temper_secondary_test.mode or temper_climb.until_at end,
    count=function(index)
        return assert(tonumber(sdk.get_managed_singleton('app.ItemManager'):call(
            'getHaveNum(System.Int32, app.Character)',TemperVisual32.finishes[index].item,_player_ch())))
    end,
    debit=function(index)
        sdk.get_managed_singleton('app.ItemManager'):call('deleteItem(System.Int32, System.Int32, app.Character)',
            TemperVisual32.finishes[index].item,1,_player_ch())
    end,
    start=function(index,weapon)
        local guard=function() return temper_weapon_key()==weapon end
        if index==1 then temper_damage_test.guard=guard; temper_damage_test.start()
        elseif index==4 then
            temper_climb.start(guard)
            temper_damage_test.guard=guard
            temper_damage_test.start({multiplier=1.08,receiver_guard=temper_climb.receiver,
                status='Gold treatment: +8% damage to the attached monster.'})
        else temper_secondary_test.guard=guard; temper_secondary_test.start(index==2 and 'reaction' or 'stamina') end
    end,
    stop=function() temper_damage_test.stop(); temper_secondary_test.stop(); temper_climb.stop() end,
})
TEMPER=TemperVisual32.new({
    complete=function(token)
        local index=TEMPER.selected
        if temper_flow.complete(token) then
            local f=TemperVisual32.finishes[index]
            local previous=DYE.records
            local saved,why=pcall(function()
                DYE.records=TemperFinish32.merge(previous,AnvilWorkpiece32.finish_parts or assert(TEMPER.parts),f)
                assert(_save(),'Finish profile could not be saved')
            end)
            if not saved then
                DYE.records=previous; DYE.record_index=nil; DYE.dirty=false
                log.error('[Tempering finish] '..tostring(why))
            else DYE.tick_at=0; pcall(_reapply_tick) end
            temper_flow.status='Tempering Complete\n'..f.bonus..' for 30 minutes.\n1 '..f.ore..' consumed.'
            temper_dialog.notify(token,temper_flow.status..'\n'..(saved and 'Finish saved.'
                or 'Finish could not be saved. Buff is active.'))
        else temper_dialog.queue(token,temper_flow.status,false) end
    end,
    upfront=true,
    roll=function(n) return math.random(n) end,
    capture=function()
        return AnvilWorkpiece32.parts
    end,
    matches=function(parts)
        return parts==AnvilWorkpiece32.parts
    end,
    write=function(p,colour)
        if not _write(p.mesh,p.mat,p.var,colour) then return false end
        local back=_read(p.mesh,p.mat,p.var)
        return back and math.abs(back[1]-colour[1])<0.01
            and math.abs(back[2]-colour[2])<0.01 and math.abs(back[3]-colour[3])<0.01 or false
    end,
})
TEMPER.show_hud=true
re.on_frame(function()
    if temper_menu.open and not temper_dialog.job then
        temper_menu.comparison_ready=temper_comparison.ready
        temper_menu.comparison_error=temper_comparison.error
        local pushed=false
        if SUI.font then pushed=pcall(imgui.push_font,SUI.font) end
        local ok,err=pcall(temper_menu.draw,TemperVisual32.finishes,temper_proposed.ready,AnvilWorkpiece32.error or temper_proposed.status)
        if pushed then pcall(imgui.pop_font) end
        if not ok then TEMPER.status="Anvil menu draw failed: "..tostring(err) end
        temper_preview.screen=temper_menu.screen
        temper_preview.comparison=true
    end
end)
AnvilWorkpiece32.before_detach=function()
    temper_flow.cancel()
    TEMPER.reset()
    if workpiece_visibility.restore() then workpiece_hidden=false; workpiece_sources={} end
end
re.on_script_reset(function() workpiece_visibility.restore() end)
re.on_application_entry("LateUpdateBehavior",function()
    AnvilWorkpiece32.prepare()
    temper_comparison.prepare()
    temper_proposed.prepare()
    if AnvilWorkpiece32.parts and not workpiece_hidden then
        local hidden,why=pcall(workpiece_visibility.hide,workpiece_sources)
        workpiece_hidden=hidden
        if not hidden then AnvilWorkpiece32.status="Weapon hiding failed: "..tostring(why) end
    elseif not AnvilWorkpiece32.parts and workpiece_hidden then
        if workpiece_visibility.restore() then workpiece_hidden=false end
    end
    local key=rawget(_G,"Interactables_session_key")
    local token=workpiece_display_token
    if not token and not TEMPER.token then return end
    local ok,err=pcall(function()
        local now=os.clock()
        TEMPER.tick(token,now,temper_menu.open or workpiece_exiting or _game_gui_open() or SUI.open==true or not AnvilWorkpiece32.parts)
        if workpiece_exiting then temper_flow.cancel() end
        temper_menu.flow_status=temper_flow.status
        if temper_dialog.error then
            temper_menu.confirming=nil
            temper_flow.status=temper_dialog.error..(temper_dialog.error_completion and ' Treatment was already applied.' or ' Nothing charged.')
            temper_menu.flow_status=temper_flow.status
            temper_dialog.error=nil
            temper_dialog.error_completion=nil
            temper_menu.prev={}; temper_menu.block_until=now+.4
        end
        if temper_dialog.answer then
            local answer=temper_dialog.answer; temper_dialog.answer=nil
            local pending=temper_menu.confirming; temper_menu.confirming=nil
            temper_menu.prev={}; temper_menu.block_until=now+.4
            if pending and answer.token==token and answer.confirmed then
                if temper_flow.begin(token,pending) then
                    TEMPER.elapsed=0; TEMPER.finished=false
                    if TEMPER.apply(pending) then temper_menu.open=false else temper_flow.cancel() end
                else temper_dialog.queue(token,temper_flow.status,false) end
            elseif pending and answer.token==token then
                temper_flow.status='Confirmation Cancelled. Nothing Charged.'
            end
        end
        if temper_menu.open and not temper_dialog.job and not _game_gui_open() then
            if now>=(temper_menu.quote_at or 0) then
                temper_menu.quote_at=now+1; temper_menu.ore_counts={}
                pcall(function()
                    local im=sdk.get_managed_singleton('app.ItemManager'); local ch=_player_ch()
                    for _,f in ipairs(TemperVisual32.finishes) do
                        temper_menu.ore_counts[f.item]=tonumber(im:call('getHaveNum(System.Int32, app.Character)',f.item,ch))
                    end
                end)
            end
            local mask=_pad_mask(); local dp=SUI.dpad.directions(mask)
            local action=temper_menu.input({up=dp.up or _kb(0x26),down=dp.down or _kb(0x28),
                accept=(mask & PAD.cross)~=0 or _kb(0x0D) or _kb(0x20),
                back=(mask & PAD.circle)~=0 or _kb(0x08) or _kb(0x10)},now,TEMPER.parts~=nil)
            local dt=math.max(0,math.min(.05,now-(temper_menu.rotate_at or now)))
            temper_menu.rotate_at=now
            local rotate=tonumber(SUI.rx) or 0
            if _kb(0x25) then rotate=-1 elseif _kb(0x27) then rotate=1 end
            if math.abs(rotate)>.2 then temper_preview.spin=(temper_preview.spin+rotate*dt*90)%360 end
            local tint_key=temper_menu.original and 'original' or tostring(temper_menu.selected or 1)
            if temper_proposed.parts and (temper_menu.dirty or temper_proposed.tint_key~=tint_key) then
                for _,p in ipairs(temper_proposed.parts) do
                    local colour=temper_menu.original and p.original or TemperVisual32.finishes[temper_menu.selected or 1].colour
                    assert(_write(p.mesh,p.mat,p.var,colour),'Proposed tint write failed')
                end
                temper_proposed.tint_key=tint_key; temper_menu.dirty=false
            end
            if action=='start' then
                local index=temper_menu.selected or 1
                temper_menu.open=true
                if temper_flow.check(token,index) then
                    local f=TemperVisual32.finishes[index]
                    temper_menu.confirming=index
                    if not temper_dialog.queue(token,'Apply '..f.name..'?\n'..f.bonus..' for 30 minutes.\nCost: 1 '..f.ore..', charged after 45 seconds of work.\nOnce applied, another treatment cannot be selected until this one ends.',true) then
                        temper_menu.confirming=nil; temper_flow.status='Confirmation unavailable. Nothing charged.'
                    end
                else
                    local f=TemperVisual32.finishes[index]
                    local notice=temper_flow.status
                    if notice:find('Not enough ore',1,true) then notice='1 '..f.ore..' is required for this treatment. Nothing charged.' end
                    temper_dialog.queue(token,notice,false)
                end
                temper_menu.flow_status=temper_flow.status
            end
            if action=='cancel' then
                temper_flow.cancel()
                _G.InteractablesTemperExitRequest={token=token,at=now}
            end
            temper_preview.open=temper_menu.open
            _G.InteractablesTemperUIOpen=temper_menu.open
            pcall(temper_menu.prompts,rawget(_G,'IrisPrompt'))
        end
    end)
    if not ok then
        TEMPER.reset(); TEMPER.status="Finish test cancelled: "..tostring(err)
        pcall(function() log.info("[TemperVisual32] "..TEMPER.status) end)
    end
end)
re.on_draw_ui(function()
    if not imgui.tree_node("Anvil tempering (visual prototype)") then return end
    imgui.text(temper_combat_probe.status)
    imgui.text(temper_stamina_probe.status)
    imgui.text(temper_flow.status)
    imgui.text(temper_climb.status)
    if temper_climb.until_at then
        imgui.text('Climb speed hook uses: '..tostring(temper_climb.hits))
        if temper_climb.last then imgui.text(temper_climb.last) end
    end
    imgui.text(temper_secondary_test.status)
    for _,test in ipairs({{'stamina','Test -5% Skill Stamina Cost'},{'reaction','Test +8% Reaction Power'}}) do
        if imgui.button(test[2]) then
            temper_climb.stop()
            temper_secondary_test.guard=nil
            temper_damage_test.stop()
            local ok,err=pcall(temper_secondary_test.start,test[1])
            if not ok then temper_secondary_test.stop('Test unavailable: '..tostring(err)) end
        end
    end
    if temper_secondary_test.mode then
        imgui.text(string.format('Secondary Test Remaining: %d seconds',math.max(0,math.ceil(temper_secondary_test.until_at-os.clock()))))
        if imgui.button('Stop Secondary Buff Test') then temper_secondary_test.stop() end
    end
    if temper_secondary_test.last then imgui.text(temper_secondary_test.last) end
    if imgui.button('Capture Knockdown + Stamina Routes (Read-Only, 60 Seconds)') then
        temper_damage_test.stop('Damage test stopped for baseline capture.')
        temper_secondary_test.stop()
        local ok,err=pcall(temper_combat_probe.arm)
        if not ok then temper_combat_probe.status='Capture unavailable: '..tostring(err) end
        ok,err=pcall(temper_stamina_probe.arm)
        if not ok then temper_stamina_probe.status='Capture unavailable: '..tostring(err) end
    end
    imgui.text(temper_damage_test.status)
    if temper_damage_test.until_at then
        imgui.text(string.format('Damage Test Remaining: %d seconds',math.max(0,math.ceil(temper_damage_test.until_at-os.clock()))))
        if imgui.button('Stop Damage Buff Test') then temper_damage_test.stop(); temper_climb.stop() end
    elseif imgui.button('Start +5% Damage Buff Test (Free, 30 Minutes)') then
        temper_climb.stop()
        temper_damage_test.guard=nil
        temper_secondary_test.stop()
        local ok,err=pcall(temper_damage_test.start)
        if not ok then temper_damage_test.stop('Damage test unavailable: '..tostring(err)) end
    end
    imgui.text('Diagnostic affects Arisen-owned damage, not yet weapon-filtered. No ore charged.')
    if temper_damage_test.last then imgui.text(temper_damage_test.last) end
    imgui.text('Current UI copy: '..tostring(temper_comparison.error or temper_comparison.status))
    imgui.text('Proposed UI copy: '..tostring(temper_proposed.error or temper_proposed.status))
    if imgui.button('Capture player weapon hits (read-only, 60 seconds)') then
        local ok,err=pcall(temper_combat_probe.arm)
        if not ok then temper_combat_probe.status='Capture unavailable: '..tostring(err) end
    end
    imgui.text(TEMPER.status)
    imgui.text(AnvilWorkpiece32.status)
    imgui.text("Anvil: 1 ore charged on completion. Buff tied to main weapon item ID; reset clears it.")
    imgui.text("Changes BaseColor tint only - not gloss, texture, sharpness or weapon stats.")
    local auto_changed,auto_on=imgui.checkbox("Prepare automatically near anvils (test)",AnvilWorkpiece32.auto_prepare~=false)
    if auto_changed then AnvilWorkpiece32.auto_prepare=auto_on end
    if not AnvilWorkpiece32.active() and not rawget(_G,"Interactables_session_token") then
        if imgui.button("Prepare display before using anvil (test)") then AnvilWorkpiece32.prewarm() end
        imgui.text("Wait for Display prepared, then use the anvil. Stay nearby; do not reset while building.")
    end
    if AnvilWorkpiece32.parts then
        imgui.text("Display materials targeted: "..#AnvilWorkpiece32.parts)
        for _,p in ipairs(AnvilWorkpiece32.parts) do imgui.text("  "..p.name) end
    end
    local changed,value=imgui.checkbox("Show tempering test notice",TEMPER.show_hud)
    if changed then TEMPER.show_hud=value end
    if TEMPER.token and not TEMPER.finished then
        imgui.text(string.format("Smithing: %d / 45 seconds",math.floor(TEMPER.elapsed)))
    end
    if TEMPER.parts then
        if imgui.button("Open weapon comparison window") then temper_menu.open=true; temper_preview.open=true end
        for i,finish in ipairs(TemperVisual32.finishes) do
            if imgui.button("Preview "..finish.name) then TEMPER.command=i end
        end
        if imgui.button("Compare original appearance") then TEMPER.command="original" end
    end
    if AnvilWorkpiece32.parts then
        imgui.text(AnvilWorkpiece32.placement_status or "Placement not yet saved")
        imgui.text(AnvilWorkpiece32.grip_status or "Hand grip not loaded")
        local hand_message=AnvilWorkpiece32.hand_status or "Hand not resolved"
        for offset=1,#hand_message,75 do imgui.text(hand_message:sub(offset,offset+74)) end
        local hand_changed,hand_follow=imgui.checkbox("Follow supporting hand (test)",AnvilWorkpiece32.follow_hand)
        if hand_changed then AnvilWorkpiece32.follow_hand=hand_follow; AnvilWorkpiece32.rebind_hand=true end
        if AnvilWorkpiece32.follow_hand then
            imgui.text("Hand-local grip controls: independent of the animation frame at entry.")
            for _,row in ipairs({{"grip_x",-2,2},{"grip_y",-2,2},{"grip_z",-2,2},
                {"grip_pitch",-180,180},{"grip_yaw",-180,180},{"grip_roll",-180,180}}) do
                local moved,v=imgui.slider_float(row[1],AnvilWorkpiece32[row[1]],row[2],row[3])
                if moved then AnvilWorkpiece32[row[1]]=v end
            end
        else
        imgui.text("Blade twist turns the blade face without changing its lengthwise direction.")
        local twisted,angle=imgui.slider_float("Blade twist",AnvilWorkpiece32.twist,-180,180)
        if twisted then AnvilWorkpiece32.twist=angle end
        for _,row in ipairs({{"height",-1,2},{"forward",-1.6,1.6},{"side",-1.6,1.6},
            {"pitch",-180,180},{"yaw",-180,180},{"roll",-180,180},{"contact",-2,2}}) do
            local moved,v=imgui.slider_float("Workpiece "..row[1],AnvilWorkpiece32[row[1]],row[2],row[3])
            if moved then AnvilWorkpiece32[row[1]]=v end
        end
        end
        if imgui.button("Save weapon/anvil placement") then AnvilWorkpiece32.save_placement() end
        if AnvilWorkpiece32.family_key then
            imgui.text('Family: '..AnvilWorkpiece32.family_key..' (individual saves take priority)')
            if imgui.button('Save Grip as Weapon-Family Default') then AnvilWorkpiece32.save_placement(true) end
        end
    end
    imgui.text("Completed treatments save the finish like a dye. Buffs last 30 minutes.")
    imgui.tree_pop()
end)
re.on_frame(function()
    if not TEMPER.token or not TEMPER.show_hud or SUI.open or SUI.gui_open or temper_menu.open then return end
    pcall(function()
        local sz=imgui.get_display_size()
        local x,y=math.max(16,sz.x-440),math.max(16,sz.y*0.58)
        draw.filled_rect(x,y,420,72,0xA0181410)
        draw.text(TEMPER.finished and "Weapon finish - visual test" or
            string.format("Tempering: %d / 45s",math.floor(TEMPER.elapsed)),x+12,y+10,0xFFEAD8B0)
        draw.text(not AnvilWorkpiece32.parts and
            ((AnvilWorkpiece32.error or AnvilWorkpiece32.blocked or not AnvilWorkpiece32.active())
                and "Display unavailable - stop; see Anvil tempering panel" or "Preparing display weapon; please wait") or TEMPER.active and TemperVisual32.finishes[TEMPER.selected].name or
            (TEMPER.finished and "See Anvil tempering in REFramework" or "Keep working to reveal a finish"),x+12,y+32,0xFFE0D8C8)
        draw.text("Finish saved on completion; early cancellation is free",x+12,y+52,0xFFE0D8C8)
    end)
end)
do
    local ok,err=SUI.dpad.install(function()
        return (SUI.open == true or temper_menu.open) and SUI.gui_open ~= true
    end,_pad_mask)
    _mq_log(ok and ("Dye D-pad navigation and pawn-order input guard installed: "..tostring(SUI.dpad.method))
        or ("Dye D-pad unavailable; stick/keyboard retained: "..tostring(err)))
end
SUI.menu_guard = require("II.DyeMenuGuard32")
do
    local ok,err=SUI.menu_guard.install(function() return SUI.open==true or temper_menu.open end)
    _mq_log(ok and "Dye pause/map request guard installed."
        or ("Dye pause/map guard unavailable: "..tostring(err)))
end
re.on_application_entry("LateUpdateBehavior", function()
    if not SUI.open then return end
    pcall(function()
        if SUI.native_pending then
            if temper_dialog.error then
                DYE.status=temper_dialog.error; temper_dialog.error=nil
                SUI.native_pending=nil; SUI.confirm=nil
            elseif temper_dialog.answer then
                local answer=temper_dialog.answer; temper_dialog.answer=nil
                local pending=SUI.native_pending; SUI.native_pending=nil; SUI.confirm=nil
                SUI.prev_btn={}; SUI.block_until=os.clock()+.4
                if answer.token==SUI.session_token then
                    if pending.kind=='notice' then
                        if pending.close_after then _sui_close(true) end
                    elseif answer.confirmed then
                        if pending.kind=='exit' then _sui_close(true)
                        elseif pending.kind=='wash' then _sui_washout()
                        else
                            local done=_sui_commit_go()==true
                            SUI.confirm={kind='notice',text=DYE.status,close_after=done}
                        end
                    else DYE.status='Cancelled. Nothing charged.' end
                end
            elseif not temper_dialog.job then
                SUI.native_pending=nil; SUI.confirm=nil; DYE.status='Dialogue ended. Please try again.'
            end
            return
        end
        if SUI.confirm then
            if temper_dialog.queue(SUI.session_token,SUI.confirm.text,SUI.confirm.kind~='notice') then
                SUI.native_pending=SUI.confirm
            else
                DYE.status=temper_dialog.error or 'Dialogue unavailable. Nothing charged.'
                SUI.confirm=nil
            end
            return
        end
        if _game_gui_open() then
            _sui_preview_revert()
            SUI.prev_btn = {}
            return
        end
        local input_ok,input_err=Perf32.call("dye.input_preview",_sui_input,SUI.worn or {})
        if not input_ok then error(input_err) end
        if not SUI.open then return end
        _dye_scan_tick()
        local worn = _worn(os.clock())
        SUI.worn = worn
        if #worn == 0 then return end
        local now=os.clock()
        if now>=(SUI.model_at or 0) then
            SUI.model_at=now+0.5
            SUI.G=_sui_garments(worn)
            local ids={}
            for _,g in ipairs(SUI.G) do
                for _,p in ipairs(g.parts) do ids[#ids+1]=DyePlan32.key(p)..":"..p.e.mesh:get_address() end
            end
            local signature=table.concat(ids,";")
            if SUI.model_signature~=signature then
                SUI.model_signature=signature; SUI.model_rev=(SUI.model_rev or 0)+1
                SUI.ri=0
            end
            local g=SUI.G[SUI.gi]
            if g then SUI.ri=math.min(SUI.ri,#g.regions) end
            _dye_counts()
            SUI.affordable={}
            for i,col in ipairs(COLORS) do
                SUI.affordable[i]={}
                for j,shade in ipairs(SHADES) do SUI.affordable[i][j]=_dye_affordable(col.key,shade) end
            end
        end
        if #SUI.G == 0 then return end
        if SUI.gi > #SUI.G then SUI.gi = 1 end
    end)
end)
re.on_frame(function()
    if not SUI.open then return end
    if SUI.confirm or SUI.native_pending then return end
    pcall(function()
        local worn = SUI.worn or {}
        if #worn > 0 then _sui_draw(worn) end
    end)
end)
pcall(_dlg_close)
re.on_script_reset(function()
    glider_preview.reset()
    temper_comparison.reset()
    temper_proposed.reset()
    temper_menu.sync(nil,false,os.clock())
    pcall(temper_menu.prompts,rawget(_G,'IrisPrompt'))
    _G.InteractablesTemperUIOpen=false
    _G.InteractablesTemperExitRequest=nil
    TEMPER.reset()
    AnvilWorkpiece32.reset()
    DyeCamera32.release()
    pcall(_sui_preview_revert)
    if dye_preview_ok then DyePreview32.reset() end
    if dialogue_instance_ok then DialogueCloneInstance32.reset() end
    if dialogue_load_ok then DialogueCloneLoad32.cancel() end
    if prefab_loader_ok then PrefabLoaderInspect32.cancel() end
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
    SUI.worn = nil
    _G.InteractablesDyeUIOpen = false
    _G.InteractablesDyeExitRequest = nil
end)
