--[[Snowboard Race random item spawner]]

function AutoSpawnItems()
	--list out all item spawning location in a table
	GameRules.GameMode.tItemSpawnLocation = GameRules.GameMode.tItemSpawnLocation or function()
    	local t = {}
    	for _,model in pairs(Entities:FindAllByModel("logo_radiant_winter_large")) do
    		t[model:entindex()] = model:GetAbsOrigin()
    	end
    	return t
  	end
   	--list out all items to be spawned in a table
   	GameRules.GameMode.tItemList = GameRules.GameMode.tItemList or function()
   		local itemkv = LoadKeyValues("scripts/npc/npc_abilities_override.txt")
		local integer = 1
		for key,value in pairs(itemkv) do
    		if string.match(key, "item_") then
        	--this is an item so store it into list
        		GameRules.GameMode.tItemList[integer] = value
   				integer = integer + 1
   			end
		end
		maxitems = integer --i want this maxvalue to be used outside of this function
		return itemkv
	end

   	--change time value to alter spawn frequency
    local repeat_interval = 30 -- Rerun this timer every *repeat_interval* game-time seconds
    local start_after = 30 -- Start this timer *start_after* game-time seconds later
   
	local ent = Entity:FindByName(nil, "random_item_spawner") 
    ent:SetThink(function()
  
      --code to spawn item at all 39 locations
      for i=1,39 do
      	CreateItemOnPositionSync(GameRules.GameMode.tItemSpawnLocation[i], GameRules.GameMode.tItemList[RandomInt(0, maxitems)])
      	--code for random item selector from item list
		--RandomInt(0, maxitems) 	--if zero would it spawn nothing? could make it having a chance of not spanwning any item (feature)?
		--[[Returns:int Get a random ''int'' within a range  ]]
      end 

      return repeat_interval
    end,"timer_60",start_after)
    
end

AutoSpawnItems()