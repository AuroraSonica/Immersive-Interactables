local T = {}
T.hints = {
    [8512]={1004,1005},
    [8509]={1351,1352,1355},
    [8519]={3004,3005,3006},
    [8524]={3402},
}
T.scan_ranges={{1000,5999}}
T.scanned={}
function T.scan_ids(motion,bank)
    if T.scanned[bank] then return T.scanned[bank] end
    local ids={}
    for _,r in ipairs(T.scan_ranges) do
        for id=r[1],r[2] do
            if motion:call("hasMotion(System.UInt32, System.UInt32)",bank,id)==true then ids[#ids+1]=id end
        end
    end
    if #ids>0 then T.scanned[bank]=ids end
    return ids
end
function T.enumerate_ids(motion,bank,info)
    local ids={}
    local ok=pcall(function()
        local count=tonumber(motion:call("getMotionCount",bank)) or 0
        for i=0,count-1 do
            if motion:call("getMotionInfoByIndex(System.UInt32, System.UInt32, via.motion.MotionInfo)",bank,i,info)~=false then
                local id=tonumber(info:call("get_MotionID"))
                if id then ids[#ids+1]=id end
            end
        end
    end)
    if ok and #ids>0 then return ids end
    return nil
end
function T.read_clips(motion, bank, wanted)
    local info=sdk.create_instance("via.motion.MotionInfo")
    if not info then info=sdk.create_instance("via.motion.MotionInfo",true) end
    if not info then return nil,"MotionInfo allocation unavailable" end
    info:add_ref()
    local candidates=T.enumerate_ids(motion,bank,info) or T.hints[bank]
    if not candidates then
        candidates=T.scan_ids(motion,bank)
        if #candidates==0 then return nil,"no motions found in bank "..bank.." (enumerate+scan)" end
    end
    local names,actual={},{}
    for _,id in ipairs(candidates) do
        if motion:call("hasMotion(System.UInt32, System.UInt32)",bank,id)==true
                and motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)",bank,id,info)==true then
            local name=info:call("get_MotionName")
            local read_id=tonumber(info:call("get_MotionID"))
            actual[#actual+1]=tostring(id).."="..tostring(name)
            for _,expected in pairs(wanted) do
                if name==expected and read_id==id then names[name]=id end
            end
        end
    end
    for phase,name in pairs(wanted) do
        if names[name]==nil then
            return nil,"awaiting/mismatched "..phase.."; candidates: "..table.concat(actual," | ")
        end
    end
    return names
end
function T.key(raw, rows)
    local name=tostring(raw or ""):lower():gsub("^it","gm"):gsub("^t(%d)","gm%1")
    local key=name:match("^(gm%d+_%d+[_%d]*)")
    while key do
        if rows[key] then return key end
        local parent=key:gsub("_%d+$","")
        if parent==key then break end
        key=parent
    end
end
function T.held_name(holder, eqids)
    local function read(fn) local ok,v=pcall(fn); if ok then return v end end
    local pick=read(function() return holder:get_field("PickableObject") end)
    if pick then
        local id=read(function() return tonumber(pick:get_field("EquipID")) end)
        if id and eqids[id] then return eqids[id] end
        local name=read(function() return pick:call("get_GameObject"):call("get_Name") end)
        if name and name~="" then return name end
    end
    local id=read(function() return tonumber(holder:get_field("Context"):get_field("EquipItemID")) end)
    if id and eqids[id] then return eqids[id] end
    local list=read(function() return holder:get_field("HoldObjects") end)
    local count=list and read(function() return tonumber(list:call("get_Count")) end) or 0
    for i=0,math.min(count or 0,16)-1 do
        local name=read(function()
            return list:call("get_Item",i):get_field("Object"):call("get_GameObject"):call("get_Name")
        end)
        if name and name~="" then return name end
    end
end
return T
