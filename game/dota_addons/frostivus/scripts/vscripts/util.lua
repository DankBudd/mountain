function CountdownClock()
	if not nCOUNTDOWNTIMER then return end

    nCOUNTDOWNTIMER = nCOUNTDOWNTIMER + 1
    local t = nCOUNTDOWNTIMER
    --print( t )
    local minutes = math.floor(t / 60)
    local seconds = t - (minutes * 60)
    local m10 = math.floor(minutes / 10)
    local m01 = minutes - (m10 * 10)
    local s10 = math.floor(seconds / 10)
    local s01 = seconds - (s10 * 10)
    local broadcast_gametimer = 
        {
            timer_minute_10 = m10,
            timer_minute_01 = m01,
            timer_second_10 = s10,
            timer_second_01 = s01,
        }
    CustomGameEventManager:Send_ServerToAllClients( "DownTime", broadcast_gametimer )
end

function SetClock( time )
    --print( "Set the clock to: " .. time )
    nCOUNTDOWNTIMER = time
end

function IsHeroMovingAnyMeans(pid)
	GameMode.tracker = GameMode.tracker or {[1] = Timers( function()
		GameMode.tracker["heroes"] = GameMode.tracker["heroes"] or (function() 
			local t = {}
			for i=0,PlayerResource:GetPlayerCount() do
				local h = PlayerResource:GetSelectedHeroEntity(i)
				if h and not h:IsNull() then
					t[tostring(i)] = h
				end
			end
			return t
		end)()

		for id,hero in pairs(GameMode.tracker["heroes"]) do
			GameMode.tracker[id] = GameMode.tracker[id] or {Vector(0,0,0), false}
			if not hero or hero:IsNull() then 
				hero = PlayerResource:GetSelectedHeroEntity(tonumber(id))
			else
				local Now = hero:GetAbsOrigin()
				local Then = GameMode.tracker[id][1]
				if (Now - Then):Length2D() > 10 then
					GameMode.tracker[id][2] = true
				else
					GameMode.tracker[id][2] = false
				end
				GameMode.tracker[id][1] = Now
			end
		end

		return 0.1
	end)}

	local step = GameMode.tracker[tostring(pid)]
	if step then 
		return step[2]
	end
	return false
end

function GetFirstPlace()
	--get the highest cp number and players who have reached that cp
	local highest, players = 0, {}
	for k,v in pairs(GameMode.tCPRecord) do
		local num = split(v, ",")
		if #num > highest then
			highest = #v
			players = {[1] = k}
		elseif #num == highest then
			table.insert(players, k)
		end
	end

	--grab ending location
	local entLoc = Entities:FindByName(nil, "End_Platform"):GetAbsOrigin()

	--calculate who is closest to ending
	if #players > 1 then
		local lowest,h = math.huge, nil
		for _,hero in pairs(players) do
			local path = GridNav:FindPathLength(hero:GetAbsOrigin(), entLoc)
			if path == -1 then
				path = (hero:GetAbsOrigin() - entLoc):Length2D()
				print("unpathable, using Length2D")
			end
			print("path: "..path)

			local cpNum = #split(tCPRecord[hero], ",")
			local cp1,cp2 = Entities:FindByName(nil, "CP_"..cpNum), Entities:FindByName(nil, "CP_"..cpNum+1)
			local cpPath = math.huge
			if cp1 and cp2 then
				print("cp's exist")
				cpPath = GridNav:FindPathLength(cp1:GetAbsOrigin(), cp2:GetAbsOrigin())
			end
			print("cpPath: "..cpPath)

			print("path > cpPath : ".. (path > cpPath) )
			if path > cpPath then
				print("path: "..path)
				path = (hero:GetAbsOrigin() - entLoc):Length2D()
			end

			print("path < lowest : ".. (path < lowest) )
			if path < lowest then
				print("lowest,h : ".. lowest..","..hero:GetName())
				lowest,h = path,hero
			end
		end
		return h
	else
		print("single player detected, skip comparisons. \nhero:"..players[1]:GetName())
		return players[1]
	end
