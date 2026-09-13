local M=require('II.WorkpieceMath32')
local F=require('II.PreviewFrame32')
local Pose=require('II.PreviewPose32')
local G={spin=0,scale=.1,ready=false,status='Preparing paraglider...'}
local wanted,leader,instance,attempt,alive=nil,nil,nil,nil,true
local held={}
local function receipt(stage)
    pcall(json.dump_file,'ImmersiveInteractables_GliderPreview32.json',{
        revision=2,stage=stage,time=os.date('%Y-%m-%d %H:%M:%S'),error=G.error})
end
local function release_resources()
    for i=#held,1,-1 do pcall(function() held[i]:release() end) end
    held={}
end
local function cleanup()
    G.ready=false; G.parts=nil; G.mesh=nil; G.centre=nil
    if instance then
        Pose.revoke(instance.token)
        local go=instance.go
        go:call('set_DrawSelf',false)
        instance.mesh:call('set_Enabled',false)
        go:call('destroy(via.GameObject)',go)
        go:release(); instance=nil
    end
    release_resources()
end
local function keep(o)
    o=assert(o,'Glider resource unavailable'):add_ref(); held[#held+1]=o; return o
end
local function provider()
    if not instance or not wanted then return nil end
    local p,q=G.pose()
    local position=ValueType.new(sdk.find_type_definition('via.Position'))
    local rotation=ValueType.new(sdk.find_type_definition('via.Quaternion'))
    for _,a in ipairs({'x','y','z'}) do
        assert(p[a]==p[a] and math.abs(p[a])<1e7,'Invalid glider preview position')
        position:set_field(a,p[a])
    end
    for _,a in ipairs({'x','y','z','w'}) do rotation:set_field(a,q[a]) end
    return {position=position,rotation=rotation,weapon_scale=G.scale}
end
function G.tick(token,owner) wanted=token; leader=owner end
function G.prepare() end
function G.reset() alive=false; wanted=nil; pcall(cleanup) end
local function update()
    if not alive then return end
    if instance and (not wanted or instance.key~=wanted or instance.leader~=leader) then cleanup() end
    if not wanted then attempt=nil; return end
    if not leader or not G.screen then return end
    if not instance and attempt~=wanted then
        attempt=wanted; G.error=nil; G.status='Preparing paraglider...'
        local runtime=rawget(_G,'PARAGLIDER_RUNTIME')
        assert(runtime and runtime.resources_ready,'Paraglider resources not ready')
        local player=assert(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'))
        local go=assert(player:call('get_GameObject'))
        receipt('creating dedicated render object')
        local object,mesh,token=Pose.create_render_companion(leader,go,provider)
        instance={go=object,mesh=mesh,token=token,key=wanted,leader=leader,at=os.clock(),stage=0}
        receipt('dedicated render object created')
        return
    end
    if not instance then return end
    assert(not Pose.error(instance.token),Pose.error(instance.token))
    if instance.stage==0 then
        local mr=keep(sdk.create_resource('via.render.MeshResource','riftspeak/paraglider/paraglider.mesh'))
        local mt=keep(sdk.create_resource('via.render.MeshMaterialResource','riftspeak/paraglider/paraglider.mdf2'))
        local mh=keep(mr:create_holder('via.render.MeshResourceHolder'))
        local material=keep(mt:create_holder('via.render.MeshMaterialResourceHolder'))
        receipt('binding dedicated mesh')
        instance.mesh:call('setMesh',mh)
        receipt('binding dedicated material')
        instance.mesh:call('set_Material',material)
        instance.stage=1; receipt('resources bound; waiting for readiness'); return
    end
    if instance.mesh:call('get_MeshReady')~=true or instance.mesh:call('get_MaterialReady')~=true then
        assert(os.clock()-instance.at<15,'Glider preview readiness timed out'); return
    end
    G.mesh=instance.mesh
    assert(G.ready or os.clock()-instance.at<15,'Glider colours or pose did not become ready')
    if Pose.confirmed(instance.token) and not G.centre then
        local tf=instance.go:call('get_Transform')
        local bounds=instance.mesh:call('get_WorldAABB')
        local origin=tf:call('get_Position')
        local delta={}
        for _,a in ipairs({'x','y','z'}) do
            local lo,hi=bounds.minpos[a],bounds.maxpos[a]
            assert(lo==lo and hi==hi and hi>=lo and hi-lo<12,'Invalid glider bounds')
            delta[a]=(lo+hi)*.5-origin[a]
        end
        G.centre=M.rotate(M.inv(tf:call('get_Rotation')),delta)
        for _,a in ipairs({'x','y','z'}) do G.centre[a]=G.centre[a]/G.scale end
        return
    end
    if Pose.confirmed(instance.token) and G.parts and #G.parts>0 then
        if not G.ready then
            instance.mesh:call('set_Enabled',true); instance.go:call('set_DrawSelf',true)
            G.ready=true; G.status='Paraglider preview ready'; receipt('preview visible')
        end
    end
end
re.on_pre_application_entry('LateUpdateBehavior',function()
    local ok,err=pcall(update)
    if not ok then
        G.error=tostring(err); G.status='Preview unavailable: '..G.error
        receipt('preview stopped'); pcall(cleanup)
    end
end)
function G.pose()
    local s=assert(G.screen)
    local rect=F.layout(s.w,s.h)
    local cam=assert(sdk.get_managed_singleton('app.CameraManager'):call('getMainCamera',0))
    local tf=cam:call('get_GameObject'):call('get_Transform')
    local p,z,x,y=tf:call('get_UniversalPosition'),tf:call('get_AxisZ'),tf:call('get_AxisX'),tf:call('get_AxisY')
    local player=sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer')
    local pp=player:call('get_GameObject'):call('get_Transform'):call('get_UniversalPosition')
    local sign=(z.x*(pp.x-p.x)+z.y*(pp.y+1-p.y)+z.z*(pp.z-p.z))>=0 and 1 or -1
    local fov=tonumber(cam:call('get_FOV')); assert(fov and fov>5 and fov<150)
    local d=1.2; local half=d*math.tan(math.rad(fov)*.5)
    local sx=(2*(rect.x+rect.w*.5)/s.w-1)*half*s.w/s.h
    local sy=(1-2*(rect.y+rect.h*.5)/s.h)*half
    local pos={}
    for _,a in ipairs({'x','y','z'}) do pos[a]=p[a]+z[a]*sign*d+x[a]*sx+y[a]*sy end
    local rotation=M.euler(math.rad(30),math.atan(-z.x*sign,-z.z*sign)+G.spin,0)
    if G.centre then
        local offset=M.rotate(rotation,G.centre)
        for _,a in ipairs({'x','y','z'}) do pos[a]=pos[a]-offset[a]*G.scale end
    end
    return pos,rotation
end
return G
