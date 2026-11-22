extends RefCounted
## The relic catalogue: 30 relics. Edit the table to rebalance or add one (see relic.gd for what
## "on", "if" and "do" can be). Each row: {n: name, r: rarity (c, u, r), on: hook, if: condition,
## do: action, v: amount, pip: pip number for the "pip" condition, once: once per turn, text}.
## In text, :name: shows that icon (:energy: :shield: :fury: :power: :impair: :heal: :draw: ...).
## A relic's own picture is img/icons/<its name in lowercase with underscores>.png, for example
## img/icons/overcharged_core.png (a gem is drawn when there is no file).

const Relic = preload("res://scripts/relics/relic.gd")
const Icons = preload("res://scripts/icons.gd")

const TABLE := [
	# ---- energy
	{"n": "Overcharged Core", "r": "r", "on": "turn", "do": "energy", "v": 1,
		"text": "Gain 1 extra :energy: at the start of every turn."},
	{"n": "Starter Spark", "r": "u", "on": "battle", "do": "energy", "v": 3,
		"text": "Gain 3 extra :energy: on the first turn of every battle."},
	{"n": "Reserve Tank", "r": "u", "on": "play", "if": "spentAll", "once": true, "do": "energy", "v": 2,
		"text": "Once per turn, if you use up all your :energy:, gain 2 :energy:."},
	{"n": "Quiet Mind", "r": "u", "on": "turn", "if": "noAtkLast", "do": "energy", "v": 2,
		"text": "At the start of your turn, gain 2 :energy: if you played no attacks last turn."},
	{"n": "Deep Well", "r": "u", "on": "passive", "do": "max_energy", "v": 2,
		"text": "Gain 2 max :energy: (you start every turn with 2 more)."},
	{"n": "Open Palm", "r": "u", "on": "turn", "if": "emptyLast", "do": "energy", "v": 3,
		"text": "If you ended your last turn with no dominoes in hand, gain 3 :energy: at the start of this turn."},
	# ---- shield
	{"n": "Banked Charge", "r": "u", "on": "turn_end", "if": "energy4", "do": "shield", "v": 10,
		"text": "If you end your turn with 4 or more :energy:, gain 10 :shield:."},
	{"n": "Iron Cloak", "r": "c", "on": "battle", "do": "shield", "v": 6,
		"text": "Gain 6 :shield: at the start of every battle."},
	{"n": "Safety Net", "r": "c", "on": "turn_end", "if": "noShield", "do": "shield", "v": 4,
		"text": "If you end your turn with no :shield:, gain 4 :shield:."},
	{"n": "Brimming Cup", "r": "c", "on": "turn", "if": "fullShield", "do": "draw", "v": 1,
		"text": "At the start of your turn, if your :shield: equals your max shield, draw 1 extra domino."},
	{"n": "Bulwark Seed", "r": "r", "on": "battle", "do": "max_shield", "v": 8,
		"text": "Gain 8 max :shield: at the start of every battle."},
	{"n": "Seedling Plate", "r": "u", "on": "turn", "if": "noShield", "do": "max_shield", "v": 1,
		"text": "At the start of your turn, if you have no :shield:, gain 1 max :shield:."},
	{"n": "Overflow Valve", "r": "u", "on": "turn", "if": "excessShield", "do": "draw", "v": 1,
		"text": "At the start of your turn, if your :shield: is above your max shield, draw 1 extra domino."},
	# ---- start of battle
	{"n": "Ember Heart", "r": "u", "on": "battle", "do": "fury", "v": 3,
		"text": "Start every battle with 3 :fury:."},
	{"n": "War Drum", "r": "c", "on": "battle", "do": "power", "v": 1,
		"text": "Start every battle with 1 :power:."},
	{"n": "Venom Fang", "r": "u", "on": "battle", "do": "impair", "v": 3,
		"text": "Apply 3 :impair: to the enemy at the start of every battle."},
	{"n": "Gambler's Purse", "r": "u", "on": "passive", "do": "rewards", "v": 1,
		"text": "Battle rewards offer 1 extra domino."},
	{"n": "Heartwood", "r": "c", "on": "battle", "do": "max_hp", "v": 5,
		"text": "Start every battle with 5 more max HP."},
	{"n": "Whetstone", "r": "c", "on": "battle", "do": "boost", "v": 2,
		"text": "Start every battle with 2 :boost:."},
	{"n": "Phoenix Feather", "r": "r", "on": "battle", "if": "lowLives", "do": "life", "v": 1,
		"text": "At the start of a battle, if you have lost a life, gain 1 life."},
	# ---- when you play a domino
	{"n": "Tile Armor", "r": "c", "on": "play", "do": "shield", "v": 1,
		"text": "Whenever you play a domino, gain 1 :shield:."},
	{"n": "Dawn Lantern", "r": "u", "on": "play", "if": "pip", "pip": 1, "do": "restack", "v": 1,
		"text": "Whenever you play a domino with a 1 pip (:light:), shuffle a random discarded domino back into your stack."},
	{"n": "Pebble Sling", "r": "c", "on": "play", "if": "pip", "pip": 2, "do": "damage", "v": 1,
		"text": "Whenever you play a domino with a 2 pip (:earth:), deal 1 damage to the enemy."},
	{"n": "Frost Shard", "r": "c", "on": "play", "if": "pip", "pip": 3, "do": "shield", "v": 1,
		"text": "Whenever you play a domino with a 3 pip (:water:), gain 1 :shield:."},
	{"n": "Kindling", "r": "c", "on": "play", "if": "pip", "pip": 4, "do": "energy", "v": 1,
		"text": "Whenever you play a domino with a 4 pip (:fire:), gain 1 :energy:."},
	{"n": "Storm Charm", "r": "c", "on": "play", "if": "pip", "pip": 5, "do": "fury", "v": 1,
		"text": "Whenever you play a domino with a 5 pip (:lightning:), gain 1 :fury:."},
	{"n": "Midnight Vial", "r": "c", "on": "play", "if": "pip", "pip": 6, "do": "heal", "v": 1,
		"text": "Whenever you play a domino with a 6 pip (:darkness:), heal 1 HP."},
	{"n": "Double Vision", "r": "u", "on": "play", "if": "double", "do": "draw", "v": 1,
		"text": "Whenever you play a double (the same pip on both halves), draw 1 domino."},
	{"n": "Hollow Bone", "r": "c", "on": "play", "if": "pip", "pip": 0, "do": "shield", "v": 2,
		"text": "Whenever you play a domino with a blank (0) half, gain 2 :shield:."},
	# ---- end of turn
	{"n": "Bandage Roll", "r": "u", "on": "turn_end", "if": "halfHp", "do": "heal", "v": 4,
		"text": "If you end your turn with half your HP or less, heal 4 HP."},
]


## Build the Relic for one row of TABLE.
static func make(row: Dictionary):
	var r = Relic.new()
	r.setup(row, Icons)
	return r


## Every relic in the catalogue.
static func build() -> Array:
	var out := []
	for row in TABLE:
		out.append(make(row))
	return out


## One relic by id ("overcharged_core") or null.
static func by_id(relic_id: String):
	for row in TABLE:
		if Icons.slug(row.n) == relic_id:
			return make(row)
	return null


## Up to n different relics you do not own yet: 60% common, 30% uncommon, 10% rare (a rarity that
## has run out is skipped).
static func roll(owned_ids: Array, n: int) -> Array:
	var pool := {"c": [], "u": [], "r": []}
	for r in build():
		if not owned_ids.has(r.id):
			pool[r.rarity].append(r)
	var out := []
	for i in n:
		var x := randf()
		var want := "c" if x < 0.6 else ("u" if x < 0.9 else "r")
		var order := [want] + ["c", "u", "r"].filter(func(k): return k != want)
		for k in order:
			if not pool[k].is_empty():
				out.append(pool[k].pop_at(randi() % pool[k].size()))
				break
	return out
