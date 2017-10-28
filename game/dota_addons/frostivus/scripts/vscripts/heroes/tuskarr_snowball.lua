tuskarr_snowball = class({})

function tuskarr_snowball:OnSpellStart()
	local target = self:GetCursorTarget()
	if not target then return end

	--start 'projectile'
	self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_tuskarr_snowball", {target = target:entindex()})
end

modifier_tuskarr_snowball = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,

	OnCreated = function(self, kv)
		local tick = 1/30
		
		--hide tusk
		self:GetCaster():AddNoDraw()

		self.target = EntIndexToHScript(kv.target)
		self.speedGrowth = self:GetAbility():GetSpecialValueFor("snowball_speed_growth") * tick
		self.growRate = self:GetAbility():GetSpecialValueFor("snowball_grow_rate") * tick
		self.speed = self:GetAbility():GetSpecialValueFor("snowball_speed") * tick

		self.stun = self:GetAbility():GetSpecialValueFor("stun_duration")
		self.radius = self:GetAbility():GetSpecialValueFor("snowball_radius")
		self.windup = self:GetAbility():GetSpecialValueFor("snowball_windup")

		--make snowball
		self.p = ParticleManager:CreateParticle("", PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
		--cp 3 vector(0,0,growth)

		self:StartIntervalThink(1/30)
	end,

	OnIntervalThink = function(self)
		local tick = 1/30

		--delay before launch
		if self.windup > 0 then
			self.windup = self.windup - tick
		end

		--start moving snowball
		self.speed = self.speed + self.speedGrowth
		local direction = (self.target:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized()
		local newPos = self:GetParent():GetAbsOrigin() + direction * self.speed

		--move tusk towards the target
		self:GetParent():SetAbsOrigin(newPos)

		--check for and stun nearby enemies
		local units = FindUnitsInRadius(int_1,Vector_2,handle_3,float_4,int_5,int_6,int_7,int_8,bool_9)
		for _,unit in pairs(units) do

		end

	end,

})