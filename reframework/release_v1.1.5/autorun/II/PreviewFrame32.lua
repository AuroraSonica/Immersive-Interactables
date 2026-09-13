local F={}
function F.turn(q,angle)
    local s,c=math.sin(angle*0.5),math.cos(angle*0.5)
    return {x=0,y=q.y*c+q.w*s,z=0,w=q.w*c-q.y*s}
end
function F.layout(sw,sh)
    local x,y=sw-790-50,(sh-580)*0.38
    local w=math.max(160,math.min(600,x-24))
    return {x=math.max(12,x-w-12),y=y,w=w,h=580}
end
function F.solve(c,sw,sh)
    assert(sw>=1000 and sh>=650,"Preview requires at least 1000x650")
    assert(c.fov>5 and c.fov<150,"Invalid camera FOV")
    local rect=F.layout(sw,sh)
    local height=2.1
    local d=height/(2*math.tan(math.rad(c.fov)*0.5)*((rect.h-90)/sh))
    assert(d>(c.near or 0.1)+0.5 and d<30,"Invalid full-size preview distance")
    local half=d*math.tan(math.rad(c.fov)*0.5)
    local sx=(2*(rect.x+rect.w*0.5)/sw-1)*half*(sw/sh)
    local centre_y=rect.y+rect.h-36-(rect.h-90)*0.5
    local sy=(1-2*centre_y/sh)*half
    local p={}
    for _,a in ipairs({"x","y","z"}) do
        p[a]=c.position[a]+c.forward[a]*d+c.right[a]*sx+c.up[a]*sy
        assert(p[a]==p[a] and math.abs(p[a])<1e7,"Invalid camera pose")
    end
    p.y=p.y-height*0.5
    local horizontal=math.sqrt(c.forward.x*c.forward.x+c.forward.z*c.forward.z)
    assert(horizontal>0.05,"Camera is too vertical to frame an upright mannequin")
    local yaw=math.atan(-c.forward.x,-c.forward.z)
    return {position=p,distance=d,rotation={x=0,y=math.sin(yaw*0.5),z=0,w=math.cos(yaw*0.5)}}
end
return F
