LinkLuaModifier("modifier_mind_swap", "heroes/mind_swap.lua", LUA_MODIFIER_MOTION_NONE)

mind_swap = class({})

function mind_swap:CastFilterResultTarget( target )
	if self:GetCaster():HasModifier("modifier_mind_swap") or target:HasModifier("modifier_mind_swap") then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function mind_swap:GetCustomCastErrorTarget( target )
	if self:GetCaster():HasModifier("modifier_mind_swap") then
		return "#already_swapped"
	end
	if target:HasModifier("modifier_mind_swap") then
		return "#target_already_swapped"
	end
end

function mind_swap:OnSpellStart()
	local target = self:GetCursorTarget()

	for k,v in pairs({self:GetCaster() = target, target = self:GetCaster()}) do
		local mod = k:AddNewModifier(v, self, "modifier_mind_swap", {duration = self:GetSpecialValueFor("duration")})
		mod.originalOwner = k:GetOwner()
		mod.originalTeam = k:GetTeam()
		mod.originalPlayer = k:GetPlayerID()

		mod._self = k._self
	end
end


modifier_mind_swap = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	OnRefresh = function(self, kv) self:OnCreated(kv) end,

	OnCreated = function(self, kv)
		if not self:GetCaster() or self:GetCaster():IsNull() then self:Destroy() end
		if not self:GetCaster():IsAlive() then self:Destroy() end

		local casterMod = self:GetCaster():FindModifierByName("modifier_mind_swap")
		if not casterMod then
			self:OnCreated(kv)
		end

		self:GetParent():SetControllableByPlayer(casterMod.originalPlayer, true)
		self:GetParent():SetPlayerID(casterMod.originalPlayer)
		self:GetParent():SetOwner(casterMod.originalOwner)
		self:GetParent():SetTeam(casterMod.originalTeam)

		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(self:GetParent():GetPlayerID()), "camera_lock", {entIndex = self:GetParent():entindex()})
		Timers(1.0, function()
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(self:GetParent():GetPlayerID()), "camera_unlock", {})
		end)
	end,

	OnDestroy = function(self)
		self:GetParent():SetControllableByPlayer(self.originalPlayer, true)
		self:GetParent():SetPlayerID(self.originalPlayer)
		self:GetParent():SetOwner(self.originalOwner)
		self:GetParent():SetTeam(self.originalTeam)

		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(self:GetParent():GetPlayerID()), "camera_lock", {entIndex = self:GetCaster():entindex()})
		Timers(1.0, function()
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(self:GetParent():GetPlayerID()), "camera_unlock", {})
		end)
	end,
})