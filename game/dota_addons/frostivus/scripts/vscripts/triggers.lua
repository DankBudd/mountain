--[[ Snowboard Race check point recorder ]]

function Checkpoint_OnStartTouch( trigger )
	GameRules.GameMode.tCPRecord = GameRules.GameMode.tCPRecord or {}
	local tCPRecord = GameRules.GameMode.tCPRecord
	GameRules.GameMode.tCurrentPlacing = GameRules.GameMode.tCurrentPlacing or {}
	local tCurrentPlacing = GameRules.GameMode.tCurrentPlacing
	local totalplayer = PlayerResource:GetPlayerCount()-- code that grab total player
	local place = 1
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	print(hHero:GetName())
	local sCheckpointTriggerName = thisEntity:GetName() --this holds info on which checkpoint triggered
	print(sCheckpointTriggerName)
	local triggerflag = 1 --Assume triggered when function called
	print "all initial variable stored and declared"
	tCurrentPlacing[sCheckpointTriggerName] = tCurrentPlacing[sCheckpointTriggerName] or {}
	-- record checkpoint triggering player based on each case
	if hHero:HasModifier("modifier_mount_movement") then
		if tCPRecord[hHero:GetPlayerOwnerID()] == nil then
			tCPRecord[hHero:GetPlayerOwnerID()] = sCheckpointTriggerName
			triggerflag = 2
			print "create new key using playerID and store this value"
		elseif string.match(tCPRecord[hHero:GetPlayerOwnerID()],sCheckpointTriggerName) then
			triggerflag = 0 --set trigger to zero since repeated checkpoint
			print "checkpoint already triggered, get out of function without doing anything"
		else
			tCPRecord[hHero:GetPlayerOwnerID()] = tCPRecord[hHero:GetPlayerOwnerID()] .. "," .. sCheckpointTriggerName
			triggerflag = 2
			print "call existing playerID and add this to the value"
		end
		if triggerflag == 2 then
			--- to account for exact number of players current placing and if leading player reaches next checkpoint before last player reaches previous checkpoint
			while tCurrentPlacing[sCheckpointTriggerName][place] ~= hHero:GetPlayerOwnerID() do
				if tCurrentPlacing[sCheckpointTriggerName][place] == nil then
					tCurrentPlacing[sCheckpointTriggerName][place] = hHero:GetPlayerOwnerID()
				else
					place = place + 1
				end
			end
			if place == totalplayer and totalplayer ~= 1 then
				--function call to give last player tusk summoning skill
				print ("give tusk summon to"..hHero:GetPlayerOwnerID())
				--reset all placeholder to nil for the next round if there is one
				for i=1,totalplayer do
					tCurrentPlacing[sCheckpointTriggerName][i] = nil
				end

			end
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(hHero:GetPlayerID()), "increment_checkpoint", {})
		elseif triggerflag == 0 then
			--notify player checkpoint already triggered
		end
	end
end
