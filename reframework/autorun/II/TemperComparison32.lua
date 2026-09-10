local Instances=require('II.DialogueCloneInstance32')
local Pose=require('II.PreviewPose32')
local Math=require('II.WorkpieceMath32')
local Preview=require('II.TemperPreview32')
local function new(view,custom_pose)
view=view or 'current'
local C={status='Preparing '..view..' weapon...',ready=false}
function C.select_source(source,first,tf,comparison_only)
    if comparison_only and first and tf~=first then return nil end
    return source
end
local inst,attempt,wanted,pending,pose_token,root_ref,weapon_ref,origin
local function snapshot(tf)
    local p,q=tf:call('get_UniversalPosition'),tf:call('get_Rotation')
    return {p={x=p.x,y=p.y,z=p.z},q={x=q.x,y=q.y,z=q.z,w=q.w}}
end
local function detach()
    if C.before_detach then pcall(C.before_detach) end
    if pose_token then Pose.revoke(pose_token) end
    pose_token,pending,root_ref,weapon_ref,origin=nil,nil,nil,nil,nil
    C.ready=false
    C.parts=nil; C.tint_key=nil
end
local function provider()
    if not wanted or (not custom_pose and not Preview.open) then return nil end
    local target,q= (custom_pose or Preview.pose)(view)
    local out=Math.solve(root_ref,weapon_ref,target,q,{x=0,y=0,z=0})
    local p=ValueType.new(sdk.find_type_definition('via.Position'))
    local rot=ValueType.new(sdk.find_type_definition('via.Quaternion'))
    for _,a in ipairs({'x','y','z'}) do
        assert(out.position[a]==out.position[a] and math.abs(out.position[a]-origin[a])<20,'Comparison outside safe bounds')
        p:set_field(a,out.position[a])
    end
    for _,a in ipairs({'x','y','z','w'}) do rot:set_field(a,out.rotation[a]) end
    return {position=p,rotation=rot,weapon_scale=C.scale or Preview.ui_scale or .35}
end
function C.active() return inst~=nil end
function C.tick(token,leader,prepare)
    wanted=token and leader and token or nil
    if inst then
        local err=Pose.error(pose_token)
        if wanted~=attempt or err then
            if err then C.error=tostring(err) end
            inst.request_stop(); detach()
        end
        inst.tick()
        C.status=C.error or inst.status
        if inst.state=='cleanup_failed' then C.blocked=true; C.error=inst.status end
        if inst.state=='finished' then inst=nil; detach() end
    end
    if not wanted and not inst then attempt=nil end
    if wanted and not inst and not C.blocked and wanted~=attempt then
        attempt=wanted; C.error=nil
        inst=Instances.new_preview({preview=true,receipt_path='ImmersiveInteractables_TemperComparison32_'..view..'.json',
            allowed=function() return wanted~=nil and wanted==attempt end,detach=detach,
            ready=function(go,player,builder)
                pending={go=go,player=player,builder=builder,leader=leader,prepare=prepare}
            end})
        inst.request()
    end
end
function C.prepare()
    if not pending or not wanted then return end
    local work=pending; pending=nil
    local ok,err=pcall(function()
        local parts,wt,_,waiting=work.prepare(work.go,true)
        if waiting then pending=work; C.status=waiting; return end
        assert(parts and #parts>0 and wt,'No current weapon on comparison shell')
        root_ref=snapshot(work.go:call('get_Transform')); weapon_ref=snapshot(wt)
        origin=snapshot(work.player:call('get_Transform')).p
        pose_token=Pose.register_companion(work.leader,work.go,work.player,work.builder,provider)
        Pose.weapon_scale(pose_token,wt)
        C.parts=parts
        C.ready=true
    end)
    if not ok then C.error=tostring(err); C.status=C.error; inst.request_stop(); detach() end
end
function C.reset() wanted=nil; detach(); if inst then inst.reset() end end
return C
end
local C=new('current'); C.new=new
return C
