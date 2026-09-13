local P={slot='Paraglider',path='riftspeak/paraglider/paraglider.mesh'}
function P.entries(runtime,owner,valid)
    local out,seen={},{}
    if type(runtime)~='table' or not owner or tostring(runtime.player_addr)~=tostring(owner) then return out end
    local config=runtime.api and runtime.api.C
    if config and config.enabled==false then return out end
    local usable=(tonumber(runtime.item_count) or 0)>=1
        or (config and (config.require_item==false or config.testing_ignore_item==true))
    if not usable then return out end
    for _,key in ipairs({'prop','pw'}) do
        local wing=runtime[key]
        if wing and wing.go and wing.mesh and valid(wing.go) then
            local ok,address=pcall(function() return tostring(wing.mesh:get_address()) end)
            if ok and not seen[address] then
                seen[address]=true
                out[#out+1]={slot=P.slot,mesh=wing.mesh,paraglider=true}
            end
        end
    end
    return out
end
function P.accept(path) return tostring(path):lower()==P.path end
return P
