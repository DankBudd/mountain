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
	GameRules.GameMode.tRComplete = GameRules.GameMode.tRComplete or {}
	local tRComplete = GameRules.GameMode.tRComplete--this holds info of hero completing current round for roundstunner
	local playerCount = PlayerResource:GetPlayerCount()
	TeamPoints["currentbest"] = TeamPoints["currentbest"] or 0
	tPointsRecord[hHero] = tPointsRecord[hHero] or 0
	winningteam = winningteam or 0
	--check checkpoint for cheating
	if string.match(GameRules.GameMode.tCPRecord[hHero],"CP_1,CP_2,CP_3,CP_4,CP_5,CP_6,CP_7") ~= nil and hHero:HasModifier("modifier_mount_movement") then
		print "player passed all checkpoints with mount"
		--store hero completing current round data
		local VarNum = VarNum or 1
		if tRComplete[VarNum] == nil then
			tRComplete[VarNum] = hHero
			VarNum = VarNum + 1
		end
		--stuns player for infinite duration at the end of round
		hHero:AddNewModifier(nil, nil, "modifier_round_stun", {})
		--give points to respective player for completing round honestly
		if tPointsRecord[7] == nil then
			tPointsRecord[7] = "taken"
			tPointsRecord[hHero] = 7 + tPointsRecord[hHero]
			triggerflag = 2
		elseif tPointsRecord[5] == nil then
			tPointsRecord[5] = "taken"
			tPointsRecord[hHero] = 5 + tPointsRecord[hHero]
		elseif tPointsRecord[3] == nil then
			tPointsRecord[3] = "taken"
			tPointsRecord[hHero] = 3 + tPointsRecord[hHero]
		elseif tPointsRecord[2] == nil then
			tPointsRecord[2] = "taken"
			tPointsRecord[hHero] = 2 + tPointsRecord[hHero]
		else
			tPointsRecord[hHero] = 1 + tPointsRecord[hHero]
		end
	else
		print "player missed a checkpoint or not mounted, do nothing"
		triggerflag = 0
		--ai will auto toss any player that gets close so if cheat too bad
	end
	for k,v in pairs(tPointsRecord) do
			print(k,v)
	end
	
	if triggerflag ~= 0 then		
		
		for i = 1,5 do
			if TeamPoints[i] == nil then
				TeamPoints[i] = 0
			end
		end
		
		--code to sum team points up
		for i=1,playerCount do --enum 2,3,6,7,8 --good,bad,custom:1;2;3
			PlayerList[i] = PlayerResource:GetSelectedHeroEntity(i-1)
			if tPointsRecord[PlayerList[i]] == nil then
				tPointsRecord[PlayerList[i]] = 0
			end
		end
		local teams = {
			DOTA_TEAM_GOODGUYS,
			DOTA_TEAM_BADGUYS,
			DOTA_TEAM_CUSTOM_1,
			DOTA_TEAM_CUSTOM_2,
			DOTA_TEAM_CUSTOM_3,
		}
		local scores = {}
		for _,t in pairs(teams) do
			scores[t] = {}
			local cap = PlayerResource:GetPlayerCountForTeam(t)
			for x = 1,cap do
				local pid = PlayerResource:GetNthPlayerIDOnTeam(t, x)
				local h = PlayerResource:GetSelectedHeroEntity(pid)

				scores[t][h] = tPointsRecord[h]
				if x==cap then
					scores[t]["total"] = 0
					for l,m in pairs(scores[t]) do
						if not l == "total" then
							scores[t]["total"] = scores[t]["total"] + m
						end
					end
				end
			end
		end
		CustomGameEventManager:Send_ServerToAllClients("SetScoreForTeam", {team = 2, score = scores[2]["total"]})
		CustomGameEventManager:Send_ServerToAllClients("SetScoreForTeam", {team = 3, score = scores[3]["total"]})
		CustomGameEventManager:Send_ServerToAllClients("SetScoreForTeam", {team = 6, score = scores[6]["total"]})
		CustomGameEventManager:Send_ServerToAllClients("SetScoreForTeam", {team = 7, score = scores[7]["total"]})
		CustomGameEventManager:Send_ServerToAllClients("SetScoreForTeam", {team = 8, score = scores[8]["total"]})
		
		TeamPoints["currentbest"] = 0
		winningenum = nil
		for k,v in pairs({[DOTA_TEAM_GOODGUYS] = scores[DOTA_TEAM_GOODGUYS]["total"], [DOTA_TEAM_BADGUYS] = scores[DOTA_TEAM_BADGUYS]["total"], [DOTA_TEAM_CUSTOM_1] = scores[DOTA_TEAM_CUSTOM_1]["total"], [DOTA_TEAM_CUSTOM_2] = scores[DOTA_TEAM_CUSTOM_2]["total"], [DOTA_TEAM_CUSTOM_3] = scores[DOTA_TEAM_CUSTOM_3]["total"]}) do
			if v > TeamPoints["currentbest"] then
				TeamPoints["currentbest"] = v
				winningenum = k
			end
		end
		if TeamPoints["currentbest"] >= GameRules.GameMode.tVoteRecord["Selected"] then
			for i=1,playerCount do
				if PlayerList[i]:GetTeamNumber() ~= winningenum then
					PlayerList[i]:AddNewModifier(nil, nil, "modifier_round_stun", {})
				else
					PlayerList[i]:RemoveModifierByName("modifier_round_stun")
				end
			end
			CustomGameEventManager:Send_ServerToAllClients( "countdown", {key1=0,key2="stop"})
			Thinkers.thinkers = {}
			GameRules:SetGameWinner(winningenum)
		end
		print "EndHere"
	end
	--perform countdown operation
	if triggerflag == 2 then
		local event1data = {key1=30,key2=nil}
		Timers(0, function()
     		print(event1data.key1.." seconds left!")
     		CustomGameEventManager:Send_ServerToAllClients( "countdown", event1data)
     		event1data.key1 = event1data.key1 - 1
     		if event1data.key1 < -1 or #tRComplete >= playerCount then
        		CustomGameEventManager:Send_ServerToAllClients( "countdown", {key1=0,key2="stop"})
         		local tploc = Entities:FindByName(nil, "Spawnitem_trigger"):GetAbsOrigin()
				print "playerlist"
				for i=1,playerCount do
					
					--code to stun and teleport all players to starting point
					PlayerList[i]:AddNewModifier(nil, nil, "modifier_round_stun", {})
					PlayerList[i]:SetAbsOrigin(tploc+Vector(-900,(i-7)*140,0))
					PlayerList[i]:SetForwardVector(Vector(1,-1,0))
					local item --remove items before next round begins
					for n =0,8 do
						item = PlayerList[i]:GetItemInSlot(n)
						if item ~= nil then	
							PlayerList[i]:RemoveItem(item)
						end
					end
					GameMode:GiveMount(PlayerList[i], "npc_dota_penguin")
					print(PlayerList[i])
				end	
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(hHero:GetPlayerID()), "increment_checkpoint", {reset=true})		
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(hHero:GetPlayerID()), "update_cp_distance", {distance="0/0",slider="0.1%"})	

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
								PlayerList[i]:RemoveModifierByName("modifier_round_stun")
							end
							--reset placeholder, round checkpoint and current placing to nil
							tPointsRecord[7] = nil
							tPointsRecord[5] = nil
							tPointsRecord[3] = nil
							tPointsRecord[2] = nil
							VarNum = 1
							GameRules.GameMode.tCPRecord = {}
							GameRules.GameMode.tCurrentPlacing = {}
							GameRules.GameMode.tRComplete = {}
        					return
    					end
    					return 1
					end)
				end

        		return
    		end
    		return 1
		end)
	end
end