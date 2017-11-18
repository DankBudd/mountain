--[[Snowboard Race end game checker]]

function Ending_Check( trigger )
	GameRules.GameMode.tPointsRecord = GameRules.GameMode.tPointsRecord or {}
	local tPointsRecord = GameRules.GameMode.tPointsRecord --this holds info of all points obtained by player
	GameRules.GameMode.TeamPoints = GameRules.GameMode.TeamPoints or {}
	local TeamPoints = GameRules.GameMode.TeamPoints--this holds info of total points obtained by each team
	--GameRules.GameMode.PlayerList = GameRules.GameMode.PlayerList or PlayerResource:GetAllHeroes()--Returns table of all the heroes in the world
	GameRules.GameMode.PlayerList = GameRules.GameMode.PlayerList or {}
	local PlayerList = GameRules.GameMode.PlayerList--this holds info of the current list of players in game
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	print(hHero:GetName())
	local triggerflag = 1 --Assume triggered when function called
	GameRules.GameMode.tVoteRecord = GameRules.GameMode.tVoteRecord or {}
	local tVoteRecord = GameRules.GameMode.tVoteRecord
	------------------------- not sure but i think code should be somewhere else (different file)
	--12(short) 24(medium) 36(long) team points to win
	-------------------------
	
	tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] or 0
	--check checkpoint for cheating
	if string.match(GameRules.GameMode.tCPRecord[hHero:GetPlayerOwnerID()],"CP_1,CP_2,CP_3,CP_4,CP_5,CP_6,CP_7") ~= nil and hHero:HasModifier("modifier_mount_movement") then
		print "player passed all checkpoints with mount"
		--give points to respective player for completing round honestly
		if tPointsRecord[7] == nil then
			tPointsRecord[7] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = 7 + tPointsRecord[hHero:GetPlayerOwnerID()]
			triggerflag = 2
		elseif tPointsRecord[5] == nil then
			tPointsRecord[5] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = 5 + tPointsRecord[hHero:GetPlayerOwnerID()]
		elseif tPointsRecord[3] == nil then
			tPointsRecord[3] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = 3 + tPointsRecord[hHero:GetPlayerOwnerID()]
		elseif tPointsRecord[2] == nil then
			tPointsRecord[2] = "taken"
			tPointsRecord[hHero:GetPlayerOwnerID()] = 2 + tPointsRecord[hHero:GetPlayerOwnerID()]
		else
			tPointsRecord[hHero:GetPlayerOwnerID()] = 1 + tPointsRecord[hHero:GetPlayerOwnerID()]
		end
	else
		print "player missed a checkpoint or not mounted, do nothing"
		triggerflag = 0
		--include code that toss player away for cheating?
	end
	

	--perform countdown operation
	if triggerflag == 2 then
		local timeEnd = GameRules:GetGameTime() + 30
		--GameEvents.Subscribe("countdown", CountDown);
		CustomGameEventManager:Send_ServerToAllClients( "countdown", {0,0})
		Timers(0, function()
     		if GameRules:GetGameTime() >= timeEnd then
        		return
    		end
    		print(math.ceil(timeEnd - GameRules:GetGameTime()).." seconds left!")
    		return 1
		end)
     	local playerCount = 0
    	for i=DOTA_TEAM_GOODGUYS, DOTA_TEAM_CUSTOM_3 do
			playerCount = playerCount + PlayerResource:GetPlayerCountForTeam(i)
		end

    	PlayerList[1] = PlayerList[1] or {}
    	PlayerList[2] = PlayerList[2] or {}
		for i=0,playerCount do
			PlayerList[1][i] = PlayerResource:GetPlayer(i)
			PlayerList[2][i] = PlayerResource:GetTeam(i)
		end
		print "playerlist"
		--PrintTable(PlayerList)
		for i=1,5 do
			TeamPoints[i] = TeamPoints[i] or 0
		end
		TeamPoints["currentbest"] = TeamPoints["currentbest"] or 0
		--code to sum team points up
		for i=0,playerCount do
			if string.match(PlayerList[2][i],"DOTA_TEAM_GOODGUYS") ~= nil then
				TeamPoints[1] = TeamPoints[1] + tPointsRecord(PlayerList[1][i]:GetPlayerOwnerID())
			elseif string.match(PlayerList[2][i],"DOTA_TEAM_BADGUYS")  ~= nil then
				TeamPoints[2] = TeamPoints[2] + tPointsRecord(PlayerList[1][i]:GetPlayerOwnerID())
			elseif string.match(PlayerList[2][i],"DOTA_TEAM_CUSTOM_1")  ~= nil then
				TeamPoints[3] = TeamPoints[3] + tPointsRecord(PlayerList[1][i]:GetPlayerOwnerID())
			elseif string.match(PlayerList[2][i],"DOTA_TEAM_CUSTOM_2")  ~= nil then
				TeamPoints[4] = TeamPoints[4] + tPointsRecord(PlayerList[1][i]:GetPlayerOwnerID())
			elseif string.match(PlayerList[2][i],"DOTA_TEAM_CUSTOM_3")  ~= nil then
				TeamPoints[5] = TeamPoints[5] + tPointsRecord(PlayerList[1][i]:GetPlayerOwnerID())
			else
				print"didntenteranyifcase"
			end
		end
    	for i=1,5 do
    		if TeamPoints["currentbest"] <= TeamPoints[i] then
    			TeamPoints["currentbest"] = TeamPoints[i]
    		end
    	end
    	--PrintTable(TeamPoints)
		--restart round if first place team points not greater than voted end point
		--function or code to sum team points up
		print(TeamPoints["currentbest"])
		--print(GameRules.GameMode.tVoteRecord["Selected"])
		--check game rounds objective vote record
		if TeamPoints["currentbest"] < GameRules.GameMode.tVoteRecord["Selected"] then
			--function call or code to send all players back to starting point
			--reset placeholder to nil
			tPointsRecord[7] = nil
			tPointsRecord[5] = nil
			tPointsRecord[3] = nil
			tPointsRecord[2] = nil
		else
			--code to call panorama UI
			--print scoreboard 
		end
		print "EndHere"
	end
	
end