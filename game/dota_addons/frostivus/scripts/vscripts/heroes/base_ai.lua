
local states = {
	["IDLE"] = 0,
	["AGGRESSIVE"] = 1,
	["RETURNING"] = 2,
	["WANDER_IDLE"] = 3,
	["PROTECTIVE"] = 4,
	["PATROL"] = 5,
	["PATROL_AGGRO"] = 6,
	["SENTRY"] = 7,
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
				for l,m in pairs(v) do
					if info[l] then
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
		local thisMorph
		for _,morph in pairs({Entities:FindByName(nil,"Morph_1"), Entities:FindByName(nil,"Morph_2")}) do
			if morph == self:GetCaster() then
				thisMorph = string.lower(morph:GetName())
			end
		end

		if not thisMorph then return end
		
		for i=1,4 do
			local ent = Entities:FindByName(nil, "patrol_point_"..i.."_"..thisMorph)
			if ent then
				if ent.GetAbsOrigin then
					table.insert(info.patrolPoints, ent:GetAbsOrigin())
				end
			end
		end
	end

	self.instance = BaseAi:MakeInstance(self:GetCaster(), info)
end