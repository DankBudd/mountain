LinkLuaModifier("modifier_mount_movement", "heroes/snowboard", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_penguin_thinker", "heroes/snowboard", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mimic_casters_states", "heroes/snowboard", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mount_anim", "heroes/snowboard", LUA_MODIFIER_MOTION_NONE)


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

							self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_mount_anim", {})
							unit:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_mount_anim", {})

							--mimic states. e.g invisibility
							self:GetParent():AddNewModifier(unit, self:GetAbility(), "modifier_mimic_casters_states", {})
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


modifier_mimic_casters_states = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,

	CheckState = function(self)
		return {
			[MODIFIER_STATE_INVISIBLE] = self:GetCaster():IsInvisible(),
			[MODIFIER_STATE_STUNNED] = self:GetCaster():IsStunned(),
			[MODIFIER_STATE_HEXED] = self:GetCaster():IsHexed(),
			[MODIFIER_STATE_FROZEN] = self:GetCaster():IsFrozen(),
			[MODIFIER_STATE_ROOTED] = self:GetCaster():IsRooted(),
			[MODIFIER_STATE_NO_UNIT_COLLISION] = self:GetCaster():NoUnitCollision(),
		}
	end,
})


modifier_mount_anim = class({	
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DeclareFunctions = function(self) return {MODIFIER_PROPERTY_OVERRIDE_ANIMATION,} end,
	GetOverrideAnimation = function(self, keys)
		if self:GetParent() ~= self:GetCaster() then
			return ACT_DOTA_FLAIL
		end
		return ACT_DOTA_SLIDE_LOOP
	end,
})


modifier_mount_movement = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	GetModifierDisableTurning = function(self, keys) return 1 end,
	GetModifierMoveSpeed_Max = function(self) return self.maxSpeed*2 end,
	GetModifierMoveSpeed_Limit = function(self) return self.maxSpeed*2 end,
	GetModifierMoveSpeedOverride = function(self) return self.baseSpeed end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_DISABLE_TURNING,
			MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
			MODIFIER_PROPERTY_MOVESPEED_MAX,
			MODIFIER_PROPERTY_MOVESPEED_LIMIT,
			MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
			MODIFIER_PROPERTY_MOVESPEED_BASE_OVERRIDE,
		}
	end,

	GetModifierMoveSpeedBonus_Constant = function(self)
		if IsClient() then
			return math.max(self:GetStackCount() - self.baseSpeed, 0)
		end
	end,

	OnCreated = function(self, kv)
		self.maxSpeed = self:GetAbility():GetSpecialValueFor("max_speed")
		self.speedStep = self:GetAbility():GetSpecialValueFor("speed_growth")
		self.turnRate = self:GetAbility():GetSpecialValueFor("turn_rate")
		self.baseSpeed = self:GetAbility():GetSpecialValueFor("base_speed")
		self.curSpeed = self.baseSpeed
		self.boost = 0

		self.delay = self:GetAbility():GetSpecialValueFor("delay")

		if IsServer() then
			if self:GetParent() == self:GetCaster() then
				self:GetParent():StartGesture( ACT_DOTA_SLIDE )
			else
				self.desiredYaw = self:GetParent():GetAnglesAsVector().y
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
				self:GetCaster():RemoveGesture( ACT_DOTA_SLIDE_LOOP )
				self:GetCaster():RemoveModifierByName("modifier_mimic_casters_states")
				self.player:RemoveModifierByName("modifier_mount_movement")
				self.player:RemoveModifierByName("modifier_mount_anim")
				if self.particle then
					ParticleManager:DestroyParticle(self.particle, true)
					ParticleManager:ReleaseParticleIndex(self.particle)
				end
				return
			end
			--when destroy on player do
			if not self:GetCaster():IsNull() then
				self:GetCaster():RemoveModifierByName("modifier_mount_movement")
				self:GetCaster():RemoveModifierByName("modifier_mount_anim")
			end
		end
	end,

	OnIntervalThink = function(self)
		if IsServer() then
			local player = self:GetParent()
			local mount = self:GetCaster()

			--if parent is player
			if self:GetCaster() ~= self:GetParent() then

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
					"modifier_jump",
				}

				--skip this tick if the player is affected by an exception
				for _,name in pairs(exceptions) do
					if player:HasModifier(name) then
						return
					end
				end

				local turnAmount = 0.0
				local curAngles = player:GetAngles()
				local angleDiff = AngleDiff( self.desiredYaw, curAngles.y )

				local turnRate
				if self.delay <= 0 then
					turnRate = self.turnRate
				else
					turnRate = self.turnRate*2
				end
				local turnMod = player:FindModifierByName("modifier_turn")
				if turnMod then
					turnRate = turnRate + (360 * turnMod.turnRate)
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
					newPos.z = GetGroundHeight(newPos, player) + 20

					--end slide if unpathable, and destroy any trees at unpathable position
					if not GridNav:CanFindPath( player:GetAbsOrigin(), newPos ) or #Entities:FindAllByClassnameWithin("dota_temp_tree", newPos, 25) > 0 then
						GridNav:DestroyTreesAroundPoint( newPos, 25, true)
						ResolveNPCPositions( player:GetAbsOrigin(), 25 )
						self:Destroy()
						return
					end

					--check if theres a hero in front of the player before moving
					local pass = true
					if not player:NoUnitCollision() then --player:IsPhased()
						local units = FindUnitsInRadius(player:GetTeamNumber(), newPos, nil, 50, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
						if #units > 0 then
							for k,v in pairs(units) do
								if v ~= player and not v:NoUnitCollision() then
									pass = false
									break
								end
							end
						end
					end
					if pass then
						--continue slide
						player:SetAbsOrigin( newPos )

						--reset the boost before calculations
						self.curSpeed = self.curSpeed - self.boost

						--calculate bonus movespeed
						self.boost = (self:GetParent():GetMoveSpeedModifier(self.baseSpeed) - self.baseSpeed)

						--update mount speed
						self.curSpeed = math.min( self.curSpeed + ( (1/30) * self.speedStep ) + self.boost, self.maxSpeed + self.boost )

					--[[	print("","GetIdealSpeed: "..player:GetIdealSpeed() .. "\n",
						"GetMoveSpeedModifier: "..player:GetMoveSpeedModifier(player:GetBaseMoveSpeed())-player:GetBaseMoveSpeed() .. "\n",
						"CurrentSpeed: "..math.ceil(self.curSpeed).."\n")]]
					else
						--start decaying speed
						self.curSpeed = math.max( self.curSpeed - ( (1/30) * self.speedStep ), self.baseSpeed)
					end
				else
					self.delay = self.delay - (1/30)
				end

				--print("Mount stats \n", "current speed: "..tostring(self.curSpeed-self.boost).."\n", "boost: "..tostring(self.boost).."\n", "post calc: "..self.curSpeed)

				--display mount speed as player movement speed
				self:SetStackCount(math.ceil(self.curSpeed))

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

				if self.curSpeed >= 400 and not self.particle then
					self.particle = ParticleManager:CreateParticle("particles/econ/courier/courier_trail_winter_2012/courier_trail_winter_2012.vpcf", PATTACH_ABSORIGIN_FOLLOW, mount)
					ParticleManager:SetParticleControlEnt(self.particle, 1, mount, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", mount:GetAbsOrigin(), false)
				elseif self.curSpeed < 400 and self.particle then
					ParticleManager:DestroyParticle(self.particle, false)
					ParticleManager:ReleaseParticleIndex(self.particle)
					self.particle = nil
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
