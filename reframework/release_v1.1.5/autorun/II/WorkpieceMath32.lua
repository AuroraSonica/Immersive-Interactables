local M={}
function M.mul(a,b)
    return {w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,
        x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,
        y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
        z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w}
end
function M.inv(q) return {x=-q.x,y=-q.y,z=-q.z,w=q.w} end
function M.twist(q,axis,angle)
    local t={x=0,y=0,z=0,w=math.cos(angle/2)}
    t[axis]=math.sin(angle/2)
    return M.mul(q,t)
end
function M.rotate(q,v)
    local r=M.mul(M.mul(q,{x=v.x,y=v.y,z=v.z,w=0}),M.inv(q))
    return {x=r.x,y=r.y,z=r.z}
end
function M.euler(x,y,z)
    local function axis(a,v) local q={x=0,y=0,z=0,w=math.cos(v/2)}; q[a]=math.sin(v/2); return q end
    return M.mul(M.mul(axis("y",y),axis("x",x)),axis("z",z))
end
function M.solve(root,weapon,target,rotation,contact)
    local localq=M.mul(M.inv(root.q),weapon.q)
    local offset=M.rotate(M.inv(root.q),{x=weapon.p.x-root.p.x,y=weapon.p.y-root.p.y,z=weapon.p.z-root.p.z})
    local q=M.mul(rotation,M.inv(localq)); local d=M.rotate(q,offset)
    local c=M.rotate(rotation,contact or {x=0,y=0,z=0})
    return {position={x=target.x-d.x-c.x,y=target.y-d.y-c.y,z=target.z-d.z-c.z},rotation=q}
end
return M
