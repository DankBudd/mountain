--[[Snowboard Race end game checker]]

function Ending_Check( trigger )
	GameRules.GameMode.tPointsRecord = GameRules.GameMode.tPointsRecord or {}
	local tPointsRecord = GameRules.GameMode.tPointsRecord --this holds info of all points obtained by player

	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	print(hHero:GetName())
	local triggerflag = 1 --Assume triggered when function called
	--check game rounds objective vote record
	------------------------- not sure but i think code should be somewhere else (different file)
	---GameRules.GameMode.tVoteRecord = GameRules.GameMode.tVoteRecord or {}
	---local tVoteRecord = GameRules.GameMode.tVoteRecord
	---GameRules.GameMode.TeamPoints = GameRules.GameMode.TeamPoints or {}
	---local TeamPoints = GameRules.GameMode.TeamPoints
	-------------------------
	--20(short) 35(medium) 50(long) team points to win

	--check checkpoint for cheating
	if string.match(GameRules.GameMode.tCPRecord[hHero:GetPlayerOwnerID()],"CP_1,CP_2,CP_3,CP_4,CP_5,CP_6,CP_7") then
		print "player passed all checkpoints"
		--give points to respective player for completing round honestly
		if tPointsRecord[10] == nil then
			tPointsRecord[10] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] + 10
			triggerflag = 2
		elseif tPointsRecord[8] == nil then
			tPointsRecord[8] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] + 8
		elseif tPointsRecord[6] == nil then
			tPointsRecord[6] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] + 6
		elseif tPointsRecord[4] == nil then
			tPointsRecord[4] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] + 4
		else
			tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] + 2
		end
	else
		print "player missed a checkpoint, do nothing"
		triggerflag = 0
		--include code that toss player away for cheating?
	end
	--function or code to sum team points up

	--countdown
	if triggerflag == 2 then
		local timeend = Time() + 30.00
		print(timeend-Time().."seconds left!!!")
		repeat
			Timers(1,function()
				print(timeend-Time().."seconds left!!!")
				return 0
			end)
		until(Time()>= timeend)
		--restart round if first place team points not greater than voted end point
		--function or code to sum team points up
		if TeamPoints[currentbest] < tVoteRecord[Selected] then
			--function call or code to send all players back to starting point
			--reset points placeholder
			tPointsRecord[10] = nil
			tPointsRecord[8] = nil
			tPointsRecord[6] = nil
			tPointsRecord[4] = nil
		else
			--code to call panorama UI
			--print scoreboard 
		end
	end
	
end