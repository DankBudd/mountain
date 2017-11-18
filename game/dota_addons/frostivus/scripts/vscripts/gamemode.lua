
if GameMode == nil then
	GameMode = class({})
end

--require stuff
require('ai/base_ai')
require('modifiers/global_modifiers')
require('thinkers')

--link global modifiers
--LinkLuaModifier(className,fileName,LuaModifierType)

function GameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	 -- Setup Rules
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( false )

	GameRules:SetHeroSelectionTime( 30 )
	GameRules:SetStrategyTime( 1 )
	GameRules:SetShowcaseTime( 0 )
	GameRules:SetPreGameTime( 30 )
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

	GameRules:SetCustomGameSetupAutoLaunchDelay( 0 )
	GameRules:LockCustomGameSetupTeamAssignment( true )
	GameRules:EnableCustomGameSetupAutoLaunch( true )

	local teams = {
		DOTA_TEAM_GOODGUYS,
		DOTA_TEAM_BADGUYS,
		DOTA_TEAM_CUSTOM_1,
		DOTA_TEAM_CUSTOM_2,
		DOTA_TEAM_CUSTOM_3,
	--	DOTA_TEAM_CUSTOM_4,
	--	DOTA_TEAM_CUSTOM_5,
	--	DOTA_TEAM_CUSTOM_6,
	--	DOTA_TEAM_CUSTOM_7,
	--	DOTA_TEAM_CUSTOM_8,
	}

	local maxPlayers = 10
	local playerCount = PlayerResource:GetPlayerCount()
	local playersPerTeam = math.floor(maxPlayers / #teams)

	for _,team in pairs(teams) do
		GameRules:SetCustomGameTeamMaxPlayers(team, playersPerTeam)
	end

	--Setup Tables
	self.trackedEntities = {}
	self.debugEntities = {}
	self.mounts = {}
	self.tCPRecord = {}
	self.tVoteRecord = {}
	print("set tables")

	GameMode = self
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
	mode:SetTopBarTeamValuesOverride ( false )
	mode:SetTopBarTeamValuesVisible( true )

	mode:SetBuybackEnabled( false )
	mode:SetCustomBuybackCostEnabled( false  )
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

				Timers(0, function()
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

	Timers(30,function()
		local maxvalue = math.max(self.tVoteRecord[12] or 0, self.tVoteRecord[24] or 0, self.tVoteRecord[36] or 0)
		--allsame 
		if self.tVoteRecord[12] == self.tVoteRecord[24] and self.tVoteRecord[24] == self.tVoteRecord[36] and self.tVoteRecord[36] == self.tVoteRecord[12] then
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
	end)
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
	elseif state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		local time = GameRules:GetGameTime()
		local expireTime = 60.0
		local items = Entities:FindAllByClassname("dota_item_drop")
		for _,item in pairs(items) do
			local timeCreated = item:GetCreationTime()
			if timeCreated+expireTime < time then
				item:RemoveSelf()
			end
		end
	elseif state == DOTA_GAMERULES_STATE_POST_GAME then
	elseif state == DOTA_GAMERULES_STATE_DISCONNECT then
	end
	return 1
end

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

	--PrintRelevent(filterTable)

	if abilityIndex then
		local ability = EntIndexToHScript(abilityIndex)
		if ability then
			if ability.IsItem then
				if ability:GetName() == "item_ancient_janggo" and orderType == DOTA_UNIT_ORDER_CAST_NO_TARGET and not GameRules:IsCheatMode() then
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
	if self.mounts[hero:GetPlayerID()] then
		UTIL_Remove(EntIndexToHScript(self.mounts[hero:GetPlayerID()]))
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

		self.mounts[hero:GetPlayerID()] = unit:entindex()
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
		GameMode:GiveMount(npc)

		for i = 0,6 do
			local ab = npc:GetAbilityByIndex(i)
			if ab then
				ab:SetLevel(1)
			end
		end

		if npc:GetPrimaryAttribute() == DOTA_ATTRIBUTE_INTELLECT then
			npc:AddNewModifier(npc, nil, "modifier_intelligence_cdr", {})
		end
	end

	if npc:HasInventory() then
		local tpScroll = npc:FindItemInInventory("item_tpscroll")
		if tpScroll then
			tpScroll:RemoveSelf()
		end
	end
end

function GameMode:OnPlayerReconnect( keys )
	print("reconnect")
end

function GameMode:OnPlayerDisconnect( keys )
	print("disconnect")
end

function GameMode:PlayerConnect( keys )
	print("connect")
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:PlayerConnectFull( keys )
	print("connect FULL")
	GameMode:StartGameMode()
end

function GameMode:OnPlayerPickHero( keys )
	print("pick hero")
end

function GameMode:OnIllusionsCreated( keys )
	print("illusion")
end

function GameMode:OnPlayerChat( keys )
	local teamonly = keys.teamonly
	local playerID = keys.playerid
	local text = string.lower(keys.text)

	local command
	local arguments = {}

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
		local c = false
		for k,v in pairs(devs) do
			if steamid == v then
				c = true
			end
		end
		if not c then return end
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
		if self.mounts[playerID] then
			UTIL_Remove( EntIndexToHScript((self.mounts[playerID])) )
			self.mounts[playerID] = nil
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
				if string.match(name, k) then
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

			--[[
				unit.instance = BaseAi:MakeInstance(unit, {
					state = WANDER_IDLE,
					aggroRange = 600,
					leash = 800,
					buffer = 200,
					spawn = unit:GetAbsOrigin(),
					override = true,
				})
			]]

			for i = 0,6 do
				local ab = unit:GetAbilityByIndex(i)
				if ab then
					ab:SetLevel(1)
					ab:SetHidden(false)
				end
			end

			table.insert(self.debugEntities, unit:entindex())
		end)
	end

	if IsCommand("-debugremove", 0) then
		for _,ID in pairs(self.debugEntities) do
			local debug = EntIndexToHScript(ID)
			if debug then
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

	if IsCommand("-lvlup", 1) then
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
		PrintTable(t)
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
