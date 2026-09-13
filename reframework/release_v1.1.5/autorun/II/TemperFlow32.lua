local F={}
local function message(err)
    local full=tostring(err)
    pcall(function() log.error('[TemperFlow32] '..full) end)
    if full:find('not found:',1,true) then return 'Anvil helper unavailable. Leave the anvil and reset scripts. Nothing charged.' end
    return (full:match('^[^\r\n]*') or full):gsub('^.-:%d+: ', ''):sub(1,180)
end
function F.new(a)
    local s={status='Choose a treatment.'}
    local function receipt(stage,extra)
        pcall(function() json.dump_file('ImmersiveInteractables_TemperFlow32.json',{
            stage=stage,status=s.status,details=extra,time=os.date('%Y-%m-%d %H:%M:%S')}) end)
    end
    function s.check(token,index)
        local candidate
        local ok,err=pcall(function()
            assert(not a.active(),'A treatment/test is already active; stop it before tempering again.')
            local weapon=assert(a.weapon(),'Main weapon unavailable')
            assert(a.count(index)>=1,'Not enough ore. Nothing charged.')
            candidate={token=token,index=index,weapon=weapon}
        end)
        s.status=ok and 'Awaiting Confirmation. Nothing Charged.' or message(err)
        return ok,candidate
    end
    function s.begin(token,index)
        s.pending=nil
        local ok,candidate=s.check(token,index)
        if ok then s.pending=candidate end
        if ok then s.status='Work started. Cancel before completion to keep your ore.' end
        receipt(ok and 'started' or 'refused',{index=index})
        return ok
    end
    function s.cancel()
        if s.pending then
            s.status='Tempering Cancelled. Nothing Charged.'
            receipt('cancelled',{index=s.pending.index})
        end
        s.pending=nil
    end
    function s.complete(token)
        local p=s.pending; if not p or p.token~=token then return end
        s.pending=nil
        local attempted,started=false,false
        local ok,err=pcall(function()
            assert(a.weapon()==p.weapon,'Weapon changed. Nothing charged.')
            assert(not a.active(),'Another treatment/test became active. Nothing charged.')
            local before=a.count(p.index); assert(before>=1,'Ore no longer available. Nothing charged.')
            started=true; a.start(p.index,p.weapon)
            attempted=true; a.debit(p.index)
            assert(a.count(p.index)==before-1,'Ore debit readback mismatch')
        end)
        if not ok then
            if started then a.stop() end
            s.status=(attempted and 'Payment unconfirmed; one ore may have been consumed. Buff stopped. ' or '')..message(err)
        else s.status='Treatment Applied: 1 Ore Consumed. Buff Active for 30 Minutes.' end
        receipt(ok and 'applied' or 'failed',{index=p.index,weapon=p.weapon,debit_attempted=attempted})
        return ok
    end
    return s
end
return F
