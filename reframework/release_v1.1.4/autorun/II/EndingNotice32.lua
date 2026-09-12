local N={}
function N.new()
    return {at=nil,next_sample=0,last_signal=nil,was_wait=false,text=nil}
end
function N.tick(s,now,enabled,signal,watch,tool_finish,sample)
    if not enabled then
        s.at=nil; s.text=nil; s.was_wait=false; s.last_signal=signal
        return
    end
    if signal and signal>(s.last_signal or -math.huge) then
        s.last_signal=signal; s.at=now; s.next_sample=now
    end
    if now>=s.next_sample and (s.at or watch) then
        s.next_sample=now+0.2
        local ok,v=pcall(sample)
        if ok and v then
            if s.actor and v.actor~=s.actor then s.at=nil end
            s.actor=v.actor
            local waiting=v.action=="WaitEndJack"
            if waiting and not s.was_wait then s.at=now end
            s.was_wait=waiting
            if not v.actor or (v.interacting==false and v.jacked==false and not waiting) then
                s.at=nil
            end
        end
    end
    if s.at and now-s.at>30 then s.at=nil end
    s.text=tool_finish and "Ending animation..."
        or (s.at and (now-s.at>20 and "Interaction is taking longer to end..." or "Ending animation..."))
        or nil
end
function N.draw(s)
    if not s.text then return end
    draw.filled_rect(20,20,350,32,0xA8181612)
    draw.text(s.text,30,26,0xFFE5DED2)
end
return N
