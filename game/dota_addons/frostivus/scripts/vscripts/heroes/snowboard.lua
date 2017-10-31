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
						if not unit:IsHexed() and not unit:IsRooted() and not unit:IsStunned() then
							self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_mount_movement", {}).player = unit
							unit:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_mount_movement", {})
						end
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
	GetModifierMoveSpeed_Max = function(self) return self.maxSpeed end,
	GetModifierMoveSpeed_Limit = function(self) return self.maxSpeed end,
	GetModifierMoveSpeedOverride = function(self) return self.baseSpeed end,

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

	GetModifierMoveSpeedBonus_Constant = function(self)
		if IsClient() then
			return self:GetStackCount()
		end
	end,
  
	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_MOVESPEED_MAX,
			MODIFIER_PROPERTY_MOVESPEED_LIMIT,
			MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
			MODIFIER_PROPERTY_MOVESPEED_BASE_OVERRIDE,
		}
	end,

	OnCreated = function(self, kv)
		if IsServer() then
			self.maxSpeed = self:GetAbility():GetSpecialValueFor("max_speed")
			self.speedStep = self:GetAbility():GetSpecialValueFor("speed_growth")
			self.turnRate = self:GetAbility():GetSpecialValueFor("turn_rate")
			self.baseSpeed = self:GetAbility():GetSpecialValueFor("base_speed")
			self.curSpeed = self.baseSpeed

			self.desiredYaw = self:GetCaster():GetAnglesAsVector().y

			self.delay = self:GetAbility():GetSpecialValueFor("delay")

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
			self:GetParent():RemoveModifierByName("modifier_movespeed")

			--TODO: spiritbreaker-like knockback away from crash location (respects gridNav)
		end
	end,

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
						local dir = params.new_pos - self:GetParent():GetAbsOrigin()
						dir.z = 0
						dir = dir:Normalized()
						local angles = VectorAngles( dir )
						self.desiredYaw = angles.y
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
				if player:IsHexed() or player:IsRooted() or player:IsStunned() then
					self.curSpeed = self.baseSpeed
					return
				end

				local exceptions = {
					"modifier_eul_cyclone",
					"modifier_tiny_toss",
					"modifier_item_forcestaff_active",
					"modifier_tusk_walrus_punch_air_time",
					"modifier_tusk_walrus_kick_air_time",
					"modifier_invoker_tornado",
				}
				
				--skip this tick if the player is affected by an exception
				for _,name in pairs(exceptions) do
					if player:HasModifier(name) then
						return
					end
				end

				local turnAmount = 0.0
				local curAngles = mount:GetAngles()
				local angleDiff = UTIL_AngleDiff( self.desiredYaw, curAngles.y )

				local turnRate
				if self.delay <= 0 then
					turnRate = self.turnRate
				else
					turnRate = self.turnRate*2
				end

				turnAmount = math.min( turnRate * (1/30), math.abs( angleDiff ) )
			
				if angleDiff < 0.0 then
					turnAmount = turnAmount * -1
				end

				if angleDiff ~= 0.0 then
					curAngles.y = curAngles.y + turnAmount
					player:SetAbsAngles( curAngles.x, curAngles.y, curAngles.z )
				end

				--short delay before movement, to prevent insta crashing into wall/tree again
				if self.delay <= 0 then
					local newPos = player:GetAbsOrigin() + player:GetForwardVector() * ( (1/30) * self.curSpeed )
					newPos.z = GetGroundHeight(newPos, player) + 5

					--end slide if unpathable, and destroy any trees at unpathable position
					if not GridNav:CanFindPath( player:GetAbsOrigin(), newPos ) then
						GridNav:DestroyTreesAroundPoint( newPos, 25, true)
						ResolveNPCPositions( newPos, 25 )
						self:Destroy()
						return
					end

					--continue slide
					player:SetAbsOrigin( newPos )
					self.curSpeed = math.min( self.curSpeed + self.speedStep, self.maxSpeed )

					--update player movement speed
					self:SetStackCount(self.curSpeed)
				else
					self.delay = self.delay - (1/30)
				end

			--if parent is mount
			else
				--short delay for animations
				if self.startedLoop == nil and self:GetElapsedTime() > 0.3 then
					self.startedLoop = true
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
