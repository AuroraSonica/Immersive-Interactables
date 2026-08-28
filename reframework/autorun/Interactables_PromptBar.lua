-- Immersive Interactables prompt bar
-- Draws button prompts in the game's own style. Shared with other mods that
-- use the same bar, so having several installed is fine.

local M = {
    enabled = true,
    slot    = "PNL_R02",
    log     = true,
}

local LOG = "Interactables_PromptBar.log"
local function _log(s)
    if not M.log then return end
    pcall(function()
        local f = io.open(LOG, "a")
        if f then f:write(os.date("[%H:%M:%S] ") .. tostring(s) .. "\n"); f:close() end
    end)
end

local TTL = 1.0
local slots = {}
local function _mounted_now()

    return rawget(_G, "IrisRiddenNow") == true
        or rawget(_G, "IrisGriffinMounted") == true
end
_G.IrisPrompt = _G.IrisPrompt or {}
_G.IrisPrompt.set = function(owner, text, prio, dist, pos, go)
    if not owner then return end

    if _mounted_now() then slots[owner] = nil; return end

    if _G.IrisStableUIOpen == true or _G.IrisFurnishUIOpen == true
        or _G.IrisFurnishFootprint == true or _G.IrisFurnishPlacing == true then
        slots[owner] = nil; return
    end
    if text == nil or text == "" then slots[owner] = nil; return end
    slots[owner] = { text = tostring(text), prio = tonumber(prio) or 0,
                     dist = tonumber(dist) or 1e9, pos = pos, go = go, at = os.clock() }
end
_G.IrisPrompt.clear = function(owner) if owner then slots[owner] = nil end end

local raw = {}
_G.IrisPrompt.set_slot = function(owner, slot, text, prio)
    if not (owner and slot) then return end
    local k = slot .. "|" .. owner

    if _mounted_now() then raw[k] = nil; return end
    if text == nil then raw[k] = nil; return end

    if text == "" then text = " " end
    raw[k] = { slot = slot, owner = owner, text = tostring(text),
               prio = tonumber(prio) or 0, at = os.clock() }
end
_G.IrisPrompt.clear_slot = function(owner, slot)
    if not owner then return end
    for k, v in pairs(raw) do
        if v.owner == owner and (slot == nil or v.slot == slot) then raw[k] = nil end
    end
end

_G.IrisPrompt.winner = function()
    local best, bd, bp, now = nil, 1e9, -1e9, os.clock()
    for owner, v in pairs(slots) do
        if now - (v.at or 0) > TTL then
            slots[owner] = nil
        else
            local d = v.dist or 1e9
            if d < bd - 0.3 or (math.abs(d - bd) <= 0.3 and v.prio > bp) then

                best, bd, bp = owner, d, v.prio
            end
        end
    end
    return best
end
_G.IrisPrompt.owner = _G.IrisPrompt.winner
_G.IrisPrompt.current = function()
    local w = _G.IrisPrompt.winner()
    return w and slots[w] and slots[w].text or nil
end
_G.IrisPrompt.current_entry = function()
    local w = _G.IrisPrompt.winner()
    return w, w and slots[w] or nil
end

local nb = { at = 0, v = false }
_G.IrisPrompt.native_busy = function()
    local now = os.clock()
    if now - nb.at < 0.15 then return nb.v end
    nb.at = now
    local v = false
    pcall(function()
        local im = sdk.get_managed_singleton("app.InteractManager")
        if im and im:call("hasHighestPriorityObjectForPlayer") == true then v = true end
    end)
    nb.v = v
    return v
end

