LinkLuaModifier("modifier_jump", "heroes/base_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dash", "heroes/base_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_turn", "heroes/base_abilities", LUA_MODIFIER_MOTION_NONE)

jump_ability = class({})

function jump_ability:OnSpellStart()
	if not self:GetCaster():HasModifier("modifier_mount_movement") then
		self:EndCooldown()
		DisplayError(self:GetCaster():GetPlayerID(), "#must_be_mounted")
		return
	end
	ProjectileManager:ProjectileDodge(self:GetCaster())
	self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_jump", {duration = 0.5}) --safety duration in case something goes wrong
end

modifier_jump = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return true end,

	OnCreated = function(self)
		if IsServer() then

			EmitSoundOn( "Hero_Tusk.IceShards.Penguin", self:GetParent() )
			--EmitSoundOn("Ability.Leap", self:GetParent())

			self.height = 0
			self.traveled = 0
			self.distance = self:GetAbility():GetSpecialValueFor("distance") 
			self.speed = self:GetAbility():GetSpecialValueFor("speed") * 0.03
			self.direction = self:GetParent():GetForwardVector()

			self:StartIntervalThink(0.03)
		end
	end,

	OnIntervalThink = function(self)
		local pos
		if self.traveled < self.distance/2 then
			self.height = self.height + self.speed/2
			pos = GetGroundPosition(self:GetParent():GetAbsOrigin(), self:GetParent()) + Vector(0,0,self.height)
		else
			self.height = self.height - self.speed/2
			pos = GetGroundPosition(self:GetParent():GetAbsOrigin(), self:GetParent()) + Vector(0,0,self.height)
		end

		if self.traveled < self.distance then
			self:GetParent():SetAbsOrigin(pos + self.direction * self.speed)
			self.traveled = self.traveled + self.speed
		else
			FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), false)
			self:Destroy()
		end
	end,
})


dash_ability = class({})

function dash_ability:OnSpellStart()	
	if not self:GetCaster():HasModifier("modifier_mount_movement") then
		self:EndCooldown()
		DisplayError(self:GetCaster():GetPlayerID(), "#must_be_mounted")
		return
	end
	self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_dash", {duration = self:GetSpecialValueFor("duration")})
end

modifier_dash = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return true end,

	CheckState = function(self) return {[MODIFIER_STATE_NO_UNIT_COLLISION] = true,} end,
	DeclareFunctions = function(self) return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,} end,
	GetModifierMoveSpeedBonus_Percentage = function(self) return self:GetAbility():GetSpecialValueFor("speed_boost") end,

	OnCreated = function(self, kv)
		EmitSoundOn("Hero_Slardar.Sprint", self:GetParent())
	end,
})



turn_ability = class({})

function turn_ability:OnToggle()
	if IsServer() then
		if not self:GetCaster():HasModifier("modifier_mount_movement") then
			if self:GetToggleState() then
				self:ToggleAbility()
			end
			self:EndCooldown()
			DisplayError(self:GetCaster():GetPlayerID(), "#must_be_mounted")
			return
		end
		if self:GetToggleState() then
			self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_turn", {duration = self:GetSpecialValueFor("duration")})
		else
			self:GetCaster():RemoveModifierByName("modifier_turn")
			self:UseResources(true, false, true)
		end
	end
end

modifier_turn = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,

	DeclareFunctions = function(self) return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,} end,
	GetModifierMoveSpeedBonus_Percentage = function(self) return self:GetAbility():GetSpecialValueFor("speed_cost")end,

	OnCreated = function(self, kv)
		self.turnRate = self:GetAbility():GetSpecialValueFor("turn_rate")
		EmitSoundOn("DOTA_Item.Butterfly", self:GetParent())
	end,

	OnDestroy = function(self)
		if IsServer() then
			if self:GetAbility():GetToggleState() then
				self:GetAbility():ToggleAbility()
			end
		end
	end,
})

tusk_ability = class({})

function tusk_ability:OnSpellStart()
	local hero = self:GetCaster()
	CreateUnitByNameAsync("tusk_the_snowballer", hero:GetAbsOrigin()+RandomVector(250), true, hero, hero, hero:GetTeamNumber(), function(unit)
		for i=0,5 do
			local ab = unit:GetAbilityByIndex(i)
			if ab then
				if not string.match(ab:GetName(), "special_bonus_") then
					ab:SetLevel(1)
				end
			end
		end
			
		unit:AddNewModifier(unit, self, "modifier_kill", {duration = 35})

		BaseAi:MakeInstance(unit, {state = 11})
	end)
	self:SetHidden(true)
end
