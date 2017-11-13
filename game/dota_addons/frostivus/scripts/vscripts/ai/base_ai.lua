IDLE = 0
AGGRESSIVE = 1
RETURNING = 2
WANDER_IDLE = 3
PROTECTIVE = 4
PATROL = 5
PATROL_AGGRO = 6
SENTRY = 7
BASIM = 8
CYCLONE = 9

THINK_STATES = {
	---------------------------------
	--these think states are unused--
	---------------------------------
	[IDLE] = "IdleThink",
	[AGGRESSIVE] = "AggresiveThink",
	[RETURNING] = "ReturningThink",
	-------------------------------------------
	--these think states are fully functional--
	-------------------------------------------
										 -- UNIQUE PARAMETERS
	[WANDER_IDLE] = "WanderIdleThink", 	 -- 

	[PROTECTIVE] = "ProtectiveThink",	 -- aggroTarget (unit)
										 -- protect (table); units or positions that the thinking unit will attempt to protect

	[PATROL] = "PatrolThink",			 -- patrolPoints (table); positions that the thinking unit will repeatedly traverse in table order

	[PATROL_AGGRO] = "PatrolAggroThink", -- aggroTarget (unit)
	[SENTRY] = "SentryThink",			 -- spawn (vector)

	[BASIM] = "BasimThink",
	[CYCLONE] = "CycloneThink",
}

local function HasBehavior(ability, behavior)
	return bit.band(tonumber(tostring(ability:GetBehavior())), behavior) == behavior
end

local function CanTargetUnit(ability, unit)
	local team = ability:GetAbilityTargetTeam()
	local caster = ability:GetCaster()
	if not unit.GetTeam then return false end

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
	--if HasBehavior(ability, DOTA_ABILITY_BEHAVIOR_NO_TARGET) then return true end
	return false
end

