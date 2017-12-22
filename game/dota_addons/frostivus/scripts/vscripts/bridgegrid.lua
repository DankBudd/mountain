BridgeGrid = {}

function dummy(pos, dur)
	CreateUnitByNameAsync("npc_dota_base", pos or Vector(0,0,0), false, nil, nil, DOTA_TEAM_NOTEAM, function(unit)
		unit:AddNewModifier(nil, nil, "modifier_phased", {})
		unit:AddNewModifier(nil, nil, "modifier_kill", {duration = dur or 1.0})

		if BridgeGrid:IsBridge(pos) then
			unit:SetAbsOrigin(pos)
		end
	end)
end

--this function finds and stores all bridge triggers
function BridgeGrid:Init()
	if self.initialized then return end
	self.initialized = true

	self.paths = Entities:FindAllByName("BridgeGrid") --TODO
	for k,v in pairs(Entities:FindAllByName("BridgeGrid1")) do
		table.insert(self.paths, v)
	end
	--bridge entities dont exist on runtime, run again incase this is the first run
	Timers(3, function()
		self.initialized = false
		self:Init()
	end)
end


function BridgeGrid:GetBridgeOrigin( trigger )
	if not trigger then return end
	local min = trigger:GetAbsOrigin() + trigger:GetBoundingMins()
	local max = trigger:GetAbsOrigin() + trigger:GetBoundingMaxs()
	max.z = min.z

	return max + (min - max):Normalized() * ((min-max):Length2D()*0.5)
end


--check self.paths and see if this vector is within any bridges
function BridgeGrid:IsBridge( vector )
	return self:GetBridge(vector) ~= nil
end

function BridgeGrid:GetBridge( vector )
	if not vector then return end
	for k,v in pairs(self.paths) do
		local min = v:GetAbsOrigin() + v:GetBoundingMins()
		local max = v:GetAbsOrigin() + v:GetBoundingMaxs()
		
		if (min.x <= vector.x) and (vector.x <= max.x) then
			if (min.y <= vector.y) and (vector.y <= max.y) then
				if (min.z <= vector.z) and (vector.z <= max.z) then
					return v
				end
			end
		end
	end
	return nil
end


--check if theres a bridge between point a and b
function BridgeGrid:IsBridgeBetweenVectors( vector, vector2 )
	return self:GetBridgeBetweenVectors(vector, vector2) ~= nil
end

function BridgeGrid:GetBridgeBetweenVectors( vector, vector2 )
	if not vector or not vector2 then return end
	local direction = (vector2 - vector):Normalized()
	local vec = vector
	for i=0,(vec - vector2):Length2D() do
		vec = vec + direction
		local result = self:GetBridge(vec)
		if result ~= nil then
			return result
		end
	end
	return nil
end


--simulate walking from point a (unit origin) to point b with setabsorigin
function BridgeGrid:CrossBridge( unit, vector )
	local from = unit:GetAbsOrigin()
	local bridge = self:GetBridgeBetweenVectors(from, vector)
	if not bridge then return end

	local children = bridge:GetChildren()

	unit:Stop()

	--reset existing timer if there is one
	if unit._BridgeGridTimerID then
		self:StopCrossing(unit, false)
	end

	print("start")
	local dt = 1/30
	local id = Timers(function()
		if not unit or unit:IsNull() then print("NULL UNIT") return end

		local speed = (unit:GetMoveSpeedModifier(unit:GetBaseMoveSpeed())) * dt
		local direction = (vector - from):Normalized()
		local forward = unit:GetForwardVector()
		--print(direction.x, direction.y, direction.z)

--		print("forward: "..tostring(forward), "direction: "..tostring(direction))

		local started = false
		if DotProduct(direction, forward) < 0.99 then
			--continuously face towards the location we want to move to 
			--print("dot: "..DotProduct(direction, forward))
			unit:FaceTowards(vector)
		else		
			--start walking once we are facing the correct direction
			if not started then
				unit:StartGesture(ACT_DOTA_RUN)
				started = true
			end


--[[
			local animTime = unit:ActiveSequenceDuration()
			local animRate = speed * animTime

			--loop walking animation
			unit._BridgeGridTimerAnimID = unit._BridgeGridTimerAnimID or Timers(function()
				if not unit or unit:IsNull() then return end
				if not unit._BridgeGridTimerID then unit:RemoveGesture(ACT_DOTA_RUN) unit._BridgeGridTimerAnimID = nil return end

				unit:StartGestureWithPlaybackRate(ACT_DOTA_RUN, animRate)

				return animTime
			end)]]


			local n,l = GetNearest(unit, children)
			local o = unit:GetAbsOrigin()
			if n then
				o.z = n:GetAbsOrigin().z
			end
			unit:SetAbsOrigin(o + direction * speed)
			--print("moving "..speed.." units")

			if not self:IsBridge(unit:GetAbsOrigin()) then
				print("end")
				self:StopCrossing(unit, true)
				return
			end
		end
		return dt
	end)
	
	unit._BridgeGridTimerID = id
	return id
end


--stop any ongoing bridge crossing for this unit.
function BridgeGrid:StopCrossing( unit, fcs )
	--reset existing timer if there is one
	RemoveTimer(unit._BridgeGridTimerID)
	unit._BridgeGridTimerID = nil
	unit:RemoveGesture(ACT_DOTA_RUN)

	if fcs then
		FindClearSpaceForUnit(unit, unit:GetAbsOrigin(), false)
	end
end


--issue a move order to the bottom of nearest bridge to vector TODO: make the function
function BridgeGrid:PathToBridge(unit, vector)
	if not self.paths[1] then print("BridgeGrid:PathToBridge() :: no bridges to path to") return end

	--print( "IsBridge() :: unit:"..tostring(self:IsBridge(unit:GetAbsOrigin())), "position: "..tostring(self:IsBridge(vector)) )

	local v,t = vector, false
	if not GridNav:CanFindPath(unit:GetAbsOrigin(), vector) then
		v = v + Vector(64,0,0)
		for i=1,6 do
			v = RotatePosition(Vector(0,0,0), QAngle(0,45*i,0), v)
			if GridNav:CanFindPath(unit:GetAbsOrigin(), v) then
				t=true
				break
			end
		end
	else
		t=true
	end

	print(t,v)
	if t then
		unit:MoveToPosition(v)
	end
end


function GetNearest( u, t, p )
	u = u or nil  t = t or {}
	local n,l = nil,math.huge
	for k,v in pairs(t) do
		local d = (p and GridNav:FindPathLength(u:GetAbsOrigin(), BridgeGrid:GetBridgeOrigin(v))) or (u:GetAbsOrigin()-v:GetAbsOrigin()):Length2D()
		if d < l then
			n,l = v,d
		end
	end
	return (n and (function() return n,l end)()) or nil --print("GetNearest() | incorrect input. expected: unit, table")
end

function BridgeGrid:ToWorldPos( vec )
	local p = Vector(GridNav:GridPosToWorldCenterX(vec.x), GridNav:GridPosToWorldCenterY(vec.y), 0)
	p.z = GetGroundHeight(p, nil)
	--print( "BridgeGrid:ToWorldPos() :: "..VectorToString(p) )
	return p
end

function BridgeGrid:ToGridPos( vec )
	--print( "BridgeGrid:ToGridPos() :: "..VectorToString(Vector(GridNav:WorldToGridPosX(vec.x), GridNav:WorldToGridPosY(vec.y), 0)) )
	return Vector(GridNav:WorldToGridPosX(vec.x), GridNav:WorldToGridPosY(vec.y), 0)
end


BridgeGrid:Init()
