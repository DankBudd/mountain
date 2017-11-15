"use strict";

(function() {
	GameEvents.Subscribe( "camera_zoom", function(args) {
	    $.Msg("Setting camera distance to: " + args.distance);
		GameUI.SetCameraDistance( Number(args.distance) );
	});
})();