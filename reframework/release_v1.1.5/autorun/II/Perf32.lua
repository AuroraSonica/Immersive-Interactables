local P={active=false,rows={}}
function P.call(label,fn,...)
    if not P.active then return pcall(fn,...) end
    local t=os.clock()
    local values=table.pack(pcall(fn,...))
    local ms=(os.clock()-t)*1000
    local r=P.rows[label] or {calls=0,total_ms=0,max_ms=0,errors=0}
    r.calls=r.calls+1; r.total_ms=r.total_ms+ms; r.max_ms=math.max(r.max_ms,ms)
    if not values[1] then r.errors=r.errors+1 end
    P.rows[label]=r
    return table.unpack(values,1,values.n)
end
function P.start(now) P.rows={}; P.active=true; P.until_at=(now or os.clock())+30 end
function P.tick(now)
    if not P.active or (now or os.clock())<P.until_at then return end
    P.active=false
    pcall(json.dump_file,"ImmersiveInteractables_Performance32.json",{time=os.date(),seconds=30,rows=P.rows,
        note="Script CPU samples, not GPU frame times. Nested rows must not be summed."})
end
if re then
    re.on_application_entry("LateUpdateBehavior",function() P.tick() end)
    re.on_draw_ui(function()
        if not imgui.tree_node("Immersive Interactables performance") then return end
        if imgui.button("Capture 30 seconds of script timings") then P.start() end
        imgui.text(P.active and "Capturing: play normally." or "Profiler idle (no routine timing or disk writes).")
        local keys={}; for k in pairs(P.rows) do keys[#keys+1]=k end; table.sort(keys)
        for _,k in ipairs(keys) do
            local r=P.rows[k]
            imgui.text(string.format("%s: mean %.3f ms, max %.3f ms, %d calls, %d errors",k,r.total_ms/r.calls,r.max_ms,r.calls,r.errors))
        end
        imgui.tree_pop()
    end)
end
return P