end

function VectorToString(vec, ignoreZ, includeVECTOR)
	if includeVECTOR == true then includeVECTOR = nil end
	includeVECTOR = includeVECTOR or "Vector"
	ignoreZ = ignoreZ or false
	if not vec then return "" end
	return (includeVECTOR and includeVECTOR.."(" or "")..math.ceil(vec.x)..","..math.ceil(vec.y)..(not ignoreZ and ","..math.ceil(vec.z)..(includeVECTOR and ")" or "") or (includeVECTOR and ")" or "")) 
end

function PanoramaPrint(msg)
	CustomGameEventManager:Send_ServerToAllClients("print", {msg = msg})
end

function FindItemsAtPoint( point, radius )
	local t = {}
	local items = Entities:FindAllInSphere(point, radius)
	for k,v in pairs(items) do
		if v.GetContainedItem then
			table.insert(t, v)
		end
	end
	return t
end

function FindClearSpaceForItem( item, point )
	local width = 40 -- width of an item container
	local spacing = 60

	local direction = Vector(0,0,0)

	while #FindItemsAtPoint(point+direction*spacing, spacing-width) > 1 do
		local function nextDir(d)
			local x = d.x
			local y = d.y

			print("FindClearSpaceForItem | X: "..x..", Y: "..y)
			if x == 0 and y == 0 then x,y = 0,1
			elseif x == -1 and y > 0 then x,y = 1,1
			elseif y > x and y >= x * -1 then x,y = 1,0
			elseif y <= x and y > x * -1 then x,y = 0,-1
			elseif y < x and y <= x * -1 then x,y = -1,0
			elseif y >= x and y < x * -1 then x,y = 0,1
			end
			return Vector(x,y,0)
		end
		direction = nextDir(direction)
	end
	item:SetAbsOrigin(point + direction * spacing)
end

function split(pString, pPattern)
	local Table = {}
	local fpat = '(.-)' .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= '' then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
		cap = pString:sub(last_end)
		table.insert(Table, cap)
	end

	return Table
end

function DisplayError( pid, message )
  if pid then
    local player = PlayerResource:GetPlayer(pid)
    if player then
      CustomGameEventManager:Send_ServerToPlayer(player, "dotaHudErrorMessage", {message=(message or "#error")})
    end
  end
end

function CDOTA_BaseNPC:GetItemSlot(item)
  if item and not item:IsNull() then
    if item:IsItem() then
      for i = 0,DOTA_ITEM_MAX-1 do
        local itemInSlot = self:GetItemInSlot(i)
        if item == itemInSlot then
          return i
        end
      end
      return nil
    end
  end
end

function BoolToString(b)
  if b == true or b == 1 then return "true" end
  if b == false or b == 0 then return "false" end
end

function TableCount(t)
  local count = 0
  if type(t) == "table" then
    for k,v in pairs(t) do
      count = count+1
    end
  end
  return count
end

function CDOTA_BaseNPC:GetBackwardVector()
  return (self:GetAbsOrigin() - (self:GetAbsOrigin() + self:GetForwardVector())):Normalized()
end

function CDOTA_BaseNPC:GetLeftVector()
  return (self:GetAbsOrigin() - (self:GetAbsOrigin() + self:GetRightVector())):Normalized()
end

function CDOTA_BaseNPC:GetDownVector()
  return (self:GetAbsOrigin() - (self:GetAbsOrigin() + self:GetUpVector())):Normalized()
end

