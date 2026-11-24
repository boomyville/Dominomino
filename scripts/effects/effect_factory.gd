extends RefCounted
## Turns a row of the catalogue ({k, m, a, b, t}) into an Effect object of the right class.

const KINDS := {
	"dmg": preload("res://scripts/effects/effect_damage.gd"),
	"hit": preload("res://scripts/effects/effect_multi_hit.gd"),
	"shield": preload("res://scripts/effects/effect_shield.gd"),
	"maxs": preload("res://scripts/effects/effect_max_shield.gd"),
	"draw": preload("res://scripts/effects/effect_draw.gd"),
	"discR": preload("res://scripts/effects/effect_discard_random.gd"),
	"discP": preload("res://scripts/effects/effect_discard_pick.gd"),
	"tutor": preload("res://scripts/effects/effect_tutor.gd"),
	"power": preload("res://scripts/effects/effect_power.gd"),
	"boost": preload("res://scripts/effects/effect_boost.gd"),
	"heal": preload("res://scripts/effects/effect_heal.gd"),
	"rerollA": preload("res://scripts/effects/effect_reroll_all.gd"),
	"rerollP": preload("res://scripts/effects/effect_reroll_pick.gd"),
	"fury": preload("res://scripts/effects/effect_fury.gd"),
	"impS": preload("res://scripts/effects/effect_impair_self.gd"),
	"impE": preload("res://scripts/effects/effect_impair_enemy.gd"),
	"selfdmg": preload("res://scripts/effects/effect_self_damage.gd"),
	"gen": preload("res://scripts/effects/effect_generate.gd"),
	"life": preload("res://scripts/effects/effect_life.gd"),
	"paylife": preload("res://scripts/effects/effect_pay_life.gd"),
	"pipdmg": preload("res://scripts/effects/effect_pip_damage.gd"),
	"playedpips": preload("res://scripts/effects/effect_played_pips.gd"),
	"uptick": preload("res://scripts/effects/effect_uptick.gd"),
}


static func make(row: Dictionary):
	var e = KINDS[row.k].new()
	e.setup(row)
	return e
