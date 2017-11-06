--[[ Snowboard Race checkpoints ]]

function Checkpoint_OnStartTouch( trigger )
	GameRules.GameMode.tCPRecord = GameRules.GameMode.tCPRecord or {}
	local tCPRecord = GameRules.GameMode.tCPRecord
	
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	print(hHero:GetName())
	local sCheckpointTriggerName = thisEntity:GetName() --this holds info on which checkpoint triggered
	print(sCheckpointTriggerName)
	local triggerflag = 1 --Assume triggered when function called
	print "all initial variable stored and declared"

	-- record checkpoint triggering player based on each case
	if tCPRecord[hHero:GetPlayerOwnerID()] == nil then
		tCPRecord[hHero:GetPlayerOwnerID()] = sCheckpointTriggerName
		triggerflag = 1
		print "create new key using playerID and store this value"
	elseif string.match(tCPRecord[hHero:GetPlayerOwnerID()],sCheckpointTriggerName) then
		triggerflag = 0 --set trigger to zero since repeated checkpoint
		print "checkpoint already triggered, get out of function without doing anything"
	else
		tCPRecord[hHero:GetPlayerOwnerID()] = tCPRecord[hHero:GetPlayerOwnerID()] .. "," .. sCheckpointTriggerName
		triggerflag = 1
		print "call existing playerID and add this to the value"
	end
	
	if triggerflag == 1 then
		--[[call Panorama Ui Code Here
		if sCheckpointTriggerName ~= "checkpoint00" then
			BroadcastMessage( "Activated " .. sCheckpointTriggerName, 3 )
			EmitGlobalSound( "DOTA_Item.Refresher.Activate" ) -- Checkpoint.Activate
		end]]
	end
end

