LinkLuaModifier("modifier_sled_penguin_movement", "heroes/snowboard", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_penguin_thinker", "heroes/snowboard", LUA_MODIFIER_MOTION_NONE)

penguin_ability = class({})

function penguin_ability:GetIntrinsicModifierName()
	return "modifier_penguin_thinker"
end

modifier_penguin_thinker = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,

	CheckState = function(self)
		local state = {
			[MODIFIER_STATE_STUNNED] = true,
			[MODIFIER_STATE_INVULNERABLE] = true,
			[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		}
		return state
	end,

	OnCreated = function(self, kv)
		if IsServer() then
			self.waitTime = 0
			self:StartIntervalThink(1.0)
		end
	end,

	OnIntervalThink = function(self)
		if IsServer() then
			if self:GetParent():HasModifier("modifier_sled_penguin_movement") then
				self.waitTime = 1.0
				return
			end
			--dont let them remount immedietly
			if self.waitTime > 0 then
				self.waitTime = self.waitTime - 1.0
				return
			end

			local units = FindUnitsInRadius(self:GetParent():GetTeamNumber(), self:GetParent():GetAbsOrigin(), nil, 110,
				DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_CLOSEST, false)

			for k,unit in pairs(units) do
				if not unit:HasModifier("modifier_sled_penguin_movement") then
					if unit:GetPlayerID() == self:GetParent():GetOwner():GetPlayerID() then
						self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_sled_penguin_movement", {})
						unit:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_sled_penguin_movement", {})
						break
					else
						DisplayError(unit:GetPlayerID(), "#not_your_mount")
					end
				end
			end
		end
	end,
})

modifier_sled_penguin_movement = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	GetModifierDisableTurning = function(self, params) return 1 end,
	GetPriority = function(self) return DOTA_MOTION_CONTROLLER_PRIORITY_HIGH end,

	GetOverrideAnimation = function(self, params)
		if self:GetParent() ~= self:GetCaster() then
			return ACT_DOTA_FLAIL
		end
		return ACT_DOTA_SLIDE_LOOP
	end,

	DeclareFunctions = function(self) 
		local funcs = {
			MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
			MODIFIER_EVENT_ON_ORDER,
			MODIFIER_PROPERTY_DISABLE_TURNING,
		}
		return funcs
	end,

	OnCreated = function(self, kv)
		if IsServer() then
			self.max_sled_speed = self:GetAbility():GetSpecialValueFor("max_speed")
			self.speed_step = self:GetAbility():GetSpecialValueFor("speed_growth")
			self.nCurSpeed = self:GetAbility():GetSpecialValueFor("base_speed")
			self.flTurnRate = self:GetAbility():GetSpecialValueFor("turn_rate")
			self.flDesiredYaw = self:GetCaster():GetAnglesAsVector().y

			self.delay = self:GetAbility():GetSpecialValueFor("delay")

			if self:ApplyHorizontalMotionController() == false then 
				self:Destroy()
				return
			end
			if self:GetParent() == self:GetCaster() then
				self:GetParent():StartGesture( ACT_DOTA_SLIDE )
			end
		end
	end,

	OnDestroy = function(self)
		if IsServer() then
			self:GetParent():RemoveHorizontalMotionController( self )
			if self:GetParent() == self:GetCaster() then
				self:GetCaster():RemoveGesture( ACT_DOTA_SLIDE_LOOP )
				EmitSoundOn( "Hero_Tusk.IceShards.Penguin", self:GetParent() )
			end
		end
	end,

	OnOrder = function(self, params)
		if IsServer() then
			local hOrderedUnit = params.unit 
			local hTargetUnit = params.target
			local nOrderType = params.order_type
			if nOrderType == DOTA_UNIT_ORDER_MOVE_TO_POSITION or nOrderType == DOTA_UNIT_ORDER_ATTACK_MOVE then
				if hOrderedUnit == self:GetParent() and self:GetParent() ~= self:GetCaster() then
					local vDir = params.new_pos - self:GetCaster():GetOrigin()
					vDir.z = 0
					vDir = vDir:Normalized()
					local angles = VectorAngles( vDir )
					local hBuff = self:GetCaster():FindModifierByName( "modifier_sled_penguin_movement" )
					if hBuff ~= nil then
						hBuff.flDesiredYaw = angles.y
					end	
				end
			end
		end
		return 0
	end,

	UpdateHorizontalMotion = function(self, me, dt)
		if IsServer() then
			--if parent is penguin
			if self:GetCaster() == self:GetParent() then
				--short delay for animations
				if self.bStartedLoop == nil and self:GetElapsedTime() > 0.3 then
					self.bStartedLoop = true
					self:GetCaster():StartGesture( ACT_DOTA_SLIDE_LOOP )
				end

				local flTurnAmount = 0.0
				local curAngles = self:GetCaster():GetAngles()
				local flAngleDiff = UTIL_AngleDiff( self.flDesiredYaw, curAngles.y )

				local flTurnRate
				if self.delay <= 0 then
					flTurnRate = self.flTurnRate
				else
					flTurnRate = self.flTurnRate*2
				end

				flTurnAmount = math.min( flTurnRate * dt, math.abs( flAngleDiff ) )
			
				if flAngleDiff < 0.0 then
					flTurnAmount = flTurnAmount * -1
				end

				if flAngleDiff ~= 0.0 then
					curAngles.y = curAngles.y + flTurnAmount
					me:SetAbsAngles( curAngles.x, curAngles.y, curAngles.z )
				end

				--short delay before movement, to prevent insta crashing into wall/tree again
				if self.delay <= 0 then
					local vNewPos = self:GetCaster():GetOrigin() + self:GetCaster():GetForwardVector() * ( dt * self.nCurSpeed )

					--end slide if unpathable, and destroy any trees at unpathable position
					if GridNav:CanFindPath( me:GetOrigin(), vNewPos ) == false then
						GridNav:DestroyTreesAroundPoint( vNewPos, 25, true)
						self:Destroy()
						return
					end

					--continue slide
					me:SetOrigin( vNewPos )
					self.nCurSpeed = math.min( self.nCurSpeed + self.speed_step, self.max_sled_speed )
				else
					self.delay = self.delay - dt
				end

				--if parent is player
			else
				--if penguin is still sliding
				if self:GetCaster():IsAlive() == false or self:GetCaster():FindModifierByName( "modifier_sled_penguin_movement" ) == nil then
					self:Destroy()
					return
				end

				--set parent origin and angles to casters
				me:SetOrigin( self:GetCaster():GetOrigin() )
				local casterAngles = self:GetCaster():GetAngles() 
				me:SetAbsAngles( casterAngles.x, casterAngles.y, casterAngles.z )
			end
		end
	end,
})