local F={}
function F.merge(records,parts,finish)
    assert(finish and finish.colour and #parts>0,'No finish surfaces available')
    local out,index={},{}
    local function key(r) return r.slot..'|'..r.path..'|'..r.mat end
    for _,r in ipairs(records) do
        local copy={}; for k,v in pairs(r) do copy[k]=v end
        out[#out+1]=copy; index[key(copy)]=#out
    end
    for _,p in ipairs(parts) do
        assert(p.path and p.path~='?' and p.name and p.original,'Incomplete finish surface')
        local r={slot=p.slot or 'WeaponMain',path=p.path,mat=p.name}
        local i=index[key(r)]; local old=i and out[i]
        r.orig=old and old.orig or p.original
        r.color={table.unpack(finish.colour)}; r.dye=finish.name
        if i then out[i]=r else out[#out+1]=r; index[key(r)]=#out end
    end
    return out
end
return F
