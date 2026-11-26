extends RefCounted
## Turns a condition id from the catalogue into a Condition object ("" means no condition).

const IDS := {
	"noSix": preload("res://scripts/conditions/cond_no_six.gd"),
	"hand6": preload("res://scripts/conditions/cond_hand_six.gd"),
	"handLe3": preload("res://scripts/conditions/cond_hand_three.gd"),
	"noShield": preload("res://scripts/conditions/cond_no_shield.gd"),
	"noAtk": preload("res://scripts/conditions/cond_no_attack.gd"),
	"noHpLost": preload("res://scripts/conditions/cond_no_hp_lost.gd"),
	"first": preload("res://scripts/conditions/cond_first_play.gd"),
	"played9": preload("res://scripts/conditions/cond_played_nine.gd"),
	"lowHp": preload("res://scripts/conditions/cond_low_hp.gd"),
	"enShield": preload("res://scripts/conditions/cond_enemy_shield.gd"),
	"lives2": preload("res://scripts/conditions/cond_lives.gd"),
	"hand4": preload("res://scripts/conditions/cond_hand_four.gd"),
	"onlyAttacks": preload("res://scripts/conditions/cond_only_attacks.gd"),
	"turn2": preload("res://scripts/conditions/cond_not_first_turn.gd"),
	"never": preload("res://scripts/conditions/cond_never.gd"),
}


static func make(id: String):
	if id == "":
		return null
	return IDS[id].new()
