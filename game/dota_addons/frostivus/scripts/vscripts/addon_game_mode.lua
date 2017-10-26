if GameModeSB == nil then
	GameModeSB = class({})
end

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	GameRules.GameModeSB = GameModeSB()
	GameRules.GameModeSB:InitGameMode()
end

function GameModeSB:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:GetGameModeEntity():SetCameraDistanceOverride( 1500 )

	GameMode = self
	ListenToGameEvent("player_chat", Dynamic_Wrap(GameMode, 'OnPlayerChat'), self)


end

-- Evaluate the state of the game
function GameModeSB:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

function split(pString, pPattern)
	local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fpat = '(.-)' .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= '' then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
		cap = pString:sub(last_end)
		table.insert(Table, cap)
	end

	return Table
end

function GameModeSB:OnPlayerChat( keys )
	local teamonly = keys.teamonly
	local playerID = keys.playerid

	print(playerID)

	local text = string.lower(keys.text)

	local command
	local arguments = {}

	for k,v in pairs(split(text, " ")) do
		if string.match(v, "-") then
			command = v
		else
			table.insert(arguments, v)
		end
	end
	print("setting camera view to: "..tostring(arguments[1]))
	GameRules:GetGameModeEntity():SetCameraDistanceOverride( arguments[1] )

	if not playerID then return end
	local player = PlayerResource:GetPlayer(playerID)
	print(player)

	local function IsCommand(str)
		local len = string.len(str)
		return string.sub(command, 1, len) == str
	end

	if IsCommand("-view") then
		local distance = arguments[1]

		--CustomGameEventManager:Send_ServerToPlayer(player, "camera_zoom", {distance = distance})
	end
end