local M={open=false,row=1,original=false,prev={},count=3}
function M.sync(token,exiting,now)
    if token~=M.token then
        M.token=token; M.open=token~=nil; M.row=1; M.original=false
        M.prev={}; M.block_until=now+0.4; M.dirty=true
    end
    if exiting or not token then M.open=false end
end
function M.input(b,now,ready)
    if not M.open then return end
    local function edge(k)
        local yes=b[k] and not M.prev[k]; M.prev[k]=b[k]==true
        return yes and now>=M.block_until
    end
    local up,down,accept,back= edge('up'),edge('down'),edge('accept'),edge('back')
    if back then M.open=false; return 'cancel' end
    local count=M.count
    if up then M.row=(M.row+count)%(count+2)+1 end
    if down then M.row=M.row%(count+2)+1 end
    if accept and ready then
        if M.row<=count then M.selected=M.row; M.original=false; M.dirty=true
        elseif M.row==count+1 then M.original=not M.original; M.dirty=true
        else M.open=false; return 'start' end
    end
end
function M.prompts(IP)
    M.native_prompts=false
    if not IP or type(IP.set_slot)~='function' or type(IP.clear_slot)~='function' then return end
    if not M.open then IP.clear_slot('interactables_temper'); return end
    for _,slot in ipairs({'PNL_R00','PNL_R01','PNL_L00','PNL_L01','PNL_L02','PNL_L03'}) do
        IP.set_slot('interactables_temper',slot,' ',200)
    end
    IP.set_slot('interactables_temper','PNL_R03',M.row==M.count+2 and 'Begin Tempering' or M.row==M.count+1 and 'Compare' or 'Preview Treatment',200)
    IP.set_slot('interactables_temper','PNL_R02','Cancel',200)
    M.native_prompts=true
end
function M.draw(finishes,ready,status)
    if not M.open then return end
    local size=imgui.get_display_size()
    local w,h=math.min(630,size.x*0.43),math.min(580,size.y-60)
    local x,y=size.x-w-40,(size.y-h)*0.38
    local px,pw=30,math.max(160,x-42)
    M.screen={w=size.x,h=size.y,x=px,y=y,pw=pw,ph=h}
    local gold,text,dim=0xFF52AEFF,0xFFE8E3DB,0xFFAAAAAA
    local half=(pw-12)*0.5
    draw.filled_rect(px,y,half,h,0x30100C0A); draw.outline_rect(px,y,half,h,dim)
    draw.text('Current',px+16,y+16,text)
    draw.text('Your equipped appearance',px+16,y+44,dim)
    draw.text(M.comparison_ready and 'Unchanged' or M.comparison_error and 'Comparison unavailable' or 'Preparing current weapon...',px+16,y+h-36,dim)
    local nx=px+half+12
    draw.filled_rect(nx,y,half,h,0x30100C0A); draw.outline_rect(nx,y,half,h,gold)
    draw.text(M.original and 'Current - A/B Comparison' or 'Proposed - New Finish',nx+16,y+16,gold)
    draw.text(M.original and 'Original shown for comparison' or finishes[M.selected or 1].name,nx+16,y+44,text)
    if not ready then draw.text(tostring(status or 'Preparing proposed weapon...'),nx+16,y+h-36,dim) end
    draw.filled_rect(x,y,w,h,0xE0100C0A); draw.outline_rect(x,y,w,h,gold)
    draw.text('Temper Weapon',x+16,y+16,gold)
    draw.text('Inspect the treatment before starting 45 seconds of work.',x+16,y+52,text)
    local count=#finishes
    for i=1,count+2 do
        local label=i<=count and finishes[i].name or i==count+1 and 'Compare Current / Proposed' or 'Begin Tempering'
        if i<=count and i==(M.selected or 1) then label=label..'  [selected]' end
        local yy=y+100+(i-1)*35
        if M.row==i then draw.filled_rect(x+12,yy-3,w-24,30,0x60505050) end
        draw.text((M.row==i and '> ' or '  ')..label,x+16,yy,text)
    end
    local treatment=finishes[M.selected or 1]
    local info=y+100+(count+2)*35+10
    if treatment.item==197 then
        draw.text('+10% monster climb speed; +8% damage to that monster',x+16,info,dim)
        draw.text('While attached; lasts 30 minutes.',x+16,info+25,dim)
        info=info+25
    else draw.text(treatment.bonus..' for 30 minutes',x+16,info,dim) end
    draw.text('Cost: 1 '..treatment.ore..' / owned: '..tostring((M.ore_counts or {})[treatment.item] or '?'),x+16,info+29,dim)
    draw.text('Charged on completion; cancelling early is free.',x+16,info+58,dim)
    draw.text('Finish persists. Buff requires this main weapon.',x+16,info+87,dim)
    draw.text(M.flow_status or '',x+16,info+116,dim)
    if not M.native_prompts then
        draw.text('Arrows / D-pad: navigate    A / Enter: select',x+16,y+h-83,text)
        draw.text('B / Backspace: cancel',x+16,y+h-55,text)
    end
end
return M
