local Instances=require("II.DialogueCloneInstance32")
local Pose=require("II.PreviewPose32")
local Frame=require("II.PreviewFrame32")
local Idle=require("II.PreviewIdle32")
local D={status="Preview waiting for dye menu."}
local token,instance,session_key,attempted_key,screen
local position_td,rotation_td
local near_method,near_checked
local owned_go
local hidden_meshes={}
function D.set_hidden(hidden)
    if not hidden then
        for _,row in ipairs(hidden_meshes) do pcall(function() row.mesh:call('set_Enabled',row.enabled) end) end
        hidden_meshes={}; return
    end
    if not owned_go or #hidden_meshes>0 then return end
    local seen,count={},0
    local function walk(tf,depth)
        assert(depth<=16,'Preview visibility hierarchy too deep')
        local id=tostring(tf:get_address()); assert(not seen[id],'Cyclic preview hierarchy')
        seen[id]=true; count=count+1; assert(count<=512,'Preview visibility hierarchy too large')
        local go=tf:call('get_GameObject')
        assert(not go:call('getComponent(System.Type)',sdk.typeof('app.Character')),'Refusing character visibility')
        local mesh=go:call('getComponent(System.Type)',sdk.typeof('via.render.Mesh'))
        if mesh then
            local enabled=mesh:call('get_Enabled')
            assert(type(enabled)=='boolean','Preview visibility unreadable')
            hidden_meshes[#hidden_meshes+1]={mesh=mesh,enabled=enabled}
            mesh:call('set_Enabled',false)
        end
        local child=tf:call('get_Child')
        while child do walk(child,depth+1); child=child:call('get_Next') end
    end
    local ok,err=pcall(walk,owned_go:call('get_Transform'),0)
    if not ok then D.set_hidden(false); D.visibility_error=tostring(err) end
end
local spin,spin_at=0,nil
function D.rotate(axis,now)
    axis=tonumber(axis) or 0
    if axis~=axis then axis=0 end
    now=now or os.clock()
    local dt=math.max(0,math.min(0.05,now-(spin_at or now)))
    spin_at=now
    if not owned_go or math.abs(axis or 0)<0.2 then return end
    spin=(spin+math.max(-1,math.min(1,axis))*dt*1.6)%(math.pi*2)
end
function D.object() return owned_go end
function D.token() return token end
function D.screen(w,h) screen={w=w,h=h} end
local function camera_pose()
    if not screen then return nil end
    local cm=assert(sdk.get_managed_singleton("app.CameraManager"))
    local cam=assert(cm:call("getMainCamera",0),"No main camera")
    local tf=assert(cam:call("get_GameObject"):call("get_Transform"))
    local p=tf:call("get_UniversalPosition")
    local z,y,x=tf:call("get_AxisZ"),tf:call("get_AxisY"),tf:call("get_AxisX")
    local ch=assert(sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer"))
    local pp=ch:call("get_GameObject"):call("get_Transform"):call("get_UniversalPosition")
    local flip=(z.x*(pp.x-p.x)+z.y*(pp.y+1-p.y)+z.z*(pp.z-p.z))>=0
    local sign=flip and 1 or -1
    local fov=assert(tonumber(cam:call("get_FOV")),"Camera FOV unavailable")
    local near=0.1
    if not near_checked then
        near_checked=true
        local m=cam:get_type_definition():get_method("get_NearClipPlane()")
        if m and #(m:get_param_types() or {})==0 and not m:is_static()
            and m:get_return_type():get_full_name()=="System.Single" then near_method=m end
    end
    if near_method then near=tonumber(near_method:call(cam)) or near end
    local solved=Frame.solve({position=p,forward={x=z.x*sign,y=z.y*sign,z=z.z*sign},
        right=x,up=y,fov=fov,near=near},screen.w,screen.h)
    solved.rotation=Frame.turn(solved.rotation,spin)
    local vp=ValueType.new(position_td)
    for _,a in ipairs({"x","y","z"}) do vp:set_field(a,solved.position[a]) end
    local vq=ValueType.new(rotation_td)
    for _,a in ipairs({"x","y","z","w"}) do vq:set_field(a,solved.rotation[a]) end
    return {position=vp,rotation=vq,distance=solved.distance}
end
local function detach()
    D.set_hidden(false)
    if owned_go and D.before_detach then pcall(D.before_detach) end
    owned_go=nil
    if token then Pose.revoke(token); token=nil end
end
function D.tick(key,open)
    session_key=open and key or nil
    if instance then
        if session_key~=attempted_key then instance.request_stop(); detach() end
        local err=Pose.error(token)
        if err then D.pose_error=err; instance.request_stop(); detach() end
        instance.tick()
        D.status=D.pose_error and ("Preview positioning failed: "..D.pose_error) or instance.status
        if instance.state=="cleanup_failed" then D.blocked=true end
        if instance.state=="finished" then instance=nil; detach() end
    end
    if not instance and not D.blocked and session_key and session_key~=attempted_key then
        attempted_key=session_key; D.pose_error=nil
        spin,spin_at=0,nil
        local current_key=session_key
        instance=Instances.new_preview({preview=true,
            allowed=function() return session_key==current_key end,
            detach=detach,
            ready=function(go,player,builder)
                position_td=assert(sdk.find_type_definition("via.Position"))
                rotation_td=assert(sdk.find_type_definition("via.Quaternion"))
                token=Pose.register(go,player,builder,camera_pose)
                owned_go=go
                local ok,err=Idle.apply(go)
                D.idle_status=ok and "Standing idle 0:10 requested." or "Idle unavailable: "..tostring(err)
            end})
        instance.request()
    end
end
function D.active() return instance~=nil end
function D.reset() detach(); if instance then instance.reset() end end
return D
