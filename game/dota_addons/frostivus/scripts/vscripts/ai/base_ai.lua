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
	return bit.band(tonumber(tostring(ability:GetBehavior())), behavior) == behavior
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
local function GetSpellToCast(unit, optStart)
	local min = optStart or 0
	local max = 5
	if min > max then return end

	print("searching for spell...")

	local behav
	local result
	local ab
	for i = min,max do
		local temp = unit:GetAbilityByIndex(i)
		if temp then
			ab = temp
			if ab:GetLevel() > 0 and ab:IsCooldownReady() and ab:GetManaCost(-1) <= unit:GetMana() then
				break
			end
		else
			ab = nil
		end
	end

	print("current spell: ", ab:GetName())

	if ab then
		if HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_PASSIVE) then
			return GetSpellToCast(unit, min+1)

		elseif HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
			behav = DOTA_ABILITY_BEHAVIOR_UNIT_TARGET

		elseif HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_POINT) then
			behav = DOTA_ABILITY_BEHAVIOR_POINT

		elseif HasBehavior(ab, DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
			behav = DOTA_ABILITY_BEHAVIOR_NO_TARGET
		end
	else
		behav = nil
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

BaseAi = {
	MakeInstance = function(self, unit, info)
		if not IsServer() or not unit or not info then return end
		if not self.initialized then self:Init() end
		local instance = {}
		setmetatable(instance, self)

		instance.unit = unit
		instance.state = info.state or IDLE

		local ar = unit:GetAcquisitionRange()
		local var = info.aggroRange or info.aggrorange
		instance.aggroRange = var or (ar ~= 0 and ar) or 1200
		instance.leash = info.leash or (ar ~= 0 and ar+250) or 1750
		instance.spawn = info.spawn or unit:GetAbsOrigin()
		instance.buffer = info.buffer or 500
		instance.idleTime = info.idleTime or 0
		instance.protect = info.protect or {}

		instance.id = DoUniqueString("instance")
		instance.nextThink = GameRules:GetGameTime()+0.5

		self.thinkers[instance.id] = instance

		print('created instance: '..instance.id)

		return instance
	end,

	Init = function(self)
		self.thinkers = {}

		local thinker = SpawnEntityFromTableSynchronous("info_target",{targetname="ai_thinker"})
		thinker:SetThink("Think", self)

		print("AI_INIT")
		self.initialized = true
	end,

	Think = function(self)
		local time = GameRules:GetGameTime()

		--iterate thru current ai thinkers
		for k,v in pairs(self.thinkers) do

			--check if its time to think
			if time >= v.nextThink then
				local success,tick

				self.thinkers[k] = nil

				--make sure unit is able to think right now
				if v.unit and v.unit:IsAlive() then
					--print("unit can think: "..v.unit:GetUnitName())
					if not v.unit:IsStunned() and not v.unit:IsHexed() then
						success,tick = xpcall(function()
							return Dynamic_Wrap(self, THINK_STATES[v.state])(v)
						end, function(err)
							return err..'\n'..debug.traceback()..'\n'
						end)
					end
				end

				if success then
					--set next think
					if tick then
						v.nextThink = v.nextThink + tick
						self.thinkers[k] = v
					end
				else
					--think has failed
					print("think failed", k, tick)
				end
			end
		end
		return 0.01
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
					self.state = AGGRESSIVE
					return RandomFloat(0.5, 3.0)
				end
			end
		end
		return RandomFloat(0.5, 3.0)
	end,

	AggresiveThink = function(self)
		print("aggro_think")

		--check if we have moved too far away from spawn
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() > self.leash then
			self.unit:MoveToPosition( self.spawn )
			self.aggroTarget = nil
			self.state = RETURNING
			return RandomFloat(0.5, 3.0)
		end

		--check if target is still alive
		if not self.aggroTarget:IsAlive() then
			self.unit:MoveToPosition( self.spawn )
			self.aggroTarget = nil
			self.state = RETURNING
			return RandomFloat(0.5, 3.0)
		end

		self.unit:MoveToTargetToAttack(self.aggroTarget)
		return RandomFloat(0.5, 3.0)
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
					return RandomFloat(0.5, 3.0)
				end
			end
		end

		--check if we have returned to spawn
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			self.state = IDLE
			return RandomFloat(0.5, 3.0)
		end
		return RandomFloat(0.5, 3.0)
	end,

	WanderIdleThink = function(self)
		print("wander_think")

		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, self.aggroRange,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		print("", "found "..tostring(#units).." enemy heroes")
		--check if state should change
		if #units > 0 then
			print("","", "enemy is in range!")
			if GetSpellToCast(self.unit) then
				print("","", "spell can be cast on enemy!")
				if self.protect == nil or self.protect == {} then
					self.protect = {self.unit}
				end
				self.waypoints = nil
				self.state = PROTECTIVE

				print("", "back to protective..")
				return RandomFloat(0.5, 3.0)
			end
		end

		--make some random waypoints
		self.waypoints = self.waypoints or {}

		print("", "we have "..#self.waypoints.." waypoints")

		while #self.waypoints < 3 do
			local wp = self.unit:GetAbsOrigin() + RandomVector(500)
			if GridNav:CanFindPath(self.unit:GetAbsOrigin(), wp) then
				if GridNav:FindPathLength(self.unit:GetAbsOrigin(), wp) < self.leash + self.buffer then
					table.insert(self.waypoints, wp)
					print("","", "making new waypoint["..tostring(#self.waypoints).."] at: Vector("..tostring(wp.x)..", "..tostring(wp.y)..", "..tostring(wp.z)..")")
				end
			end 
		end

		--check if waypoint reached
		if (self.waypoints[1] - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			print("","", "reached a waypoint! removing it..")
			table.remove(self.waypoints, 1)
		end

		print("", "moving to next waypoint")
		--move towards next waypoint 
		self.unit:MoveToPosition(self.waypoints[1])
		return RandomFloat(0.5, 3.0)
	end,

	ProtectiveThink = function(self)
		print("protective_think")

		--check if theres actually something to protect
		if self.protect and #self.protect <= 0 then
			print("", "nothing to protect", type(self.protect), self.protect)
			self.state = WANDER_IDLE
			return RandomFloat(0.5, 3.0)
		end

		--iterate thru areas/units to protect
		for i = 1,#self.protect do
			print("", "currently protecting:", self.protect[i])
			--grab a spell
			local ab,behav = GetSpellToCast(self.unit)
			if not ab then
				print("","", "nothing to cast, stop protecting for this think")
				break
			end
			--grab an instance of thing we are protecting
			local protect = self.protect[i]
			if type(protect) ~= "vector" then
				print("", "protecting a unit")
				--try to buff thing if its a unit
				if CanTargetUnit(ab, protect) then
					print("", "our unit can be buffed")
					if CastSpell(self.unit, protect, ab, behav) then
						print("", "SUCCEEDED in buffing ally")
					else
						print("", "FAILED in buffing ally")
					end
				end
				protect = protect:GetAbsOrigin()
			end

			--find and target any enemies near protect
			local units = FindUnitsInRadius(self.unit:GetTeam(), protect, nil, self.aggroRange,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

			print("", "found "..tostring(#units).." enemy heroes")
			for _,unit in pairs(units) do
				if CastSpell(self.unit, unit, ab, behav) then
					print("","", "SUCCEEDED in attacking enemy")
					break
				else
					print("","", "FAILED in attacking enemy")
				end
			end
		end

		print("", "back to wandering..")
		self.state = WANDER_IDLE
		return RandomFloat(0.5, 3.0)
	end,
}