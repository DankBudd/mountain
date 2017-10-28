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