local D={alive=true}
local B='System.Boolean'
local types={'System.String','System.String','System.String','System.String','System.String',B,'System.Int32',B,
 'System.UInt32','System.Int32','System.Int32','via.render.TextureResourceHolder',B,B,B,B,B,'System.Single',B,B}
local methods,requesting={},false
local function resolve(name,params,result)
 local found
 for _,m in ipairs(assert(sdk.find_type_definition('app.GuiManager')):get_methods()) do
  local p=m:get_param_types() or {}; local same=#p==#params
  for i,v in ipairs(params) do if not p[i] or p[i]:get_full_name()~=v then same=false end end
  if m:get_name()==name and same then assert(not found,'Ambiguous dialogue method'); found=m end
 end
 assert(found and not found:is_static() and found:get_return_type():get_full_name()==result,'Dialogue signature unavailable: '..name)
 return found
end
local function install()
 if D.installed then return end
 methods.open=resolve('requestDialog',types,'System.Void')
 methods.visible=resolve('IsDispDialogGui',{},B)
 methods.result=resolve('getDialogState',{},'app.ui010101.RetVal')
 methods.hide=resolve('requestHideDialog',{},'System.Void')
 local guid={}; for i,v in ipairs(types) do guid[i]=i<=5 and 'System.Guid' or v end
 local other=resolve('requestDialog',guid,'System.Void')
 local enum=assert(sdk.find_type_definition('app.ui010101.RetVal'))
 for name,value in pairs({None=0,Sel0=1,Sel1=2,Cancel=5}) do
  local f=assert(enum:get_field(name)); assert(f:is_static() and tonumber(f:get_data(nil))==value,'Dialogue enum changed')
 end
 D.installed=true
 for _,m in ipairs({methods.open,other}) do
  sdk.hook(m,function()
   if D.alive and D.job and not requesting then
    local j=D.job
    if j.completion then D.notice={token=j.token,text=j.text,owner=j.completion}
    else D.error='Another dialogue took priority. Please try again.' end
    D.job=nil; D.releasing=nil
   end
  end,function(retval) return retval end)
 end
end
function D.owns(token)
 local j=D.job
 return token~=nil and ((j~=nil and j.token==token and j.phase~='queued')
  or (D.releasing~=nil and D.releasing.token==token and os.clock()<D.releasing.until_at)) or false
end
function D.queue(token,text,confirm,completion)
 if D.job then return false end
 local ok,err=pcall(install)
 if not ok then D.error=tostring(err); return false end
 D.error=nil; D.error_completion=nil; D.answer=nil
 D.job={token=token,text=text,confirm=confirm,completion=completion,phase='queued',deadline=os.clock()+15}
 return true
end
function D.notify(token,text)
 local ok,owner=pcall(function()
  return tostring(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'):get_address())
 end)
 if not ok then D.error='Completion notice unavailable: '..tostring(owner); D.error_completion=true; return false end
 D.notice={token=token,text=text,owner=owner}
 pcall(json.dump_file,'ImmersiveInteractables_TemperCompletion32.json',{stage='notice pending',text=text,token=token})
 return true
end
function D.tick(observe)
 if D.alive and not observe and not D.job and D.notice then
  local n=D.notice
  if D.queue(n.token,n.text,false,n.owner) then D.notice=nil
  else D.error_completion=true; D.notice=nil end
 end
 if not D.alive or not D.job then return end
 local j=D.job
 local ok,err=pcall(function()
  local gm=assert(sdk.get_managed_singleton('app.GuiManager'))
  if j.phase=='queued' then
   if observe then return end
   if j.completion then
    local owner=tostring(sdk.get_managed_singleton('app.CharacterManager'):call('get_ManualPlayer'):get_address())
    if owner~=j.completion then D.job=nil; return end
   else
    if rawget(_G,'Interactables_session_token')~=j.token then D.job=nil; return end
    if os.clock()>j.deadline then error('Dialogue queue expired') end
   end
   if methods.visible:call(gm) or gm:call('isPausedGUI') or reframework:is_drawing_ui() then return end
   j.phase='opening'; j.deadline=os.clock()+10
   requesting=true
   local opened,why=pcall(function() methods.open:call(gm,j.text,j.confirm and 'Confirm' or 'OK',j.confirm and 'Cancel' or '',
    '','',false,0,false,40,0,-1,nil,true,false,false,false,true,-1.0,false,false) end)
   requesting=false; assert(opened,why)
   if j.completion then pcall(json.dump_file,'ImmersiveInteractables_TemperCompletion32.json',{stage='notice requested',text=j.text,token=j.token}) end
   return
  end
  local visible=methods.visible:call(gm)
  if visible then
   j.seen=true
   local value=tonumber(methods.result:call(gm))
   if value==0 then j.none=true end
   if j.none and (value==1 or value==2 or value==5) and not j.closing then
    j.choice=value; j.closing=true
   end
   if j.closing and not j.hide_requested and not observe then
    j.hide_requested=true; methods.hide:call(gm)
   end
  elseif j.seen then
   local value=tonumber(methods.result:call(gm))
   if j.none and (value==1 or value==2 or value==5) then j.choice=j.choice or value end
   D.answer={token=j.token,confirmed=j.confirm and j.choice==1}
   D.releasing={token=j.token,until_at=os.clock()+1}
   pcall(function() json.dump_file('ImmersiveInteractables_TemperDialog32.json',
    {token=j.token,choice=j.choice,confirmed=D.answer.confirmed}) end)
   D.job=nil
   if j.completion then pcall(json.dump_file,'ImmersiveInteractables_TemperCompletion32.json',{stage='notice acknowledged',text=j.text,token=j.token}) end
  elseif os.clock()>j.deadline then error('Native dialogue did not appear') end
 end)
 if not ok then requesting=false; D.error=tostring(err); D.error_completion=j.completion~=nil; D.job=nil end
end
re.on_pre_application_entry('UpdateBehavior',function() D.tick(false) end)
re.on_frame(function() D.tick(true) end)
re.on_script_reset(function() D.alive=false; D.job=nil end)
return D
