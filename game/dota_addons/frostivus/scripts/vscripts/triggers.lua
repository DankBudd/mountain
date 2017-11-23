--[[ Snowboard Race check point recorder ]]

function Checkpoint_OnStartTouch( trigger )
	GameRules.GameMode.tCPRecord = GameRules.GameMode.tCPRecord or {}
	local tCPRecord = GameRules.GameMode.tCPRecord
	GameRules.GameMode.tCurrentPlacing = GameRules.GameMode.tCurrentPlacing or {}
	local tCurrentPlacing = GameRules.GameMode.tCurrentPlacing
	local totalplayer = PlayerResource:GetPlayerCount()-- code that grab total player
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	print(hHero:GetName())
	local sCheckpointTriggerName = thisEntity:GetName() --this holds info on which checkpoint triggered
	print(sCheckpointTriggerName)
	local triggerflag = 1 --Assume triggered when function called
	print "all initial variable stored and declared"
	tCurrentPlacing[sCheckpointTriggerName] = tCurrentPlacing[sCheckpointTriggerName] or {}
	-- record checkpoint triggering player based on each case
	if hHero:HasModifier("modifier_mount_movement") then
		if tCPRecord[hHero] == nil then
			tCPRecord[hHero] = sCheckpointTriggerName
			print "create new key using herohandle and store this value"
		elseif string.match(tCPRecord[hHero],sCheckpointTriggerName) then
			triggerflag = 0 --set trigger to zero since repeated checkpoint
			print "checkpoint already triggered, get out of function without doing anything"
		else
			tCPRecord[hHero] = tCPRecord[hHero] .. "," .. sCheckpointTriggerName
			print "call existing herohandle and add this to the value"
		end
		for k,v in pairs(tCPRecord) do
			print(k,v)
		end
		if triggerflag == 1 then
			local placing =  1 -- assume always first
			--- to account for exact number of players current placing and if leading player reaches next checkpoint before last player reaches previous checkpoint
			while tCurrentPlacing[sCheckpointTriggerName][placing] ~= hHero do
				--keep repeating until player has filled one slot
				--if first available slot is empty fill with hero else check next slot
				if tCurrentPlacing[sCheckpointTriggerName][placing] == nil then
					tCurrentPlacing[sCheckpointTriggerName][placing] = hHero
				else
					placing = placing + 1
				end
			end
			if placing == totalplayer and totalplayer ~= 1 then
				print ("give tusk summon to"..tostring(hHero:GetName()))
				--function call to unhide last player tusk summoning skill
				hHero:GetAbilityByIndex(3):SetHidden(false)
			end
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(hHero:GetPlayerID()), "increment_checkpoint", {})
		end
	end
end
