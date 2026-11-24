-- Standalone Roblox Studio training project; original implementation.
local FSM = {}
FSM.__index = FSM
local transitions = {
    Idle = {Parrying=true,Vaulting=true,Repairing=true,Unhooking=true,Stunned=true,Grabbed=true,Downed=true},
    Parrying = {Idle=true,Grabbed=true,Downed=true},
    Vaulting = {Idle=true,Grabbed=true,Downed=true},
    Repairing = {Idle=true,Grabbed=true,Downed=true,Stunned=true},
    Unhooking = {Idle=true,Grabbed=true,Downed=true,Stunned=true},
    Stunned = {Idle=true,Downed=true},
    Grabbed = {Idle=true,Downed=true},
    Downed = {Idle=true,Grabbed=true},
}
function FSM.new(clock)
    return setmetatable({clock=clock, state="Idle", deadline=nil, destroyed=false, token=0}, FSM)
end
function FSM:Update()
    if not self.destroyed and self.deadline and self.clock() >= self.deadline then
        self.deadline=nil
        self.state="Idle"
        self.token+=1
    end
    return self.state
end
function FSM:GetState()
    return self:Update()
end
function FSM:SetState(nextState,duration)
    self:Update()
    if self.destroyed or not transitions[self.state][nextState] then return false end
    if duration~=nil and (type(duration)~="number" or duration~=duration or duration<=0 or duration==math.huge) then return false end
    self.state=nextState
    self.token+=1
    self.deadline=duration and (self.clock()+duration) or nil
    return true
end
function FSM:Destroy()
    self.destroyed=true
    self.deadline=nil
    self.token+=1
end
return FSM
