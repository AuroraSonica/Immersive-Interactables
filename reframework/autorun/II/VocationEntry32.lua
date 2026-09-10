local V={}
function V.safe(s)
    return s and s.owner and s.jacked==false and s.interacting==false
        and s.action0=='NormalLocomotion' and s._BlockMenu==0
        and s.loading==false and s.paused==false and s.menuType=='none'
        and s.IsRequestGUIPause==false and s.IsMenuUIPause==false
end
function V.new(a)
    local t={status='Not tested. Save your game before trying this native menu.'}
    function t.queue(now)
        if t.attempted or t.pending then return false end
        local s=a.state()
        if not V.safe(s) then t.status='Stand idle outside every menu and interaction.'; return false end
        t.pending={owner=s.owner,deadline=now+15}; t.status='Queued. Close REFramework to run once.'
        return true
    end
    function t.tick(now,drawing)
        local p=t.pending; if not p then return end
        if now>p.deadline then t.pending=nil; t.status='Queue expired. Nothing opened.'; return end
        if drawing then return end
        local s=a.state()
        if not V.safe(s) or s.owner~=p.owner then
            t.pending=nil; t.status='Context changed. Request cancelled.'; return
        end
        t.pending=nil; t.attempted=true
        a.record('before_request',s)
        local ok,err=pcall(a.open)
        t.status=ok and 'Request sent once. Back out normally; do not Reset Scripts while open.' or tostring(err)
        a.record(ok and 'request_returned' or 'request_failed',{status=t.status})
    end
    return t
end
return V
