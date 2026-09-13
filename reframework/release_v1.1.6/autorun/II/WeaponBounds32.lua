local M=require('II.WorkpieceMath32')
local B={}
function B.capture(parts,weapon)
    local origin=weapon:call('get_Position')
    local rotation=weapon:call('get_Rotation')
    local inv=M.inv(rotation)
    local seen,points={},{}
    for _,part in ipairs(parts) do
        local mesh=part.mesh; local id=tostring(mesh:get_address())
        if not seen[id] then
            seen[id]=true
            local box=assert(mesh:call('get_WorldAABB'))
            local lo,hi=box.minpos,box.maxpos
            for bits=0,7 do
                local p={}
                for i,a in ipairs({'x','y','z'}) do
                    assert(lo[a]==lo[a] and hi[a]==hi[a] and hi[a]>=lo[a],'Invalid weapon bounds')
                    p[a]=((bits & (1<<(i-1)))~=0 and hi[a] or lo[a])-origin[a]
                end
                points[#points+1]=M.rotate(inv,p)
            end
        end
    end
    assert(#points>0,'Missing weapon bounds')
    local lo,hi={x=math.huge,y=math.huge,z=math.huge},{x=-math.huge,y=-math.huge,z=-math.huge}
    for _,p in ipairs(points) do for _,a in ipairs({'x','y','z'}) do lo[a]=math.min(lo[a],p[a]); hi[a]=math.max(hi[a],p[a]) end end
    local centre={}
    for _,a in ipairs({'x','y','z'}) do
        assert(hi[a]-lo[a]<12,'Weapon bounds too large')
        centre[a]=(lo[a]+hi[a])*.5
    end
    return {centre=centre,points=points}
end
function B.distance(bounds,q,right,up,forward,rects,sw,sh,fov)
    local function dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
    local half=math.tan(math.rad(fov)*.5)
    local d=3.5
    for _,r in ipairs(rects) do
        local l=(2*(r.x+28)/sw-1)*half*sw/sh
        local rr=(2*(r.x+r.w-28)/sw-1)*half*sw/sh
        local bottom=(1-2*(r.y+r.h-54)/sh)*half
        local top=(1-2*(r.y+86)/sh)*half
        local sx,sy=(l+rr)*.5,(bottom+top)*.5
        assert(rr>l and top>bottom,'Preview panel too small')
        for _,p in ipairs(bounds.points) do
            local v=M.rotate(q,{x=p.x-bounds.centre.x,y=p.y-bounds.centre.y,z=p.z-bounds.centre.z})
            local x,y,z=dot(v,right),dot(v,up),dot(v,forward)
            d=math.max(d,.4-z,(x-rr*z)/(rr-sx),(l*z-x)/(sx-l),
                (y-top*z)/(top-sy),(bottom*z-y)/(sy-bottom))
        end
    end
    assert(d==d and d<14,'Weapon cannot fit safely at authored scale')
    return d
end
return B