local function GetSpellToCast(unit, optStart)
	local min = optStart or 0
	local max = 5
	if min > max then return end

	print("","searching for spell...")

	local behav
	local ab
	for i = min,max do
		local temp = unit:GetAbilityByIndex(i)
		if temp then
			if temp:GetLevel() > 0 and temp:IsCooldownReady() and temp:GetManaCost(-1) <= unit:GetMana() then
				ab = temp
				break
			end
		else
			ab = nil
		end
	end

	if ab then
		print("","current spell: ", ab:GetName())
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
		instance.aggroRange = info.aggroRange or (ar ~= 0 and ar) or 1200
		instance.leash = info.leash or (ar ~= 0 and ar+250) or 1750
		instance.spawn = info.spawn or unit:GetAbsOrigin()
		instance.buffer = info.buffer or 500
		instance.protect = info.protect or {}

		instance.id = DoUniqueString("instance")
		instance.nextThink = GameRules:GetGameTime()+0.5
		instance.lastThink = GameRules:GetGameTime()

		--store everything else passed into MakeInstance
		for k,v in pairs(info) do
			--dont overwrite instance data
			if not instance[k] then
				instance[k] = v
			end
		end

		--if unit already has an instance then overwrite the old one per request
		if unit.instance then
			if info.override then
				self.thinkers[unit.instance.id] = nil
			end
		end

		self.thinkers[instance.id] = instance

		print('created instance: '..instance.id)

		--fix for tiny toss
		if unit:GetUnitName() == "tiny_the_tosser" then
			local ab = unit:FindAbilityByName("tiny_toss")
			if ab then
				if unit:HasModifier("modifier_tiny_toss_charge_counter") then
					unit:RemoveModifierByName("modifier_tiny_toss_charge_counter")
				else
					unit:AddNewModifier(unit, ab, "modifier_tiny_toss_charge_counter", {})
				end
			end
		end

		return instance
	end,

	Init = function(self)
		self.thinkers = {}
		self.initialized = true

		local thinker = SpawnEntityFromTableSynchronous("info_target",{targetname="ai_thinker"})
		thinker:SetThink("Think", self)

		print("AI_INIT")
	end,

	Think = function(self)
		if not self.initialized then return end

		--iterate thru current ai thinkers
		for id,instance in pairs(self.thinkers) do
			--check if its time to think
			local time = GameRules:GetGameTime()
			if time >= instance.nextThink then
				--make sure unit is able to think right now

				local success,int
				if instance.unit and not instance.unit:IsNull() then
					--print("unit can think: "..instance.unit:GetUnitName())

					success,int = xpcall(function()
						return Dynamic_Wrap(self, THINK_STATES[instance.state])(instance)
					end, function(err)
						return err.."\n"..debug.traceback().."\n"
					end)
				else
					print("null unit is trying to think.. kill thinker", id)
					self.thinkers[id] = nil
				end

				--set next think
				if success then
					--print("think succeeded", id)
					local nextThink = RandomFloat(1.0, 3.0)
					if int then nextThink = int end
					if self.thinkers[id] then
						self.thinkers[id].lastThink = time
						self.thinkers[id].nextThink = time + nextThink
					end
				else
					--think has failed
					print("think failed.. kill thinker", id)
					print(int)
					self.thinkers[id] = nil
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
					return
				end
			end
		end
		return
	end,

	AggresiveThink = function(self)
		print("aggro_think")

		--check if we have moved too far away from spawn
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() > self.leash then
			self.unit:MoveToPosition( self.spawn )
			self.aggroTarget = nil
			self.state = RETURNING
			return
		end

		--check if target is still alive
		if not self.aggroTarget:IsAlive() then
			self.unit:MoveToPosition( self.spawn )
			self.aggroTarget = nil
			self.state = RETURNING
			return
		end

		self.unit:MoveToTargetToAttack(self.aggroTarget)
		return
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
					return
				end
			end
		end

		--check if we have returned to spawn
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			self.state = IDLE
			return
		end
		return
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
				self.protect = {self.unit}
				self.state = PROTECTIVE

				print("", "back to protective..")
				return
			end
		end

		--send them back to spawn if they go too far away
		if (self.spawn - self.unit:GetAbsOrigin()):Length2D() > self.leash+self.buffer then
			self.unit:MoveToPosition(self.spawn)
			return 3.0
		end

		--make some random waypoints
		self.waypoints = self.waypoints or {}
		self.wpTimes = self.wpTimes or {}

		print("", "we have "..tostring(#self.waypoints).." waypoints")

		local attempts = 0
		while #self.waypoints < 3 do
			attempts = attempts+1
			print("", "generating waypoints for "..self.unit:GetUnitName().."...")
			local wp = self.unit:GetAbsOrigin() + RandomVector(500)
			if GridNav:CanFindPath(self.unit:GetAbsOrigin(), wp) or attempts > 2 then
				if GridNav:FindPathLength(self.unit:GetAbsOrigin(), wp) < self.leash + self.buffer or attempts > 2 then
					table.insert(self.waypoints, wp)
					self.wpTimes[wp] = self.lastThink
					print("","", "making new waypoint["..tostring(#self.waypoints).."] at: Vector("..tostring(math.ceil(wp.x))..", "..tostring(math.ceil(wp.y))..", "..tostring(math.ceil(wp.z))..") after "..tostring(attempts).." attempts")
					attempts = 0
				end
			end 
		end

		--check if waypoint reached
		if (self.waypoints[1] - self.unit:GetAbsOrigin()):Length2D() <= 10 or GameRules:GetGameTime()-10 > self.wpTimes[self.waypoints[1]] then
			print("","", "reached a waypoint! removing it..")
			table.remove(self.waypoints, 1)
		end

		print("", "moving to next waypoint")
		--move towards next waypoint 
		self.unit:MoveToPosition(self.waypoints[1])
		return
	end,

	ProtectiveThink = function(self)
		print("protective_think")

		--check if theres actually something to protect
		if not self.protect or #self.protect <= 0 then
			print("", "nothing to protect", self.protect)
			self.state = WANDER_IDLE
			return
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

			if ab:GetName() == "tiny_toss" then
				local range = ab:GetSpecialValueFor("grab_radius")
				if (self.unit:GetAbsOrigin() - unit:GetAbsOrigin()):Length2D() > range then
					self.unit:MoveToNPC(unit)
					return 1.0
				end
			end
		end

		print("", "back to wandering..")
		self.state = WANDER_IDLE
		return
	end,

	--take preset waypoints and patrol between them
	PatrolThink = function(self)
		print("patrol_think")
		if not self.patrolPoints or #self.patrolPoints < 2 then
			print("", ((self.patrolPoints ~= nil and "we only have "..tostring(#self.patrolPoints)) or "no") .. " points to patrol.. killing thinker")
			BaseAi.thinkers[self.id] = nil
			return
		end
		print("", "we have "..tostring(#self.patrolPoints).." patrol points to traverse")

		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, self.aggroRange,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		if #units>0 then
			self.lastPos = self.unit:GetAbsOrigin()
			self.aggroTarget = units[1]
			self.state = PATROL_AGGRO
			return
		end

		local toPatrol = self.lastPos or self.patrolPoints[1]
		--check if waypoint reached
		if (toPatrol - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			print("","", "reached a patrol point!")
			self.lastPos = nil
			--cycle patrol points
			table.insert(self.patrolPoints, table.remove(self.patrolPoints, 1))
		end
		print("", "moving to patrol point... Vector("..tostring(math.ceil(self.patrolPoints[1].x))..", "..tostring(math.ceil(self.patrolPoints[1].y))..", "..tostring(math.ceil(self.patrolPoints[1].z))..")" )
		--move towards next patrol point 
		self.unit:MoveToPosition(self.patrolPoints[1])
	end,

	PatrolAggroThink = function(self)
		print("patrol_aggro")
		--check if we have moved too far away from patrol point
		if (self.lastPos - self.unit:GetAbsOrigin()):Length2D() > self.leash then
			print("", "too far from waypoints, return to patrol")
			self.unit:MoveToPosition( self.lastPos )
			self.aggroTarget = nil
			self.state = PATROL
			return
		end

		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, self.aggroRange,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		--if current enemy is still in range
		if (self.unit:GetAbsOrigin() - self.aggroTarget:GetAbsOrigin()):Length2D() < self.aggroRange then
			print("", "enemy still in range")
			--cast on enemy
			local ab,behav = GetSpellToCast(self.unit)
			if ab then
				print("", "valid ability found, casting..")
				if CastSpell(self.unit, self.aggroTarget, ab, behav) then
					print("","", "cast on target success")
					return
				else
					print("","", "cast on target failed")
				end
			else
				print("", "no valid ability to cast")
			end
		else
			print("", "target is out of range..")
			--find new target
			if #units > 0 then
				print("","", "found a new target, continue think")
				self.aggroTarget = units[1]
				return
			end
			print("","", "no targets in range")
		end

		print("", "returning to patrol...")
		self.aggroTarget = nil
		self.state = PATROL
		return
	end,

	SentryThink = function(self)
		print("sentry_think")
		local ab,behav = GetSpellToCast(self.unit)
		if not ab then print("", "no valid ability to cast") return end

		if self.unit:GetUnitName() == "tiny_the_tosser" then
			ab = FindAbilityByName("tiny_toss")
			behav = DOTA_ABILITY_BEHAVIOR_UNIT_TARGET

			local vec = Vector(-500,0,1024)

			self.unit.tinyTarget = self.unit.tinyTarget or CreateUnitByNameAsync("npc_dota_base", vec, false, nil, nil, 0, function(dummy)
				print("making tiny dummy")
				dummy:AddNewModifier(nil, nil, "modifier_dummy", {})
			end)
			print("tiny casting on dummy")
			self.unit:CastAbilityOnTarget(self.unit.tinyTarget, ab, self.unit:GetPlayerOwnerID())
			ab:EndCooldown()
			return 0.1
		end

		local range = ab:GetCastRange() or self.aggroRange
		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, range,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

		print("", "ability cast range: "..tostring(range))
		if #units>0 then
			if CastSpell(self.unit, units[1], ab, behav) then
				print("","cast success")
				return
			else
				print("","cast fail")
			end
		end

		print("","no units to act on")
		self.unit:MoveToPosition(self.spawn)
		return
	end,

	--this needs work
	BasimThink = function(self)
		local units = FindUnitsInRadius(self.unit:GetTeam(), self.unit:GetAbsOrigin(), nil, 800, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		self.lastSnowball = self.lastSnowball or GameRules:GetGameTime()
		if self.lastSnowball+10 < GameRules:GetGameTime() then
			if units then
				if not self.snowballing then
					self.unit:FaceTowards(units[1]:GetAbsOrigin())
					self.unit:StartGesture(ACT_DOTA_IDLE_RARE)
					self.snowballing = 0
				end
			end
		else
			if not self.snowballing then
				self.unit:StartGesture(ACT_DOTA_IDLE)
			end
		end

		local int = RandomFloat(1.5, 2.5)
		if self.snowballing and self.snowballing >= 5 then self.snowballing = nil end 
		if self.snowballing then self.snowballing = self.snowballing + int end
		return int
	end,

	CycloneThink = function(self)
		print("cyclone_think")
		self.waypoints = self.waypoints or {}
		while #self.waypoints < 5 do 
			print("", "generating waypoints...")
			self.waypoints[#waypoints+1] = self.unit:GetAbsOrigin()+RandomVector(700)
		end

		if (self.waypoints[1] - self.unit:GetAbsOrigin()):Length2D() <= 10 then
			print("","", "reached a waypoint!")
			--cycle way points
			table.insert(self.waypoints, table.remove(self.waypoints, 1))
		end
		print("", "moving to waypoint... Vector("..tostring(math.ceil(self.waypoints[1].x))..", "..tostring(math.ceil(self.waypoints[1].y))..", "..tostring(math.ceil(self.waypoints[1].z))..")" )
		--move towards next patrol point 
		self.unit:MoveToPosition(self.waypoints[1])
	end,

}