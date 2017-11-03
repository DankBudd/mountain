
base_ai = class({})

function base_ai:OnUpgrade()
	if self.instance then return end
	
	local info = {
		state = 3,
		protect = {self:GetCaster()},
		aggrorange = 600,
		leash = 800,
		buffer = 200,
		spawn = self:GetCaster():GetAbsOrigin(),
	}

	--local kv = LoadKeyValues("scripts/npc/npc_units_custom.txt")
	if kv then
		for k,v in pairs(kv) do
			if k == self:GetCaster():GetUnitName() then
				for l,m in pairs(v) do
					local var = string.lower(l)
					if info[var] then
						if var == "state" then
							info[var] = states[m]
						else
							info[var] = tonumber(m)
						end
					end
				end
			end
		end
	end

	print("UPGRADE")
	--for now using a fixed ai, having trouble formatting kv properly
	self.instance = BaseAi:MakeInstance(self:GetCaster(), {
		state = WANDER_IDLE,
		--protect = {self:GetCaster()},
		aggroRange = 800,
		leash = 1000,
		buffer = 250,
		spawn = self:GetCaster():GetAbsOrigin(),
	})

end