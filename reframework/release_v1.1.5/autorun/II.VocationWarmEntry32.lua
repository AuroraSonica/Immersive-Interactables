local Loader=require('II.DialogueCloneLoad32')
local Borrow=require('II.VocationBorrow32')
local prepared,prepare_error=pcall(Borrow.prepare)
local Gate=require('II.VocationEntry32')
local snapshot=require('II.AnvilTrace32').snapshot
local C=require('II.Compat32')
local lease,array,owner,queued,issued,seen,at
local status='Ready. Save first: native screen opening is still experimental.'
local report={revision=1,events={}}
local function record(stage)
    report.events[#report.events+1]={stage=stage,time=os.date('%Y-%m-%d %H:%M:%S')}
    while #report.events>64 do table.remove(report.events,1) end
    local ok,result=pcall(json.dump_file,'ImmersiveInteractables_VocationWarmEntry32.json',report)
    if (not ok or result==false) and not report.write_warning then
        report.write_warning=true
        pcall(function() log.warn('[Vocation] Diagnostic receipt unavailable; native lifecycle continues') end)
    end
end
local function state()
    local s=snapshot()
    local gm=assert(sdk.get_managed_singleton('app.GuiManager'))
    local player=assert(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'))
    s.owner=tostring(player:get_address())
    s.loading=gm:call('get_IsLoadGui'); s.paused=gm:call('isPausedGUI')
    s.interacting=rawget(_G,'Interactables_session_token')~=nil
    return s,gm
end
local function release()
    if lease then lease.cancel() end
    assert(not lease or lease.state~='cleanup_failed','Vocation resource cleanup failed')
    if array then array:release(); array=nil end
end
local API={}
function API.busy() return lease~=nil or issued==true end
function API.queue()
    if not prepared then return false,tostring(prepare_error) end
    if API.busy() then return false,'Vocation menu is already opening or open' end
    local ok,err=pcall(function()
        local s=state(); assert(Gate.safe(s),'Stand idle outside native menus and interactions')
        owner=s.owner; queued=os.clock(); seen=nil; at=nil
        lease=Loader.new_vocation_lease()
        lease.request(); status='Preparing vocation menu.'; record('queued')
    end)
    if not ok then status=tostring(err) end
    return ok,status
end
_G.InteractablesVocation32=API
re.on_draw_ui(function()
    if not imgui.tree_node('Vocation Menu — Borrowed Prefab Test') then return end
    imgui.text(prepared and status or tostring(prepare_error))
    imgui.text('Preloads first, then opens once. Do not Reset Scripts while loading or open.')
    if prepared and not lease and not issued and imgui.button('Queue Preloaded Vocation Menu') then
        API.queue()
    end
    imgui.tree_pop()
end)
re.on_pre_application_entry('UpdateBehavior',function()
    if not lease then return end
    local ok,err=pcall(function()
        if not issued then
            if reframework:is_drawing_ui() then return end
            local s,gm=state()
            assert(s.owner==owner and Gate.safe(s),'Context changed before opening')
            assert(os.clock()-queued<35,'Preload timed out')
            lease.tick()
            status='Preparing vocation menu: '..lease.state
            assert(lease.state~='stopped' and lease.state~='cleanup_failed',lease.status)
            if lease.state~='ready_held' then return end
            local m=C.method('app.GuiManager','requestJobGuildMenu2',
                {'app.Character.JobEnum[]','app.ui040101_00.MenuKind','System.Boolean'})
            assert(not m:is_static() and m:get_return_type():get_full_name()=='System.Void','Unexpected guild signature')
            array=assert(sdk.create_managed_array('app.Character.JobEnum',0)); array:add_ref()
            assert(array:call('get_Length')==0,'Nonempty vocation array')
            record('preloaded_request'); issued=true; at=os.clock()
            Borrow.run(lease.prefab,lease.ctrl,function() m:call(gm,array,0,false) end)
            record('request_returned'); status='Native request sent. Back out normally; do not reset scripts.'
        else
            local s=state()
            if s.loading or s.paused or s.menuType~='none' then seen=true end
            if seen and s.owner==owner and Gate.safe(s) then
                record('native_menu_closed'); release(); lease=nil
                issued=false; seen=nil; owner=nil; queued=nil; at=nil
                status='Menu closed; preload released.'
            elseif os.clock()-at>30 and not seen then
                status='No menu observed. Lease retained for safety; report this result.'
            end
        end
    end)
    if not ok then
        status=tostring(err)
        pcall(record,'error: '..status)
        if not issued then pcall(release); lease=nil; issued=true end
    end
end)
re.on_script_reset(function()
    if _G.InteractablesVocation32==API then _G.InteractablesVocation32=nil end
    if not issued then pcall(release) end
end)
