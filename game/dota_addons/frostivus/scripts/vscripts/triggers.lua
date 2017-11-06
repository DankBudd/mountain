--[[ Snowboard Race checkpoints ]]

function Checkpoint_OnStartTouch( trigger )
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	local sCheckpointTriggerName = thisEntity:GetName() --this holds info on which checkpoint triggered
	local trigger = 1 --Assume triggered when function called
	local tCPRecord = {}--construct table 
	print "all initial variable stored and declared"
	-- record checkpoint triggering player based on each case
	if tCPRecord[hHero:GetPlayerID()] == nil then
		tCPRecord[hHero:GetPlayerID()] = sCheckpointTriggerName
		trigger = 1
		print "create new key using playerID and store this value"
	else if string.match(tCPRecord[hHero:GetPlayerID()],sCheckpointTriggerName) then
		trigger = 0 --set trigger to zero since repeated checkpoint
		print "checkpoint already triggered, get out of function without doing anything"
	else
		tCPRecord[hHero:GetPlayerID()] = tCPRecord[hHero:GetPlayerID()] .. "," .. sCheckpointTriggerName
		trigger = 1
		print "call existing playerID and add this to the value"
	end
	
	if trigger == 1 then
		--[[call Panorama Ui Code Here
		if sCheckpointTriggerName ~= "checkpoint00" then
			BroadcastMessage( "Activated " .. sCheckpointTriggerName, 3 )
			EmitGlobalSound( "DOTA_Item.Refresher.Activate" ) -- Checkpoint.Activate
		end]]
	end
end

