
local states = {
	["IDLE"] = 0,
	["AGGRESSIVE"] = 1,
	["RETURNING"] = 2,
	["WANDER_IDLE"] = 3,
	["PROTECTIVE"] = 4,
	["PATROL"] = 5,
	["PATROL_AGGRO"] = 6,
	["SENTRY"] = 7,
	["BASIM"] = 8,
	["CYCLONE"] = 9,
	["END_TINY"] = 10,
}

base_ai = class({})

function base_ai:OnUpgrade()
	if self.instance then return end

	--default values
	local info = { 
		state = WANDER_IDLE,
		aggroRange = 1000,
		leash = 1200,
		buffer = 250,
		spawn = self:GetCaster():GetAbsOrigin(),
		patrolPoints = {},

	}
	local kv = LoadKeyValues("scripts/npc/npc_units_custom.txt")
	if kv then
		for k,v in pairs(kv) do
			if k == self:GetCaster():GetUnitName() then
			--	print("\n loading kv for unit: "..k)
				for l,m in pairs(v) do
					if info[l] then
					--	print( "", "setting "..tostring(l)..": ".. info[l].. " to " .. (tonumber(m) or m.."("..states[m]..")").."\n" )
						info[l] = tonumber(m) or m
					end
				end
			end
		end
	end
	if type(info.state) ~= "number" then
		info.state = states[info.state]
	end

	--grab patrol points from map
	if self:GetCaster():GetUnitName() == "morphling_the_striker" then
		Timers(30, function()
			local agi = self:GetCaster():FindAbilityByName("morphling_morph_agi")
			local str = self:GetCaster():FindAbilityByName("morphling_morph_str")

			if not agi:GetToggleState() and not str:GetToggleState() then
				agi:ToggleAbility()
			elseif agi:GetToggleState() then
				str:ToggleAbility()
			elseif str:GetToggleState() then
				agi:ToggleAbility()
			end

			return RandomInt(5, 7)
		end)

		local thisMorph
		for _,morph in pairs({Entities:FindByName(nil,"Morph_1"), Entities:FindByName(nil,"Morph_2")}) do
			if morph == self:GetCaster() then
				thisMorph = string.lower(morph:GetName())
			end
		end

		if not thisMorph then return end
		--print(thisMorph)

		for i=1,4 do
			--print("","searching for: ".."patrol_point_"..i.."_"..thisMorph)
			local ent = Entities:FindByName(nil, "patrol_point_"..i.."_"..thisMorph)
			if ent then
				--print("","entity exists")
				if ent.GetAbsOrigin then
					--print("","","found em!")
					table.insert(info.patrolPoints, ent:GetAbsOrigin())
				end
			end
		end
	end

	if self:GetCaster():GetUnitName() == "tiny_the_tosser" then
		if Entities:FindByName(nil, "End_Tiny") == self:GetCaster() then -- Tiny_End
			info.state = END_TINY
		end
	end

	for i=0,6 do
		local ab = self:GetCaster():GetAbilityByIndex(i)
		if ab then
			if ab:GetLevel() > 0 then
				if bit.band(ab:GetBehavior(), DOTA_ABILITY_BEHAVIOR_AUTOCAST) == DOTA_ABILITY_BEHAVIOR_AUTOCAST then
					if not ab:GetAutoCastState() then
						ab:ToggleAutoCast()
					end
				end
			end
		end
	end


	self:GetCaster().instance = BaseAi:MakeInstance(self:GetCaster(), info)
end