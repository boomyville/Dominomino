extends RefCounted
## The domino catalogue: 102 dominoes plus Garbage (the last entry). The first 80 come from the web build.
## Ported from the web build (index.html). Edit the numbers here to rebalance.
## build() turns this table into DominoData objects (with Effect and Condition objects inside).
##
## Each domino: {"n": name, "r": rarity (c, u, r, g), "c": play condition id ("" = always playable), "fx": [effects]}
## Each effect: {"k": kind, "m": value mode, "a": a, "b": b, "t": hit count}
## "e": true makes a domino ephemeral. (pipdmg also has "p": which pip counts and "w": "board" or "hand")
## The effect size comes from the pip total s (0 to 12), so bigger pips mean bigger effects:
##   S = s*a + b      C = ceil(s/a) + b      F = floor(s/a) + b
##   K = b (constant) L = max(1, round(a*s + b))      no "m" = the effect has no number
##
## Effect kinds:
##   dmg hit(t hits)  shield  maxs (max shield)  draw  discR (discard random)  discP (discard of your choice)
##   tutor (find in stack)  power  boost  heal  rerollA (all in hand)  rerollP (one of your choice)
##   fury  impS (impair yourself)  impE (impair the enemy)  selfdmg (lose HP)  gen (add random dominoes to stack)  life
##   playedpips (damage = pips of every domino you played)  paylife (lose a life, pair with condition "lives2")  pipdmg (damage per pip of one number on the board / in hand)

