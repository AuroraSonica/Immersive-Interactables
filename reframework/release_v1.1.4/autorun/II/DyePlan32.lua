local P={}
function P.key(p) return p.e.slot.."|"..p.e.path.."|"..p.m.name end
function P.material(name)
    local s=tostring(name):gsub("_[Mm]at$","")
    s=(s:match("([%a]+_?%d*)$") or s):gsub("[_%d]+$",""):lower()
    if #s>18 or not s:match("^%a+$") then return "Surface" end
    if s=="wp" then return "Finish" end
    return s:sub(1,1):upper()..s:sub(2)
end
function P.regions(parts)
    local by,out={},{}
    for _,p in ipairs(parts) do
        local label=P.material(p.m.name)
        if not by[label] then by[label]={label=label,parts={}}; out[#out+1]=by[label] end
        local list=by[label].parts; list[#list+1]=p
    end
    table.sort(out,function(a,b) return a.label<b.label end)
    for _,r in ipairs(out) do table.sort(r.parts,function(a,b) return P.key(a)<P.key(b) end) end
    return out
end
function P.new() return {choices={},revision=0} end
function P.stage(plan,parts,item,col,shade)
    for _,p in ipairs(parts) do
        plan.choices[P.key(p)]={item=item,col=col,shade=shade,group=item.."|"..P.material(p.m.name)}
    end
    plan.revision=plan.revision+1
end
function P.remove(plan,parts)
    for _,p in ipairs(parts) do plan.choices[P.key(p)]=nil end
    plan.revision=plan.revision+1
end
function P.resolve(plan,garments)
    local found,out={},{}
    for _,g in ipairs(garments) do
        for _,p in ipairs(g.parts) do
            local k=P.key(p); local c=plan.choices[k]
            if c and not found[k] then out[#out+1]={part=p,choice=c}; found[k]=true end
        end
    end
    for k in pairs(plan.choices) do if not found[k] then return nil,"Equipment changed; reselect your colours." end end
    return out
end
function P.cost(rows,recipe)
    local out,seen={},{}
    for _,r in ipairs(rows) do
        local c=r.choice; local k=c.item.."|"..c.col.key.."|"..c.shade.key
        if not seen[k] then
            seen[k]=true
            for bowl,n in pairs(recipe(c.col.key,c.shade)) do out[bowl]=(out[bowl] or 0)+n end
        end
    end
    return out
end
function P.count(plan) local n=0; for _ in pairs(plan.choices) do n=n+1 end; return n end
function P.group_count(plan)
    local seen,n={},0
    for _,c in pairs(plan.choices) do
        if not seen[c.group] then seen[c.group]=true; n=n+1 end
    end
    return n
end
return P
