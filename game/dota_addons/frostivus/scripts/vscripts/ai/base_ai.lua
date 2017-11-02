IDLE = 0
AGGRESSIVE = 1
RETURNING = 2
WANDER_IDLE = 3

THINK_STATES = {
	[IDLE] = "IdleThink",
	[AGGRESSIVE] = "AggresiveThink",
	[RETURNING] = "ReturningThink",
	[WANDER_IDLE] = "WanderIdleThink"
}

BaseAi = class({
	MakeInstance = function(self, unit, info)
		if not IsServer() then return end
		local instance = {}
		setmetatable(instance, self)

		instance.unit = unit
		instance.state = IDLE

		local ar = unit:GetAcquisitionRange()
		instance.aggroRange = info.aggroRange or (ar ~= 0 and ar) or 1200
		instance.leash = info.leash or (ar ~= 0 and ar+250) or 1750
		instance.spawn = info.spawn or unit:GetAbsOrigin()
		instance.buffer = info.buffer or 500

		unit:SetContextThink(DoUniqueString("aiThinker"), Dynamic_Wrap(self, "GlobalThink"), 0.5)
		return instance
	end,

	GlobalThink = function(self)
		if not self.unit then return end
		if not self.unit:IsAlive() then return end

		Dynamic_Wrap(self, THINK_STATES[self.state])(self)

		return 0.5
	end,

	IdleThink = function(self)
		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, self.aggroRange,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		if #units > 0 then
			if GridNav:CanFindPath(self.unit:GetAbsOrigin(), units[1]:GetAbsOrigin()) then
				if GridNav:FindPathLength(self.unit:GetAbsOrigin(), units[1]:GetAbsOrigin()) < self.leash + self.buffer then
					self.unit:MoveToTargetToAttack( units[1] )
					self.aggroTarget = units[1]
					self.state = AGGRESSIVE
					return true
				end
			end
		end

	end,

	AggresiveThink = function(self)	
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() > self.leash then
			self.unit:MoveToPosition( self.spawn )
			self.state = RETURNING
			return true
		end

		if not self.aggroTarget:IsAlive() then
			self.unit:MoveToPosition( self.spawn )
			self.state = RETURNING
			return true
		end
	end,

	ReturningThink = function(self)
		local range = self.aggroRange * 0.5
		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, range,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		if #units > 0 then
			if GridNav:CanFindPath(self.unit:GetAbsOrigin(), units[1]:GetAbsOrigin()) then
				if GridNav:FindPathLength(self.unit:GetAbsOrigin(), units[1]:GetAbsOrigin()) < self.leash + self.buffer then
					self.unit:MoveToTargetToAttack( units[1] )
					self.aggroTarget = units[1]
					self.state = AGGRESSIVE
					return true
				end
			end
		end

		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			self.aggroTarget = nil
			self.state = AI_STATE_IDLE
			return true
		end
	end,
})

BaseAi._index = BaseAi
return BaseAi