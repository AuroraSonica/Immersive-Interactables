local T={}
T.finishes={
    {name="Silver Ore Treatment",ore='Silver Ore',item=196,cost=1,bonus='+5% weapon damage',colour={1.65,1.72,1.85,1}},
    {name="Fulgin Ore Treatment",ore='Fulgin Ore',item=198,cost=1,bonus='+8% knockdown power',colour={0.28,0.32,0.38,1}},
    {name="Copper Ore Treatment",ore='Copper Ore',item=195,cost=1,bonus='-5% skill stamina cost',colour={0.85,0.57,0.30,1}},
    {name='Gold Ore Treatment',ore='Gold Ore',item=197,cost=1,
        bonus='+10% monster climb speed; +8% attached-target damage',colour={1.5,1.05,0.30,1}},
}
function T.is_anvil(key)
    return key=="gm82_053" or key=="gm82_053_01" or key=="gm50_045_00"
end
function T.eligible(label)
    return ({Iron=true,Steel=true,Metal=true,Blade=true,Finish=true,Silver=true,Bronze=true})[label]==true
end
function T.new(a)
    local s={elapsed=0,status="Visual test: work at an anvil for 45 seconds.",selected=1}
    function s.restore()
        local failed=false
        for _,p in ipairs(s.parts or {}) do
            local ok,result=pcall(a.write,p,p.original)
            if not ok or result~=true then failed=true end
        end
        s.parts=nil; s.active=false
        if failed then s.status="Preview ended; some old meshes could not be restored. Re-equip the weapon." end
        return not failed
    end
    function s.apply(index)
        if not s.parts or not T.finishes[index] then return false end
        s.selected=index
        for _,p in ipairs(s.parts) do
            local ok,result=pcall(a.write,p,T.finishes[index].colour)
            if not ok or result~=true then
                s.restore(); s.status="Finish write failed; preview cancelled. No changes saved."; return false
            end
        end
        s.active=true; s.status=T.finishes[index].name.." preview. Treatment applies on completion."
        return true
    end
    function s.original()
        if not s.parts then return false end
        for _,p in ipairs(s.parts) do
            local ok,result=pcall(a.write,p,p.original)
            if not ok or result~=true then s.restore(); return false end
        end
        s.active=false; s.status="Original appearance for comparison; choose a finish to compare."
        return true
    end
    function s.tick(token,now,paused)
        if token~=s.token then
            s.restore(); s.token=token; s.elapsed=0; s.finished=false; s.last=now; s.command=nil
            s.status="Visual test: work at an anvil for 45 seconds."
        end
        local dt=math.max(0,math.min(0.25,now-(s.last or now))); s.last=now
        if not token then return end
        if s.parts and not a.matches(s.parts) then
            s.restore(); s.finished=true; s.status="Weapon changed; preview cancelled. Start a new anvil session."
        end
        if a.upfront and not s.parts and not s.finished then
            local ok,parts=pcall(a.capture)
            if ok and parts and #parts>0 then s.parts=parts end
        end
        if paused then return end
        if not s.finished then
            s.elapsed=math.min(45,s.elapsed+dt)
            if s.elapsed>=45 then
                s.finished=true
                local ok,parts=pcall(a.capture)
                if not ok or not parts or #parts==0 then
                    s.status="No supported main-weapon finish surfaces found. No changes made."; return
                end
                s.parts=parts
                if s.apply(a.upfront and s.selected or (a.roll and a.roll(#T.finishes) or 1)) and a.complete then
                    a.complete(s.token)
                end
            end
        end
        if s.command then
            local cmd=s.command; s.command=nil
            if cmd=="restore" then s.restore(); s.status="Original appearance restored; nothing saved."
            elseif cmd=="original" then s.original()
            else s.apply(cmd) end
        end
    end
    function s.reset() s.restore(); s.token=nil; s.command=nil end
    return s
end
return T
