
if GameMode == nil then
	GameMode = class({})
end

function GameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:GetGameModeEntity():SetCameraDistanceOverride( 2250 )

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


	GameMode = self
	ListenToGameEvent("player_chat", Dynamic_Wrap(GameMode, 'OnPlayerChat'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(GameMode, 'OnPlayerReconnect'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(GameMode, 'OnPlayerDisconnect'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(GameMode, 'PlayerConnect'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(GameMode, 'PlayerConnectFull'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(GameMode, 'OnPlayerPickHero'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(GameMode, 'OnItemPickedUp'), self)
	ListenToGameEvent("dota_illusions_created", Dynamic_Wrap(GameMode, 'OnIllusionsCreated'), self)
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

function GameMode:PlayerConnectFull( keys )
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
		print(math.max(math.min(1000, arguments[1]), 2500)))
		CustomGameEventManager:Send_ServerToPlayer(player, "camera_zoom", {distance = distance})
	end

	if IsCommand("-newhero") then
		local name = arguments[1]
		local gold = PlayerResource:GetGold(playerID)
		local exp = PlayerResource:GetTotalEarnedXP(playerID)
		local oldHero = PlayerResource:GetSelectedHeroEntity(playerID)

		--grab old heroes items
		local items = {}
		for i = 0,DOTA_ITEM_MAX-1 do
			local item = oldHero:GetItemInSlot(i)
			if item then
				items[i] = item
			end
		end

		--precache new hero, and swap their hero
		local newhero
		PrecacheUnitByNameAsync(name, function() 
			newhero = PlayerResource:ReplaceHeroWith(playerID, name, gold, exp)
		end, playerID)

		--give the new hero their old items
		if newhero then
			for pos,itemName in pairs(items) do
				local item = CreateItem(itemName, newhero, newhero)
				if item then
					item:SetPurchaser(newhero)
					newhero:AddItem(item)
					hero:SwapItems(hero:GetItemSlot(item), pos)
				end
			end
		end
	end

	if IsCommand("-spawn") then
		local name = arguments[1]
		local hero = PlayerResource:GetSelectedHeroEntity(playerID)

		CreateUnitByNameAsync(name, hero:GetAbsOrigin(), true, hero, hero, hero:GetTeamNumber(), function(unit)
			unit:SetControllableByPlayer(playerID, true)
			unit:SetOwner(hero)
			unit:SetHasInventory(true)
			FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), true)
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
end