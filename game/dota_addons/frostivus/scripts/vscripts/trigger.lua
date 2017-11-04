function CP_OnStartTouch( keys )
	local hero = keys.activator
	local triggerName = thisEntity:GetName()
	print("trigger: "..triggerName, "entered by hero: "..hero:GetUnitName())
	
end