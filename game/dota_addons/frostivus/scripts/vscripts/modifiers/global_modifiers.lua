LinkLuaModifier("modifier_dummy", "modifiers/global_modifiers", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_intelligence_cdr", "modifiers/global_modifiers", LUA_MODIFIER_MOTION_NONE)

modifier_dummy = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,

	GetModifierIncomingDamage_Percentage = function(self) return 0 end,
	GetAbsoluteNoDamagePhysical = function(self) return 1 end,
	GetAbsoluteNoDamageMagical = function(self) return 1 end,
	GetAbsoluteNoDamagePure = function(self) return 1 end,

	OnCreated = function(self, kv)
		if IsServer() then
			self:GetParent():AddNoDraw()
		end
	end,

	OnDestroy = function(self)
		if IsServer() then
			self:GetParent():RemoveNoDraw()
		end
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
			MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
			MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
			MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
		}
	end,

	CheckState = function(self)
		return {
			--[MODIFIER_STATE_STUNNED] = true,
			--[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
			[MODIFIER_STATE_ATTACK_IMMUNE] = true,
			[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
			[MODIFIER_STATE_NO_HEALTH_BAR] = true,
			[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
			[MODIFIER_STATE_PROVIDES_VISION] = false,
		}
	end,
})


modifier_intelligence_cdr = class({
	IsHidden = function(self) return true end,
	IsPurgeable = function(self) return false end,
	DeclareFunctions = function(self) return {MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE_STACKING} end,
	GetModifierPercentageCooldownStacking = function(self) return self:GetStackCount() * 0.01 end,

	--stack count bullshit to transfer Intellect value to client
	OnCreated = function(self, kv) self:StartIntervalThink(1) end,
	OnIntervalThink = function(self) if IsServer() then self:SetStackCount(self:GetParent():GetIntellect()) end end,
})