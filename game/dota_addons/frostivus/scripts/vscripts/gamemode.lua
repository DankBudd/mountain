
if GameMode == nil then
	GameMode = class({})
end

--require stuff
require('ai/base_ai')
require('thinkers')
require('modifiers/global_modifiers')
require('bridgegrid')
require('constants')

--link global modifiers
--LinkLuaModifier(className,fileName,LuaModifierType)

function GameMode:InitGameMode()
	GameMode = self
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	 -- Setup Rules
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( false )

	GameRules:SetHeroSelectionTime( 30 )
	GameRules:SetStrategyTime( 1 )
	GameRules:SetShowcaseTime( 0 )
	GameRules:SetPreGameTime( 25 )
	GameRules:SetPostGameTime( 30 )

	GameRules:SetTreeRegrowTime( 60 )
	GameRules:SetRuneSpawnTime( 30 )

	GameRules:SetGoldPerTick( 0 )
	GameRules:SetGoldTickTime( 0 )
	GameRules:SetStartingGold( 0 )

	GameRules:SetUseBaseGoldBountyOnHeroes( true )
	GameRules:SetUseCustomHeroXPValues( false )

	GameRules:SetFirstBloodActive( false )
	GameRules:SetHideKillMessageHeaders( true )

	GameRules:SetCustomGameEndDelay( 5 )
	GameRules:SetCustomVictoryMessageDuration( 20 )

	--GameRules:SetCustomGameSetupAutoLaunchDelay( 0 )
	--GameRules:LockCustomGameSetupTeamAssignment( false )
	--GameRules:EnableCustomGameSetupAutoLaunch( true )

	local teams = {
		[DOTA_TEAM_GOODGUYS] = 2,
		[DOTA_TEAM_BADGUYS] = 2,
		[DOTA_TEAM_CUSTOM_1] = 2,
		[DOTA_TEAM_CUSTOM_2] = 2,
		[DOTA_TEAM_CUSTOM_3] = 2,
	}

	for k,v in pairs(teams) do
		GameRules:SetCustomGameTeamMaxPlayers(k, v)
	end

	GameMode.GetActivePlayersID = function(self)
		local p = {}
		local ids = self:GetAllPlayersID()
		for k,v in pairs(players) do
			if PlayerResource:IsValidPlayer(v) and (PlayerResource:GetConnectionState(v) == DOTA_CONNECTION_STATE_NOT_YET_CONNECTED or PlayerResource:GetConnectionState(v) == DOTA_CONNECTION_STATE_CONNECTED) then
				table.insert(p, v)
			end
		end
		return p
	end

	GameMode.GetAllPlayersID = function(self)
		if not self.AllPlayersID then
			local p = {}
			for t=DOTA_TEAM_FIRST,DOTA_TEAM_COUNT do 
				for i=1,DOTA_MAX_PLAYERS do
					local pid = PlayerResource:GetNthPlayerIDOnTeam(t,i)
					if PlayerResource:IsValidPlayerID(pid) then
						table.insert(p, pid)
					end
				end
			end
			self.AllPlayersID = p
		end
		return self.AllPlayersID
	end

	GameMode.GetAllPlayers = function(self)
		local p = {}
		local ids = self:GetAllPlayersID()
		for k,v in pairs(ids) do
			if PlayerResource:IsValidPlayer(v) then
				local player = PlayerResource:GetPlayer(v)
				if player then
					table.insert(p, player)
				end
			end
		end
		return p
	end

	--Setup Tables
	self.trackedEntities = {}
	self.debugEntities = {}
	self.mounts = {}
	self.tCPRecord = {}
	self.tVoteRecord = {}
	print("set tables")

	--Setup Listeners
	ListenToGameEvent("player_chat", Dynamic_Wrap(GameMode, 'OnPlayerChat'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(GameMode, 'OnPlayerReconnect'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(GameMode, 'OnPlayerDisconnect'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(GameMode, 'PlayerConnect'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(GameMode, 'PlayerConnectFull'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(GameMode, 'OnPlayerPickHero'), self)
	ListenToGameEvent('dota_illusions_created', Dynamic_Wrap(GameMode, 'OnIllusionsCreated'), self)
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(GameMode, 'OnNpcSpawn'), self)

	CustomGameEventManager:RegisterListener("player_vote", Dynamic_Wrap(GameMode, "OnPlayerVote") )

	--Setup Filters
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(GameMode, 'OrderManager'), self)
	GameRules:GetGameModeEntity():SetModifierGainedFilter(Dynamic_Wrap(GameMode, 'ModifierManager'), self)

	--stat attributes
	_G.DOTA_ATTRIBUTE_INTELLIGENCE_COOLDOWN_REDUCTION = 0.5 --0.5%
	local sv = {
		[DOTA_ATTRIBUTE_STRENGTH_DAMAGE] = 0,
		[DOTA_ATTRIBUTE_STRENGTH_HP] = 0,
		[DOTA_ATTRIBUTE_STRENGTH_HP_REGEN_PERCENT] = 0,
		[DOTA_ATTRIBUTE_STRENGTH_STATUS_RESISTANCE_PERCENT] = 0.01, --1%

		[DOTA_ATTRIBUTE_AGILITY_DAMAGE] = 0,
		[DOTA_ATTRIBUTE_AGILITY_ARMOR] = 0,
		[DOTA_ATTRIBUTE_AGILITY_ATTACK_SPEED] = 0,
		[DOTA_ATTRIBUTE_AGILITY_MOVE_SPEED_PERCENT] = 0.01, --1%

		[DOTA_ATTRIBUTE_INTELLIGENCE_DAMAGE] = 0,
		[DOTA_ATTRIBUTE_INTELLIGENCE_MANA] = 0,
		[DOTA_ATTRIBUTE_INTELLIGENCE_MANA_REGEN_PERCENT] = 0,
		[DOTA_ATTRIBUTE_INTELLIGENCE_SPELL_AMP_PERCENT] = 0,
		[DOTA_ATTRIBUTE_INTELLIGENCE_MAGIC_RESISTANCE_PERCENT] = 0,
	}
	for s,v in pairs(sv) do
		GameRules:GetGameModeEntity():SetCustomAttributeDerivedStatValue(s, v)
	end
end

function GameMode:StartGameMode()
	if mode then
		return
	end
	local time = string.gsub(string.gsub(GetSystemTime(), ':', ''), '^0+','')
	--print(time, type(time), tonumber(time))
	math.randomseed(time)

	mode = GameRules:GetGameModeEntity()

	--mode:SetCameraDistanceOverride( 2250 ) --override locks the camera and prevents it from being changed by other methods.
	CustomGameEventManager:Send_ServerToAllClients("camera_zoom", {distance = 2250})

	-- Set GameMode parameters
	mode:SetTopBarTeamValuesOverride( true )
	mode:SetTopBarTeamValuesVisible( true )

	mode:SetBuybackEnabled( false )
	mode:SetCustomBuybackCostEnabled( false )
	mode:SetCustomBuybackCooldownEnabled( false )
	mode:SetGoldSoundDisabled( false )

	mode:SetRemoveIllusionsOnDeath( false )
	mode:SetLoseGoldOnDeath( false )
	mode:SetFixedRespawnTime( 15 ) 

	mode:SetMaximumAttackSpeed( 600 )
	mode:SetMinimumAttackSpeed( 1 )

	mode:SetStashPurchasingDisabled( true )
	mode:SetStickyItemDisabled( false )
	mode:SetRecommendedItemsDisabled( true )

	mode:SetBotThinkingEnabled( false )
	mode:SetTowerBackdoorProtectionEnabled( false )

	mode:SetAnnouncerDisabled( false )
	mode:SetKillingSpreeAnnouncerDisabled( true )
	mode:SetFogOfWarDisabled( true )
	mode:SetUnseenFogOfWarEnabled( false )

	mode:SetDaynightCycleDisabled( false )


	ParticleManager:CreateParticle("particles/rain_fx/econ_snow.vpcf", PATTACH_EYES_FOLLOW, GameRules:GetGameModeEntity())

	--[[local c = {
		"basim"
	}
	for k,v in pairs(Entities:FindAllByName("cosmetic_cour") ) do
		CreateUnitByNameAsync(c[RandomInt(1, #c)], v:GetAbsOrigin(), true, nil, nil, DOTA_TEAM_NEUTRALS, function(unit)
			unit:SetMoveCapability(DOTA_UNIT_CAP_MOVE_GROUND)
			unit:SetBaseMoveSpeed(200)

			BaseAi:MakeInstance(unit, {state = BASIM, spawn = unit:GetAbsOrigin()})
		end) 
	end]]


	--populate the map
	for k,v in pairs(Entities:FindAllByName("cosmetic_snow") ) do
		v:SetAbsOrigin(v:GetAbsOrigin()+RandomVector(500))
	end

	local cyclones = Entities:FindAllByName("cosmetic_cyclone")
	for k,v in pairs(Entities:FindAllByName("cosmetic_cyclone_stop")) do table.insert(cyclones, v) end
	for _,cyclone in pairs(cyclones) do
		--unit to represent the cyclone particle
		CreateUnitByNameAsync("npc_dota_base", cyclone:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_NEUTRALS, function(unit)
			unit:AddNewModifier(unit, nil, "modifier_dummy", {})
			unit:SetMoveCapability(DOTA_UNIT_CAP_MOVE_FLY)
			unit:SetBaseMoveSpeed(405)
			unit.particle = cyclone

			if cyclone:GetName() == "cosmetic_cyclone" then
				--ai for the cylone to move around
				BaseAi:MakeInstance(unit, {state = CYCLONE, spawn = unit:GetAbsOrigin()})

				Timers(function()
					if not unit or unit:IsNull() then return end
					unit.particle:SetAbsOrigin(unit:GetAbsOrigin())
					return 0.03
				end)
			end

			Timers(1, function()
				if not unit or unit:IsNull() then return end

				local units = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, 125, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
				for _,hero in pairs(units) do
					if not hero.cycloned then
						hero.cycloned = true

						hero:AddNewModifier(unit, nil, "modifier_ice_cyclone", {duration = 2.5}) --applys a slow effect ondestroy

						EmitSoundOn("DOTA_Item.Cyclone.Activate", hero)
						EmitSoundOn("Hero_Winter_Wyvern.SplinterBlast.Target", hero)

						local p = ParticleManager:CreateParticle("particles/econ/events/winter_major_2016/cyclone_wm16.vpcf", PATTACH_WORLDORIGIN, hero)
						ParticleManager:SetParticleControl(p, 0, hero:GetAbsOrigin())
						ParticleManager:SetParticleControl(p, 1, hero:GetAbsOrigin())
						ParticleManager:SetParticleControl(p, 3, hero:GetAbsOrigin())
						ParticleManager:SetParticleControl(p, 5, Vector(1,1,1))

						local liftTime = 0
						local origin = hero:GetAbsOrigin()
						local forward = hero:GetForwardVector()
						--start hero cyclone timer
						Timers(0, function()
							if not hero or hero:IsNull() then return end
							local timesToSpin = 2

							--calculate their next facing position
							local newFoward = RotatePosition(Vector(0,0,0), QAngle(0,timesToSpin*360*0.03,0), hero:GetForwardVector())
							hero:SetForwardVector(newFoward)

							--gradually increase their height
							hero:SetAbsOrigin( Vector(origin.x, origin.y, math.min(hero:GetAbsOrigin().z + (500 * 0.03), GetGroundHeight(hero:GetAbsOrigin(), hero)+400)) )

							liftTime = liftTime + 0.03
							--end cyclone
							if liftTime >= 2.4 then
								--ground the unit
								hero:SetAbsOrigin(GetGroundPosition(hero:GetAbsOrigin(), hero))
								hero:SetForwardVector(forward)

								--destroy the heroes cyclone
								ParticleManager:DestroyParticle(p, false)
								ParticleManager:ReleaseParticleIndex(p)

								--delay before they can be cycloned again
								Timers(3.0, function() if not hero or hero:IsNull() then return end hero.cycloned = nil end)
								
								EmitSoundOn("Hero_Winter_Wyvern.SplinterBlast.Splinter", hero)
								--end timer
								return
							end
							--continue timer
							return 0.03
						end)
					end
				end
				return 0.5
			end)
		end)
	end
end

function GameMode:OnGameStateChanged()
	local state = GameRules:State_Get()
	if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		local maxvalue = math.max(self.tVoteRecord[12] or 0, self.tVoteRecord[24] or 0, self.tVoteRecord[36] or 0)
		--allsame 
		print(self.tVoteRecord[12], self.tVoteRecord[24], self.tVoteRecord[36])
		if self.tVoteRecord[12] == self.tVoteRecord[24] and self.tVoteRecord[24] == self.tVoteRecord[36] and self.tVoteRecord[36] == self.tVoteRecord[12] then
			print("default to 24")
			self.tVoteRecord["Selected"] = 24 --default to medium
		elseif self.tVoteRecord[12] == self.tVoteRecord[24] and self.tVoteRecord[12] == maxvalue then --short & medium same
			if RollPercentage(50) then
				self.tVoteRecord["Selected"] = 12
			else
				self.tVoteRecord["Selected"] = 24
			end
		elseif self.tVoteRecord[24] == self.tVoteRecord[36] and self.tVoteRecord[24] == maxvalue then --medium & long same
			if RollPercentage(50) then
				self.tVoteRecord["Selected"] = 24
			else
				self.tVoteRecord["Selected"] = 36
			end
		elseif self.tVoteRecord[36] == self.tVoteRecord[12] and self.tVoteRecord[36] == maxvalue then --long & short same
			if RollPercentage(50) then
				self.tVoteRecord["Selected"] = 36
			else
				self.tVoteRecord["Selected"] = 12
			end
		else --anything else
			if self.tVoteRecord[12] == maxvalue then
				self.tVoteRecord["Selected"] = 12
			elseif self.tVoteRecord[24] == maxvalue then
				self.tVoteRecord["Selected"] = 24
			elseif self.tVoteRecord[36] == maxvalue then
				self.tVoteRecord["Selected"] = 36
			else
				self.tVoteRecord["Selected"] = 24
			end
		end

		CustomGameEventManager:Send_ServerToAllClients("remove_voting_screen", {})
		CustomGameEventManager:Send_ServerToAllClients("update_goal", {kills_to_win = self.tVoteRecord["Selected"]})
	end
end

-- Evaluate the state of the game
function GameMode:OnThink()
	local state = GameRules:State_Get()

	if state == DOTA_GAMERULES_STATE_INIT then
	elseif state == DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD then
	elseif state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
	elseif state == DOTA_GAMERULES_STATE_HERO_SELECTION then
	elseif state == DOTA_GAMERULES_STATE_STRATEGY_TIME then		

		for pid = 0,DOTA_MAX_TEAM_PLAYERS-1 do
			local player = PlayerResource:GetPlayer(pid)
			if player and not PlayerResource:HasSelectedHero(pid) then
				player:MakeRandomHeroSelection()
			end
		end

	elseif state == DOTA_GAMERULES_STATE_TEAM_SHOWCASE then
	elseif state == DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD then
	elseif state == DOTA_GAMERULES_STATE_PRE_GAME then

		CustomGameEventManager:Send_ServerToAllClients( "show_timer", {} )
		SetClock(0)

	elseif state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		CountdownClock()

		local event_data = {key1=3,key2="Start!"}
		self.countdown = self.countdown or Timers(function()

			--print(event_data.key1.." seconds left!")
			CustomGameEventManager:Send_ServerToAllClients( "countdown", event_data)
			event_data.key1 = event_data.key1 - 1

			if event_data.key1 < -1 then
				CustomGameEventManager:Send_ServerToAllClients( "countdown", {key1=0,key2="stop"})
				--remove the stun modifier from each player
				local i = 1
				local hero = PlayerResource:GetSelectedHeroEntity(i-1)
				while hero:HasModifier("modifier_round_stun") do
					hero:RemoveModifierByName("modifier_round_stun")
					i = i + 1
					hero = PlayerResource:GetSelectedHeroEntity(i-1)
					if not hero or hero:IsNull() then
						break 
					end
				end
				return
			end
			return 1
		end)

		local time = GameRules:GetGameTime()
		local expireTime = 60.0
		local items = Entities:FindAllByClassname("dota_item_drop")
		for _,item in pairs(items) do
			local timeCreated = item:GetCreationTime()
			if timeCreated+expireTime < time then
				item:RemoveSelf()
			end
		end

		--currently requires 1 checkpoint to be reached before it starts working.
		--this should probably be moved into a timer somewhere for faster updating
		for i=0,PlayerResource:GetPlayerCount() - 1 do
			local player = PlayerResource:GetPlayer(i)
			if player then
				local hero = PlayerResource:GetSelectedHeroEntity(i)
				if hero then
					if self.tCPRecord[hero] then
						if hero:HasModifier("modifier_mount_movement") then
							local num = #split(self.tCPRecord[hero], ",")
							local nextCP = Entities:FindByName(nil, "CP_"..num+1)
							local lastCP = Entities:FindByName(nil, "CP_"..num)

							if nextCP and lastCP then

--								local function dummy(pos)
--									CreateUnitByNameAsync("npc_dota_base", pos, false, nil, nil, DOTA_TEAM_NOTEAM, function(unit)
--										unit:AddNewModifier(nil, nil, "modifier_kill", {duration = 0.999})
--									end)
--								end

								local nOrigin = nextCP:GetAbsOrigin()
								local maxNext = nOrigin + nextCP:GetBoundingMaxs()
								local minNext = nOrigin + nextCP:GetBoundingMins()
								maxNext.z = minNext.z --2D bounds

								local next,nc = math.huge, Vector(0,0,0)
								local next2,nc2 = math.huge, Vector(0,0,0)
								for k,v in pairs({maxNext, minNext, Vector(maxNext.x, minNext.y, minNext.z), Vector(minNext.x, maxNext.y, maxNext.z)}) do
									local dist = (hero:GetAbsOrigin() - v):Length2D()
									if dist < next and dist ~= next2 then
										next,nc = dist, v
									end
									if dist < next2 and dist ~= next then
										next2,nc2 = dist, v
									end
								end

								local lOrigin = lastCP:GetAbsOrigin()
								local maxLast = lOrigin + lastCP:GetBoundingMaxs()
								local minLast = lOrigin + lastCP:GetBoundingMins()
								maxLast.z = minLast.z --2D bounds

								local last,lc = math.huge, Vector(0,0,0)
								local last2,lc2 = math.huge, Vector(0,0,0)
								for k,v in pairs({maxLast, minLast, Vector(maxLast.x, minLast.y, minLast.z), Vector(minLast.x, maxLast.y, maxLast.z)}) do
									local dist = (hero:GetAbsOrigin() - v):Length2D()
									if dist < last and dist ~= last2 then
										last,lc = dist, v
									end
									if dist < last2 and dist ~= last then
										last2,lc2 = dist, v
									end
								end

								local toNext = CalcDistanceToLineSegment2D(hero:GetAbsOrigin(), nc, nc2)
								local toLast = CalcDistanceToLineSegment2D(hero:GetAbsOrigin(), lc, lc2)

								local between = CalcDistanceToLineSegment2D( (lc + (lc-lc2):Normalized() * (lc-lc2):Length2D()/2), nc, nc2)
								--print("tick")

								local dis = math.floor(toLast).."/"..math.floor(between)
								--max 100%, minimum 0.1%
								local width = tostring(math.ceil(math.max( math.min( (between - toNext) * 0.01, 100 ), 0.1 ))).."%"
								--print(between, toNext, (between - toNext) * 0.01)
								--print(width.."\n")

								CustomGameEventManager:Send_ServerToPlayer(player, "update_cp_distance", {distance = dis, slider = width})
							end
						else
							--Get back on your mount!!
							CustomGameEventManager:Send_ServerToPlayer(player, "get_back_on_mount", {penguin = self.mounts[hero:entindex()]})
						end
					end
				end
			end
		end
	elseif state == DOTA_GAMERULES_STATE_POST_GAME then
	elseif state == DOTA_GAMERULES_STATE_DISCONNECT then
	end

	if self.lastGameState and self.lastGameState ~= state then
		self:OnGameStateChanged()
	end
	self.lastGameState = state
	return 1
end

--doesnt have access to self
function GameMode:OnPlayerVote( keys )
	GameRules.GameMode.tVoteRecord[keys.vote] = GameRules.GameMode.tVoteRecord[keys.vote] or 0
	GameRules.GameMode.tVoteRecord[keys.vote] = GameRules.GameMode.tVoteRecord[keys.vote]+1
end
--------------------------------------------------------------

function GameMode:OrderManager( keys )
	local issuer = keys.issuer_player_id_const
	local units = keys.units
	local orderType = keys.order_type
	local abilityIndex = keys.entindex_ability
	local targetIndex = keys.entindex_target
	local pos = Vector(keys.position_x, keys.position_y, keys.position_z)
	local queue = keys.queue
	local sequenceNumber = keys.sequence_number_const

	--PrintRelevent(keys)

	if abilityIndex then
		local ability = EntIndexToHScript(abilityIndex)
		if ability then
			if ability.IsItem then
				if ability:GetName() == "item_ancient_janggo" and orderType == DOTA_UNIT_ORDER_CAST_NO_TARGET and not GameRules.wtfEnabled then
					--set to 2 because its going to use a charge immeditetly after we set it
					ability:SetCurrentCharges(2)
				end
				local hero = units["0"]

				if orderType == DOTA_UNIT_ORDER_PICKUP_ITEM then
					ability:SetOwner(hero)
					ability:SetPurchaser(hero)
				end
			end
		end
--		print("Filter | ability cast: "..ability:GetName())
	end

	local target
	if targetIndex then
		target = EntIndexToHScript(targetIndex)
--		print("Filter | target entity: "..target:GetName())
--		print("Filter | target position: "..tostring(target:GetAbsOrigin()))
	end

	if pos == Vector(0,0,0) then
		if target then
			pos = target:GetAbsOrigin()
		end
	end
	if units and units["0"] then
		local hero = EntIndexToHScript(units["0"])
		RemoveTimer(hero.noWalk)
		BridgeGrid:StopCrossing(hero)
		if hero:HasModifier("modifier_mount_movement") then
			local mod = hero:FindModifierByName("modifier_mount_movement")

			if orderType == DOTA_UNIT_ORDER_MOVE_TO_POSITION
			or orderType == DOTA_UNIT_ORDER_CAST_POSITION
			or orderType == DOTA_UNIT_ORDER_CAST_TARGET
			or orderType == DOTA_UNIT_ORDER_CAST_TARGET_TREE
			or orderType == DOTA_UNIT_ORDER_DROP_ITEM 
			or orderType == DOTA_UNIT_ORDER_PICKUP_ITEM then
				if mod:GetParent() ~= mod:GetCaster() then
					local dir = pos - mod:GetParent():GetAbsOrigin()
					dir.z = 0
					dir = dir:Normalized()
					local angles = VectorAngles( dir )
					mod.desiredYaw = angles.y
				end	
			end
			if orderType == DOTA_UNIT_ORDER_MOVE_TO_POSITION 
			or orderType == DOTA_UNIT_ORDER_MOVE_TO_TARGET
			or orderType == DOTA_UNIT_ORDER_MOVE_TO_DIRECTION
			or orderType == DOTA_UNIT_ORDER_PATROL then
				return false
			end
			if orderType == DOTA_UNIT_ORDER_PICKUP_ITEM then
				--stop them from walking but allow them to pick up the item..?
				hero.noWalk = Timers(function() 
					if not hero or hero:IsNull() then return end
					if (hero:GetAbsOrigin() - pos):Length2D() <= 10 then return end

					if hero:IsMoving() then
						local dt = 0.03
						local speed = hero:GetMoveSpeedModifier(hero:GetBaseMoveSpeed()) * dt
						hero:SetAbsOrigin(hero:GetAbsOrigin()+hero:GetBackwardVector()*speed)
					end

					return dt
				end)
			end
		else
			local moveorders = constants("DOTA_UNIT_ORDER", "move")
			if vlua.find(moveorders, orderType) then
				BridgeGrid:PathToBridge(hero, pos)
			end
			--[[
			if not GridNav:CanFindPath(hero:GetAbsOrigin(), pos) then
				if BridgeGrid:IsBridge(hero:GetAbsOrigin()) then
					local bridge = BridgeGrid:GetBridgeBetweenVectors(hero:GetAbsOrigin(), pos)
					if bridge then
						BridgeGrid:CrossBridge(hero, BridgeGrid:GetBridgeOrigin(bridge))
					end
				end
			end
			]]
		end
	end
	--return true by default to keep all other orders unchanged
	return true
end

function GameMode:ModifierManager( keys )
	local parentIndex = keys.entindex_parent_const
	local casterIndex = keys.entindex_caster_const
	local abilityIndex = keys.entindex_ability_const
	local modifierName = keys.name_const
	local duration = keys.duration

	if not parentIndex or not casterIndex or not abilityIndex then
--[[		print(
		"modifier: "..modifierName,
		 "parent: "..tostring((parentIndex ~= nil and (EntIndexToHScript(parentIndex):GetUnitName() ~= "" and EntIndexToHScript(parentIndex):GetUnitName()) or EntIndexToHScript(parentIndex):GetName()) or nil),
		  "caster: "..tostring((casterIndex ~= nil and (EntIndexToHScript(casterIndex):GetUnitName() ~= "" and EntIndexToHScript(casterIndex):GetUnitName()) or EntIndexToHScript(casterIndex):GetName()) or nil),
		   "ability: "..tostring((abilityIndex ~= nil and EntIndexToHScript(abilityIndex):GetName()) or nil)
		)]]
		return true
	end
	local parent = EntIndexToHScript( parentIndex )
	local caster = EntIndexToHScript( casterIndex )
	local ability = EntIndexToHScript( abilityIndex )
	local modifier = parent:FindModifierByNameAndCaster(modifierName, caster)
--[[
	print(
	"modifier: "..modifierName,
	 "parent: "..parent:GetUnitName(),
	  "caster: "..caster:GetUnitName(),
	   "ability: "..ability:GetName()
	)]]

	if modifierName == "modifier_generic_invulnerablity" then return false end

	--return true by default to leave all other modifiers unchanged
	return true
end

function GameMode:GiveMount(hero, mountName)
	if not hero or hero:IsNull() then return end
	--remove old mount if they have one
	if self.mounts[hero:entindex()] then
		hero:RemoveModifierByName("modifier_mount_movement")
		UTIL_Remove(EntIndexToHScript(self.mounts[hero:entindex()]))
	end
	--default to penguin
	if not mountName then mountName = "npc_dota_penguin" end
	--create mount
	CreateUnitByNameAsync(mountName, hero:GetAbsOrigin(), true, hero, hero, hero:GetTeamNumber(), function(unit)
		unit:SetOwner(hero)
		unit:SetForwardVector(hero:GetForwardVector())
		FindClearSpaceForUnit(unit, hero:GetAbsOrigin() + hero:GetForwardVector() * 150, true)

		--ensure mount has leveled abilities
		for i = 0,6 do
			local ab = unit:GetAbilityByIndex(i)
			if ab then
				ab:SetLevel(1)
			end
		end

		self.mounts[hero:entindex()] = unit:entindex()
	end)
end

function GameMode:OnNpcSpawn(keys)
	local npc = EntIndexToHScript(keys.entindex)
	--print("npc: "..npc:GetUnitName().." has spawned")

	if npc:GetClassname() == "npc_dota_companion" then
		npc:SetOwner(self.lastSpawnedHero)
		self.trackedEntities[self.lastSpawnedHero:entindex()] = keys.entindex
	end

	if npc:IsRealHero() then
		self.lastSpawnedHero = npc

		for i = 0,6 do
			local ab = npc:GetAbilityByIndex(i)
			if ab then
				if not string.match(ab:GetName(), "special_bonus_") then
					ab:SetLevel(1)
				end
			end
		end

		npc:GetAbilityByIndex(3):SetHidden(true)

		if npc:GetPrimaryAttribute() == DOTA_ATTRIBUTE_INTELLECT then
			npc:AddNewModifier(npc, nil, "modifier_intelligence_cdr", {})
		end

		local spawnEnt = Entities:FindByName(nil, "Spawnitem_trigger")
		if spawnEnt then
			local tploc = spawnEnt:GetAbsOrigin()

			self.var = self.var or -5
			self.hasSpawned = self.hasSpawned or {}
			if not self.hasSpawned[npc:GetPlayerID()] then
				self.hasSpawned[npc:GetPlayerID()] = true
				Timers(1.5, function() 
					npc:SetAbsOrigin(tploc+Vector(-900,(self.var)*160,0))
					self.var = self.var + 1
					npc:SetForwardVector(Vector(1,-1,0))
					
					npc:AddNewModifier(nil, nil, "modifier_round_stun", {})
					self:GiveMount(npc)
				end)
			end
		end
	end

	Timers(function()
		local tpScroll = npc:FindItemInInventory("item_tpscroll")
		if tpScroll then
			npc:RemoveItem(tpScroll)
		end
	end)
end

function GameMode:OnPlayerReconnect( keys )
	--print("reconnect")
end

function GameMode:OnPlayerDisconnect( keys )
	--print("disconnect")
end

function GameMode:PlayerConnect( keys )
	--print("connect")
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:PlayerConnectFull( keys )
	--print("connect FULL")
	GameMode:StartGameMode()
end

function GameMode:OnPlayerPickHero( keys )
	--print("pick hero")
end

function GameMode:OnIllusionsCreated( keys )
	--print("illusion")
end

function GameMode:OnPlayerChat( keys )
	local teamonly = keys.teamonly
	local playerID = keys.playerid
	local text = string.lower(keys.text)

	local command
	local arguments = {}

	--command variable currently unused other than to skip the first word
	for k,v in pairs(split(text, " ")) do
		if string.match(v, "-") and not command then
			command = v
		else
			table.insert(arguments, v)
		end
	end

	if not playerID then return end
	local player = PlayerResource:GetPlayer(playerID)
	if not player then return end

	local function IsCommand(str, num)
		if string.sub(text, 1, string.len(str)) == str then
			if #arguments >= num then
				return true
			end
		end
		return false 
	end

	--///////////////////////
	-- public chat commands
	--///////////////////////

	if IsCommand("-view", 1) then
		local args = tonumber(arguments[1]) * 0.01
		if not args then return end

		local min = 1200
		local max = 3000
		local distance = math.floor(min + (max - min) * args)
		CustomGameEventManager:Send_ServerToPlayer(player, "camera_zoom", {distance = distance})
	end


	if IsCommand("-unstuck", 0) then
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		FindClearSpaceForUnit(hero, hero:GetAbsOrigin(), false)

		local record = self.tCPRecord[hero]
		if record then
			local ent = Entities:FindByName( nil, "CP_"..#split(record, ",") )
			if ent then
				if not GridNav:CanFindPath(hero:GetAbsOrigin(), ent:GetAbsOrigin()) then
					self:GiveMount(hero)
				end
			end
		end
	end



	--//////////////////////
	-- debug chat commands
	--//////////////////////

	local devs = {
		["DankBot"] = 76561198157673452,
		["Pro§ aren'T☣xic"] = 76561198109346328,
	}

	local steamid = PlayerResource:GetSteamID(playerID)
	--print(PlayerResource:GetSelectedHeroEntity(playerID):GetName(), steamid)
	if not GameRules:IsCheatMode() then
--[[		local c = false
		for k,v in pairs(devs) do
			if steamid == v then
				c = true
			end
		end
		if not c then return end]]
		return
	end

	if IsCommand("-newhero", 1) then
		local name = arguments[1]
		local gold = PlayerResource:GetGold(playerID)
		local exp = PlayerResource:GetTotalEarnedXP(playerID)
		local oldHero = PlayerResource:GetSelectedHeroEntity(playerID)

		if not string.match(name, "npc_dota_hero_") then
			name = "npc_dota_hero_"..name
		end

		--remove their old mount
		if self.mounts[oldHero:entindex()] then
			UTIL_Remove( EntIndexToHScript( self.mounts[oldHero:entindex()] ) )
			self.mounts[oldHero:entindex()] = nil
		end

		--this is broken i guess? thanks volvo
--[[	--grab old heroes items
		local items = {}
		for i = 0,DOTA_ITEM_MAX-1 do
			local item = oldHero:GetItemInSlot(i)
			if item then
				items[i] = item
				oldHero:DropItemAtPositionImmediate(item, Vector(0,0,0))
				item:GetContainer():Destroy()
			end
		end]]

		--precache new hero, and swap their hero
		PrecacheUnitByNameAsync(name, function()
			local newhero = PlayerResource:ReplaceHeroWith(playerID, name, gold, exp)
			local hero
			--if success, remove old hero
			if newhero then
				hero = newhero
				GameMode:RemovePet(oldHero)
				UTIL_Remove(oldHero)
			else
				--failure, give them a new mount
				hero = oldhero
				GameMode:GiveMount(hero)
			end

--[[		--give them their items back, regardless of success
			for pos,item in pairs(items) do
				if item then
					item:SetPurchaser(hero)
					hero:AddItem(item)
					hero:SwapItems(hero:GetItemSlot(item), pos)
				end
			end]]
		end, playerID)
	end

	if IsCommand("-spawn", 1) then
		local name = arguments[1]
		local team = arguments[2]

		local exceptions = {
			["tusk_the_snowballer"] = true,
			["tiny_the_tosser"] = true,
			["drow_the_guster"] = true,
			["morphling_the_striker"] = true,
			["aa_the_vortexer"] = true,
			["cm_the_frostbiter"] = true,
			["invoker_the_ghost"] = true,
			["jakiro_the_icepather"] = true,
			["lich_the_froster"] = true,
			["ww_the_curser"] = true,
			["basim"] = true,
		}

		--autocomplete for our units
		for k,v in pairs(exceptions) do
			if string.len(name) >= 3 then
				if string.match(k, name) then
					name = k
				end
			end
		end

		--dont add npc_dota_ to our units
		if not exceptions[name] then
			--add it to any other unit
			if not string.match(name, "npc_dota_") then
				name = "npc_dota_"..name
			end
		end

		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		local teamNumber = hero:GetTeamNumber()
		if team then
			if team == string.match(team, "neutral") then
				teamNumber = DOTA_TEAM_NEUTRALS
			elseif team == string.match(team, "goodguy") then
				teamNumber = DOTA_TEAM_GOODGUYS
			elseif team == string.match(team, "badguy") or team == string.match(team, "enemy") then
				teamNumber = DOTA_TEAM_BADGUYS
			end
		end

		CreateUnitByNameAsync(name, hero:GetAbsOrigin(), true, hero, hero, teamNumber, function(unit)
			unit:SetControllableByPlayer(playerID, true)
			unit:SetOwner(hero)
			FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), true)

			for i = 0,6 do
				local ab = unit:GetAbilityByIndex(i)
				if ab and ab:GetLevel() <= 0 then
					ab:SetLevel(1)
					ab:SetHidden(false)
				end
			end

			BaseAi:MakeInstance(unit, {
				state = INVOKER,
				override = true,
			})

			table.insert(self.debugEntities, unit:entindex())
		end)
	end

	if IsCommand("-debugremove", 0) then
		for _,ID in pairs(self.debugEntities) do
			local debug = EntIndexToHScript(ID)
			if debug then
				if self.mounts[debug:entindex()] then
					UTIL_Remove( EntIndexToHScript(self.mounts[debug:entindex()]) )
					self.mounts[debug:entindex()] = nil
				end
				UTIL_Remove(debug)
				self.debugEntities[ID] = nil
			end
		end
	end

	if IsCommand("-item", 1) then
		if GameRules:IsCheatMode() then return end
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		local name = arguments[1]

		if not string.match(name, "item_") then
			name = "item_"..name
		end

		local item = CreateItem(name, hero, hero)
		if item then
			--could do some key value iteration for this, but i dont have a function for it setup yet
			if item:RequiresCharges() then
				if item:GetCurrentCharges() <= 0 then
					item:SetCurrentCharges(1)
				end
			end
			item:SetPurchaser(hero)
			hero:AddItem(item)
		end
	end

	if IsCommand("-lvlup", 0) then
		if GameRules:IsCheatMode() then return end
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		local num = tonumber(arguments[1]) or 1
		for i=1,num do
			hero:HeroLevelUp(false)
		end
	end

	if IsCommand("-test", 0) then
		local t = {}
		local ent = Entities:First()
		while ent do
			local this = ent
			ent = Entities:Next(ent)

			t[this:GetClassname()] = (t[this:GetClassname()] ~= nil and t[this:GetClassname()] + 1) or 1
		end
		table.sort( t )
		PrintTable(t)
	end

	if IsCommand("-wtf", 0) then
		if GameRules:IsCheatMode() then
			GameRules.wtfEnabled = true
		end
	end

	if IsCommand("-unwtf", 0) then
		GameRules.wtfEnabled = false
	end
end

function GameMode:RemovePet(index)
	if type(index) ~= "number" then
		index = index:entindex()
	end
	local petIndex = self.trackedEntities[index]
	if petIndex then
		UTIL_Remove( EntIndexToHScript( petIndex ) )
		self.trackedEntities[index] = nil
	end
end
