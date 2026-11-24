-- Synthetic NPC interactions only. No public game hooks, input injection or remotes.
local FSM=require(script.Parent.CharacterStateMachine)
local Items=require(script.Parent.ItemCooldownService)
local Resolver={}
Resolver.__index=Resolver
function Resolver.new(clock,config)
    config=config or {window=.8,successCooldown=90,failureCooldown=60,stun=4}
    for _,key in ipairs({"window","successCooldown","failureCooldown","stun"}) do
        local n=config[key]
        assert(type(n)=="number" and n==n and n>0 and n<math.huge,"Invalid "..key)
    end
    assert(config.successCooldown>=config.window and config.failureCooldown>=config.window,"Cooldown shorter than window")
    config=table.clone(config)
    return setmetatable({clock=clock,config=config,items=Items.new(clock,config),actors={},attacks={}},Resolver)
end
function Resolver:Register(id,skin)
    if self.actors[id] then self:Respawn(id) else self.actors[id]=FSM.new(self.clock) end
    self.items:Register(id)
    if skin then self.items:Grant(id,skin) end
    self.attacks[id]={}
end
function Resolver:Respawn(id)
    if not self.actors[id] then return false end
    self.actors[id]:Destroy()
    self.actors[id]=FSM.new(self.clock)
    self.items:Interrupt(id)
    self.attacks[id]={}
    return true
end
function Resolver:Remove(id)
    if self.actors[id] then self.actors[id]:Destroy() end
    self.actors[id]=nil
    self.attacks[id]=nil
    self.items:Remove(id)
end
function Resolver:SetAction(id,state,duration)
    local actor=self.actors[id]
    if not actor or state=="Parrying" then return false end
    local wasParrying=actor:GetState()=="Parrying"
    local ok=actor:SetState(state,duration)
    if ok and wasParrying then self.items:Interrupt(id) end
    return ok
end
function Resolver:RequestParry(id)
    local actor=self.actors[id]
    if not actor or actor:GetState()~="Idle" then return false,"ACTION_LOCK" end
    local ok,reason=self.items:CanUse(id)
    if not ok then return false,reason end
    local activation=self.items:Begin(id)
    if not activation then return false,"NOT_READY" end
    if not actor:SetState("Parrying",self.config.window) then
        self.items:Interrupt(id)
        return false,"ACTION_LOCK"
    end
    return true,"ACTIVE"
end
function Resolver:ResolveSyntheticContact(targetId,attackId,kind,contact)
    local actor=self.actors[targetId]
    if not actor then return "NO_ACTOR" end
    if type(attackId)~="number" or attackId%1~=0 or attackId<1 then return "INVALID_ATTACK" end
    if kind~="Basic" and kind~="Lunge" and kind~="Grab" and kind~="Projectile" and kind~="Special" then return "INVALID_KIND" end
    -- Monotonically increasing NPC event sequence; a duplicate cannot resolve twice.
    local history=self.attacks[targetId]
    if history.last and attackId<=history.last then return "DUPLICATE" end
    history.last=attackId
    if not contact then return "NO_CONTACT" end
    local state=actor:GetState()
    local activation=self.items:GetActive(targetId)
    if (kind=="Basic" or kind=="Lunge") and state=="Parrying" and activation then
        if self.items:Resolve(targetId,activation,true) then
            actor:SetState("Idle")
            return "PARRY_SUCCESS",self.config.stun
        end
    end
    if kind=="Grab" then
        self:SetAction(targetId,"Grabbed")
        return "BYPASS_GRAB"
    end
    if state=="Parrying" then self:SetAction(targetId,"Idle") end
    return "HIT"
end
return Resolver
