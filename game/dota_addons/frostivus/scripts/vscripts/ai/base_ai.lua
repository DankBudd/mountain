IDLE = 0
AGGRESSIVE = 1
RETURNING = 2
WANDER_IDLE = 3
PROTECTIVE = 4

THINK_STATES = {
	[IDLE] = "IdleThink",
	[AGGRESSIVE] = "AggresiveThink",
	[RETURNING] = "ReturningThink",
	[WANDER_IDLE] = "WanderIdleThink",
	[PROTECTIVE] = "ProtectiveThink",
}

local function HasBehavior(ability, behavior)
	return bit.band(ability:GetBehavior(), behavior) == behavior
end

--might need to improve this further
local function CanTargetUnit(ability, unit)
	local team = ability:GetAbilityTargetTeam()
	local caster = ability:GetCaster()
	if not unit.GetTeam then return false end

	local NT_behav = HasBehavior(ability, DOTA_ABILITY_BEHAVIOR_NO_TARGET)
	local UT_behav = HasBehavior(ability, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
	local PT_behav = HasBehavior(ability, DOTA_ABILITY_BEHAVIOR_POINT)

	if team == DOTA_UNIT_TARGET_TEAM_FRIENDLY then
		if caster:GetTeam() == unit:GetTeam() then
			return true
		end
	end
	if team == DOTA_UNIT_TARGET_TEAM_ENEMY then
		if caster:GetTeam() ~= unit:GetTeam() then
			return true
		end
	end
	if team == DOTA_UNIT_TARGET_TEAM_BOTH then return true end
	if NT_behav then return true end
	return false
end

--need to improve spell casting ai
--	make this return nil if MAX(5) spells have been cycled and none are castable
local function GetSpellToCast(unit, optStart)
	local min = optStart or 0
	local max = 5
	if min > max then return end

	local behav
	local result
	local ab
	for i = min,max do
		local temp = unit:GetAbilityByIndex(i)
		if temp then
			ab = temp
			if ab:IsCooldownReady() and ab:GetManaCost(-1) <= unit:GetMana() then
				break
			end
		end
	end

	if ab then
		if HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_PASSIVE) then
			ab,behav = GetSpellToCast(unit, min+1)

		elseif HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
			behav = DOTA_ABILITY_BEHAVIOR_UNIT_TARGET

		elseif HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_POINT) then
			behav = DOTA_ABILITY_BEHAVIOR_POINT

		elseif HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
			behav = DOTA_ABILITY_BEHAVIOR_NO_TARGET
		end
	end

	return ab,behav
end

local function CastSpell(unit, target, ability, behavior)
	if unit:IsChanneling() then return end

	if not CanTargetUnit(ability, target) then
		return false
	end

	if behavior == DOTA_ABILITY_BEHAVIOR_UNIT_TARGET then
		if type(target) == "vector" then
			target = FindUnitsInRadius(unit:GetAbsOrigin(), target, nil, 250,
			 DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_TYPE_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)[1]
		end
		if not target then return false end
		unit:CastAbilityOnTarget(target, ability, unit:GetPlayerOwnerID())
		return true
	end
	if behavior == DOTA_ABILITY_BEHAVIOR_POINT then
		if type(target) ~= "vector" then
			target = target:GetAbsOrigin()
		end
		unit:CastAbilityOnPosition(target, ability, unit:GetPlayerOwnerID())
		return true
	end
	if behavior == DOTA_ABILITY_BEHAVIOR_NO_TARGET then
		unit:CastAbilityNoTarget(ability, unit:GetPlayerOwnerID())
		return true
	end
	return false
end

