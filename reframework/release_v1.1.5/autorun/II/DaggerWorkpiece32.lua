local D={path='character/wp/wp03/000/wp03_000.mesh'}
local base='character/wp/wp03/000/wp03_000'
local held,bindings={},{}
local mesh_holder,material_holder
function D.family(path)
    return tostring(path):lower():match('/(wp%d%d)/')
end
function D.required(path)
    return ({wp04=true,wp05=true,wp07=true,wp08=true,wp10=true})[D.family(path)]==true
end
local function keep(o)
    assert(o,'Dagger resource unavailable'); o=o:add_ref(); held[#held+1]=o; return o
end
local function method(name,param)
    local found
    for _,m in ipairs(assert(sdk.find_type_definition('via.render.Mesh')):get_methods()) do
        local p=m:get_param_types() or {}
        if m:get_name()==name and #p==1 and p[1]:get_full_name()==param then
            assert(not found and not m:is_static() and m:get_return_type():get_full_name()=='System.Void','Dagger mesh signature mismatch')
            found=m
        end
    end
    return assert(found,'Dagger setter unavailable: '..name)
end
function D.prewarm()
    if mesh_holder then return true end
    local mr=keep(sdk.create_resource('via.render.MeshResource',base..'.mesh'))
    local mt=keep(sdk.create_resource('via.render.MeshMaterialResource',base..'.mdf2'))
    mesh_holder=keep(mr:create_holder('via.render.MeshResourceHolder'))
    material_holder=keep(mt:create_holder('via.render.MeshMaterialResourceHolder'))
    return true
end
local function assign(mesh)
    local setmesh=method('setMesh','via.render.MeshResourceHolder')
    local setmaterial=method('set_Material','via.render.MeshMaterialResourceHolder')
    mesh:call('set_Enabled',false)
    setmesh:call(mesh,mesh_holder); setmaterial:call(mesh,material_holder)
end
function D.bind(mesh,owner,player_meshes)
    local id=tostring(mesh:get_address())
    assert(not player_meshes[id],'Refusing to replace equipped mesh')
    local key=tostring(owner:get_address())..':'..id
    local b=bindings[key]
    if not b then
        D.prewarm()
        b={at=os.clock(),retries=0}; bindings[key]=b
        assign(mesh)
        return false
    end
    if mesh:call('get_MeshReady')==true and mesh:call('get_MaterialReady')==true then
        b.ready=true
        return true
    end
    if b.ready then return true end
    if os.clock()-b.at>=10 then
        assert(b.retries<2,'Dagger resources did not become ready')
        b.retries=b.retries+1; b.at=os.clock()
        assign(mesh)
    end
    return false
end
pcall(D.prewarm)
function D.forget(owner)
    local prefix=tostring(owner:get_address())..':'
    for k in pairs(bindings) do if k:sub(1,#prefix)==prefix then bindings[k]=nil end end
end
if re and re.on_script_reset then
    re.on_script_reset(function()
        for i=#held,1,-1 do pcall(function() held[i]:release() end) end
        held={}; bindings={}; mesh_holder,material_holder=nil,nil
    end)
end
return D
