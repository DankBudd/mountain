--[[Snowboard Race end game checker]]

function Ending_Check( trigger )
	
	GameRules.GameMode.tPointsRecord = GameRules.GameMode.tPointsRecord or {}
	local tPointsRecord = GameRules.GameMode.tPointsRecord --this holds info of all points obtained by player
	GameRules.GameMode.TeamPoints = GameRules.GameMode.TeamPoints or {}
	local TeamPoints = GameRules.GameMode.TeamPoints--this holds info of total points obtained by each team
	--------------------------------------------------
	--12(short) 24(medium) 36(long) team points to win
	--------------------------------------------------
	GameRules.GameMode.SumTemp1 = GameRules.GameMode.SumTemp1 or {}
	SumTemp1 = GameRules.GameMode.SumTemp1
	GameRules.GameMode.SumTemp2 = GameRules.GameMode.SumTemp2 or {}
	SumTemp2 = GameRules.GameMode.SumTemp2
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
			if PlayerList[i]:GetTeamNumber() == 2 then
				if SumTemp1[1] == nil then
					SumTemp1[1] = tPointsRecord[PlayerList[i]]
				else
					SumTemp2[1] = tPointsRecord[PlayerList[i]]
				end
			elseif PlayerList[i]:GetTeamNumber() == 3 then
				if SumTemp1[2] == nil then
					SumTemp1[2] = tPointsRecord[PlayerList[i]]
				else
					SumTemp2[2] = tPointsRecord[PlayerList[i]]
				end	
			elseif PlayerList[i]:GetTeamNumber() == 6 then
				if SumTemp1[3] == nil then
					SumTemp1[3] = tPointsRecord[PlayerList[i]]
				else
					SumTemp2[3] = tPointsRecord[PlayerList[i]]
				end
			elseif PlayerList[i]:GetTeamNumber() == 7 then
				if SumTemp1[4] == nil then
					SumTemp1[4] = tPointsRecord[PlayerList[i]]
				else
					SumTemp2[4] = tPointsRecord[PlayerList[i]]
				end
			elseif PlayerList[i]:GetTeamNumber() == 8 then
				if SumTemp1[5] == nil then
					SumTemp1[5] = tPointsRecord[PlayerList[i]]
				else
					SumTemp2[5] = tPointsRecord[PlayerList[i]]
				end
			else
				print "wtf"
			end
		end
		TeamPoints[1] = (SumTemp1[1] or 0) + (SumTemp2[1] or 0)--enum 2 
		TeamPoints[2] = (SumTemp1[2] or 0) + (SumTemp2[2] or 0)--enum 3
		TeamPoints[3] = (SumTemp1[3] or 0) + (SumTemp2[3] or 0)--enum 6
		TeamPoints[4] = (SumTemp1[4] or 0) + (SumTemp2[4] or 0)--enum 7
		TeamPoints[5] = (SumTemp1[5] or 0) + (SumTemp2[5] or 0)--enum 8
		for i=1,5 do	
			if TeamPoints["currentbest"] <= TeamPoints[i] then
  				TeamPoints["currentbest"] = TeamPoints[i]
				winningteam = i
	   			print(winningteam)
			end	
		end			  			
	    for k,v in pairs(TeamPoints) do
			print(k,v) 
		end
		if winningteam == 1 then
	   		winningenum = 2
	   	elseif winningteam == 2 then
	   		winningenum = 3
	   	elseif winningteam == 3 then
	   		winningenum = 6
	   	elseif winningteam == 4 then
	   		winningenum = 7
	   	elseif winningteam == 5 then
	   		winningenum = 8
	   	end	
		if TeamPoints["currentbest"] >= GameRules.GameMode.tVoteRecord["Selected"] then
			for i=1,playerCount do
				if PlayerList[i]:GetTeamNumber() ~= winningenum then
					PlayerList[i]:AddNewModifier(nil, nil, "modifier_round_stun", {})
				else
					PlayerList[i]:RemoveModifierByName("modifier_round_stun")
				end
			end
			GameRules:SetGameWinner(winningteam)
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
							GameRules.GameMode.SumTemp1 = {}
							GameRules.GameMode.SumTemp2 = {} 
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