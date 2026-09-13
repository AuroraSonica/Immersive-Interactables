local R={entries={},prev=false}
local keys={gm51_062=true,gm51_062_01=true,gm51_062_02=true,gm51_331=true,gm51_332=true}
local static_keys={sm51_331_00=true,sm51_332_00=true,
    sm51_062_00=true,sm51_062_01=true,sm51_062_02=true,
    sm51_339_00=true,sm50_503_00=true}
R.static={}
R.anchors={{nkey='Bakbattahl spear rack (mapped)',
    anchor={x=-1379.2491455078,y=108.2824935913,z=418.7877807617}}}
local atlas_ok,authored=pcall(require,'II.VocationAtlas32')
R.authored_count=0
R.atlas_error=not atlas_ok and tostring(authored) or nil
for _,p in ipairs(atlas_ok and authored or {}) do
    local original=R.anchors[1].anchor
    if (p[2]-original.x)^2+(p[3]-original.y)^2+(p[4]-original.z)^2>0.0625 then
        R.anchors[#R.anchors+1]={nkey=p[1]..' (scene)',anchor={x=p[2],y=p[3],z=p[4]},authored=true}
        R.authored_count=R.authored_count+1
    end
end
local anchor_file='ImmersiveInteractables_VocationLocations32.json'
local function coordinates(p)
    return type(p)=='table' and type(p.x)=='number' and type(p.y)=='number' and type(p.z)=='number'
        and p.x==p.x and p.y==p.y and p.z==p.z
        and math.abs(p.x)<1000000 and math.abs(p.y)<1000000 and math.abs(p.z)<1000000
end
if json then
    local ok,rows=pcall(json.load_file,anchor_file)
    if ok and type(rows)=='table' then
        for _,row in ipairs(rows) do
            if coordinates(row.anchor) and type(row.nkey)=='string' and #R.anchors<2048 then
                R.anchors[#R.anchors+1]={anchor=row.anchor,nkey=row.nkey,user=true}
            end
        end
    end
end
local function cell_key(x,y,z) return x..':'..y..':'..z end
function R.reindex()
    R.cells={}; R.near_cell=nil; R.near_anchors={}
    for _,e in ipairs(R.anchors) do
        local p=e.anchor
        local key=cell_key(math.floor(p.x/16),math.floor(p.y/16),math.floor(p.z/16))
        local bucket=R.cells[key] or {}; R.cells[key]=bucket
        bucket[#bucket+1]=e
    end
end
function R.nearby_anchors(p)
    local x,y,z=math.floor(p.x/16),math.floor(p.y/16),math.floor(p.z/16)
    local key=cell_key(x,y,z)
    if key~=R.near_cell then
        R.near_cell=key; R.near_anchors={}
        for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
            for _,e in ipairs(R.cells[cell_key(x+dx,y+dy,z+dz)] or {}) do
                R.near_anchors[#R.near_anchors+1]=e
            end
        end end end
    end
    return R.near_anchors
end
R.reindex()
function R.register(kind,p)
    local read,plain=pcall(function()
        return {x=tonumber(p.x),y=tonumber(p.y),z=tonumber(p.z)}
    end)
    p=read and plain or nil
    if not coordinates(p) then return false,'Player position unavailable' end
    for _,row in ipairs(R.anchors) do
        local q=row.anchor
        if (q.x-p.x)^2+(q.y-p.y)^2+(q.z-p.z)^2<2.25 then
            return false,'A mapped station already covers this spot'
        end
    end
    local row={nkey=kind..' (mapped)',anchor={x=p.x,y=p.y,z=p.z},user=true}
    local saved={}
    for _,e in ipairs(R.anchors) do if e.user then saved[#saved+1]=e end end
    saved[#saved+1]=row
    local ok,result=pcall(json.dump_file,anchor_file,saved)
    if not ok or result==false then return false,'Location could not be saved' end
    R.anchors[#R.anchors+1]=row; R.reindex(); R.next_check=nil
    return true,'Saved '..kind..' at your standing position'
end
function R.resource_matches(path)
    local p=tostring(path or ''):lower():gsub('\\','/')
    if not p:find('environment/props/',1,true) then return false end
    local basename=p:match('/([^/]+)%.mesh$')
    return static_keys[basename]==true
end
function R.discover(now,pp)
    if now<(R.scan_tick or 0) then return end
    R.scan_tick=now+0.2
    if not R.scan then
        if now<(R.scan_at or 0) then return end
        if R.scan_origin and pp and not R.force_scan then
            local p=R.scan_origin
            if (pp.x-p.x)^2+(pp.y-p.y)^2+(pp.z-p.z)^2<1600 then return end
        end
        R.scan_at=now+30
        local sm=sdk.get_native_singleton('via.SceneManager')
        local scene=sm and sdk.call_native_func(sm,sdk.find_type_definition('via.SceneManager'),'get_CurrentScene')
        if not scene then return end
        local started=os.clock()
        local arr=scene:call('findComponents(System.Type)',sdk.typeof('via.render.Mesh'))
        local ms=(os.clock()-started)*1000
        R.find_ms=ms; R.find_peak=math.max(R.find_peak or 0,ms)
        R.searches=(R.searches or 0)+1
        if not arr then return end
        arr:add_ref()
        R.force_scan=false
        R.scan_origin=pp and {x=pp.x,y=pp.y,z=pp.z} or nil
        R.scan={arr=arr,cursor=0,count=tonumber(arr:call('get_Length')) or 0,found={},inventory={}}
    end
    local s=R.scan
    local batch_started=os.clock()
    local processed=0
    for i=s.cursor,math.min(s.cursor+63,s.count-1) do
        if processed>0 and os.clock()-batch_started>=0.001 then break end
        pcall(function()
            local mesh
            pcall(function() mesh=s.arr:get_element(i) end)
            if not mesh then mesh=s.arr:call('GetValue(System.Int32)',i) end
            local go=mesh and mesh:call('get_GameObject')
            local name=go and tostring(go:call('get_Name')):lower():gsub('%s*%(%d+%)$','')
            local matched=static_keys[name] or keys[name]
            local resource_path
            if not matched and go then
                local ok,path=pcall(function()
                    local resource=mesh:call('getMesh')
                    return resource and tostring(resource:call('get_ResourcePath'))
                end)
                if ok then resource_path=path; matched=R.resource_matches(path) end
            end
            if not R.inventory_saved and #s.inventory<4096 and go then
                local row={name=name,path=resource_path,matched=matched==true}
                pcall(function()
                    local p=go:call('get_Transform'):call('get_UniversalPosition')
                    row.position={x=p.x,y=p.y,z=p.z}
                end)
                s.inventory[#s.inventory+1]=row
            end
            if matched then
                s.found[#s.found+1]={go=go,nkey=name}
            end
        end)
        processed=processed+1
    end
    s.cursor=s.cursor+processed
    R.batch_peak=math.max(R.batch_peak or 0,(os.clock()-batch_started)*1000)
    if s.cursor>=s.count then
        if not R.inventory_saved then
            local ok,result=pcall(json.dump_file,'ImmersiveInteractables_RackInventory32.json',
                {time=os.date(),total=s.count,meshes=s.inventory})
            R.inventory_saved=ok and result~=false
        end
        R.static=s.found; s.arr:release(); R.scan=nil
    end
end
function R.matches(key) return keys[key]==true end
if re and re.on_script_reset then re.on_script_reset(function()
    local IP=rawget(_G,'IrisPrompt')
    if IP and IP.clear then pcall(IP.clear,'interactables_vocation') end
    R.entries={}; R.prev=false
    R.static={}
    if R.scan then pcall(function() R.scan.arr:release() end); R.scan=nil end
end) end
function R.refresh(list)
    R.next_check=nil; R.best=nil; R.dist=nil
    R.entries={}
    for _,e in ipairs(list or {}) do
        if R.matches(e.nkey) then R.entries[#R.entries+1]=e end
    end
end
function R.tick(ctx)
    R.ctx=ctx
    local IP=rawget(_G,'IrisPrompt')
    local api=rawget(_G,'InteractablesVocation32')
    local down=ctx.down()
    local edge=down and not R.prev; R.prev=down
    local now=os.clock()
    if sdk and (not ctx.discover_allowed or ctx.discover_allowed()) then
        local ok,err=pcall(R.discover,now,ctx.player_pos())
        R.scan_error=not ok and tostring(err) or nil
    end
    if IP and IP.clear then IP.clear('interactables_vocation') end
    local allowed,reason=ctx.allowed()
    local overlay=ctx.overlay and ctx.overlay() or false
    local blocked=not IP and 'Shared prompt API missing' or not api and 'Vocation opener missing'
        or api.busy() and 'Vocation menu busy' or not allowed and (reason or 'Interaction blocked') or nil
    R.blocked=blocked
    R.status='Searching for nearby rack'
    if #R.entries==0 and #R.static==0 and #R.anchors==0 then return end
    if edge or now>=(R.next_check or 0) then
    R.next_check=now+0.2
    local pp=ctx.player_pos()
    if not pp then R.best=nil; return end
    local best,dist
    for _,list in ipairs({R.entries,R.static,R.nearby_anchors(pp)}) do
    for _,e in ipairs(list) do
        pcall(function()
            if not e.anchor and not ctx.valid(e.go) then e.dead=true; return end
            local p=e.anchor or ctx.pos(e.go)
            if not p then return end
            local d=(p.x-pp.x)^2+(p.y-pp.y)^2+(p.z-pp.z)^2
            if not dist or d<dist then best=e; dist=d end
        end)
    end
    end
    R.best,R.dist=best,dist
    for i=#R.static,1,-1 do if R.static[i].dead then table.remove(R.static,i) end end
    end
    local best,dist=R.best,R.dist
    if not best then return end
    R.status=string.format('Nearest: %s, %.2f m (range 2.50 m)',tostring(best.nkey),math.sqrt(dist))
    if not overlay then R.last_gameplay=blocked or (dist>=6.25 and 'Nearest rack out of range' or 'Rack in range; offering prompt') end
    if blocked or overlay or dist>=6.25 then return end
    if not best.anchor and not ctx.valid(best.go) then R.best=nil; R.next_check=nil; return end
    local pos
    if best.anchor then
        pos=ctx.anchor_render_pos and ctx.anchor_render_pos(best.anchor)
        if not pos then return end
    else pos=ctx.render_pos(best.go) end
    IP.set('interactables_vocation','Change Vocation',14,math.sqrt(dist),pos,best.go)
    if edge and IP.winner()=='interactables_vocation' then
        local ok,reason=api.queue()
        if not ok then ctx.notice(reason) end
    end
end
if re and re.on_draw_ui then re.on_draw_ui(function()
    if imgui.tree_node('Vocation Rack Status') then
        imgui.text(R.status or 'Waiting for update')
        imgui.text('Gameplay gate: '..(R.blocked or 'Clear'))
        imgui.text('Before opening REFramework: '..(R.last_gameplay or 'Not sampled near a rack yet'))
        imgui.text(string.format('Cached racks: %d gimmicks, %d scenery',#R.entries,#R.static))
        imgui.text(string.format('Locations: %d scene-derived, %d mapped',R.authored_count,#R.anchors-R.authored_count))
        if R.atlas_error then imgui.text('Scene atlas unavailable: '..R.atlas_error) end
        imgui.text('Stand at the usable front of a rack/barrel. Saves this location only, not all copies.')
        for _,kind in ipairs({'Weapon rack','Weapon barrel'}) do
            if imgui.button('Register '..kind..' here') then
                local p=R.ctx and R.ctx.player_pos()
                local ok,msg=R.register(kind,p)
                R.mapping_status=msg
            end
        end
        if R.mapping_status then imgui.text(R.mapping_status) end
        if imgui.button('Refresh nearby rack discovery') then R.force_scan=true; R.scan_at=0 end
        imgui.text('Discovery: on movement of 40 m, minimum 30 seconds between searches; manual refresh available.')
        if R.scan then imgui.text(string.format('Discovery: %d / %d',R.scan.cursor,R.scan.count)) end
        if R.scan_error then imgui.text(R.scan_error) end
        imgui.text(string.format('Discovery samples: %d searches; search last/peak %.2f / %.2f ms; batch peak %.2f ms',
            R.searches or 0,R.find_ms or 0,R.find_peak or 0,R.batch_peak or 0))
        imgui.tree_pop()
    end
end) end
return R
