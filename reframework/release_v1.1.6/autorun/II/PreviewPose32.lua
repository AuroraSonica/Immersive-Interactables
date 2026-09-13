local P={}
local C=require("II.Compat32")
local records={}
local active
local function id(o) return o and o:get_address() end
function P.allowed(obj,name)
    if active and active.scale_tf==obj and active.scaling then return name=='set_LocalScale' end
    return active~=nil and obj==active.tf and
        (name=="set_UniversalPosition" or name=="set_Rotation")
end
local function register(go,player,builder,provider,leader)
    if leader then
        assert(records[leader] and not records[leader].leader,"Comparison owner unavailable")
        local companions=0
        for _,r in pairs(records) do
            if r.leader then companions=companions+1 end
            assert(id(r.go)~=id(go),"Comparison must own a separate shell")
            assert(r.player_id==id(player),"Comparison player differs from owner")
        end
        assert(companions<2,'Only two comparison companions are allowed')
    else assert(next(records)==nil,"Another preview pose is active") end
    assert(go and player and id(go)~=id(player),"Preview cannot own player transform")
    assert(go:call("get_Valid")==true,"Preview object invalid")
    assert(builder and id(builder:call("get_GameObject"))==id(go),"Builder not owned by preview")
    assert(not go:call("getComponent(System.Type)",sdk.typeof("app.Character")),"Refusing character transform")
    local tf=assert(go:call("get_Transform"))
    assert(id(tf:call("get_GameObject"))==id(go),"Transform not owned by preview")
    for name,param in pairs({set_UniversalPosition="via.Position",set_Rotation="via.Quaternion"}) do
        local m=C.method("via.Transform",name,{param})
        assert(not m:is_static() and m:get_return_type():get_full_name()=="System.Void","Preview setter signature changed")
    end
    local token={}
    records[token]={go=go,tf=tf,provider=provider,leader=leader,player_id=id(player)}
    return token
end
function P.register(go,player,builder,provider) return register(go,player,builder,provider) end
function P.register_companion(leader,go,player,builder,provider)
    assert(leader,"Comparison requires live owner token")
    return register(go,player,builder,provider,leader)
end
function P.create_render_companion(leader,player,provider)
    assert(records[leader],'Render preview requires a live mannequin owner')
    local go=assert(sdk.find_type_definition('via.GameObject'):get_method('create(System.String)')
        :call(nil,'II_ParagliderPreview32')):add_ref()
    local ok,mesh,token=pcall(function()
        go:call('set_DrawSelf',false); go:call('set_UpdateSelf',true)
        local folder=player:call('get_Folder')
        assert(folder,'Player scene folder unavailable'); go:call('set_FolderSelf',folder)
        local mesh=assert(go:call('createComponent(System.Type)',sdk.typeof('via.render.Mesh')))
        mesh:call('set_Enabled',false)
        mesh:call('set_StaticMesh',false); mesh:call('set_ForceDynamicMesh',true)
        local token=register(go,player,mesh,provider,leader)
        local r=records[token]
        r.scale_tf=r.tf; r.scale_base={x=1,y=1,z=1}
        return mesh,token
    end)
    if not ok then
        pcall(function() go:call('destroy(via.GameObject)',go); go:release() end)
        error(mesh)
    end
    return go,mesh,token
end
function P.confirmed(token) return records[token] and records[token].confirmed==true end
function P.weapon_scale(token,tf)
    local r=assert(records[token],'Preview token missing')
    assert(r.leader,'Only UI companions may scale weapons')
    assert(tf~=r.tf,'Never scale the clone root')
    local go=assert(tf:call('get_GameObject'))
    assert(go:call('getComponent(System.Type)',sdk.typeof('via.render.Mesh')),'Weapon must have a mesh')
    local t,owned=tf,false
    for _=1,17 do
        if t==r.tf then owned=true; break end
        assert(not t:call('get_GameObject'):call('getComponent(System.Type)',sdk.typeof('app.Character')),'Refusing character hierarchy')
        t=t:call('get_Parent'); if not t then break end
    end
    assert(owned,'Weapon must belong to this preview shell')
    local method=C.method('via.Transform','set_LocalScale',{'via.vec3'})
    assert(not method:is_static() and method:get_return_type():get_full_name()=='System.Void','Scale signature changed')
    local s=tf:call('get_LocalScale')
    r.scale_base={x=s.x,y=s.y,z=s.z}; r.scale_tf=tf
end
function P.revoke(token)
    records[token]=nil
    for t,r in pairs(records) do if r.leader==token then records[t]=nil end end
end
re.on_pre_application_entry("LateUpdateBehavior",function()
    for token,r in pairs(records) do
        local ok,err=pcall(function()
            if r.leader and not records[r.leader] then records[token]=nil; return end
            if r.go:call("get_Valid")~=true then records[token]=nil; return end
            local pose=r.provider()
            if not pose then return end
            if not r.started then
                local ok,v=pcall(json.dump_file,"ImmersiveInteractables_PreviewPose32.json",
                    {revision=2,mode="unscaled_upright",stage="before first owned pose write",phase="pre-LateUpdateBehavior",time=os.date("%Y-%m-%d %H:%M:%S")})
                assert(ok and v~=false,"Cannot save first preview pose stage")
                r.started=true
            end
            active=r
            if r.scale_tf and pose.weapon_scale and r.last_scale~=pose.weapon_scale then
                assert(pose.weapon_scale>=.1 and pose.weapon_scale<=1,'UI scale outside safe range')
                local v=ValueType.new(sdk.find_type_definition('via.vec3'))
                for _,a in ipairs({'x','y','z'}) do v:set_field(a,r.scale_base[a]*pose.weapon_scale) end
                r.scaling=true
                r.scale_tf:call('set_LocalScale',v)
                r.scaling=false
                local actual=r.scale_tf:call('get_LocalScale')
                for _,a in ipairs({'x','y','z'}) do assert(math.abs(actual[a]-r.scale_base[a]*pose.weapon_scale)<.001,'Weapon scale did not take effect') end
                pcall(json.dump_file,'ImmersiveInteractables_WeaponScale32.json',{
                    owner=tostring(id(r.go)),factor=pose.weapon_scale,
                    actual={x=actual.x,y=actual.y,z=actual.z},stage='owned weapon local scale readback matched'})
                r.last_scale=pose.weapon_scale
            end
            r.tf:call("set_UniversalPosition",pose.position)
            r.tf:call("set_Rotation",pose.rotation)
            if not r.confirmed then
                local actual=r.tf:call("get_UniversalPosition")
                for _,a in ipairs({"x","y","z"}) do
                    assert(math.abs(actual[a]-pose.position[a])<0.001,
                        "Preview position write did not take effect; fully restart to reload the scoped guard")
                end
            end
            if not r.confirmed then
                r.confirmed=true
                pcall(json.dump_file,"ImmersiveInteractables_PreviewPose32.json",
                    {revision=2,mode="unscaled_upright",stage="owned pose position readback matched",phase="pre-LateUpdateBehavior",
                        distance=pose.distance,position={x=pose.position.x,y=pose.position.y,z=pose.position.z},
                        rotation={x=pose.rotation.x,y=pose.rotation.y,z=pose.rotation.z,w=pose.rotation.w},
                        time=os.date("%Y-%m-%d %H:%M:%S")})
            end
        end)
        active=nil
        if not ok then token.error=tostring(err); records[token]=nil end
    end
end)
function P.error(token) return token and token.error end
re.on_script_reset(function() records={}; active=nil end)
return P
