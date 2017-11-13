# changelog 

## v0.2
	
	### heroes
	+ all heroes now have fixed stats depending on their primary attribute
	+ all heroes now have 3 base abilities: jump, dash, pivot (can only be used while mounted)

	### mounts
	+ mount movement now uses movespeed bonuses

	### panorama
	+ added overthrow ui

	### ai
	+ added custom ai for all units

	### bug fixes
	+ toss requiring charges
	+ not picking a hero during hero pick screen will no longer not random your hero, resulting in having no hero at all	
	+ scrolling in will no longer mess up the camera, making the majority of the screen not rendered
	+ 7.07 stat bonuses have been properly adjusted, and added cooldown reduction for int heroes instead of magic resistance.


## v0.1

	### mounts
	+ reworked mount movement to work with forced motion
	+ fixed penguin spawning
	+ short delay before mount movement, double turn rate before movement starts
	+ trees now get destroyed upon crashing into them
	+ added various checks to improve mounting/dismounting
	+ each player is assigned their own mount, you cant use someone else's mount
	+ half-implemented support for different mounts

	### chat commands
	+ fixed newhero
	+ fixed debugremove
	+ added item and lvlup commands

	### known bugs
	+ not picking a hero during hero pick screen will not random your hero, resulting in having no hero at all
	+ scrolling in will mess up the camera, making the majority of the screen not rendered