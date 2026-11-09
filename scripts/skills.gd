extends RefCounted
## Fixed skill name per unordered pip pair (28 pairs) plus a deterministic effect.
## Display only for now: nothing here changes the game state.

# Pairs are ordered by pip total, then by the low pip:
# (0,0) (0,1) (0,2) (1,1) (0,3) (1,2) (0,4) (1,3) (2,2) ... (5,6) (6,6)
const NAMES = [
	"Fumble", "Pinprick", "Quick Nip", "Paired Poke", "Shadow Tap", "Sidestep", "Hollow Jab",
	"Pocket Sand", "Twin Flick", "Moth Wing", "Rabbit Punch", "Needle Rain", "Void Whisper", "Thorn Snap",
	"Lantern Slash", "Double Trouble", "Dusk Lunge", "Iron Burrow", "Comet Tail", "Hexed Reel", "Briar Storm",
	"Quad Quake", "Moonfall", "Ember Crown", "Wolfsbane", "Fivefold Fury", "Eclipse Fang", "Twelve Moons"
]
const KINDS = ["dmg", "blk", "buf", "deb"]
const BUFFS = ["Strength", "Thorns", "Regen", "Haste"]
const DEBUFFS = ["Weak", "Vulnerable", "Poison", "Slow"]


static func combo_index(lo: int, hi: int) -> int:
	var i := 0
	for s in range(13):
		for l in range(7):
			var h := s - l
			if h >= l and h <= 6:
				if l == lo and h == hi:
					return i
				i += 1
	return 0


static func skill(a: int, b: int) -> Dictionary:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	var s := lo + hi
	var n := 1 if s <= 3 else (2 if s <= 7 else 3)
	var f: float = [1.0, 1.0, 0.7, 0.6][n]
	var dbl := 1.25 if (lo == hi and s > 0) else 1.0
	var start := (lo * 3 + hi) % 4
	var base := {
		"dmg": s * 1.5 + 1.0,
		"blk": s * 1.3 + 1.0,
		"buf": 1.0 + floor(s / 4.0),
		"deb": 1.0 + floor(s / 3.0),
	}
	var buff_name: String = BUFFS[s % 4]
	var debuff_name: String = DEBUFFS[(s + 1) % 4]
	var parts := PackedStringArray()
	for i in n:
		var k: String = KINDS[(start + i) % 4]
		var v := int(maxf(1.0, round(base[k] * f * dbl)))
		if k == "dmg":
			parts.append("Deal %d damage" % v)
		elif k == "blk":
			parts.append("Gain %d block" % v)
		elif k == "buf":
			parts.append("Gain %d %s" % [v, buff_name])
		else:
			parts.append("Apply %d %s" % [v, debuff_name])
	return {
		"name": NAMES[combo_index(lo, hi)],
		"desc": ". ".join(parts) + ".",
		"power": s,
		"dbl": dbl > 1.0,
	}
