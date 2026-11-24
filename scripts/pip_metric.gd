extends RefCounted
## The number an effect takes from a domino's two pips. Most effects use the pip total ("sum"). Some use
## the higher pip, the lower pip, the difference between them or their product. An effect row asks for one
## with "src": "sum" (the default), "max", "min", "diff" or "prod".

const SOURCES := ["sum", "max", "min", "diff", "prod"]
const NOTES := {
	"max": "the higher pip",
	"min": "the lower pip",
	"diff": "the difference between the pips",
	"prod": "the product of the pips",
}


static func of(src: String, a: int, b: int) -> int:
	match src:
		"max":
			return maxi(a, b)
		"min":
			return mini(a, b)
		"diff":
			return absi(a - b)
		"prod":
			return a * b
	return a + b


## What to add to the effect text so the player knows where the number comes from ("" for the total).
static func note(src: String) -> String:
	return " (%s)" % NOTES[src] if NOTES.has(src) else ""
