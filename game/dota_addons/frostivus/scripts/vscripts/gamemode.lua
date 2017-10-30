
if GameMode == nil then
	GameMode = class({})
end

--require stuff
--require('')

--link global modifiers
--LinkLuaModifier(className,fileName,LuaModifierType)

function GameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	 -- Setup rules
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( false )

	GameRules:SetHeroSelectionTime( 30 )
	GameRules:SetPreGameTime( 0 )
	GameRules:SetShowcaseTime( 0 )
	GameRules:SetStrategyTime( 0 )
	GameRules:SetPostGameTime( 30 )
	GameRules:SetTreeRegrowTime( 60 )
	GameRules:SetGoldPerTick( 0 )
	GameRules:SetGoldTickTime( 0 )
	GameRules:SetRuneSpawnTime( 30 )

	GameRules:SetUseBaseGoldBountyOnHeroes( true )
	GameRules:SetUseCustomHeroXPValues( false )

	GameRules:SetFirstBloodActive( false )
	GameRules:SetHideKillMessageHeaders( true )

	GameRules:SetCustomGameEndDelay( 5 )
	GameRules:SetCustomVictoryMessageDuration( 20 )
	GameRules:SetStartingGold( 0 )

	GameRules:SetCustomGameSetupAutoLaunchDelay( 0 )
	GameRules:LockCustomGameSetupTeamAssignment( true )
	GameRules:EnableCustomGameSetupAutoLaunch( true )

	--Setup Listeners
	GameMode = self
	ListenToGameEvent("player_chat", Dynamic_Wrap(GameMode, 'OnPlayerChat'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(GameMode, 'OnPlayerReconnect'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(GameMode, 'OnPlayerDisconnect'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(GameMode, 'PlayerConnect'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(GameMode, 'PlayerConnectFull'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(GameMode, 'OnPlayerPickHero'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(GameMode, 'OnItemPickedUp'), self)
	ListenToGameEvent("dota_illusions_created", Dynamic_Wrap(GameMode, 'OnIllusionsCreated'), self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap(GameMode, 'OnNpcSpawn'), self)



	--Setup Filters
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(GameMode, "OrderManager"), self)

	--Setup Tables
	self.trackedEntities = {}
	self.debugEntities = {}
	self.mounts = {}
end

--this function will only run once, when the first player is fully loaded.
function GameMode:StartGameMode()
	if mode then
		return
	end

	mode = GameRules:GetGameModeEntity()

	-- Set GameMode parameters
	mode:SetCameraDistanceOverride( 2250 )
	mode:SetTopBarTeamValuesOverride ( false )
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
	mode:SetFogOfWarDisabled( false )
	mode:SetUnseenFogOfWarEnabled( false )

	mode:SetDaynightCycleDisabled( false )
end 

-- Evaluate the state of the game
function GameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
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
--		print("Filter | ability cast: "..ability:GetName())
	end

	local target
	if targetIndex then
		target = EntIndexToHScript(targetIndex)
--		print("Filter | target entity: "..target:GetName())
--		print("Filter | target position: "..tostring(target:GetAbsOrigin()))
	end

	if pos ~= Vector(0,0,0) then
--		print("Filter | world position: "..tostring(pos))
	end

	--return true by default to keep all other orders unchanged
	return true
end

function GameMode:GiveMount(hero, mountName)
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
	if npc:GetClassname() == "npc_dota_companion" then
		npc:SetOwner(self.lastSpawnedHero)
		self.trackedEntities[self.lastSpawnedHero:entindex()] = keys.entindex
	end
	if npc:IsRealHero() then
		self.lastSpawnedHero = npc
		GameMode:GiveMount(npc)
	end
end

function GameMode:OnPlayerReconnect( keys )
end

function GameMode:OnPlayerDisconnect( keys )
end

function GameMode:PlayerConnect( keys )
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:PlayerConnectFull( keys )
	GameMode:StartGameMode()
end

function GameMode:OnPlayerPickHero( keys )
end

function GameMode:OnItemPickedUp( keys )
end

function GameMode:OnIllusionsCreated( keys )
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

	local function IsCommand(str)
		return string.sub(text, 1, string.len(str)) == str
	end

	if IsCommand("-view") then
		local distance = arguments[1]
		CustomGameEventManager:Send_ServerToPlayer(player, "camera_zoom", {distance = distance})
	end

	if IsCommand("-newhero") then
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

		--grab old heroes items
		local items = {}
		for i = 0,DOTA_ITEM_MAX-1 do
			local item = oldHero:GetItemInSlot(i)
			if item then
				items[i] = item
				oldHero:DropItemAtPositionImmediate(item, Vector(0,0,0))
				item:GetContainer():Destroy()
			end
		end

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
			--give them their items back, regardless of success
			for pos,item in pairs(items) do
				if item then
					item:SetPurchaser(hero)
					hero:AddItem(item)
					hero:SwapItems(hero:GetItemSlot(item), pos)
				end
			end
		end, playerID)
	end

	if IsCommand("-spawn") then
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
		}

		if not exceptions[name] then
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
			elseif team == string.match(team, "badguy") then
				teamNumber = DOTA_TEAM_BADGUYS
			end
		end

		CreateUnitByNameAsync(name, hero:GetAbsOrigin(), true, hero, hero, teamNumber, function(unit)
			unit:SetControllableByPlayer(playerID, true)
			unit:SetOwner(hero)
			FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), true)

			for i = 0,15 do
				local ab = unit:GetAbilityByIndex(i)
				if ab then
					ab:SetLevel(1)
				end
			end

			table.insert(self.debugEntities, unit:entindex())
		end)
	end

	if IsCommand("-displayerror") then
		local msg = arguments[1]
		DisplayError(playerID, msg)
	end

	if IsCommand("-debugremove") then
		for _,ID in pairs(self.debugEntities) do
			local debug = EntIndexToHScript(ID)
			if debug then
				UTIL_Remove(debug)
				self.debugEntities[ID] = nil
			end
		end
	end

	if IsCommand("-test") then
		local ents = {}
		local ent = Entities:First()
		--index all entities in a sorted table
		while ent do
			local className = ent:GetClassname()
			local tName 
			if className == "" then
				tName = ent:GetDebugName()
			end
			if not tName or tName:IsNull() then
				tName = className
			end

			ents[tName] = ents[tName] or 0
			ents[tName] = ents[tName] +1

			ent = Entities:Next(ent)
		end
		--print entity table
		if arguments[1] == "print" then
			table.sort( ents )
			for k,v in pairs(ents) do
				print(v,k)
			end
		end
	end

	if IsCommand("-item") then
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

	if IsCommand("-lvlup") then
		if GameRules:IsCheatMode() then return end
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		local num = arguments[1]
		for i=1,num do
			hero:HeroLevelUp(false)
		end
	end
end

function GameMode:RemovePet(hero)
	if type(hero) == "number" then
		hero = EntIndexToHScript(hero)
	end
	local petIndex = self.trackedEntities[hero:entindex()]
	if petIndex then
		UTIL_Remove( EntIndexToHScript( petIndex ) )
		self.trackedEntities[hero:entindex()] = nil
	end
end
