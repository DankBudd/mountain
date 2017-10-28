
if GameMode == nil then
	GameMode = class({})
end

function GameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	 -- Setup rules
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( true )
	GameRules:SetHeroSelectionTime( 30 )
	GameRules:SetPreGameTime( 0 )
	GameRules:SetPostGameTime( 30 )
	GameRules:SetTreeRegrowTime( 60 )
	GameRules:SetUseCustomHeroXPValues( false )
	GameRules:SetGoldPerTick( 0 )
	GameRules:SetGoldTickTime( 0 )
	GameRules:SetRuneSpawnTime( 30 )
	GameRules:SetUseBaseGoldBountyOnHeroes( true )

	GameRules:SetFirstBloodActive( false )
	GameRules:SetHideKillMessageHeaders( true )

	GameRules:SetCustomGameEndDelay( 5 )
	GameRules:SetCustomVictoryMessageDuration( 20 )
	GameRules:SetStartingGold( 650 )

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

	--Setup Tables
	self.DebugEntities = {}
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

		if not string.match(name, "npc_dota_hero") then
			name = "npc_dota_hero"..name
		end

		--grab old heroes items
		local items = {}
		for i = 0,DOTA_ITEM_MAX-1 do
			local item = oldHero:GetItemInSlot(i)
			if item then
				items[i] = item
				oldHero:DropItemAtPositionImmediate(item, Vector(0,0,0))
			end
		end

		--precache new hero, and swap their hero
		PrecacheUnitByNameAsync(name, function()
			local newhero = PlayerResource:ReplaceHeroWith(playerID, name, gold, exp)
			--give the new hero their old items
			if newhero then
				for pos,item in pairs(items) do
					if item then
						item:SetPurchaser(newhero)
						newhero:AddItem(item)
						newhero:SwapItems(newhero:GetItemSlot(item), pos)
					end
				end
				UTIL_Remove(oldHero)
			end
		end, playerID)
	end

	if IsCommand("-spawn") then
		local name = arguments[1]
		local team = arguments[2]

		if not string.match(name, "npc_dota_") then
			name = "npc_dota_"..name
		end

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

		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		CreateUnitByNameAsync(name, hero:GetAbsOrigin(), true, hero, hero, teamNumber, function(unit)
			unit:SetControllableByPlayer(playerID, true)
			unit:SetOwner(hero)
			unit:SetHasInventory(true)
			FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), true)

			table.insert(self.DebugEntities, unit:entindex())
		end)
	end

	--this might not work as planned
	if IsCommand("-settime") then
		local time
		if type(tonumber(arguments[1])) ~= "number" then
			time = (arguments[1] == "day" and 0.25) or 0
		else
			time = tonumber(arguments[1])
		end
		GameRules:SetTimeOfDay(time)
	end

	if IsCommand("-displayerror") then
		local msg = arguments[1]
		DisplayError(playerID, msg)
	end

	if IsCommand("-debugremove") then
		for _,ID in pairs(self.DebugEntities) do
			local debug = EntIndexToHScript(ID)
			if debug then
				print( "debug:", debug:GetPlayerID() )
				local ent = Entities:First()
				while ent ~= nil do
					if ent:GetClassname() == "npc_dota_companion" then
						local companion = EntIndexToHScript(ent:entindex())
						print( "companion:", companion:GetPlayerID() )
					end
					ent = Entities:Next(ent)
				end
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
end
