extends RefCounted
## What each status (and shield, lives) means, for the "status effect information" cards that can be
## shown under a domino's info. Add an entry here and map the effect kinds that use it in BY_KIND.

const ENTRIES := {
	"fury": {"name": "Fury", "icon": "fury",
		"text": "Adds its value to every attack you make. Goes down by 1 after each attack. Gaining Fury cancels Impair."},
	"impair": {"name": "Impair", "icon": "impair",
		"text": "Negative Fury: lowers every attack by its value. Goes down by 1 after each attack. Fury cancels it."},
	"power": {"name": "Power", "icon": "power",
		"text": "Adds its value to every attack for the rest of the battle. It never goes down."},
	"boost": {"name": "Boost", "icon": "boost",
		"text": "Adds its value to your next attack only, then it is used up."},
	"shield": {"name": "Shield", "icon": "shield",
		"text": "Soaks damage before you lose HP. At the start of your turn anything above your max shield is lost."},
	"max_shield": {"name": "Max Shield", "icon": "max_shield",
		"text": "The most Shield you keep from one turn to the next."},
	"life": {"name": "Lives", "icon": "life",
		"text": "Not HP. You lose a life if you end a turn without playing a domino. At 0 lives the run is over."},
}

## effect kind -> the glossary entries it uses
const BY_KIND := {
	"fury": ["fury"], "impS": ["impair"], "impE": ["impair"], "power": ["power"], "boost": ["boost"],
	"shield": ["shield"], "maxs": ["max_shield"], "paylife": ["life"], "life": ["life"],
}


## The glossary ids (in order, no repeats) for the effects of a domino.
static func for_domino(d) -> Array:
	var out := []
	for e in d.data.effects:
		for id in BY_KIND.get(e.kind, []):
			if not out.has(id):
				out.append(id)
	return out
