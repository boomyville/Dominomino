extends RefCounted
## The relic catalogue: 48 relics. Edit the table to rebalance or add one (see relic.gd for what
## "on", "if" and "do" can be). Each row: {n: name, r: rarity (c, u, r), on: hook, if: condition,
## do: action, v: amount, pip: pip number for the "pip" condition, once: once per turn, breaks: true to crumble
## after doing its action once, text}.
## starter: true means you begin the run with it (it is never offered or sold).
## WEAPONS (below) are relics that add dominoes; you have exactly one equipped.
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
	{"n": "Heartwood", "r": "c", "on": "passive", "do": "max_hp", "v": 5,
		"text": "Gain 5 max HP (it does not heal you)."},
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
	# ---- lives, cards, gems and the shop
	{"n": "Time Pendant", "r": "r", "starter": true, "on": "passive", "do": "rewind", "v": 1,
		"text": "Adds a Rewind turn button: restart the current turn for the cost of 1 life (not with only 1 life left)."},
	{"n": "Spare Heart", "r": "r", "on": "victory", "if": "every3", "do": "life", "v": 1,
		"text": "Gain 1 life after every 3rd battle you win."},
	{"n": "Warm Hearth", "r": "u", "on": "victory", "if": "oneLife", "do": "life", "v": 1,
		"text": "If you win a battle with only 1 life, gain 1 life."},
	{"n": "Bottomless Satchel", "r": "r", "on": "turn", "do": "draw", "v": 1,
		"text": "Draw 1 extra domino at the start of every turn."},
	{"n": "Jeweler's Loupe", "r": "r", "on": "passive", "do": "gems", "v": 1,
		"text": "Gain 1 more gem after every battle."},
	{"n": "Haggler's Tongue", "r": "u", "on": "passive", "do": "shop_discount", "v": 1,
		"text": "Everything in the shop costs 1 gem less (never below 1)."},
	# ---- rule benders and doubled turns
	{"n": "Loose Grip", "r": "u", "on": "passive", "do": "ignore_hand", "v": 1,
		"text": "Ignore every \"you must hold N dominoes\" condition on your dominoes."},
	{"n": "Stalwart Charm", "r": "u", "on": "battle", "do": "stalwart", "v": 1,
		"text": "Start every battle with 1 Stalwart: every :shield: you gain is doubled until the end of your first turn."},
	{"n": "Phial of Renewal", "r": "u", "on": "battle", "do": "regenerative", "v": 1,
		"text": "Start every battle with 1 Regenerative: all :heal: you get is doubled until the end of your first turn."},
	# ---- artifacts that break: they do their job once and are gone
	{"n": "Lizard Tail", "r": "r", "on": "death", "do": "revive", "v": 3, "breaks": true,
		"text": "Does nothing until you would lose the run. Then gain 3 lives, heal half your max HP, and the Lizard Tail crumbles."},
	{"n": "Last Meal", "r": "c", "on": "turn", "if": "halfHp", "do": "heal", "v": 8, "breaks": true,
		"text": "At the start of your turn, if you have half your HP or less, heal 8 HP. Then it is eaten and gone."},
	{"n": "Emergency Bulwark", "r": "c", "on": "battle", "do": "shield", "v": 5, "vc": true, "count": {"mode": "down", "start": 3},
		"text": "Start every battle with 5 :shield: for each point on its counter (15, then 10, then 5). The counter goes down by 1 every time and it breaks at 0."},
	{"n": "Fragile Gauntlet", "r": "u", "on": "battle", "do": "power", "v": 1, "vc": true, "count": {"mode": "down", "start": 3},
		"text": "Start every battle with :power: equal to its counter (3, then 2, then 1). The counter goes down by 1 every time and it breaks at 0."},
	{"n": "Dwindling Flame", "r": "c", "on": "battle", "do": "fury", "v": 1, "vc": true, "count": {"mode": "down", "start": 4},
		"text": "Start every battle with :fury: equal to its counter (4, 3, 2, 1). The counter goes down by 1 every time and it breaks at 0."},
	{"n": "Waning Phial", "r": "c", "on": "battle", "do": "heal", "v": 3, "vc": true, "count": {"mode": "down", "start": 3},
		"text": "Start every battle by healing 3 HP for each point on its counter (9, 6, 3). The counter goes down by 1 every time and it breaks at 0."},
	# ---- counters that count up and never break
	{"n": "Spiked Buckler", "r": "c", "on": "play", "do": "shield", "v": 3, "count": {"mode": "up", "every": 3, "event": "attack", "reset": "turn"},
		"text": "Every 3 attack dominoes you play, gain 3 :shield:. The counter starts again at 0 every turn."},
	{"n": "Scribe's Quill", "r": "u", "on": "play", "do": "draw", "v": 1, "count": {"mode": "up", "every": 3, "event": "skill", "reset": "turn"},
		"text": "Every 3 skill dominoes you play, draw 1 domino. The counter starts again at 0 every turn."},
	{"n": "Tally Stick", "r": "u", "on": "play", "do": "energy", "v": 1, "count": {"mode": "up", "every": 4, "event": "play", "reset": "turn"},
		"text": "Every 4 dominoes you play, gain 1 :energy:. The counter starts again at 0 every turn."},
]

