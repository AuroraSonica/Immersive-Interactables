local Instances=require("II.DialogueCloneInstance32")
local Pose=require("II.PreviewPose32")
local Math=require("II.WorkpieceMath32")
local Hand=require("II.WorkpieceHand32")
local Preview=require("II.TemperPreview32")
local W={status="Workpiece waiting for anvil.",height=0.90,forward=0.75,side=0,yaw=0,pitch=90,roll=0}
local CFG="ImmersiveInteractables/workpiece_placement.json"
local ranges={height={-1,2},forward={-1.6,1.6},side={-1.6,1.6},yaw={-180,180},pitch={-180,180},roll={-180,180},contact={-2,2}}
ranges.twist={-180,180}
local profiles={}
pcall(function() local data=json.load_file(CFG); if type(data)=="table" and type(data.profiles)=="table" then profiles=data.profiles end end)
local function apply_profile(profile)
    for k,r in pairs(ranges) do
        local v=profile[k]
        if type(v)=="number" and v==v then W[k]=math.max(r[1],math.min(r[2],v)) end
    end
end
W.contact=0
W.twist=0
W.follow_hand=true
W.grip_x,W.grip_y,W.grip_z=0,0,0
W.grip_pitch,W.grip_yaw,W.grip_roll=0,0,0
function W.save_placement(as_family)
    if not W.profile_key then return false end
    local profile={}; for k in pairs(ranges) do profile[k]=W[k] end
    if W.follow_hand and W.last_grip and Hand.valid(W.last_grip) then
        profile.right_hand_grip=W.last_grip; profile.grip_version=2
    end
    if as_family and not W.family_key then return false end
    profiles[as_family and W.family_key or W.profile_key]=profile
    local ok,v=pcall(json.dump_file,CFG,{version=1,profiles=profiles})
    W.placement_status=ok and v~=false and (profile.right_hand_grip and "Right-hand grip saved for repeat entries." or "Placement saved; hand grip not captured yet.") or "Placement save failed."
    if ok and v~=false and profile.right_hand_grip then W.grip_status="Hand-relative grip saved. Re-enter to verify." end
    return ok and v~=false
