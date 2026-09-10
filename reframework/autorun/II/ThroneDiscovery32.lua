local D={searches=0,cache_hits=0}
function D.reset()
    D.candidate,D.scene_address,D.search_at=nil,nil,nil
end
function D.find(now)
    local sm=sdk.get_native_singleton("via.SceneManager")
    local td=sdk.find_type_definition("via.SceneManager")
    local scene=sm and td and sdk.call_native_func(sm,td,"get_CurrentScene")
    if not scene then D.reset(); return end
    local address=scene:get_address()
    if address~=D.scene_address then D.reset(); D.scene_address=address end
    local c=D.candidate
    if c then
        local ok,valid=pcall(function()
            if c.go:call("get_Valid")~=true then return false end
            local io=c.owner:call("getInteract")
            return io and io:get_address()==c.io:get_address()
                and io:call("get_Valid()")==true
        end)
        if ok and valid then D.cache_hits=D.cache_hits+1; return c end
        D.candidate=nil
        D.search_at=nil
    end
    if now<(D.search_at or 0) then return end
    D.search_at=now+10.0
    D.searches=D.searches+1
    local arr=scene:call("findComponents(System.Type)",sdk.typeof("app.gm05_045"))
    if arr then arr:add_ref() end
    local n=arr and tonumber(arr:call("get_Length")) or 0
    for i=0,n-1 do
        local ok,found=pcall(function()
            local owner=arr:get_element(i)
            local go=owner and owner:call("get_GameObject")
            if not go or tostring(go:call("get_Name")):lower()~="gm51_752"
                or go:call("get_Valid")~=true then return end
            local io=owner:call("getInteract")
            if not io or io:call("get_Valid()")~=true then return end
            go:add_ref(); owner:add_ref(); io:add_ref()
            return {go=go,owner=owner,io=io}
        end)
        if ok and found then D.candidate=found; return found end
    end
end
return D
