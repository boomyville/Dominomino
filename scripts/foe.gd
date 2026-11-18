extends "res://scripts/combatant.gd"
## The enemy: a Combatant with a level, a name and the intents it has planned for its next turn.

const NAMES := ["Gruff Hare", "Bone Rabbit", "Iron Hare", "Void Rabbit", "Warlord Hare"]

var lv := 1
var title := ""
var intent := []     # [{k: "atk" | "blk" | "lifeatk" | "discH" | "mill" | "junk", v}]


func _init(level: int = 1) -> void:
	var hit_points := 70 + (level - 1) * 10 + (level - 1) * (level - 1) * 5
	super(hit_points)
	lv = level
	title = NAMES[level - 1] if level <= NAMES.size() else "Hare Lord %d" % level