end
local instance,attempt,key,pose_token,root,weapon,anchor,reference_root,reference_weapon
local hand,hand_reference
local saved_grip,grip_controls
local warm_until,warm_key
local lifecycle={}
local function trace(event,detail)
    lifecycle[#lifecycle+1]={event=event,detail=detail,clock=os.clock()}
    if #lifecycle>40 then table.remove(lifecycle,1) end
    pcall(json.dump_file,"ImmersiveInteractables_WorkpieceEntry32.json",{events=lifecycle})
end
function W.prewarm()
    if instance or W.blocked then return false end
    warm_until=os.clock()+60; warm_key="anvil-prewarm:"..tostring(os.clock())
    W.warming=true
    trace("prewarm requested",warm_key)
    return true
end
local function detach()
    Preview.open=false
    if W.before_detach then pcall(W.before_detach) end
    if pose_token then Pose.revoke(pose_token) end
    pose_token,root,weapon,anchor,W.parts,W.pending=nil,nil,nil,nil,nil,nil
    W.finish_parts=nil
    reference_root,reference_weapon=nil,nil
    hand,hand_reference=nil,nil
    saved_grip,grip_controls,W.last_grip=nil,nil,nil
end
local function transform(tf)
    local p,q=tf:call("get_UniversalPosition"),tf:call("get_Rotation")
    return {p={x=p.x,y=p.y,z=p.z},q={x=q.x,y=q.y,z=q.z,w=q.w}}
end
local function provider()
    if not root or not weapon then return nil end
    local target={x=anchor.p.x+anchor.z.x*W.forward+anchor.x.x*W.side,
        y=anchor.p.y+W.height,z=anchor.p.z+anchor.z.z*W.forward+anchor.x.z*W.side}
    local rotation=Math.euler(math.rad(W.pitch),anchor.yaw+math.rad(W.yaw),math.rad(W.roll))
    rotation=Math.twist(rotation,W.contact_axis or "z",math.rad(W.twist))
    if W.follow_hand and hand then
        local current=hand.sample()
        local base=saved_grip or {p={x=0,y=0,z=0},q={x=0,y=0,z=0,w=1}}
        local grip={p={x=base.p.x+W.grip_x,y=base.p.y+W.grip_y,z=base.p.z+W.grip_z},
            q=Math.mul(base.q,Math.euler(math.rad(W.grip_pitch),math.rad(W.grip_yaw),math.rad(W.grip_roll)))}
        target,rotation=Hand.place(current,grip)
        W.last_grip=grip
    end
    if not reference_root then reference_root,reference_weapon=transform(root),transform(weapon) end
    local contact={x=0,y=0,z=0}; contact[W.contact_axis or "z"]=W.contact
    if W.follow_hand and hand then contact={x=0,y=0,z=0} end
    if Preview.open and not Preview.keep_hand then
        local ok,p,q=pcall(Preview.pose)
        if ok then target,rotation,contact=p,q,{x=0,y=0,z=0}
        else Preview.open=false; W.status="Comparison framing unavailable: "..tostring(p) end
    end
    local out=Math.solve(reference_root,reference_weapon,target,rotation,contact)
    local p=ValueType.new(sdk.find_type_definition("via.Position"))
    local q=ValueType.new(sdk.find_type_definition("via.Quaternion"))
    for _,a in ipairs({"x","y","z"}) do
        assert(out.position[a]==out.position[a] and math.abs(out.position[a]-anchor.p[a])<20,"Workpiece offset out of bounds")
        p:set_field(a,out.position[a])
    end
    for _,a in ipairs({"x","y","z","w"}) do q:set_field(a,out.rotation[a]) end
    return {position=p,rotation=q}
end
function W.active() return instance~=nil end
function W.comparison_owner() return pose_token end
function W.prepare()
    local pending=W.pending
    if not pending then return end
    if W.warming then return end
    trace("isolate at entry",tostring(key))
    W.pending=nil
    local ok,err=pcall(function()
        local go,player,builder=pending.go,pending.player,pending.builder
        local parts,wt,finish_parts,waiting=pending.prepare(go)
        if waiting then W.pending=pending; W.status=waiting; return end
        assert(parts and #parts>0 and wt,"No independent weapon meshes found on clone")
        root=go:call("get_Transform"); weapon=wt
        local bounds_ok,bounds=pcall(function() return require('II.WeaponBounds32').capture(parts,wt) end)
        Preview.bounds=bounds_ok and bounds or nil
        Preview.bounds_error=not bounds_ok and tostring(bounds) or nil
        local pt=player:call("get_Transform")
        local p,z,x=pt:call("get_UniversalPosition"),pt:call("get_AxisZ"),pt:call("get_AxisX")
        anchor={p={x=p.x,y=p.y,z=p.z},z={x=z.x,z=z.z},x={x=x.x,z=x.z},yaw=math.atan(z.x,z.z)}
        local supplied=rawget(_G,"Interactables_anvil_anchor")
        local station=supplied and supplied.token==key and supplied.position
        W.anchor_mode="character fallback"
        if station and type(station.x)=="number" and type(station.y)=="number" and type(station.z)=="number"
            and (station.x-p.x)^2+(station.y-p.y)^2+(station.z-p.z)^2<9 then
            anchor.p={x=station.x,y=station.y,z=station.z}; W.anchor_mode="anvil origin"
        end
        local path=parts[1].path or "unknown"
        local family=path:lower():match('/(wp%d%d)/')
        W.family_key=family and ('weapon-family|'..family) or nil
        W.profile_key=tostring(rawget(_G,"Interactables_session_key")).."|"..path.."|"..W.anchor_mode
        apply_profile({height=0.90,forward=station and W.anchor_mode=="anvil origin" and 0 or 0.75,
            side=0,yaw=0,pitch=90,roll=0,contact=0,twist=0})
        W.contact_axis="z"
        if path:lower():find("/wp09/",1,true) then
            apply_profile({pitch=90,yaw=90}); W.contact_axis="y"
        end
        local profile=profiles[W.profile_key] or (W.family_key and profiles[W.family_key])
        if type(profile)=="table" then apply_profile(profile) end
        W.grip_x,W.grip_y,W.grip_z=0,0,0
        W.grip_pitch,W.grip_yaw,W.grip_roll=0,0,0
        if type(profile)=="table" and Hand.valid(profile.right_hand_grip) then
            local old=profile.right_hand_grip
            saved_grip={p={x=old.p.x,y=old.p.y,z=old.p.z},q={x=old.q.x,y=old.q.y,z=old.q.z,w=old.q.w}}
            if profile.grip_version~=2 then
                local c={x=0,y=0,z=0}; c[W.contact_axis]=W.contact
                local d=Math.rotate(saved_grip.q,c)
                for _,a in ipairs({"x","y","z"}) do saved_grip.p[a]=saved_grip.p[a]-d[a] end
            end
            grip_controls={}; for k in pairs(ranges) do grip_controls[k]=W[k] end
        end
        W.grip_status=saved_grip and "Using saved hand-local grip (v2)." or "Fixed hand-local starting grip (v2): calibrate once after repeat-entry check."
        trace("grip profile",{key=W.profile_key,loaded=saved_grip~=nil})
        W.placement_status="Anchor: "..W.anchor_mode..". Contact offset follows local "..W.contact_axis:upper().."."
        local hand_ok,value=pcall(Hand.new,player)
        hand=hand_ok and value or nil
        W.hand_status=hand_ok and "Right supporting hand resolved (R_Arm_Hand); follow test active." or ("Right-hand follow unavailable: "..tostring(value))
        trace("hand resolution",W.hand_status)
        pose_token=Pose.register(go,player,builder,provider)
        W.parts=parts
        W.finish_parts=finish_parts
        local materials={}
        for _,p in ipairs(parts) do materials[#materials+1]={path=p.path,material=p.name,original=p.original} end
        pcall(json.dump_file,"ImmersiveInteractables_AnvilWorkpieceVisual32.json",
            {stage="weapon isolated; pose pending",time=os.date("%Y-%m-%d %H:%M:%S"),materials=materials})
    end)
    if not ok then
        W.error="Workpiece preparation failed: "..tostring(err)
        pcall(json.dump_file,"ImmersiveInteractables_AnvilWorkpieceVisual32.json",{stage="failed",error=W.error})
        instance.request_stop(); detach()
    end
end
function W.tick(session,allowed,prepare)
    local native_session=allowed and session or nil
    if W.warming and native_session then
        trace("prewarm handover",W.pending and "built before entry" or "still building at entry")
        if instance and attempt==warm_key then attempt=native_session end
        W.warming=false; warm_until,warm_key=nil,nil
    elseif W.warming and (not allowed or os.clock()>warm_until) then
        trace("prewarm cancelled",not allowed and "preview eligibility lost" or "60 second expiry")
        W.warming=false; warm_until,warm_key=nil,nil
    end
    key=allowed and (native_session or (W.warming and warm_key)) or nil
    if instance then
        local err=Pose.error(pose_token)
        if key~=attempt or err then
            if err then
                W.error="Workpiece positioning failed: "..tostring(err)
                pcall(json.dump_file,"ImmersiveInteractables_AnvilWorkpieceVisual32.json",
                    {stage="pose failed",error=W.error,time=os.date("%Y-%m-%d %H:%M:%S")})
            end
            instance.request_stop(); detach()
        end
        instance.tick()
        W.status=W.error or instance.status
        if W.warming and W.pending then W.status="Display prepared. Use the anvil now; preparation expires after 60 seconds." end
        if instance.state=="cleanup_failed" then W.blocked=true end
        if instance.state=="finished" then instance=nil; detach() end
    end
    if not instance and not W.blocked and key and key~=attempt then
        attempt=key; W.error=nil
        trace("new clone requested",W.warming and "prewarm" or "native session (not prewarmed)")
        local this=key
        instance=Instances.new_preview({preview=true,receipt_path="ImmersiveInteractables_AnvilWorkpiece32.json",
            allowed=function() return key~=nil and key==attempt end,detach=detach,
            ready=function(go,player,builder)
                W.pending={go=go,player=player,builder=builder,prepare=prepare}
                trace("clone ready",W.warming and "waiting for entry" or "already in session")
            end})
        instance.request()
    end
end
function W.reset() detach(); if instance then instance.reset() end end
return W
