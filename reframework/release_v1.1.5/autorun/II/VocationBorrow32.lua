local C=require('II.Compat32')
local M={}
local scope,installed,alive=nil,false,true
local receipt={revision=2,events={}}
local function record(stage)
    if #receipt.events>=40 then return end
    receipt.events[#receipt.events+1]={stage=stage,time=os.date('%Y-%m-%d %H:%M:%S')}
    pcall(json.dump_file,'ImmersiveInteractables_VocationBorrow32.json',receipt)
end
local function install()
    if installed then return end
    local copy=C.method('app.PrefabController','.ctor',{'via.Prefab'})
    local empty=C.method('app.PrefabController','.ctor',{})
    for _,m in ipairs({copy,empty}) do
        assert(not m:is_static() and m:get_return_type():get_full_name()=='System.Void','Unexpected controller constructor')
    end
    local field=assert(sdk.find_type_definition('app.PrefabController'):get_field('_Item'))
    assert(field:get_type():get_full_name()=='via.Prefab','Unexpected controller item field')
    sdk.hook(copy,function(args)
        local s=scope
        if not alive or not s then return end
        record('constructor_entered')
        if s.used then record('rejected: already used'); return end
        local source=sdk.to_managed_object(args[3])
        if not source then record('rejected: source not managed'); return end
        if source:get_address()~=s.prefab:get_address() then record('rejected: source '..tostring(source:get_address())..' expected '..tostring(s.prefab:get_address())); return end
        local target=sdk.to_managed_object(args[2])
        if not target or target:get_type_definition():get_full_name()~='app.PrefabController'
            or target:get_address()==s.owner:get_address() then record('rejected: target type or owner alias'); return end
        s.used=true
        local ok,err=pcall(function()
            record('matched: initialising controller')
            empty:call(target)
            target:set_field('_Item',s.prefab)
            assert(target:get_field('_Item'):get_address()==s.prefab:get_address(),'Borrow readback mismatch')
            assert(target:call('get_RefCount')==0,'Unexpected initial reference count')
            s.bound=true
            record('bound: readback confirmed')
        end)
        if not ok then s.error=tostring(err); record('bind failed: '..s.error) end
        return sdk.PreHookResult.SKIP_ORIGINAL
    end,function(retval) return retval end)
    installed=true
    record('hook registered')
end
function M.prepare() assert(alive,'Inactive module'); install() end
function M.run(prefab,owner,request)
    assert(not scope and alive,'Borrow scope unavailable')
    assert(prefab:get_type_definition():get_full_name()=='via.Prefab','Wrong prefab type')
    assert(prefab:read_qword(0x10)>=0x10000,'Preloaded resource pointer unavailable')
    assert(installed,'Constructor hook must be prepared before queuing')
    local s={prefab=prefab,owner=owner}
    scope=s
    record('request scope entered')
    local ok,err=pcall(request)
    scope=nil
    record('request scope exited; bound='..tostring(s.bound==true))
    if not ok then error(err) end
    assert(not s.error,s.error)
    assert(s.bound,'Native request did not use the scoped prefab constructor')
    return true
end
if re and re.on_script_reset then re.on_script_reset(function() alive=false; scope=nil end) end
return M
