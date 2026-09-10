local M=require("II.WorkpieceMath32")
local Bounds=require('II.WeaponBounds32')
local P={open=false,spin=0,tilt=60,zoom=1,keep_hand=true,ui_scale=.15}
function P.pose(which)
    local cam=assert(sdk.get_managed_singleton("app.CameraManager"):call("getMainCamera",0))
    local tf=cam:call("get_GameObject"):call("get_Transform")
    local p=tf:call("get_UniversalPosition")
    local z,x,y=tf:call("get_AxisZ"),tf:call("get_AxisX"),tf:call("get_AxisY")
    local player=sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer")
    local pp=player:call("get_GameObject"):call("get_Transform"):call("get_UniversalPosition")
    local sign=(z.x*(pp.x-p.x)+z.y*(pp.y+1-p.y)+z.z*(pp.z-p.z))>=0 and 1 or -1
    local fov=assert(tonumber(cam:call("get_FOV")))
    assert(fov>5 and fov<150,"Invalid preview FOV")
    local yaw=math.atan(-z.x*sign,-z.z*sign)+math.rad(P.spin)
    local rotation=M.euler(math.rad(P.tilt),yaw,0)
    local d=1.2
    if P.bounds and P.screen then
        local s=P.screen; local width=P.comparison and (s.pw-12)*.5 or s.pw
        local rects={{x=s.x,y=s.y,w=width,h=s.ph}}
        if P.comparison then rects[2]={x=s.x+width+12,y=s.y,w=width,h=s.ph} end
        local ok,fit=pcall(Bounds.distance,P.bounds,rotation,x,y,{x=z.x*sign,y=z.y*sign,z=z.z*sign},rects,s.w,s.h,fov)
        if ok then
            P.required_distance=fit
            P.fit_status=fit>d and 'Near-camera limit: full weapon may exceed panel' or 'Near-camera framing'
        else P.fit_status=tostring(fit) end
    else P.fit_status=P.bounds_error or 'Bounds pending; fallback framing' end
    assert(d>0.5 and d<15,"Preview distance out of bounds")
    local target={}
    for _,a in ipairs({"x","y","z"}) do target[a]=p[a]+z[a]*sign*d-x[a]*0.9-y[a]*1.3 end
    if P.screen then
        local s=P.screen
        if P.comparison then
            local halfwidth=(s.pw-12)*0.5
            s={w=s.w,h=s.h,x=s.x+(which=='current' and 0 or halfwidth+12),
                y=s.y,pw=halfwidth,ph=s.ph}
        end
        local half=d*math.tan(math.rad(fov)*0.5)
        local sx=(2*(s.x+s.pw*0.5)/s.w-1)*half*s.w/s.h
        local sy=(1-2*(s.y+s.ph*0.5+16)/s.h)*half
        for _,a in ipairs({'x','y','z'}) do target[a]=p[a]+z[a]*sign*d+x[a]*sx+y[a]*sy end
    end
    if P.bounds then
        local offset=M.rotate(rotation,P.bounds.centre)
        for _,a in ipairs({'x','y','z'}) do target[a]=target[a]-offset[a]*P.ui_scale end
    end
    if P.receipt_token~=P.session_token then P.receipt_token=P.session_token; P.receipts={} end
    local view=which or 'proposed'
    if P.session_token and not (P.receipts or {})[view] then
        P.receipts=P.receipts or {}
        P.receipts[view]={camera={x=p.x,y=p.y,z=p.z},target=target,distance=d,fov=fov,
            forward={x=z.x*sign,y=z.y*sign,z=z.z*sign},screen=P.screen,tilt=P.tilt,
            bounds=P.bounds,scale=P.ui_scale,fit=P.fit_status,required_distance=P.required_distance}
        pcall(function() json.dump_file('ImmersiveInteractables_TemperFraming32.json',P.receipts) end)
    end
    return target,rotation
end
function P.draw(temper,finishes)
    if not P.open then return end
    if not temper.parts then P.open=false; return end
    local visible=imgui.begin_window("Weapon finish preview (test)",true,0)
    if visible then
        imgui.text("Visual comparison only - no buff, payment or permanent changes.")
        imgui.text("The workpiece is temporarily shown in front of the camera.")
        local changed,v=imgui.slider_float("Rotate weapon",P.spin,-180,180); if changed then P.spin=v end
        changed,v=imgui.slider_float("Tilt weapon",P.tilt,-90,90); if changed then P.tilt=v end
        changed,v=imgui.slider_float("Preview distance",P.zoom,0.7,1.5); if changed then P.zoom=v end
        if imgui.button("Original") then temper.command="original" end
        for i,f in ipairs(finishes) do
            if imgui.button(f.name) then temper.command=i end
        end
        imgui.text(temper.status)
        if imgui.button("Close comparison - return weapon to hand") then P.open=false end
    else P.open=false end
    imgui.end_window()
end
return P
