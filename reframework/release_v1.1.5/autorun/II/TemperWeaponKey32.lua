local K={}
local function read(f) local ok,v=pcall(f); if ok then return v end; return nil end
local function id(sd)
    if not sd then return end
    local n=tonumber(read(function() return sd:call('get_ItemId') end))
    if not n or n<=0 then n=tonumber(read(function() return sd:get_field('_ItemId') end)) end
    if n and n>0 and n==math.floor(n) then return n end
end
function K.resolve(ch,eq,compat)
    local aw=read(function() return compat.current_weapons(eq) end)
    local main=aw and read(function() return aw:get_field('Main') end)
    local item=id(main)
    if not item then
        local data=read(function() return eq:call('getCloneData') end)
        local equips=data and read(function() return data:get_field('Equips') end)
        local slot=equips and read(function() return equips:get_element(0) end)
        item=id(slot and read(function() return slot:get_field('_ItemData') end))
    end
    if not item then error('Equipped weapon identity unavailable. Nothing charged.',0) end
    return tostring(ch:get_address())..':'..tostring(item)
end
return K
