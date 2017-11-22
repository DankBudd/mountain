LinkLuaModifier("modifier_dummy", "modifiers/global_modifiers", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_intelligence_cdr", "modifiers/global_modifiers", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ice_cyclone", "modifiers/global_modifiers", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_round_stun", "modifiers/global_modifiers", LUA_MODIFIER_MOTION_NONE)

modifier_dummy = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,

	GetModifierIncomingDamage_Percentage = function(self) return 0 end,
	GetAbsoluteNoDamagePhysical = function(self) return 1 end,
	GetAbsoluteNoDamageMagical = function(self) return 1 end,
	GetAbsoluteNoDamagePure = function(self) return 1 end,

	OnCreated = function(self, kv)
		if IsServer() then
			self.nodraw = kv.nodraw
			if self.nodraw then
				self:GetParent():AddNoDraw()
			end
		end
	end,

	OnDestroy = function(self)
		if IsServer() then
			if self.nodraw then
				self:GetParent():RemoveNoDraw()
			end
		end
	end,

	DeclareFunctions = function()
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
	DeclareFunctions = function() return {MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE_STACKING} end,
	GetModifierPercentageCooldownStacking = function(self) return self:GetStackCount() * (_G.DOTA_ATTRIBUTE_INTELLIGENCE_COOLDOWN_REDUCTION or 0.5) end,

	--stack count bullshit to transfer Intellect value to client
	OnCreated = function(self, kv) self:StartIntervalThink(1) end,
	OnIntervalThink = function(self) if IsServer() then self:SetStackCount(self:GetParent():GetIntellect()) end end,
})


modifier_ice_cyclone = class({
	IsHidden = function(self) return self:GetDuration() == self.start end,
	IsPurgable = function(self) return true end,
--	DestroyOnExpire = function(self) return self:GetDuration() ~= self.start end,
	IsStunDebuff = function(self) return self:GetDuration() == self.start end,

	OnCreated = function(self, kv)
		self.start = self:GetDuration()
		self.slow = kv.slow or -25
		self.slowDuration = kv.slowDuration or (self.start * 1.5)
	end,

	OnRemoved = function(self)
		if self:GetDuration() == self.start then
			--weird hack
			self.DestroyOnExpire = function(self) return false end
			self:SetDuration(self.slowDuration, true)
		end
	end,

	CheckState = function(self) 
		if self:GetDuration() ~= self.start then
			--weird hack
			if self.DestroyOnExpire and not self.DestroyOnExpire() then
				self.DestroyOnExpire = function(self) return true end
			end
			return {}
		end
		return { 
			[MODIFIER_STATE_STUNNED] = self:GetDuration() == self.start,
			[MODIFIER_STATE_INVULNERABLE] = self:GetDuration() == self.start,
		}
	end,

	DeclareFunctions = function() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, } end,
	GetModifierMoveSpeedBonus_Percentage = function(self) if self:GetDuration() ~= self.start then return self.slow end end,

	GetStatusEffectName = function(self) if self:GetDuration() ~= self.start then return "particles/status_fx/status_effect_frost.vpcf" end end,
	HeroEffectPriority = function(self) if self:GetDuration() ~= self.start then return 100 end end,
})


modifier_round_stun = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	GetOverrideAnimation = function(self) return ACT_DOTA_DISABLED end,
	CheckState = function(self) return {[MODIFIER_STATE_STUNNED] = true,} end,

	OnCreated = function(self, kv)
		self.p = ParticleManager:CreateParticle("particles/econ/items/winter_wyvern/winter_wyvern_ti7/wyvern_cold_embrace_ti7buff.vpcf",  PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	end,
	OnDestroy = function(self)
		ParticleManager:DestroyParticle(self.p, false)
		ParticleManager:ReleaseParticleIndex(self.p)
	end,
})