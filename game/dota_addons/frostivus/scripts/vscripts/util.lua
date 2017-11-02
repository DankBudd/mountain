

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
  if item then
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