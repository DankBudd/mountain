"use strict";

function DisplayError(data)
{
	GameEvents.SendEventClientSide("dota_hud_error_message", {
		"splitscreenplayer": 0,
		"reason": data.reason || 80,
		"message": data.message
	})
}

(function()
{
	GameEvents.Subscribe("dotaHudErrorMessage", DisplayError)
})();