--[[Snowboard Race random item spawner]]

function AutoSpawnItems()
	--list out all item spawning location in a table
	if not _G.tItemSpawnLocation then
		_G.tItemSpawnLocation = {}
		for i=1,39 do
			local ent = Entities:FindByName(nil, "itemspawnlocation_"..i)
			_G.tItemSpawnLocation[i] = ent:GetAbsOrigin()
			print "grabbing locations"
		end
	end
  	print "finish first table"
  	PrintTable(_G.tItemSpawnLocation)
   	--list out all items to be spawned in a table
	if not _G.tItemList then
		_G.tItemList = {}
		local itemkv = LoadKeyValues("scripts/npc/npc_abilities_override.txt")
		for key,value in pairs(itemkv) do
			--this is an item so store it into list
			if string.match(key, "item_") then
				table.insert(_G.tItemList, key)
			end
		end
	end
	print "finish second table"
	PrintTable(_G.tItemList)
   	--change time value to alter spawn frequency
    local repeat_interval = 15 -- Rerun this timer every *repeat_interval* game-time seconds
    local start_after = 1 -- Start this timer *start_after* game-time seconds later
	    
	Timers(start_after, function()
        --code to spawn item at all locations specified from table
        for i=1,#_G.tItemSpawnLocation do
            local rand = RandomInt(0, #_G.tItemList)
        	if rand ~= 0 then
                local item = CreateItem(_G.tItemList[rand], nil, nil)
                CreateItemOnPositionSync(_G.tItemSpawnLocation[i], item)
                print ("item spawned: "..item:GetName())
           	end
        end 
        return repeat_interval
    end)
end
--AutoSpawnItems()