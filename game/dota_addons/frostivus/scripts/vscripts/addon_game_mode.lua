require('util')
require('gamemode')

function Precache( context )
	local heroes = {
		"doom",
		"chaos_knight",
		"huskar",
		"phoenix",
		"clinkz",
		"lina",
		"batrider",
		"ogre_magi",
		"warlock",
		"ember_spirit",
	}

	for _,heroName in pairs(heroes) do
		PrecacheUnitByNameSync("npc_dota_hero_"..heroName, context)
	end
end

-- Create the game mode when we activate
function Activate()
	GameRules.GameMode = GameMode()
	GameRules.GameMode:InitGameMode()
end
