var Dialogues = {};

//params -- entindex, text
function SetDialogue( params ) {
	var dialogue = Dialogues[entindex]
	if (dialogue) {
		//localize the string if needed
		if (params.text.substring(0, 1) === "#") {
			params.text = $.Localize(params.text);
		}

		dialogue.text = params.text;
	} else { 
		if (!params.repeated) {
			params.repeated = true;
			SetDialogue(params);
		}
	}
}

function UpdateDialogues() {
	$.Schedule(1/120, UpdateDialogues)
	var mainPanel = $.GetContextPanel();
	var classes = [ "npc_dota_creep_neutral", "npc_dota_creature"];

	//grab heroes
	var ents = Entities.GetAllHeroEntities().filter(function(entity) {
		return HasModifier(entity, "modifier_dialogue")
	});

	//grab non heroes
	for (var cl of classes) {
		all = all.concat(Entities.GetAllEntitiesByClassName(cl).filter(function(entity) {
			return HasModifier(entity, "modifier_dialogue");
		}));
	}

	var OnScreen = _.chain(all)
		.reject(function(entity) {
			return Entities.IsOutOfGame(entity);
		})
		.filter(function(entity) {
			return Entities.IsAlive(entity);
		})
		.map(function(entity) {
			var abs = Entities.GetAbsOrigin(entity);
			var lightBar = HasModifier(entity, "modifier_dialogue");
			var offset = Entities.GetHealthBarOffset(entity);

			var x = Game.WorldToScreenX(abs[0], abs[1], abs[2]+offset);
			var y = Game.WorldToScreenY(abs[0], abs[1], abs[2]+offset);

			return {id: entity, x: x, y: y, abs: abs}
		})
		.reject(function(mapped) {
			return mapped.x = -1 || mapped.y == -1;
		})
		.filter(function(mapped) {
			return GameUI.GetScreenWorldPosition(mapped.x, mapped.y) != null;
		})
		.each(function(entity) {
			if (_.has(Dialogues, entity.id)) {
				//update position
				PositionDialogues(entity)
			} else {
				//create dialogue
				var panel = $.CreatePanel("Panel", mainPanel, "");
				panel.BLoadLayoutSnippet("DialogueBox");

				$.Msg(panel);
				
				//store dialogue
				Dialogues[entity.id] = panel;
				//update position
				PositionDialogues(entity);
			}
		}).value();

	var oldEnts = _.omit(Dialogues, function(value, key) {
		return _.some(OnScreen, function(entity) { return entity.id == key });
	});

	_.each(oldEnts, function(panel, key) {
		panel.DeleteAsync(0);
		delete Dialogue[key];
	});
}

function PositionDialogues(entity, spawn) {
	var panel = Dialogue[entity.id];
	
	var screenHR = Game.GetScreenHeight() / 1080;

	entity.x /= screenHR;
	entity.y /= screenHR;
	
	//	panel.style.x = (Math.floor(entity.x) - Math.round(Math.max(pieceSize * max, 140) / 2)) + "px";
	panel.style.x = (Math.floor(entity.x) + "px";
	panel.style.y = (Math.floor(entity.y) - 50) + "px";

//	var text = panel.FindChildTraverse("Dialogue")
//	text.text = "TODO:";
}

GameEvents.Subscribe( "SetDialogue", SetDialogue( params ) );
UpdateDialogues()