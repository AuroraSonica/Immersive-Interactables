local R={status="Disabled: native prefab preparation returned an invalid managed object",state="blocked"}
function R.request() return false end
function R.tick() end
return R