## The weapons. You own as many as you find but only ONE is equipped: it adds its dominoes to the
## stack or your hand (see relic.gd). They are never unequipped, only replaced by another weapon.
const WEAPONS := [
	{"n": "Short Sword", "r": "c", "weapon": true, "starter": true,
		"adds": [{"t": "Sword Slash", "n": 3, "when": "battle", "pos": "stack"},
				{"t": "Quick Strike", "n": 2, "when": "battle", "pos": "stack"}],
		"text": "Adds 3 Sword Slash and 2 Quick Strike to your stack at the start of every battle."},
	{"n": "Long Sword", "r": "u", "weapon": true,
		"adds": [{"t": "Heavy Blade", "n": 2, "when": "battle", "pos": "bottom"}],
		"text": "Adds 2 Heavy Blade to the BOTTOM of your stack at the start of every battle."},
	{"n": "Rapier", "r": "u", "weapon": true,
		"adds": [{"t": "En Garde", "n": 1, "when": "turn", "pos": "hand"}],
		"text": "Adds an En Garde to your hand at the start of every turn."},
	{"n": "Sawtooth Blade", "r": "u", "weapon": true,
		"adds": [{"t": "Rip and Shred", "n": 2, "when": "battle", "pos": "stack"}],
		"text": "Adds 2 Rip and Shred to your stack at the start of every battle."},
	{"n": "Shining Blade", "r": "r", "weapon": true,
		"adds": [{"t": "Cutting Edge", "n": 1, "when": "battle", "pos": "top"}],
		"text": "Adds a Cutting Edge to the TOP of your stack at the start of every battle."},
]


## Build the Relic for one row of TABLE or WEAPONS.
static func make(row: Dictionary):
	var r = Relic.new()
	r.setup(row, Icons)
	return r


## Every artifact in the catalogue (not the weapons).
static func build() -> Array:
	var out := []
	for row in TABLE:
		out.append(make(row))
	return out


## Every weapon.
static func build_weapons() -> Array:
	var out := []
	for row in WEAPONS:
		out.append(make(row))
	return out


## One artifact or weapon by id ("overcharged_core", "short_sword") or null.
static func by_id(relic_id: String):
	for row in TABLE + WEAPONS:
		if Icons.slug(row.n) == relic_id:
			return make(row)
	return null


## Up to n different artifacts you do not own yet: 60% common, 30% uncommon, 10% rare (a rarity that has
## run out is skipped). Starter artifacts and weapons are never rolled. Pass the game's
## RandomNumberGenerator to make it repeatable from the seed.
static func roll(owned_ids: Array, n: int, rng: RandomNumberGenerator = null) -> Array:
	return _roll_from(build(), owned_ids, n, rng)


## The same for weapons.
static func roll_weapons(owned_ids: Array, n: int, rng: RandomNumberGenerator = null) -> Array:
	return _roll_from(build_weapons(), owned_ids, n, rng)


static func _roll_from(all: Array, owned_ids: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var pool := {"c": [], "u": [], "r": []}
	for r in all:
		if not owned_ids.has(r.id) and not r.starter:
			pool[r.rarity].append(r)
	var out := []
	for i in n:
		var x: float = rng.randf() if rng != null else randf()
		var want := "c" if x < 0.6 else ("u" if x < 0.9 else "r")
		var order := [want] + ["c", "u", "r"].filter(func(k): return k != want)
		for k in order:
			if not pool[k].is_empty():
				var at: int = (rng.randi() if rng != null else randi()) % pool[k].size()
				out.append(pool[k].pop_at(at))
				break
	return out