function PrintTable(t, indent, done)
  if type(t) ~= "table" then return end

  done = done or {}
  done[t] = true
  indent = indent or 0

  local l = {}
  for k, v in pairs(t) do
    table.insert(l, k)
  end

  table.sort(l)
  for k, v in ipairs(l) do
    -- Ignore FDesc
    if v ~= 'FDesc' then
      local value = t[v]

      if type(value) == "table" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..":")
        PrintTable (value, indent + 2, done)
      elseif type(value) == "userdata" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        PrintTable ((getmetatable(value) and getmetatable(value).__index) or getmetatable(value), indent + 2, done)
      else
        if t.FDesc and t.FDesc[v] then
          print(string.rep ("\t", indent)..tostring(t.FDesc[v]))
        else
          print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        end
      end
    end
  end
end


--orderfilter printer, prints only data relevant to the ordertype passed in filterTable
function PrintRelevent(t)
	local oT = {
		[0] = "DOTA_UNIT_ORDER_NONE",
		[1] = "DOTA_UNIT_ORDER_MOVE_TO_POSITION",
		[2] = "DOTA_UNIT_ORDER_MOVE_TO_TARGET",
		[3] = "DOTA_UNIT_ORDER_ATTACK_MOVE",
		[4] = "DOTA_UNIT_ORDER_ATTACK_TARGET",
		[5] = "DOTA_UNIT_ORDER_CAST_POSITION",
		[6] = "DOTA_UNIT_ORDER_CAST_TARGET",
		[7] = "DOTA_UNIT_ORDER_CAST_TARGET_TREE",
		[8] = "DOTA_UNIT_ORDER_CAST_NO_TARGET", 
		[9] = "DOTA_UNIT_ORDER_CAST_TOGGLE",
		[10] = "DOTA_UNIT_ORDER_HOLD_POSITION",
		[11] = "DOTA_UNIT_ORDER_TRAIN_ABILITY",
		[12] = "DOTA_UNIT_ORDER_DROP_ITEM",
		[13] = "DOTA_UNIT_ORDER_GIVE_ITEM",
		[14] = "DOTA_UNIT_ORDER_PICKUP_ITEM",
		[15] = "DOTA_UNIT_ORDER_PICKUP_RUNE",
		[16] = "DOTA_UNIT_ORDER_PURCHASE_ITEM",
		[17] = "DOTA_UNIT_ORDER_SELL_ITEM",
		[18] = "DOTA_UNIT_ORDER_DISASSEMBLE_ITEM",
		[19] = "DOTA_UNIT_ORDER_MOVE_ITEM",
		[20] = "DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO",
		[21] = "DOTA_UNIT_ORDER_STOP",
		[22] = "DOTA_UNIT_ORDER_TAUNT",
		[23] = "DOTA_UNIT_ORDER_BUYBACK",
		[24] = "DOTA_UNIT_ORDER_GLYPH",
		[25] = "DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH",
		[26] = "DOTA_UNIT_ORDER_CAST_RUNE",
		[27] = "DOTA_UNIT_ORDER_PING_ABILITY",
		[28] = "DOTA_UNIT_ORDER_MOVE_TO_DIRECTION",
		[29] = "DOTA_UNIT_ORDER_PATROL",
		[30] = "DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION",
		[31] = "DOTA_UNIT_ORDER_RADAR",
		[32] = "DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK",
		[33] = "DOTA_UNIT_ORDER_CONTINUE",
		[34] = "DOTA_UNIT_ORDER_VECTOR_TARGET_CANCELED",
		[35] = "DOTA_UNIT_ORDER_CAST_RIVER_PAINT"
	}
	--print all non-zero values. does print ordertype if it's zero
	local printed = false
	print()
	print("-------------")
	if t["order_type"] then
		for o,n in pairs(oT) do
			if t["order_type"] == o then
				print("order_type: "..n)
				printed = true
				break
			end
		end
	end
	if not printed then
		print("order_type: "..t["order_type"])
	end
	for k,v in pairs(t) do
		if type(v)=="table" then
			PrintTable({["units"]=v})
		end
		if k~="order_type" and type(v) ~= "table" and v ~= 0 then
			print(k..": "..v)
		end
	end
end