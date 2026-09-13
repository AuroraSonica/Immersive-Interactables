local V={}
function V.new()
    local held={}
    local function restore()
        local failed={}
        for _,r in ipairs(held) do
            local ok=pcall(function()
                local go=r.mesh:call("get_GameObject")
                if go and go:call("get_Valid")==true then r.mesh:call("set_Enabled",r.enabled) end
            end)
            if not ok then failed[#failed+1]=r end
        end
        held=failed
        return #held==0
    end
    return {restore=restore,hide=function(meshes)
        if #held>0 then return end
        local seen={}
        local ok,err=pcall(function()
            for _,mesh in ipairs(meshes) do
                local id=mesh:get_address()
                if not seen[id] then
                    seen[id]=true
                    local enabled=mesh:call("get_Enabled")
                    assert(type(enabled)=="boolean","Weapon visibility unreadable")
                    held[#held+1]={mesh=mesh,enabled=enabled}
                    if enabled then mesh:call("set_Enabled",false) end
                end
            end
        end)
        if not ok then restore(); error(err) end
    end}
end
return V
