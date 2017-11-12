Thinkers = {
	Init = function(self)
		self.thinkers = {}
		local ent = SpawnEntityFromTableSynchronous("info_target", {targetname = "thinker"})
		ent:SetThink("Think", self)
	end,

	Think = function(self)
		local time = GameRules:GetGameTime()
		for k,v in pairs(self.thinkers) do

			if time >= v.nextThink then

				local success,int = xpcall(function()
					return (v.context and v.callback(v.context, v)) or v.callback(v)
				end, function(err)
					return err.."\n"..debug.traceback().."\n"
				end)

				if success then
					if int then
						self.thinkers[k].nextThink = time + int
					else
						self.thinkers[k] = nil	
					end
				else
					print("thinker has failed: "..k)
					print(int)
					self.thinkers[k] = nil
				end
			end
		end
		return 0.01
	end,
}

Thinkers:Init()

function Timers(delay, args, context)
	if type(delay) == "function" then
		context = args
		args = delay
		delay = 0
	end
	local name = DoUniqueString("thinker")
	Thinkers.thinkers[name] = {nextThink = GameRules:GetGameTime()+delay, callback = args, context = context}
	return name
end