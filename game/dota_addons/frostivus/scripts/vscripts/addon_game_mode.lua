
require('util')
require('gamemode')

function Precache( context )
	local heroes = {
		"doom_bringer",
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

	local enemyHeroes = {
		"tusk",
		"tiny",
		"drow_ranger",
		"morphling",
		"ancient_apparition",
		"crystal_maiden",
		"invoker",
		"lich",
		"winter_wyvern",
	}
	
	for _,heroName in pairs(heroes) do
		PrecacheUnitByNameSync("npc_dota_hero_"..heroName, context)
	end

	for _,heroName in pairs(enemyHeroes) do
		PrecacheUnitByNameSync("npc_dota_hero_"..heroName, context)
	end

	PrecacheModel("models/creeps/ice_biome/penguin/penguin.vmdl", context)
	PrecacheModel("models/items/courier/basim/basim.vmdl", context)
end

-- Create the game mode when we activate
function Activate()
	GameRules.GameMode = GameMode()
	GameRules.GameMode:InitGameMode()
end