local padnames, padlogged = nil, false
_G.IrisPad = _G.IrisPad or {}
_G.IrisPad.bit = function(...)
    if not padnames then
        padnames = {}
        pcall(function()
            local t = sdk.find_type_definition("via.hid.GamePadButton")
            for _, f in ipairs(t:get_fields()) do
                pcall(function() padnames[f:get_name()] = f:get_data(nil) end)
            end
        end)
        if not padlogged then
            padlogged = true
            local all = {}
            for k, v in pairs(padnames) do all[#all + 1] = k .. "=" .. tostring(v) end
            table.sort(all)
            _log("via.hid.GamePadButton fields: " .. table.concat(all, ", "))
        end
    end
    for _, n in ipairs({ ... }) do
        if padnames[n] then
            _log("pad resolve: '" .. n .. "' = " .. tostring(padnames[n]))
            return padnames[n], n
        end
    end
    _log("⛔ pad resolve FAILED for: " .. table.concat({ ... }, ", ") .. " - none of those fields exist")
    return 0, nil
end

local IRIS_PAD_KB = {
    [0x40080] = 0x46, [0x80] = 0x46, [0x40000] = 0x46, [16777280] = 0x46,
    [0x20020] = 0x20, [0x20]  = 0x20, [0x20000] = 0x20, [8] = 0x20,
    [0x400]   = 0x02, [0x100] = 0x11,
}
_G.IrisPad.down = function(bit)
    if not bit or bit == 0 then return false end
    local vk = IRIS_PAD_KB[math.floor(bit)]
    if vk then
        local hit = false
        pcall(function() hit = reframework:is_key_down(vk) == true end)
        if hit then return true end
    end
    local d = false
    pcall(function()

        local pm = sdk.get_native_singleton("via.hid.GamePad")
        local dev = pm and sdk.call_native_func(pm, sdk.find_type_definition("via.hid.GamePad"),
                                                "get_MergedDevice")
        if not dev then return end
        local b = math.floor(dev:call("get_Button") or 0)
        local m = math.floor(bit)
        d = (b & m) == m
    end)
    return d
end

local getobj, gui = nil, { warned = false }
pcall(function()
    getobj = sdk.find_type_definition("via.gui.Control"):get_method("getObject(System.String)")
end)

local WORLD_GUID_TEXT = "17a15b10-2026-4dd2-9a11-000000000001"
local world = {
    guid = nil, warned = false, enabled = true,
    req_ok = false, text_ok = false, text_warned = false, owner = nil,
}
pcall(function()
    local parse = sdk.find_type_definition("System.Guid"):get_method("Parse(System.String)")
    world.guid = parse and parse:call(nil, WORLD_GUID_TEXT)
end)

_G.InteractablesPromptMessagePre = function(args)
    local hit = false
    pcall(function()
        local g = sdk.to_valuetype(args[2], "System.Guid")
        hit = g and tostring(g:ToString()):lower() == WORLD_GUID_TEXT
    end)
    thread.get_hook_storage().iris_world_prompt = hit
end
_G.InteractablesPromptMessagePost = function(retval)
    local out = retval
    pcall(function()
        if thread.get_hook_storage().iris_world_prompt ~= true then return end
        local text = _G.IrisPrompt.current()
        if text then out = sdk.to_ptr(sdk.create_managed_string(text)) end
    end)
    return out
end

-- REFramework cannot remove hooks on script reset. Install these once and route
-- through fresh global functions so repeated reloads never stack stale closures.
if not _G.InteractablesPromptMessageHooksInstalled then
    local function pre(args)
        local f = rawget(_G, "InteractablesPromptMessagePre")
        if type(f) == "function" then return f(args) end
    end
    local function post(retval)
        local f = rawget(_G, "InteractablesPromptMessagePost")
        if type(f) == "function" then return f(retval) end
        return retval
    end
    local hooked = 0
    pcall(function()
        local td = sdk.find_type_definition("via.gui.message")
        for _, method in ipairs(td and td:get_methods() or {}) do
            pcall(function()
                if method:get_name() ~= "get" then return end
                local ps = method:get_param_types()
                if ps and #ps >= 1 and ps[1]:get_full_name() == "System.Guid" then
                    sdk.hook(method, pre, post); hooked = hooked + 1
                end
            end)
        end
    end)
    pcall(function()
        local td = sdk.find_type_definition("app.MessageManager")
        local method = td and td:get_method("getMessage(System.Guid)")
        if method then sdk.hook(method, pre, post); hooked = hooked + 1 end
    end)
    if hooked > 0 then _G.InteractablesPromptMessageHooksInstalled = true end
    _log("native world prompt message bridge armed on " .. tostring(hooked) .. " surface(s)")
end

local function _world_prompt(owner, entry)
    if not (world.enabled and entry and entry.pos and world.guid) then return false end
    world.req_ok, world.text_ok, world.owner = false, false, nil
    local ok = pcall(function()

        local gm = sdk.get_managed_singleton("app.GuiManager")
        local guide = gm and gm:get_field("InteractGuide")
        if not guide then error("InteractGuide is not live") end
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local player = cm and cm:get_ManualPlayer()
        local go = player and player:call("get_GameObject")
        if not go then error("Player GameObject is not live") end
        local td = sdk.find_type_definition("app.ui020701")
        local req = td and td:get_method(
            "reqDraw(via.vec3, System.Guid, via.GameObject, System.Boolean)")
        if not req then error("ui020701.reqDraw unavailable") end
        req:call(guide, entry.pos, world.guid, go, false)
        world.req_ok = true

        local txt = guide:get_field("TxtInteract")
        if not txt then error("InteractGuide.TxtInteract is not live") end
        txt:call("set_Message", entry.text)
        world.text_ok = true
        world.owner = owner
    end)
    if not ok and not world.warned then
        world.warned = true
        _log("native world prompt request failed; retaining IRIS world-label fallback")
    end
    if world.req_ok and not world.text_ok and not world.text_warned then
        world.text_warned = true
        _log("native world prompt frame succeeded but TxtInteract label write failed")
    end
    return ok
end

_G.IrisPrompt.native_world_ready = function(owner)
    return world.enabled and world.req_ok and world.text_ok
        and (owner == nil or world.owner == owner)
end

local function _panel_write(map)
    if not getobj then return false end
    local ok = false
    pcall(function()
        local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"),
                      sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
        if not scene then return end
        local ui = scene:call("findGameObject(System.String)", "ui010201")
        if not ui then return end
        if ui:call("get_DrawSelf") ~= true then return end
        local base = ui:call("getComponent(System.Type)", sdk.typeof("app.GUIBase"))
        local root = base and base:get_field("Root")
        if not root then return end
        for slot, txt in pairs(map) do

            local path = (slot .. "/PNL_txt/mtx_00")
            local node = getobj:call(root, "PNL_top/" .. path)
            if node then

                local is_text = false
                pcall(function()
                    local td = node:get_type_definition()
                    while td do
                        if td:get_full_name() == "via.gui.Text" then is_text = true; return end
                        td = td:get_parent_type()
                    end
                end)
                if is_text then
                    pcall(function() node:call("set_Message", txt) end)
                    ok = true
                end
            end
        end
    end)
    return ok
end

re.on_application_entry("LateUpdateBehavior", function()

    world.req_ok, world.text_ok, world.owner = false, false, nil
    if M.enabled == false then return end

    if _mounted_now() then
        slots, raw = {}, {}
        return
    end

    local map, now = nil, os.clock()
    for k, v in pairs(raw) do
        if now - (v.at or 0) > TTL then
            raw[k] = nil
        else
            map = map or {}
            local cur = map[v.slot]
            if not cur or v.prio > cur.prio then map[v.slot] = { text = v.text, prio = v.prio } end
        end
    end

    local b_wanted = false
    if not _G.IrisPrompt.native_busy() then
        local owner, entry = _G.IrisPrompt.current_entry()
        if entry and entry.text then
            b_wanted = true
            _world_prompt(owner, entry)
            map = map or {}
            map[M.slot] = { text = entry.text, prio = math.huge }
        end
    end

    if not map then return end
    local flat = {}
    for slot, e in pairs(map) do flat[slot] = e.text end
    local ok = _panel_write(flat)
    if b_wanted and not ok and not gui.warned then
        gui.warned = true
        _log("could not write the prompt slot (panel hidden, or the game is not offering "
             .. M.slot .. " in this context - a withheld slot cannot be forced; see the "
             .. "PlayState wall). Falling back to our own world labels.")
    end
end)

re.on_script_reset(function() slots = {}; raw = {} end)

re.on_draw_ui(function()
    if not imgui.tree_node("IMMERSIVE INTERACTABLES - PROMPT BAR") then return end
    imgui.text("Modules publish an action; the game's button panel shows it.")
    local cur = _G.IrisPrompt.current()
    imgui.text("currently offering: " .. (cur and ("'" .. cur .. "'") or "nothing"))
    local n = 0
    for owner, v in pairs(slots) do
        n = n + 1
        imgui.text(string.format("   %-18s '%s'  (prio %d)", tostring(owner), v.text, v.prio))
    end
    if n == 0 then imgui.text("   (no module is offering an action right now)") end
    local rn = 0
    for _, v in pairs(raw) do
        if rn == 0 then imgui.text("explicit slots (each names its own button):") end
        rn = rn + 1
        imgui.text(string.format("   %-10s '%s'   <- %s", v.slot, v.text, tostring(v.owner)))
    end
    local c
    c, M.enabled = imgui.checkbox("enabled", M.enabled ~= false)
    c, world.enabled = imgui.checkbox("native world prompt frame", world.enabled ~= false)
    imgui.text("world frame: " .. (world.req_ok and "live" or "idle")
        .. " | label write: " .. (world.text_ok and "ok" or "not yet"))
    local sc, sv = imgui.input_text("panel slot (PNL_R02 = B, PNL_R03 = A)", M.slot)
    if sc and sv ~= "" then M.slot = sv end
    c, M.log = imgui.checkbox("write the log", M.log)
    imgui.tree_pop()
end)

_log("IrisPromptBar loaded - slot " .. tostring(M.slot))