BaseAi = class({
	MakeInstance = function(self, unit, info)
		if not IsServer() or not unit then return end
		print("making_instance")
		local instance = {}
		setmetatable(instance, self)

		instance.unit = unit
		instance.state = info.state or IDLE

		local ar = unit:GetAcquisitionRange()
		instance.aggroRange = info.aggroRange or (ar ~= 0 and ar) or 1200
		instance.leash = info.leash or (ar ~= 0 and ar+250) or 1750
		instance.spawn = info.spawn or unit:GetAbsOrigin()
		instance.buffer = info.buffer or 500
		instance.idleTime = info.idleTime or 0
		instance.protect = info.protect or {}

		unit:SetContextThink(DoUniqueString("aiThinker"), function()
			if not instance.unit then print("no unit to think") return end
			if not instance.unit:IsAlive() then print(instance.unit:GetUnitName().." has died. kill thinker") return end
			--print(instance.unit:GetUnitName().." is thinking...")
			if instance.unit:IsStunned() or instance.unit:IsHexed() or GameRules:IsGamePaused() then
				return 0.5
			end

			--think on state with info instance
			Dynamic_Wrap(self, THINK_STATES[instance.state])(instance)
			return 0.5
		end, 0.5)

		return instance
	end,

	IdleThink = function(self)
		print("idle_think")
		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, self.aggroRange,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		--check if entity is within aggro range (need to change attack behavior to spell casts)
		if #units > 0 then
			if GridNav:CanFindPath(self.unit:GetAbsOrigin(), units[1]:GetAbsOrigin()) then
				if GridNav:FindPathLength(self.unit:GetAbsOrigin(), units[1]:GetAbsOrigin()) < self.leash + self.buffer then
					self.unit:MoveToTargetToAttack( units[1] )
					self.aggroTarget = units[1]
					self.idleTime = 0
					self.state = AGGRESSIVE
					return true
				end
			end
		end

		--this needs to be improved
		self.idleTime = self.idleTime + 0.5
		if self.idleTime >= 3 + (0.5*RandomInt(0,6)) then
			--insert taunt here
			print("taunt")
			self.idleTime = 0
		end


		print("idleTime: "..tostring(self.idleTime))
	end,

	AggresiveThink = function(self)
		print("aggro_think")
		--check if we have moved too far away from spawn
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() > self.leash then
			self.unit:MoveToPosition( self.spawn )
			self.state = RETURNING
			return true
		end

		--check if target is still alive
		if not self.aggroTarget:IsAlive() then
			self.unit:MoveToPosition( self.spawn )
			self.state = RETURNING
			return true
		end

		self.unit:MoveToTargetToAttack(self.aggroTarget)
	end,

	ReturningThink = function(self)
		print("return_think")
		local range = self.aggroRange * 0.5
		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, range,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		--check for more nearby enemies
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

		--check if we have returned to spawn
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			self.aggroTarget = nil
			self.state = IDLE
			return true
		end
	end,

	WanderIdleThink = function(self)
		print("wander_think")
		--make some random waypoints
		self.waypoints = self.waypoints or {}
		while #self.waypoints < 3 do
			local wp = self.unit:GetAbsOrigin() + RandomVector(500)
			if GridNav:CanFindPath(self.unit:GetAbsOrigin(), wp) then
				if GridNav:FindPathLength(self.unit:GetAbsOrigin(), wp) < self.leash + self.buffer then
					table.insert(self.waypoints, wp)
				end
			end 
		end

		--check if waypoint reached
		if (self.waypoints[1] - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			table.remove(self.waypoints, 1)
		end

		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, self.aggroRange,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		--TODO: improve logic between wander and protective
		--check if state should change
		if #units > 0 then
			--if has any castable spells
				--if can attack
					self.state = PROTECTIVE
					self.protect = (self.protect ~= {} and self.protect) or {self.unit}
					return true
				--end
			--end
		end

		--move towards next waypoint 
		self.unit:MoveToPosition(self.waypoints[1])
	end,

	ProtectiveThink = function(self)
		print("protective_think")
		--check if theres actually something to protect
		if #self.protect <= 0 then
			self.state = WANDER_IDLE
			return true
		end

		--iterate thru areas/units to protect
		for i = 1,#self.protect do
			--grab a spell
			local ab,behav = GetSpellToCast(self.unit)
			--grab an instance of thing we are protecting
			local protect = self.protect[i]
			if type(protect) ~= "vector" then
				--try to buff thing if its a unit
				if CanTargetUnit(ab, protect) then
					CastSpell(self.unit, protect, ab, behav)
				end
				protect = protect:GetAbsOrigin()
			end

			--find and target any enemies near protect
			local units = FindUnitsInRadius(self.unit:GetTeam(), protect, nil, self.aggroRange,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

			for _,unit in pairs(units) do
				CastSpell(self.unit, unit, ab, behav)
				return true
			end

			self.state = WANDER_IDLE
			return true
		end
	end,
})