const TY := [
	{"n": "Slash", "r": "c", "c": "", "fx": [{"k": "dmg", "m": "S", "a": 1, "b": 2}]},
	{"n": "Twin Fang", "r": "c", "c": "", "fx": [{"k": "hit", "m": "C", "a": 2, "b": 1, "t": 2}]},
	{"n": "Triple Thorn", "r": "u", "c": "", "fx": [{"k": "hit", "m": "F", "a": 3, "b": 1, "t": 3}]},
	{"n": "Iron Guard", "r": "c", "c": "", "fx": [{"k": "shield", "m": "S", "a": 1, "b": 3}]},
	{"n": "Fortify", "r": "u", "c": "", "fx": [{"k": "maxs", "m": "F", "a": 4, "b": 1}, {"k": "shield", "m": "C", "a": 2, "b": 1}]},
	{"n": "Parry", "r": "c", "c": "", "fx": [{"k": "shield", "m": "S", "a": 1, "b": 1}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Quick Study", "r": "c", "c": "", "fx": [{"k": "draw", "m": "F", "a": 5, "b": 1}]},
	{"n": "Reckless Strike", "r": "c", "c": "", "fx": [{"k": "dmg", "m": "S", "a": 1, "b": 4}, {"k": "discR", "m": "K", "a": 0, "b": 1}]},
	{"n": "Gambit", "r": "u", "c": "", "fx": [{"k": "dmg", "m": "S", "a": 2, "b": 1}, {"k": "discP", "m": "K", "a": 0, "b": 1}]},
	{"n": "Scout", "r": "u", "c": "", "fx": [{"k": "tutor", "m": "K", "a": 0, "b": 1}, {"k": "shield", "m": "F", "a": 3, "b": 1}]},
	{"n": "War Cry", "r": "u", "c": "", "fx": [{"k": "power", "m": "F", "a": 4, "b": 1}]},
	{"n": "Sharpen", "r": "c", "c": "", "fx": [{"k": "boost", "m": "S", "a": 1, "b": 2}]},
	{"n": "Mend", "r": "c", "c": "", "fx": [{"k": "heal", "m": "S", "a": 1, "b": 2}]},
	{"n": "Chaos Dice", "r": "u", "c": "", "fx": [{"k": "rerollA"}, {"k": "shield", "m": "C", "a": 2, "b": 2}]},
	{"n": "Loaded Dice", "r": "u", "c": "", "fx": [{"k": "rerollP"}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Second Wind", "r": "c", "c": "", "fx": [{"k": "heal", "m": "C", "a": 2, "b": 1}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Battle Trance", "r": "u", "c": "", "fx": [{"k": "dmg", "m": "C", "a": 2, "b": 1}, {"k": "power", "m": "K", "a": 0, "b": 1}]},
	{"n": "Shield Bash", "r": "c", "c": "", "fx": [{"k": "dmg", "m": "C", "a": 2, "b": 2}, {"k": "shield", "m": "C", "a": 2, "b": 2}]},
	{"n": "Precision", "r": "u", "c": "", "fx": [{"k": "boost", "m": "C", "a": 2, "b": 2}, {"k": "draw", "m": "K", "a": 0, "b": 1}]},
	{"n": "Lifesteal", "r": "u", "c": "", "fx": [{"k": "dmg", "m": "C", "a": 2, "b": 2}, {"k": "heal", "m": "F", "a": 3, "b": 1}]},
	{"n": "Rage Up", "r": "c", "c": "", "fx": [{"k": "fury", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Sting", "r": "c", "c": "", "fx": [{"k": "impE", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Blood Ward", "r": "c", "c": "", "fx": [{"k": "shield", "m": "L", "a": 1.2, "b": 4}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Blood Rage", "r": "c", "c": "", "fx": [{"k": "fury", "m": "L", "a": 0.6, "b": 2}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Cheap Shot", "r": "c", "c": "first", "fx": [{"k": "dmg", "m": "L", "a": 1.2, "b": 4}]},
	{"n": "Opening Guard", "r": "c", "c": "first", "fx": [{"k": "shield", "m": "L", "a": 1.4, "b": 4}]},
	{"n": "Desperate Swing", "r": "c", "c": "lowHp", "fx": [{"k": "dmg", "m": "L", "a": 1.6, "b": 3}]},
	{"n": "Second Skin", "r": "c", "c": "noShield", "fx": [{"k": "shield", "m": "L", "a": 1.4, "b": 5}]},
	{"n": "Light Hands", "r": "c", "c": "handLe3", "fx": [{"k": "draw", "m": "L", "a": 0, "b": 2}]},
	{"n": "Clean Hands", "r": "c", "c": "noSix", "fx": [{"k": "dmg", "m": "L", "a": 1.3, "b": 4}]},
	{"n": "Full Grip", "r": "c", "c": "hand6", "fx": [{"k": "dmg", "m": "L", "a": 1.2, "b": 4}, {"k": "shield", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Steady Guard", "r": "c", "c": "noAtk", "fx": [{"k": "shield", "m": "L", "a": 1.3, "b": 4}, {"k": "heal", "m": "L", "a": 0.4, "b": 1}]},
	{"n": "Flawless Blow", "r": "c", "c": "noHpLost", "fx": [{"k": "dmg", "m": "L", "a": 1.5, "b": 4}]},
	{"n": "Taunt", "r": "c", "c": "", "fx": [{"k": "impE", "m": "L", "a": 0.7, "b": 1}, {"k": "shield", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Spite", "r": "c", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 0.8, "b": 3}, {"k": "impE", "m": "L", "a": 0.4, "b": 1}]},
	{"n": "Warm Up", "r": "c", "c": "", "fx": [{"k": "fury", "m": "L", "a": 0.4, "b": 1}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Reckless Blow", "r": "c", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 1.5, "b": 6}, {"k": "impS", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Quick Patch", "r": "c", "c": "lowHp", "fx": [{"k": "heal", "m": "L", "a": 1.2, "b": 4}]},
	{"n": "Rummage", "r": "c", "c": "", "fx": [{"k": "draw", "m": "L", "a": 0, "b": 2}, {"k": "discP", "m": "L", "a": 0, "b": 1}]},
	{"n": "Pile Driver", "r": "c", "c": "", "fx": [{"k": "hit", "m": "L", "a": 0.7, "b": 1, "t": 2}]},
	{"n": "Reset", "r": "c", "c": "", "fx": [{"k": "rerollA"}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Fury Guard", "r": "c", "c": "", "fx": [{"k": "shield", "m": "L", "a": 0.8, "b": 2}, {"k": "fury", "m": "L", "a": 0.3, "b": 1}]},
	{"n": "Sharp Eyes", "r": "c", "c": "first", "fx": [{"k": "boost", "m": "L", "a": 1, "b": 2}]},
	{"n": "Jab", "r": "c", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 0.9, "b": 2}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Berserker", "r": "u", "c": "", "fx": [{"k": "fury", "m": "L", "a": 0.8, "b": 2}, {"k": "dmg", "m": "L", "a": 0.8, "b": 2}]},
	{"n": "Crippling Blow", "r": "u", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 1, "b": 3}, {"k": "impE", "m": "L", "a": 0.6, "b": 2}]},
	{"n": "Hex", "r": "u", "c": "", "fx": [{"k": "impE", "m": "L", "a": 1, "b": 2}]},
	{"n": "Battle Lust", "r": "u", "c": "", "fx": [{"k": "fury", "m": "L", "a": 0.8, "b": 3}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Iron Resolve", "r": "u", "c": "", "fx": [{"k": "shield", "m": "L", "a": 1.5, "b": 5}, {"k": "fury", "m": "L", "a": 0.4, "b": 1}]},
	{"n": "Hard Bargain", "r": "u", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 1.8, "b": 5}, {"k": "impS", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Veteran’s Edge", "r": "u", "c": "played9", "fx": [{"k": "dmg", "m": "L", "a": 1.7, "b": 5}]},
	{"n": "Last Stand", "r": "u", "c": "lowHp", "fx": [{"k": "dmg", "m": "L", "a": 2.2, "b": 6}]},
	{"n": "Bare Knuckle", "r": "u", "c": "handLe3", "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 5}]},
	{"n": "Meditate", "r": "u", "c": "noAtk", "fx": [{"k": "heal", "m": "L", "a": 0.8, "b": 3}, {"k": "draw", "m": "L", "a": 0, "b": 1}]},
	{"n": "Siphon Fury", "r": "u", "c": "", "fx": [{"k": "fury", "m": "L", "a": 0.9, "b": 2}, {"k": "heal", "m": "L", "a": 0.4, "b": 1}]},
	{"n": "Whirlwind", "r": "u", "c": "noShield", "fx": [{"k": "hit", "m": "L", "a": 0.5, "b": 1, "t": 3}]},
	{"n": "Spare Parts", "r": "u", "c": "", "fx": [{"k": "gen", "m": "L", "a": 0, "b": 1}, {"k": "shield", "m": "L", "a": 0.7, "b": 2}]},
	{"n": "Calm Mind", "r": "u", "c": "handLe3", "fx": [{"k": "draw", "m": "L", "a": 0, "b": 3}]},
	{"n": "Overclock", "r": "u", "c": "", "fx": [{"k": "power", "m": "L", "a": 0.4, "b": 1}, {"k": "selfdmg", "m": "L", "a": 0, "b": 2}]},
	{"n": "Mulligan", "r": "u", "c": "hand6", "fx": [{"k": "rerollA"}, {"k": "draw", "m": "L", "a": 0, "b": 2}]},
	{"n": "Shatter", "r": "u", "c": "enShield", "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 5}, {"k": "impE", "m": "L", "a": 0.3, "b": 1}]},
	{"n": "Patient Strike", "r": "u", "c": "first", "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 4}]},
	{"n": "Second Chance", "r": "r", "c": "", "fx": [{"k": "life", "m": "L", "a": 0, "b": 2}, {"k": "gen", "m": "L", "a": 0, "b": 2}]},
	{"n": "Rampage", "r": "r", "c": "", "fx": [{"k": "hit", "m": "L", "a": 0.6, "b": 2, "t": 3}, {"k": "fury", "m": "L", "a": 0.6, "b": 2}]},
	{"n": "Annihilate", "r": "r", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 2.2, "b": 6}, {"k": "impE", "m": "L", "a": 0.6, "b": 2}]},
	{"n": "Bulwark of Ages", "r": "r", "c": "", "fx": [{"k": "shield", "m": "L", "a": 2, "b": 6}, {"k": "maxs", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Phoenix Draught", "r": "r", "c": "", "fx": [{"k": "heal", "m": "L", "a": 2, "b": 6}, {"k": "draw", "m": "L", "a": 0, "b": 2}, {"k": "shield", "m": "L", "a": 0.5, "b": 2}]},
	{"n": "Blood Frenzy", "r": "r", "c": "", "fx": [{"k": "fury", "m": "L", "a": 1.2, "b": 4}, {"k": "dmg", "m": "L", "a": 1.2, "b": 3}, {"k": "selfdmg", "m": "L", "a": 0, "b": 3}]},
	{"n": "Time Warp", "r": "r", "c": "", "fx": [{"k": "draw", "m": "L", "a": 0, "b": 3}, {"k": "boost", "m": "L", "a": 1, "b": 3}]},
	{"n": "Warlord", "r": "r", "c": "", "fx": [{"k": "power", "m": "L", "a": 0.5, "b": 2}, {"k": "fury", "m": "L", "a": 0.8, "b": 2}]},
	{"n": "Grand Design", "r": "r", "c": "", "fx": [{"k": "tutor"}, {"k": "tutor"}, {"k": "shield", "m": "L", "a": 1, "b": 3}]},
	{"n": "Soul Rend", "r": "r", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 1.8, "b": 6}, {"k": "impE", "m": "L", "a": 1, "b": 2}, {"k": "heal", "m": "L", "a": 0.5, "b": 1}]},
	{"n": "Fortress", "r": "r", "c": "noShield", "fx": [{"k": "shield", "m": "L", "a": 2.5, "b": 8}]},
	{"n": "Pure Heart", "r": "r", "c": "noHpLost", "fx": [{"k": "dmg", "m": "L", "a": 3, "b": 7}]},
	{"n": "Fortune’s Wheel", "r": "r", "c": "", "fx": [{"k": "rerollA"}, {"k": "draw", "m": "L", "a": 0, "b": 3}, {"k": "shield", "m": "L", "a": 1, "b": 3}]},
	{"n": "Hundred Cuts", "r": "r", "c": "noSix", "fx": [{"k": "hit", "m": "L", "a": 1, "b": 2, "t": 3}]},
	{"n": "Dominion", "r": "r", "c": "hand6", "fx": [{"k": "dmg", "m": "L", "a": 2, "b": 6}, {"k": "shield", "m": "L", "a": 1.5, "b": 4}]},
	{"n": "Last Gasp", "r": "r", "c": "lowHp", "fx": [{"k": "dmg", "m": "L", "a": 3.5, "b": 8}, {"k": "selfdmg", "m": "L", "a": 0, "b": 4}]},
	{"n": "Overwhelm", "r": "r", "c": "", "fx": [{"k": "impE", "m": "L", "a": 1.4, "b": 3}, {"k": "boost", "m": "L", "a": 1, "b": 4}]},
	{"n": "Ascension", "r": "r", "c": "", "fx": [{"k": "fury", "m": "L", "a": 1.5, "b": 4}, {"k": "power", "m": "L", "a": 0.5, "b": 1}, {"k": "maxs", "m": "L", "a": 0.3, "b": 1}]},
	# ---- elements: damage for every pip of one number (1 light, 2 earth, 3 water, 4 fire, 5 lightning, 6 darkness)
	{"n": "Sunburst", "r": "c", "c": "", "fx": [{"k": "pipdmg", "p": 1, "w": "board", "m": "K", "a": 0, "b": 2}]},
	{"n": "Landslide", "r": "c", "c": "", "fx": [{"k": "pipdmg", "p": 2, "w": "board", "m": "K", "a": 0, "b": 2}]},
	{"n": "Tidal Crash", "r": "u", "c": "", "fx": [{"k": "pipdmg", "p": 3, "w": "board", "m": "K", "a": 0, "b": 3}]},
	{"n": "Inferno", "r": "u", "c": "", "fx": [{"k": "pipdmg", "p": 4, "w": "board", "m": "K", "a": 0, "b": 3}]},
	{"n": "Fireball", "r": "r", "c": "", "fx": [{"k": "pipdmg", "p": 4, "w": "board", "m": "K", "a": 0, "b": 4}]},
	{"n": "Thunderclap", "r": "u", "c": "", "fx": [{"k": "pipdmg", "p": 5, "w": "hand", "m": "K", "a": 0, "b": 3}]},
	{"n": "Eclipse", "r": "u", "c": "", "fx": [{"k": "pipdmg", "p": 6, "w": "hand", "m": "K", "a": 0, "b": 3}]},
	# ---- paid for with a life (cannot be played when you have only 1 life)
	{"n": "Blood Pact", "r": "u", "c": "lives2", "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "dmg", "m": "L", "a": 2.4, "b": 7}]},
	{"n": "Soul Tithe", "r": "u", "c": "lives2", "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "draw", "m": "L", "a": 0.25, "b": 3}]},
	{"n": "Hex of Ruin", "r": "u", "c": "lives2", "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "impE", "m": "L", "a": 1.2, "b": 4}]},
	{"n": "Crimson Ritual", "r": "r", "c": "lives2", "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "fury", "m": "L", "a": 1.2, "b": 5}, {"k": "power", "m": "L", "a": 0.3, "b": 1}]},
	{"n": "Sacrificial Blade", "r": "r", "c": "lives2", "fx": [{"k": "paylife", "m": "K", "a": 0, "b": 1}, {"k": "hit", "m": "L", "a": 1.2, "b": 3, "t": 3}]},
	# ---- ephemeral: stronger than the normal kind, but discarded at the end of the turn if you do not play them
	{"n": "Lunge", "r": "c", "c": "", "e": true, "fx": [{"k": "dmg", "m": "L", "a": 1.6, "b": 4}]},
	{"n": "Flash Guard", "r": "c", "c": "", "e": true, "fx": [{"k": "shield", "m": "L", "a": 1.6, "b": 5}]},
	{"n": "Focus", "r": "u", "c": "", "e": true, "fx": [{"k": "fury", "m": "L", "a": 1.0, "b": 3}]},
	{"n": "Quick Draw", "r": "u", "c": "", "e": true, "fx": [{"k": "draw", "m": "L", "a": 0.3, "b": 3}]},
	{"n": "Overpower", "r": "r", "c": "", "e": true, "fx": [{"k": "dmg", "m": "L", "a": 3.0, "b": 9}]},
	# ---- weapon dominoes (rarity w): only a weapon adds them, they are never offered as rewards
	{"n": "Quick Strike", "r": "w", "c": "first", "e": true, "fx": [{"k": "dmg", "m": "L", "a": 2.5, "b": 3}]},
	{"n": "Heavy Blade", "r": "w", "c": "", "fx": [{"k": "dmg", "m": "L", "a": 3.0, "b": 8}]},
	{"n": "En Garde", "r": "w", "c": "", "e": true, "fx": [{"k": "shield", "m": "L", "a": 1.0, "b": 4}, {"k": "dmg", "m": "L", "a": 1.2, "b": 3}]},
	{"n": "Rip and Shred", "r": "w", "c": "", "fx": [{"k": "playedpips", "m": "K", "a": 0, "b": 1}]},
	{"n": "Cutting Edge", "r": "w", "c": "", "fx": [{"k": "hit", "m": "K", "a": 0, "b": 5, "t": 5}]},
	{"n": "Garbage", "r": "g", "c": "never", "fx": []},
]

## Index of Garbage: always the last row of TY.
const GARBAGE := 102

const DominoData = preload("res://scripts/domino_data.gd")
const EffectFactory = preload("res://scripts/effects/effect_factory.gd")
const ConditionFactory = preload("res://scripts/conditions/condition_factory.gd")


## Build the catalogue: one DominoData per row of TY (the Garbage entry is the last).
static func build() -> Array:
	var out := []
	for i in TY.size():
		var row: Dictionary = TY[i]
		var d = DominoData.new()
		d.id = i
		d.title = row.n
		d.rarity = row.r
		d.condition = ConditionFactory.make(row.c)
		d.ephemeral = row.get("e", false)
		for e in row.fx:
			d.effects.append(EffectFactory.make(e))
		out.append(d)
	return out


## A random kind of domino (never Garbage or a weapon domino): 60% common, 30% uncommon, 10% rare.
## Pass the game's RandomNumberGenerator to make it repeatable from the seed.
static func rand_type(rng: RandomNumberGenerator = null) -> int:
	var x: float = rng.randf() if rng != null else randf()
	var r := "c" if x < 0.6 else ("u" if x < 0.9 else "r")
	return rand_type_of(r, rng)


## A random kind of this rarity.
static func rand_type_of(r: String, rng: RandomNumberGenerator = null) -> int:
	var pool := []
	for i in TY.size():
		if TY[i].r == r:
			pool.append(i)
	var k: int = rng.randi() if rng != null else randi()
	return pool[k % pool.size()]


## Position of a kind in the catalogue by its name (-1 if there is none).
static func index_of(title: String) -> int:
	for i in TY.size():
		if TY[i].n == title:
			return i
	return -1
