LinkLuaModifier("modifier_adaptive_strike_knockback", "ai/adaptive_strike.lua", LUA_MODIFIER_MOTION_NONE)

adaptive_strike = class({})

function adaptive_strike:OnSpellStart()
	local target = self:GetCursorTarget()
	if not target then return end
	local proj = "particles/units/heroes/hero_morphling/morphling_adaptive_strike_".. ((self:GetCaster():FindAbilityByName("morphling_morph_str"):GetToggleState() and "str") or "agi") .."_proj.vpcf"

	EmitSoundOn("Hero_Morphling.AdaptiveStrikeStr.Cast", self:GetCaster())

	local info = {
		EffectName = proj,
		Ability = self,
		Target = target,
		Source = self:GetCaster(),
		bDodgeable = false,
		bProvidesVision = false,
		vSpawnOrigin = self:GetCaster():GetAbsOrigin(),
		iMoveSpeed = 1150,
		iVisionRadius = 0,
		iVisionTeamNumber = self:GetCaster():GetTeamNumber(),
		iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_HITLOCATION,
	}
	ProjectileManager:CreateTrackingProjectile(info)
end

function adaptive_strike:OnProjectileHit( hTarget, vLocation)
	if not IsServer() or not hTarget or hTarget:IsNull() then return end

	local p = ParticleManager:CreateParticle("particles/units/heroes/hero_morphling/morphling_adaptive_strike.vpcf", PATTACH_POINT, hTarget)
	ParticleManager:SetParticleControlEnt(p, 1, hTarget, PATTACH_POINT_FOLLOW, "attach_hitloc", GetGroundPosition(hTarget:GetAbsOrigin(), hTarget), false)
	ParticleManager:ReleaseParticleIndex(p)

	EmitSoundOn("Hero_Morphling.AdaptiveStrike", hTarget)

	hTarget:AddNewModifier(self:GetCaster(), self, "modifier_adaptive_strike_knockback", {})
end

modifier_adaptive_strike_knockback = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	IsStunDebuff = function(self) return true end,
	CheckState = function(self) return {[MODIFIER_STATE_STUNNED] = true,} end,

	OnCreated = function(self, kv)
		if not IsServer() then return end
		self.direction = (self:GetParent():GetAbsOrigin() - self:GetCaster():GetAbsOrigin()):Normalized() --would normally use vLocation instead of caster for direction, but valve does it this way.
		
		local agi = self:GetCaster():FindAbilityByName("morphling_morph_agi"):GetToggleState()
		local str = self:GetCaster():FindAbilityByName("morphling_morph_str"):GetToggleState()

		local minMax = ((agi and "min") or (str and "max")) or "min"

		self.stun = self:GetAbility():GetSpecialValueFor( minMax.."_stun_duration" )
		self.knockback = self:GetAbility():GetSpecialValueFor( minMax.."_knockback_distance" )

		self.speed = self:GetAbility():GetSpecialValueFor("knockback_speed") or 1400
		self.traveled = 0

		self:StartIntervalThink(0.03)
	end,

	OnIntervalThink = function(self)
		if not IsServer() then return end
		local speed = self.speed * 0.03

		self:GetParent():SetAbsOrigin(self:GetParent():GetAbsOrigin() + self.direction * speed)

		self.traveled = self.traveled + speed
		if self.traveled >= self.knockback then 
			FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), false)
			self:SetDuration( math.max( self.stun-self:GetElapsedTime(), self:GetAbility():GetSpecialValueFor("min_stun_duration") ), true )
			self:StartIntervalThink(-1)
		end
	end,

	OnRemoved = function(self)
		if not IsServer() then return end
		if self.traveled < self.knockback then
			if self:GetParent():IsAlive() then
				FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), false)
			end
		end
	end,
})