-- Server-owned inventory and item state. Skin is visual metadata only.
local ItemService={}
ItemService.__index=ItemService
function ItemService.new(clock,config)
    return setmetatable({clock=clock, config=config, users={}},ItemService)
end
function ItemService:Register(id)
    if not self.users[id] then self.users[id]={owned=false,skin="Default",readyAt=0,serial=0,activation=nil} end
end
function ItemService:Grant(id,skin)
    local u=self.users[id]
    if not u then return false end
    u.owned=true
    u.skin=skin or "Default"
    return true
end
function ItemService:CanUse(id)
    local u=self.users[id]
    if not u or not u.owned then return false,"NOT_OWNED" end
    if self.clock()<u.readyAt then return false,"COOLDOWN" end
    return true,"READY"
end
function ItemService:Begin(id)
    local ok,reason=self:CanUse(id)
    if not ok then return nil,reason end
    local u=self.users[id]
    u.serial+=1
    local now=self.clock()
    u.activation={id=u.serial,startedAt=now,endsAt=now+self.config.window,resolved=false}
    u.readyAt=now+self.config.failureCooldown
    return u.serial,"ACTIVE"
end
function ItemService:GetActive(id)
    local u=self.users[id]
    local a=u and u.activation
    if not a or a.resolved or self.clock()>=a.endsAt then return nil end
    return a.id
end
function ItemService:Resolve(id,activationId,success)
    local u=self.users[id]
    local a=u and u.activation
    if not a or a.resolved or a.id~=activationId then return false end
    if success and self.clock()>=a.endsAt then return false end
    a.resolved=true
    if success then u.readyAt=self.clock()+self.config.successCooldown end
    return true
end
function ItemService:Interrupt(id)
    local u=self.users[id]
    if u and u.activation then u.activation.resolved=true end
end
function ItemService:GetRemaining(id)
    local u=self.users[id]
    return u and math.max(0,u.readyAt-self.clock()) or 0
end
function ItemService:Remove(id)
    self.users[id]=nil
end
return ItemService
