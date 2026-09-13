local M=require("II.WorkpieceMath32")
local H={}
local HAND_NAME="R_Arm_Hand"
function H.new(player)
    local report={stage="resolving",target=HAND_NAME,errors={},names={}}
    local function save() pcall(json.dump_file,"ImmersiveInteractables_WorkpieceHand32.json",report) end
    local function attempt(label,fn)
        local ok,v=pcall(fn)
        if not ok then report.errors[label]=tostring(v) end
        return ok and v or nil
    end
    local tf=assert(player:call("get_Transform"))
    local hand=attempt("transform lookup",function() return tf:call("getJointByName",HAND_NAME) end)
    local motion=attempt("motion component",function() return player:call("getComponent(System.Type)",sdk.typeof("via.motion.Motion")) end)
    if not hand and motion then
        hand=attempt("motion lookup",function() return motion:call("getJointByName",HAND_NAME) end)
    end
    local count=motion and tonumber(attempt("joint count",function() return motion:call("get_JointCount") end)) or 0
    report.count=count; report.motion=motion~=nil
    if not hand and count and count>0 and count<=1024 then
        for i=0,count-1 do
            local j=attempt("joint "..i,function() return motion:call("getJoint",i) end)
            local name=j and attempt("name "..i,function() return j:call("get_Name") end)
            if type(name)=="string" then report.names[#report.names+1]=name end
            if name==HAND_NAME then hand=j; break end
        end
    end
    report.stage=hand and "resolved" or "unavailable"; save()
    assert(hand,"Supporting-hand joint unavailable; see WorkpieceHand32 receipt (joint count "..tostring(count)..")")
    local function sample()
        assert(player:call("get_Valid")==true,"Hand owner invalid")
        local p=hand:call("get_Position")
        local q=hand:call("get_Rotation")
        local r,u=tf:call("get_Position"),tf:call("get_UniversalPosition")
        return {p={x=u.x+p.x-r.x,y=u.y+p.y-r.y,z=u.z+p.z-r.z},
            q={x=q.x,y=q.y,z=q.z,w=q.w}}
    end
    return {sample=sample,name=HAND_NAME}
end
function H.follow(reference,current,position,rotation)
    local delta=M.mul(current.q,M.inv(reference.q))
    local d=M.rotate(delta,{x=position.x-reference.p.x,y=position.y-reference.p.y,z=position.z-reference.p.z})
    return {x=current.p.x+d.x,y=current.p.y+d.y,z=current.p.z+d.z},M.mul(delta,rotation)
end
function H.bind(hand,position,rotation)
    local inv=M.inv(hand.q)
    return {p=M.rotate(inv,{x=position.x-hand.p.x,y=position.y-hand.p.y,z=position.z-hand.p.z}),q=M.mul(inv,rotation)}
end
function H.place(hand,grip)
    local d=M.rotate(hand.q,grip.p)
    return {x=hand.p.x+d.x,y=hand.p.y+d.y,z=hand.p.z+d.z},M.mul(hand.q,grip.q)
end
function H.valid(grip)
    if type(grip)~="table" or type(grip.p)~="table" or type(grip.q)~="table" then return false end
    for _,a in ipairs({"x","y","z"}) do
        local v=grip.p[a]; if type(v)~="number" or v~=v or math.abs(v)>5 then return false end
    end
    local n=0
    for _,a in ipairs({"x","y","z","w"}) do
        local v=grip.q[a]; if type(v)~="number" or v~=v then return false end
        n=n+v*v
    end
    return math.abs(n-1)<0.01
end
return H
