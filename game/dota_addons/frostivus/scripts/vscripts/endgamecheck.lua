--[[Snowboard Race end game checker]]

function Ending_Check( trigger )
	
	GameRules.GameMode.tPointsRecord = GameRules.GameMode.tPointsRecord or {}
	local tPointsRecord = GameRules.GameMode.tPointsRecord --this holds info of all points obtained by player
	GameRules.GameMode.TeamPoints = GameRules.GameMode.TeamPoints or {}
	local TeamPoints = GameRules.GameMode.TeamPoints--this holds info of total points obtained by each team
	--------------------------------------------------
	--12(short) 24(medium) 36(long) team points to win
	--------------------------------------------------
	GameRules.GameMode.PlayerList = GameRules.GameMode.PlayerList or {}
	local PlayerList = GameRules.GameMode.PlayerList--this holds info of the current list of players in game
	local hHero = trigger.activator --this holds info on checkpoint trigger hero
	print(hHero:GetName())
	local triggerflag = 1 --Assume triggered when function called
	GameRules.GameMode.tVoteRecord = GameRules.GameMode.tVoteRecord or {}
	local tVoteRecord = GameRules.GameMode.tVoteRecord
	GameRules.GameMode.tRComplete = GameRules.GameMode.tRComplete or {}
	local tRComplete = GameRules.GameMode.tRComplete--this holds info of hero completing current round for roundstunner
	
	tPointsRecord[hHero:GetPlayerOwnerID()] = tPointsRecord[hHero:GetPlayerOwnerID()] or 0
	--check checkpoint for cheating
	if string.match(GameRules.GameMode.tCPRecord[hHero:GetPlayerOwnerID()],"CP_1,CP_2,CP_3,CP_4,CP_5,CP_6,CP_7") ~= nil and hHero:HasModifier("modifier_mount_movement") then
		print "player passed all checkpoints with mount"
		--store hero completing current round data
		local z = z or 1
		if tRComplete[z] == nil then
			tRComplete[z] = hHero
		end
		z = z + 1
		--stuns player for infinite duration at the end of round
		hHero:AddNewModifier(nil, nil, "modifier_round_stun", {})
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
		local event1data = {key1=30,key2=nil}
		Timers(0, function()
     		print(event1data.key1.." seconds left!")
     		CustomGameEventManager:Send_ServerToAllClients( "countdown", event1data)
     		event1data.key1 = event1data.key1 - 1
     		if event1data.key1 < -1 or #tRComplete >= PlayerResource:GetPlayerCount() then
        		CustomGameEventManager:Send_ServerToAllClients( "countdown", {key1=0,key2="stop"})
        		local playerCount = 0
    			for i=DOTA_TEAM_GOODGUYS, DOTA_TEAM_CUSTOM_3 do
					playerCount = playerCount + PlayerResource:GetPlayerCountForTeam(i)
				end
		    	PlayerList[1] = PlayerList[1] or {}
    			PlayerList[2] = PlayerList[2] or {}
				for i=1,playerCount do
					PlayerList[1][i] = PlayerResource:GetPlayer(i-1)
					PlayerList[2][i] = PlayerResource:GetTeam(i-1)
				end
				print "playerlist"
				print(PlayerList[1][1])
				--PrintTable(PlayerList)
				for i=1,5 do
					TeamPoints[i] = TeamPoints[i] or 0
				end
				TeamPoints["currentbest"] = TeamPoints["currentbest"] or 0
				--code to sum team points up
				for i=1,playerCount do
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
				
				print(TeamPoints["currentbest"])
				--print(GameRules.GameMode.tVoteRecord["Selected"])
				--check game rounds objective vote record
				--restart round if first place team points not greater than voted end point
				if TeamPoints["currentbest"] < GameRules.GameMode.tVoteRecord["Selected"] then
					--new round countdown
					local event2data = {key1=3,key2="Start!"}
					Timers(0, function()
     					print(event2data.key1.." seconds left!")
     					CustomGameEventManager:Send_ServerToAllClients( "countdown", event2data)
    					event2data.key1 = event2data.key1 - 1
    					if event2data.key1 < -1 then
    						CustomGameEventManager:Send_ServerToAllClients( "countdown", {key1=0,key2="stop"})
        					--remove the stun modifier from each player
							for i=1,playerCount do
								local hero = PlayerResource:GetSelectedHeroEntity(PlayerList[1][i]:GetPlayerID())
								hero:RemoveModifierByName("modifier_round_stun")
							end
							--reset placeholder to nil
							tPointsRecord[7] = nil
							tPointsRecord[5] = nil
							tPointsRecord[3] = nil
							tPointsRecord[2] = nil
        					return
    					end
    					return 1
					end)
			
				else
					--code to call panorama UI
					--print scoreboard 
				end
				print "EndHere"
        		return
    		end
    		return 1
		end)
	end
end