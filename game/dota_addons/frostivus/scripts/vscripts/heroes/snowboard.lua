LinkLuaModifier("modifier_mount_movement", "heroes/snowboard", LUA_MODIFIER_MOTION_NONE)
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
			self.tick = 1.0
			self.waitTime = 0
			self:StartIntervalThink(1.0)
		end
	end,

	OnIntervalThink = function(self)
		if IsServer() then
			if self:GetParent():HasModifier("modifier_mount_movement") then
				self.waitTime = self.tick*2
				return
			end
			--dont let them remount immedietly
			if self.waitTime > 0 then
				self.waitTime = self.waitTime - self.tick
				return
			end

			local units = FindUnitsInRadius(self:GetParent():GetTeamNumber(), self:GetParent():GetAbsOrigin(), nil, 110,
				DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_CLOSEST, false)

			for k,unit in pairs(units) do
				if not unit:HasModifier("modifier_mount_movement") then
					if unit:GetPlayerID() == self:GetParent():GetOwner():GetPlayerID() then
						self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_mount_movement", {}).player = unit
						unit:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_mount_movement", {})
						break
					else
						DisplayError(unit:GetPlayerID(), "#not_your_mount")
					end
				end
			end
		end
	end,
})


modifier_mount_movement = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	GetModifierDisableTurning = function(self, params) return 1 end,

	GetOverrideAnimation = function(self, params)
		if self:GetParent() ~= self:GetCaster() then
			return ACT_DOTA_FLAIL
		end
		return ACT_DOTA_SLIDE_LOOP
	end,

	DeclareFunctions = function(self) 
		local funcs = {
			MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
			MODIFIER_PROPERTY_DISABLE_TURNING,
			MODIFIER_EVENT_ON_ORDER,
			MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
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

			self.delay = self:GetAbility():GetSpecialValueFor("delay") or 1.0

			if self:GetParent() == self:GetCaster() then
				self:GetParent():StartGesture( ACT_DOTA_SLIDE )
			end

			--think every server tick
			self:StartIntervalThink(1/30)
		end
	end,

	OnDestroy = function(self)
		if IsServer() then
			--when destroy on mount do
			if self:GetParent() == self:GetCaster() then
				EmitSoundOn( "Hero_Tusk.IceShards.Penguin", self:GetParent() )
				self.player:RemoveModifierByName("modifier_mount_movement")
				return
			end
			--when destroy on player do
			self:GetCaster():RemoveModifierByName("modifier_mount_movement")

			--TODO: spiritbreaker-like knockback away from crash location
		end
	end,

--[[OnAbilityFullyCast = function(self, params)
		if IsServer() then
			if self:GetParent() == params.caster then
				self:GetParent():Stop()
			end
		end
	end,]]

	OnOrder = function(self, params)
		if IsServer() then
			local hOrderedUnit = params.unit 
			local hTargetUnit = params.target
			local nOrderType = params.order_type
			if nOrderType == DOTA_UNIT_ORDER_MOVE_TO_POSITION
			or nOrderType == DOTA_UNIT_ORDER_CAST_POSITION
			or nOrderType == DOTA_UNIT_ORDER_CAST_TARGET
			or nOrderType == DOTA_UNIT_ORDER_CAST_TARGET_TREE then
				if hOrderedUnit == self:GetParent() then
					if self:GetParent() ~= self:GetCaster() then
						local vDir = params.new_pos - self:GetParent():GetAbsOrigin()
						vDir.z = 0
						vDir = vDir:Normalized()
						local angles = VectorAngles( vDir )
						self.flDesiredYaw = angles.y
					end	
				end
			end
		end
		return 0
	end,

	OnIntervalThink = function(self)
		if IsServer() then
			local player = self:GetParent()
			local mount = self:GetCaster()

			--if parent is player
			if self:GetCaster() ~= self:GetParent() then

				if player:IsMoving() then
					player:Stop()
				end

				local exceptions = {
					"modifier_eul_cyclone",
					--force_staff
					--toss
					--walrus punch
					--walrus kick
					--tornado
				}
				
				--skip this tick if the player is effected by an exception
				for _,name in pairs(exceptions) do
					if player:HasModifier(name) then
						return
					end
				end

				local flTurnAmount = 0.0
				local curAngles = mount:GetAngles()
				local flAngleDiff = UTIL_AngleDiff( self.flDesiredYaw, curAngles.y )

				local flTurnRate
				if self.delay <= 0 then
					flTurnRate = self.flTurnRate
				else
					flTurnRate = self.flTurnRate*2
				end

				flTurnAmount = math.min( flTurnRate * (1/30), math.abs( flAngleDiff ) )
			
				if flAngleDiff < 0.0 then
					flTurnAmount = flTurnAmount * -1
				end

				if flAngleDiff ~= 0.0 then
					curAngles.y = curAngles.y + flTurnAmount
					player:SetAbsAngles( curAngles.x, curAngles.y, curAngles.z )
				end

				--short delay before movement, to prevent insta crashing into wall/tree again
				if self.delay <= 0 then
					local vNewPos = player:GetAbsOrigin() + player:GetForwardVector() * ( (1/30) * self.nCurSpeed )
					vNewPos.z = GetGroundHeight(vNewPos, player) + 5

					--end slide if unpathable, and destroy any trees at unpathable position
					if not GridNav:CanFindPath( player:GetAbsOrigin(), vNewPos ) then
						GridNav:DestroyTreesAroundPoint( vNewPos, 25, true)
						ResolveNPCPositions( vNewPos, 25 )
						self:Destroy()
						return
					end

					--continue slide
					player:SetAbsOrigin( vNewPos )
					self.nCurSpeed = math.min( self.nCurSpeed + self.speed_step, self.max_sled_speed )
				else
					self.delay = self.delay - (1/30)
				end

			--if parent is mount
			else
				--short delay for animations
				if self.bStartedLoop == nil and self:GetElapsedTime() > 0.3 then
					self.bStartedLoop = true
					self:GetCaster():StartGesture( ACT_DOTA_SLIDE_LOOP )
				end

				player = self.player
				--if player is not still sliding, destroy
				if not player:IsAlive() or not player:HasModifier("modifier_mount_movement") then
					self:Destroy()
					return
				end

				--move mount to player
				mount:SetAbsOrigin( player:GetAbsOrigin() )

				--update mount angles
				local playerAngles = player:GetAngles() 
				mount:SetAbsAngles( playerAngles.x, playerAngles.y, playerAngles.z )
			end
		end
	end,
})