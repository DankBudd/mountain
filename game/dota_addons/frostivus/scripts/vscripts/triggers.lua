--[[ Snowboard Race checkpoints ]]

function Checkpoint_OnStartTouch( trigger )
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	local sCheckpointTriggerName = thisEntity:GetName() --this holds info on which checkpoint triggered
	tblAccountRecord = {}
	-- record checkpoint triggering player
	if self._tPlayerIDToAccountRecord[hHero:GetPlayerID()] then
		tblAccountRecord = self._tPlayerIDToAccountRecord[hHero:GetPlayerID()]
	else
		self._tPlayerIDToAccountRecord[hHero:GetPlayerID()] = tblAccountRecord
	end
	if not tblAccountRecord["checkpoints"] then
		tblAccountRecord["checkpoints"] = sCheckpointTriggerName
	else
		tblAccountRecord["checkpoints"] = tblAccountRecord["checkpoints"] .. "," .. sCheckpointTriggerName
	end
	--call Panorama Ui Code Here
	--[[if sCheckpointTriggerName ~= "checkpoint00" then
		BroadcastMessage( "Activated " .. sCheckpointTriggerName, 3 )
		EmitGlobalSound( "DOTA_Item.Refresher.Activate" ) -- Checkpoint.Activate
	end]]
end

