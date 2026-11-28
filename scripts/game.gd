extends RefCounted
## Game state, rules and turn flow. No nodes in here, so it can run headless (see tests/test_rules.gd).
## Everything the player would see or wait for goes through the ui object (main.gd, or NullUI in tests).
##
## The pieces it is built from:
##   Dominoes (table) -> DominoData (a kind of domino) -> Effect / Condition objects (what it does)
##   Domino            one domino you hold: its kind plus its own pips
##   Combatant / Foe   HP, shield and statuses (Fury, Power, Boost) for the player and the enemy
##   Status            one status; children of status.gd
## Relics, statuses and dominoes are all models (model.gd). active_models() lists them and dispatch()
## calls a hook on each. Changes to HP, shield and statuses go through scripts/cmd/. What has
## happened this battle is in `history` (combat_log.gd), not in counters.
## Ported from the web build (index.html).

const Dominoes = preload("res://scripts/dominoes.gd")
const Domino = preload("res://scripts/domino.gd")
const Combatant = preload("res://scripts/combatant.gd")
const Foe = preload("res://scripts/foe.gd")
const NullUI = preload("res://scripts/null_ui.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const Library = preload("res://scripts/library.gd")
const Boons = preload("res://scripts/boons.gd")
const AbstractModel = preload("res://scripts/model.gd")
const CombatLog = preload("res://scripts/combat_log.gd")
const DamageCmd = preload("res://scripts/cmd/damage_cmd.gd")
const CreatureCmd = preload("res://scripts/cmd/creature_cmd.gd")

const N := 20
const MAXE := 10            # energy per turn
const MAXH := 12            # most dominoes your hand can hold
const START_LIVES := 3
const START_GEMS := 9
const SHOP_CHANCE := 0.3    # chance that "Next battle" is replaced by "Shop" (after battle 1 it always is)
const PLAYER_HP := 50
const EQUIP_SLOTS := 8      # artifacts you can have equipped at once; the rest wait in the inventory
const RELIC_CHANCE := 0.2   # chance that a victory offers "a domino or a random artifact"
const START_HAND := 6
const DRAW_PER_TURN := 4
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
## Top-left cell of each 3x3 character footprint. They mirror each other through the board centre.
const CH := {"p": Vector2(14, 8), "c": Vector2(3, 9)}

var ui = NullUI.new()
## Every random choice in the game goes through rng, so a run is repeatable from its seed: the stack
## order and the enemy's plans of a battle come out the same if you restart the battle.
var seed_value := 0
var rng := RandomNumberGenerator.new()
## A new game starts with the Short Sword and the Time Pendant. (Tests turn this off.)
static var starter_gear := true
var data: Array = Dominoes.build()    # the catalogue: one DominoData per kind of domino

# board
var occ := {}          # Vector2 cell -> {id, owner, pip}
var chars := {}        # Vector2 cell -> "p" | "c"
var placed := []       # every domino on the board: {x, y, rot, a, b, owner}
# dominoes. Played dominoes stay on the board and discarded ones stay in the discard pile:
# neither comes back during a battle. Each battle the stack is rebuilt from your collection.
var collection := []   # every Domino you own
var stack := []        # draw pile (top = last)
var discard := []
var hand := []
var battle_deck := []     # every domino this battle started with (the stack window lists these)
# artifacts (Relic objects, see relics/relics.gd)
var weapon = null         # the ONE equipped weapon (a Relic with weapon true); it cannot be unequipped, only replaced
var stored_weapons := []  # weapons you own but do not use
var gems := START_GEMS
var shop := []            # [{kind: domino | relic | weapon | upgrade, item, price, sold}] while a shop is open
var shop_note := ""       # what the last purchase did (for the shop window)
var end_turn_after_play := false   # a domino that "ends your turn" sets this; play_domino then ends the turn
var shop_pending := false # the screen between battles offers a shop instead of Next battle
var victory_summary := {} # {dealt, lost, gems, battle} for the victory screen
var battle_snap := {}     # the start of this battle (for Restart battle)
var turn_snap := {}       # the start of this turn (for the Time Pendant)
var relics := []          # equipped artifacts (only these do anything), at most EQUIP_SLOTS
var stored_relics := []   # owned but not equipped
var max_hp_bonus := 0     # extra max HP for the whole run (a boon)
var relic_chance := RELIC_CHANCE
var artifact_offered := false   # this victory offers the choice of a domino or an artifact
var reward_note := ""           # what the last reward was, shown on the screen between battles
# battle
var pl                 # Combatant: you
var foe                # Foe: the enemy
var history = CombatLog.new()   # what has happened this battle: query it instead of keeping counters
var bat := {}          # only state that is not history: {extra_draw}
var energy := MAXE
var lives := START_LIVES
var battle_no := 1
var played_this_turn := false
var uid := 0
var stats := {}
# flow
var busy := 0          # 0 free, 1 computer turn, 2 resolving effects, 3 reward screen
var ended := false
var reason := ""
var _cache := {}


func _init() -> void:
	new_game()


## begin = false is for the title screen flow: the run is set up but the first battle waits for run_intro() (the boon and the
## starting rewards).
func new_game(seed_override: int = -1, begin: bool = true) -> void:
	seed_value = seed_override if seed_override >= 0 else 100000000 + randi() % 900000000
	rng.seed = hash("run:%d" % seed_value)
	collection = starter_collection()
	weapon = null
	stored_weapons.clear()
	gems = START_GEMS
	shop = []
	shop_note = ""
	shop_pending = false
	victory_summary = {}
	battle_snap = {}
	turn_snap = {}
	relics.clear()
	stored_relics.clear()
	artifact_offered = false
	reward_note = ""
	battle_no = 1
	stats = new_stats()
	lives = START_LIVES
	ended = false
	reason = ""
	max_hp_bonus = 0
	pl = Combatant.new(PLAYER_HP)
	foe = Foe.new(1)
	if starter_gear:
		weapon = Relics.by_id("short_sword")
		add_relic(Relics.by_id("time_pendant"))
	if begin:
		start_battle()


## The start of a run (after new_game(-1, false)): choose 1 of 3 random boons, then 3 reward screens that only offer common
## dominoes, then the first battle begins.
func run_intro() -> void:
	var boons: Array = Boons.pick(rng, 3)
	var cards := []
	for b in boons:
		cards.append(Boons.card(b))
	var c: int = await ui.pick("Choose a boon", "Pick one boon to start your run.", cards)
	await Boons.apply(self, boons[clampi(c, 0, boons.size() - 1)])
	var taken := []
	for round in 3:
		var opts := []
		for i in 3:
			var d = make_domino(Dominoes.rand_type_of("c", rng, taken))
			taken.append(d.data.id)
			opts.append(d)
		await Boons.offer_dominoes(self, "Starting reward %d of 3" % (round + 1), "Choose a common domino to add to your stack, or skip.", opts)
	start_battle()
	ui.refresh()


static func new_stats() -> Dictionary:
	return {"played": 0, "wasted": 0, "turn": 1, "spent": 0, "pips": 0, "doubles": 0, "free": 0,
			"max_cost": 0, "cpu": 0, "lost": 0, "battles": 0, "selfdmg": 0, "dealt": 0, "taken": 0,
			"absorbed": 0, "shield": 0, "healed": 0, "drawn": 0, "rerolls": 0,
			"t0": Time.get_ticks_msec(), "t1": 0}


# ---- making dominoes ------------------------------------------------------

## A domino of this kind with the kind's own pips (see pip_spec.gd). Give pips_a / pips_b (0 to 6) to
## force a stable pip of that value on that half.
func make_domino(type_id: int, pips_a: int = -1, pips_b: int = -1):
	return Domino.new(data[type_id], pips_a, pips_b)


## A random domino of a random kind (never Garbage) with the kind's pips.
func new_domino(exclude: Array = []):
	return make_domino(Dominoes.rand_type(rng, exclude))


## A domino of this kind by name, at level 1 (for effects that make dominoes).
func make_named(title: String):
	return make_domino(Dominoes.index_of(title))


func garbage():
	return make_domino(Dominoes.GARBAGE)


## The starting deck is the first 20 kinds of the catalogue.
func starter_collection() -> Array:
	var out := []
	for i in 20:
		out.append(make_domino(i))
	return out


func start_battle() -> void:
	_strip_temporary_dominoes()
	rng.seed = hash("battle:%d:%d" % [seed_value, battle_no])    # the same stack and plans every time
	battle_snap = {"hp": pl.hp, "lives": lives, "stats": stats.duplicate(true)}
	occ.clear()
	chars.clear()
	placed.clear()
	_cache.clear()
	for who in CH:
		for i in 3:
			for j in 3:
				chars[CH[who] + Vector2(i, j)] = who
	energy = energy_cap()
	played_this_turn = false
	bat = {"extra_draw": 0, "dealt0": stats.dealt, "taken0": stats.taken, "self0": stats.selfdmg}
	history.clear()
	history.add("battle_started")
	stack.clear()
	for d in collection:
		stack.append(d.copy())
	var top := []
	var bottom := []
	for w in _weapon_dominoes("battle"):
		match w.pos:
			"bottom":
				bottom.append(w.d)
			"top":
				top.append(w.d)
			_:
				stack.append(w.d)
	rshuffle(stack)
	for d in bottom:
		stack.insert(0, d)       # the bottom of the stack: drawn last
	for d in top:
		stack.append(d)          # the top of the stack: drawn first
	for d in stack:
		d.roll_all(rng)          # unstable and volatile pips get their value for this battle
	battle_deck = stack.duplicate()
	discard.clear()
	hand.clear()
	draw(START_HAND)
	new_intent()
	dispatch("on_battle_start")
	_weapon_turn()
	emit("turn_started", "on_turn_start")
	draw(bat.extra_draw)
	busy = 0
	snapshot_turn()


# ---- the hand, stack and discard pile -------------------------------------

## Draws one domino from the stack. Nothing is drawn if the hand is full (max 12) or the stack is empty.
func draw_one() -> bool:
	if hand.size() >= MAXH:
		ui.hand_full()
		return false
	if stack.is_empty():
		return false
	var d = stack.pop_back()
	_enter_hand(d, "stack")
	stats.drawn += 1
	emit("card_drawn", "after_card_drawn", {"title": d.data.title}, {"card": d})
	return true


## Draw a random domino of one type ("attack" or "skill") from the stack into your hand. False if there is none.
func draw_matching(type_id: String) -> bool:
	if hand.size() >= MAXH:
		ui.hand_full()
		return false
	var found := []
	for i in stack.size():
		if stack[i].type() == type_id:
			found.append(i)
	if found.is_empty():
		return false
	var d = stack.pop_at(found[rng.randi() % found.size()])
	_enter_hand(d, "stack")
	stats.drawn += 1
	emit("card_drawn", "after_card_drawn", {"title": d.data.title}, {"card": d})
	return true


## Play a domino from your hand again for free: its effects run `times` times, it does not go on the board, and then it
## is discarded (Dual Wield, Barrage).
func replay_domino(d, times: int) -> void:
	var i := hand.find(d)
	if i < 0:
		return
	hand.remove_at(i)
	_cache.clear()
	ui.refresh()
	for t in times:
		if foe.hp <= 0 or pl.hp <= 0:
			break
		history.add("domino_replayed", {"title": d.data.title})
		await run_fx(d)           # (run_fx ends the attack: Fury ticks down for every play)
		ui.refresh()
		await ui.pause(0.3)
	discard.append(d)
	history.add("card_discarded", {"title": d.data.title})
	ui.card_discarded(d)
	_cache.clear()
	ui.refresh()


## The one way a domino gets into the hand. source says where the UI shows it coming from:
## "stack" (the Stack button) or "top" (the top of the screen).
func _enter_hand(d, source: String) -> void:
	d.ang = 0
	d.hand_turn = history.turn
	hand.append(d)
	_cache.clear()
	ui.card_entered(d, source)


## Put a domino that was made by an effect straight into your hand (nothing happens if the hand is
## full: returns false). In the UI it flies in from the top of the screen unless source says "stack".
func add_to_hand(d, source: String = "top") -> bool:
	if hand.size() >= MAXH:
		ui.hand_full()
		return false
	_enter_hand(d, source)
	history.add("card_added", {"title": d.data.title, "source": source})
	return true


func draw(n: int) -> int:
	var k := 0
	for i in n:
		if draw_one():
			k += 1
	return k


func rshuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## The dominoes your weapon adds when: "battle" or "turn". [{d: the domino, pos}].
func _weapon_dominoes(when: String) -> Array:
	var out := []
	if weapon == null:
		return out
	for add in weapon.adds:
		if add.when != when:
			continue
		var kind := Dominoes.index_of(add.t)
		for i in add.n:
			var d = make_domino(kind)
			d.origin = "equipment"          # it belongs to the weapon: gone when the battle is over
			d.set_level(weapon.level)       # the weapon's level (as far as this domino goes)
			d.roll_all(rng)
			out.append({"d": d, "pos": add.pos})
	return out


## Start of a turn: dominoes with volatile pips get new values wherever they are (stack, hand or discard
## pile). Dominoes already played on the board keep the pips they were played with.
func _roll_volatile_pips() -> void:
	for pile in [stack, hand, discard]:
		for d in pile:
			if d != null and d.has_volatile():
				d.roll_volatile(rng)
	_cache.clear()


## The weapon's start-of-turn dominoes go straight into your hand (if there is room).
func _weapon_turn() -> void:
	for w in _weapon_dominoes("turn"):
		if hand.size() >= MAXH:
			ui.hand_full()
			continue
		_enter_hand(w.d, "top")
		battle_deck.append(w.d)
		announce_new_card()


## Ephemeral dominoes still in your hand when the turn ends go to the discard pile.
func _discard_ephemeral() -> void:
	for d in hand.duplicate():
		if d != null and d.data.ephemeral:
			hand.erase(d)
			discard.append(d)
			history.add("card_discarded", {"title": d.data.title})
			ui.card_discarded(d)


## Tell the UI which card was just added to the hand. Kept as its own function because arithmetic
## written inline right after an await hit a Godot 4.1 to 4.4 bug (it read a stale temporary).
func announce_new_card() -> void:
	ui.fresh(hand.size() - 1)


## Discard a random domino from the hand. Returns false if the hand is empty.
func discard_random_from_hand() -> bool:
	if hand.is_empty():
		return false
	var d = hand.pop_at(rng.randi() % hand.size())
	discard.append(d)
	history.add("card_discarded", {"title": d.data.title})
	_cache.clear()
	ui.card_discarded(d)
	return true


func discard_hand_card(index: int) -> void:
	var d = hand.pop_at(maxi(index, 0))
	discard.append(d)
	history.add("card_discarded", {"title": d.data.title})
	_cache.clear()
	ui.card_discarded(d)
	ui.refresh()


## Reroll effects change only the current pips, so they end with the battle (see domino.gd).
func reroll_hand() -> void:
	for d in hand:
		d.reroll(rng)
	stats.rerolls += hand.size()
	_cache.clear()
	ui.float_text("p", "Rerolled hand")


func reroll_card(index: int) -> void:
	var d = hand[maxi(index, 0)]
	d.reroll(rng)
	stats.rerolls += 1
	_cache.clear()


## Uptick: both current pips of a domino in hand go up by 1 (max 6) until the battle ends.
func uptick_card(index: int) -> void:
	hand[maxi(index, 0)].uptick()
	_cache.clear()
	ui.float_text("p", "Uptick")


func generate_into_stack(n: int) -> void:
	for i in n:
		var d = new_domino()
		d.roll_all(rng)
		stack.insert(rng.randi() % (stack.size() + 1), d)


## Indices of the stack, sorted by domino name (so the stack order is not revealed).
func stack_order_by_title() -> Array:
	var idx := range(stack.size())
	idx.sort_custom(func(p, q): return stack[p].data.title < stack[q].data.title)
	return idx


## Move the chosen domino (position c in the sorted list) from the stack into the hand.
func tutor_take(order: Array, c: int) -> void:
	var got = stack.pop_at(order[maxi(c, 0)])
	_enter_hand(got, "stack")
	announce_new_card()
	ui.refresh()
	await ui.pause(0.3)
	ui.fresh(-1)


# ---- relics ---------------------------------------------------------------

func has_relic(relic_id: String) -> bool:
	for r in relics:
		if r.id == relic_id:
			return true
	return false


## You got an artifact: it is equipped if a slot is free, otherwise it waits in the inventory.
## Returns true when it was equipped.
func add_relic(relic) -> bool:
	if relics.size() < EQUIP_SLOTS:
		relics.append(relic)
		return true
	stored_relics.append(relic)
	return false


func equip_relic(relic) -> bool:
	if not stored_relics.has(relic) or relics.size() >= EQUIP_SLOTS:
		return false
	stored_relics.erase(relic)
	relics.append(relic)
	return true


func unequip_relic(relic) -> void:
	if relics.has(relic):
		relics.erase(relic)
		stored_relics.append(relic)


## Ids of every artifact you own, equipped or not.
func relic_ids() -> Array:
	var out := []
	for r in relics + stored_relics + stored_weapons:
		out.append(r.id)
	if weapon != null:
		out.append(weapon.id)
	return out


## Make another weapon your equipped one. The old one goes back to your inventory. A weapon can never
## be put away without replacing it.
func equip_weapon(w) -> bool:
	if not stored_weapons.has(w):
		return false
	stored_weapons.erase(w)
	if weapon != null:
		stored_weapons.append(weapon)
	weapon = w
	return true


## The Time Pendant is equipped: the Rewind turn button exists.
func has_rewind() -> bool:
	return relic_sum("rewind") > 0


func can_rewind_turn() -> bool:
	return has_rewind() and not ended and busy == 0 and lives > 1 and not turn_snap.is_empty() and turn_snap.lives > 1


## Remember the start of this turn (hand, stack, board, both fighters, the random numbers ...).
func snapshot_turn() -> void:
	turn_snap = {
		"hand": _states(hand), "stack": _states(stack), "discard": _states(discard),
		"deck": battle_deck.duplicate(),
		"occ": occ.duplicate(true), "placed": placed.duplicate(true),
		"pl": pl.get_state(), "foe": foe.get_state(),
		"energy": energy, "lives": lives, "played": played_this_turn,
		"bat": bat.duplicate(true), "history": history.save(), "stats": stats.duplicate(true), "rng": rng.state,
	}
	ui.autosave_point()


func _states(pile: Array) -> Array:
	var out := []
	for d in pile:
		out.append({"d": d, "a": d.a, "b": d.b, "rolled": d.rolled, "ang": d.ang} if d != null else null)
	return out


func _restore_pile(states: Array) -> Array:
	var out := []
	for st in states:
		if st == null:
			out.append(null)
			continue
		var d = st.d
		d.a = st.a
		d.b = st.b
		d.rolled = st.rolled
		d.ang = st.ang
		out.append(d)
	return out


## Time Pendant: go back to the start of this turn and pay 1 life for it. Returns false if it cannot.
func restart_turn() -> bool:
	if not can_rewind_turn():
		return false
	var t: Dictionary = turn_snap
	hand = _restore_pile(t.hand)
	stack = _restore_pile(t.stack)
	discard = _restore_pile(t.discard)
	battle_deck = t.deck.duplicate()
	occ = t.occ.duplicate(true)
	placed = t.placed.duplicate(true)
	pl.set_state(t.pl)
	foe.set_state(t.foe)
	energy = t.energy
	played_this_turn = t.played
	bat = t.bat.duplicate(true)
	history.load_saved(t.history)
	stats = t.stats.duplicate(true)
	rng.state = t.rng
	_reset_counters()
	lives = t.lives - 1
	stats.lost += 1
	busy = 0
	_cache.clear()
	ui.flash()
	ui.refresh()
	return true


## Start this battle over: same stack order, same enemy plans, and your HP, lives and stats as they were
## when it began. (Works after a defeat too.)
func restart_battle() -> bool:
	if battle_snap.is_empty() or (busy != 0 and not ended):
		return false
	lives = battle_snap.lives
	stats = battle_snap.stats.duplicate(true)
	pl.hp = battle_snap.hp
	pl = fresh_player()
	foe = Foe.new(battle_no)
	ended = false
	reason = ""
	start_battle()
	ui.refresh()
	return true


# ---- gems and the shop ----------------------------------------------------

func shop_price(i: int) -> int:
	return maxi(1, shop[i].price - relic_sum("shop_discount"))


## Can shop item i be bought right now? (An upgrade also needs a domino that is not at its top level.)
func can_buy(i: int) -> bool:
	if i < 0 or i >= shop.size() or shop[i].sold or gems < shop_price(i):
		return false
	if shop[i].kind != "upgrade":
		return true
	return not (upgradable_weapons() if shop[i].mode == "weapon" else upgradable_dominoes()).is_empty()


## Buy shop item i. An upgrade of mode "pick" needs target: the domino in your collection to upgrade.
## Nothing is paid when this returns false.
func buy(i: int, target = null) -> bool:
	if not can_buy(i):
		return false
	if shop[i].kind == "upgrade" and shop[i].mode == "pick" and (target == null or not upgradable_dominoes().has(target)):
		return false
	if shop[i].kind == "upgrade" and shop[i].mode == "weapon" and (target == null or not upgradable_weapons().has(target)):
		return false
	gems -= shop_price(i)
	shop[i].sold = true
	shop_note = ""
	match shop[i].kind:
		"domino":
			collection.append(shop[i].item)
		"relic":
			add_relic(shop[i].item)
		"weapon":
			stored_weapons.append(shop[i].item)
		"upgrade":
			_buy_upgrade(shop[i].mode, target)
	return true


## The dominoes in your collection that can still go up a level (weapon dominoes take their weapon's level).
func upgradable_dominoes() -> Array:
	return collection.filter(func(d): return d.can_upgrade() and d.data.rarity != "w")


## The weapons (the equipped one and the ones in your inventory) that can still go up a level.
func upgradable_weapons() -> Array:
	var out := []
	for w in [weapon] + stored_weapons:
		if w != null and w.can_upgrade():
			out.append(w)
	return out


## Give a level to the chosen domino ("pick"), a random one ("random") or two different random ones ("random2").
func _buy_upgrade(mode: String, target) -> void:
	var chosen := []
	if mode == "weapon":
		var before_w: String = target.display_name()
		target.upgrade()
		shop_note = "Upgraded: %s is now %s (and so are the dominoes it adds)" % [before_w, target.display_name()]
		return
	if mode == "pick":
		chosen = [target]
	else:
		var pool := upgradable_dominoes()
		rshuffle(pool)
		chosen = pool.slice(0, 1 if mode == "random" else 2)
	var lines := []
	for d in chosen:
		var before: String = d.display_name()
		d.upgrade()
		lines.append("%s is now %s" % [before, d.display_name()])
	shop_note = "Upgraded: " + ", ".join(lines)


## The upgrade in every shop is one of these, chosen at random.
const UPGRADE_MODES := ["pick", "random", "random2"]
const UPGRADE_PRICE := {"pick": 5, "random": 3, "random2": 6, "weapon": 6}
## A shop has a 10% chance of also offering to upgrade one of your weapons.
const WEAPON_UPGRADE_CHANCE := 0.1
const UPGRADE_TEXT := {
	"pick": "[b]Upgrade a domino[/b]\nChoose any domino you own that is not at its top level. It goes up a level.",
	"random": "[b]Upgrade a random domino[/b]\nOne domino you own, picked at random, goes up a level.",
	"random2": "[b]Upgrade 2 random dominoes[/b]\nTwo different dominoes you own, picked at random, each go up a level.",
	"weapon": "[b]Upgrade a weapon[/b]\nChoose one of your weapons. It goes up a level, and so do the dominoes it adds.",
}


## What a rarity costs as a domino: common 2-3 gems, uncommon 4-5, rare 6-8.
func _domino_price(r: String) -> int:
	match r:
		"c":
			return rng.randi_range(2, 3)
		"u":
			return rng.randi_range(4, 5)
		"r":
			return rng.randi_range(6, 8)
	return 1


## 5 dominoes (one of them always rare), 2 artifacts (twice the price of a domino of their rarity) and
## 1 weapon (1.5 times). Rarer ones turn up less often (60 / 30 / 10).
func generate_shop() -> Array:
	var used := []         # the shop never sells two of the same domino
	var doms := [make_domino(Dominoes.rand_type_of("r", rng))]
	used.append(doms[0].data.id)
	for i in 4:
		var d = new_domino(used)
		used.append(d.data.id)
		doms.append(d)
	rshuffle(doms)
	var items := []
	for d in doms:
		items.append({"kind": "domino", "item": d, "price": _domino_price(d.data.rarity), "sold": false})
	for r in Relics.roll(relic_ids(), 2, rng):
		items.append({"kind": "relic", "item": r, "price": 2 * _domino_price(r.rarity), "sold": false})
	for w in Relics.roll_weapons(relic_ids(), 1, rng):
		items.append({"kind": "weapon", "item": w, "price": roundi(1.5 * _domino_price(w.rarity)), "sold": false})
	var mode: String = UPGRADE_MODES[rng.randi() % UPGRADE_MODES.size()]
	items.append({"kind": "upgrade", "mode": mode, "item": {"text": UPGRADE_TEXT[mode]}, "price": UPGRADE_PRICE[mode], "sold": false})
	if rng.randf() < WEAPON_UPGRADE_CHANCE and not upgradable_weapons().is_empty():
		items.append({"kind": "upgrade", "mode": "weapon", "item": {"text": UPGRADE_TEXT["weapon"]}, "price": UPGRADE_PRICE["weapon"], "sold": false})
	for it in items:
		if it.kind != "upgrade":
			Library.offer(_library_kind(it.kind), _library_id(it), "shop")
	return items


## The library's name for a shop item's kind and the id it is listed under.
func _library_kind(shop_kind: String) -> String:
	return {"domino": "domino", "relic": "artifact", "weapon": "weapon"}[shop_kind]


func _library_id(it: Dictionary) -> String:
	return it.item.data.title if it.kind == "domino" else it.item.id


## You are leaving the shop: everything you could have afforded but did not buy counts as skipped in the library.
func leave_shop() -> void:
	for i in shop.size():
		var it: Dictionary = shop[i]
		if it.kind == "upgrade" or it.sold or it.get("counted", false):
			continue
		it["counted"] = true
		if gems >= shop_price(i):
			Library.skip(_library_kind(it.kind), _library_id(it), "shop")


## What happened in the battle you just won, for the victory screen.
func _victory_numbers() -> Dictionary:
	return {
		"dealt": stats.dealt - bat.dealt0,
		"lost": (stats.taken - bat.taken0) + (stats.selfdmg - bat.self0),
		"gems": rng.randi_range(2, 3) + relic_sum("gems"),
		"battle": battle_no,
	}


## Max HP at the start of a battle: the base plus artifacts that raise it.
func base_max_hp() -> int:
	return PLAYER_HP + max_hp_bonus + relic_sum("max_hp")


## A fresh Combatant for the next battle: no shield, no statuses, max shield back to normal, max HP
## from your equipped artifacts. HP is NOT restored: you keep what you have (at most the new max).
func fresh_player():
	var keep: int = pl.hp
	var c = Combatant.new(base_max_hp())
	c.hp = mini(keep, c.max_hp)
	return c


## The whole deck of this battle, alphabetical: [{d, state}] where state is "stack" (not drawn yet),
## "hand" or "drawn" (played or discarded).
func battle_deck_entries() -> Array:
	var all := battle_deck.duplicate()
	for pile in [stack, hand, discard]:
		for d in pile:
			if d != null and not all.has(d):
				all.append(d)
	all.sort_custom(_domino_before)
	var out := []
	for d in all:
		var state := "drawn"
		if hand.has(d):
			state = "hand"
		elif stack.has(d):
			state = "stack"
		out.append({"d": d, "state": state})
	return out


## Every domino you own, alphabetical, all "stack" (for between battles).
func collection_entries() -> Array:
	var all := collection.duplicate()
	all.sort_custom(_domino_before)
	var out := []
	for d in all:
		out.append({"d": d, "state": "stack"})
	return out


static func _domino_before(x, y) -> bool:
	var a: String = x.data.title.to_lower()
	var b: String = y.data.title.to_lower()
	if a != b:
		return a < b
	if x.total() != y.total():
		return x.total() < y.total()
	return x.a < y.a


## Total of a passive number from every relic ("max_energy", "rewards").
func relic_sum(key: String) -> int:
	var n := 0
	for r in relics:
		n += r.passive_value(key)
	return n


## Every model that can react right now: relics, the statuses on both combatants and the dominoes in
## your hand. p / f replace you / the enemy (previews pass copies).
func active_models(p = null, f = null) -> Array:
	var out := []
	out.append_array(relics)
	out.append_array((p if p != null else pl).models())
	out.append_array((f if f != null else foe).models())
	out.append_array(hand)
	return out


## Call a hook (one of AbstractModel.HOOKS) on every active model, lowest priority first. The list
## is copied first, so a hook that changes the hand or the board cannot upset the loop.
func dispatch(hook: String, ctx: Dictionary = {}) -> void:
	assert(AbstractModel.HOOKS.has(hook), "unknown hook: " + hook)
	for m in AbstractModel.in_order(active_models()):
		m.call(hook, self, ctx)


## Write an event to the combat history and, if hook is not "", dispatch it. The hook gets the event
## data plus anything in extra (live objects such as source, target, card).
func emit(type: String, hook: String = "", data: Dictionary = {}, extra: Dictionary = {}) -> void:
	var ev := history.add(type, data)
	if hook != "":
		var ctx := ev.duplicate()
		ctx.merge(extra)
		dispatch(hook, ctx)


## "p" for you, "c" for the enemy (the side names the UI uses).
func side_of(creature) -> String:
	return "p" if creature == pl else "c"


## Energy you start each turn with.
func energy_cap() -> int:
	return MAXE + relic_sum("max_energy")


func gain_energy(n: int) -> void:
	energy += n
	ui.float_text("p", "+%d energy" % n)


func lose_energy(n: int) -> void:
	energy = maxi(0, energy - n)
	_cache.clear()
	ui.float_text("p", "-%d energy" % n)


func gain_shield(n: int) -> void:
	CreatureCmd.gain_shield(self, pl, n)


func gain_life(n: int) -> void:
	lives += n
	ui.float_text("p", "+%d li%s" % [n, "fe" if n == 1 else "ves"])


## Draw right now because of a relic (nothing is drawn if the hand is full or the stack is empty).
func relic_draw(n: int) -> void:
	for i in n:
		if draw_one():
			announce_new_card()
			ui.float_text("p", "+1 domino")


## Shuffle n random discarded dominoes back into the stack. Returns how many moved.
func restack_random(n: int = 1) -> int:
	var moved := 0
	for i in n:
		if discard.is_empty():
			break
		var d = discard.pop_at(rng.randi() % discard.size())
		stack.insert(rng.randi() % (stack.size() + 1), d)
		moved += 1
	if moved > 0:
		_cache.clear()
		ui.float_text("p", "Domino back in stack")
	return moved


## How many dominoes you draw at the start of a turn.
func draws_per_turn() -> int:
	return DRAW_PER_TURN + bat.extra_draw


## How many pips with this number are on the board ("board") or in your hand ("hand").
func count_pips(pip: int, where: String) -> int:
	var n := 0
	if where == "board":
		for c in occ:
			if occ[c].pip == pip:
				n += 1
	else:
		for d in hand:
			if d.a == pip:
				n += 1
			if d.b == pip:
				n += 1
	return n


# ---- geometry -------------------------------------------------------------

## rot even -> 2 wide x 1 tall, rot odd -> 1 wide x 2 tall (x, y is the min corner)
static func dims(rot: int) -> Vector2:
	return Vector2(2, 1) if rot % 2 == 0 else Vector2(1, 2)


## Returns [cell of pip a, cell of pip b]
static func cells_of(m: Dictionary) -> Array:
	var x: int = m.x
	var y: int = m.y
	match m.rot & 3:
		0:
			return [Vector2(x, y), Vector2(x + 1, y)]
		1:
			return [Vector2(x, y), Vector2(x, y + 1)]
		2:
			return [Vector2(x + 1, y), Vector2(x, y)]
		_:
			return [Vector2(x, y + 1), Vector2(x, y)]


static func clamp_m(m: Dictionary) -> void:
	var d := dims(m.rot)
	m.x = clampi(m.x, 0, N - int(d.x))
	m.y = clampi(m.y, 0, N - int(d.y))


# ---- board rules ----------------------------------------------------------

## Returns {ok, cost, why}. who is "p" or "c". free ignores the energy limit (CPU).
func check(m: Dictionary, free := false, who := "p") -> Dictionary:
	var cs := cells_of(m)
	var pips := [m.a, m.b]
	var touches := {}
	var cost := 0
	var stem := false
	for c in cs:
		if occ.has(c) or chars.has(c):
			return {"ok": false, "why": "Space taken"}
	for k in 2:
		var touched := false
		for d in DIRS:
			var nb: Vector2 = cs[k] + d
			if chars.has(nb):
				if chars[nb] == who:
					stem = true
				continue
			if not occ.has(nb):
				continue
			var o: Dictionary = occ[nb]
			if o.owner == who:
				stem = true
			if o.pip != pips[k]:
				return {"ok": false, "why": "Pips must match"}
			touched = true
			touches[o.id] = touches.get(o.id, 0) + 1
			if touches[o.id] > 1:
				return {"ok": false, "why": "Touches same domino twice"}
		if not touched:
			cost += pips[k]
	if not stem:
		return {"ok": false, "why": "Connect to your character"}
	if cost > energy and not free:
		return {"ok": false, "why": "Needs %d energy" % cost, "cost": cost}
	return {"ok": true, "cost": cost}


## Board check plus the domino's own play condition. m.i is the index of the domino in hand.
func check_p(m: Dictionary) -> Dictionary:
	if m.has("i") and m.i >= 0 and m.i < hand.size():
		if not cond_ok(m.i):
			var c = hand[m.i].data.condition
			if c.id == "never":
				return {"ok": false, "why": "Garbage cannot be played"}
			return {"ok": false, "why": "Needs: " + c.text}
	return check(m)


## Does the hand domino at index i meet its play condition right now?
func cond_ok(i: int) -> bool:
	if pl.value("berserk") > 0 and hand[i].type() != "attack":
		return false          # Berserk: only attack dominoes this turn
	var c = hand[i].data.condition
	if c != null and c.hand_size and relic_sum("ignore_hand") > 0:
		return true           # Loose Grip: "you must hold N dominoes" does not matter
	return c == null or c.met(self, i)


## Is there a legal spot on the board for these pips? Cached until the board or energy changes.
func _board_can(a: int, b: int) -> bool:
	var key := "%d,%d" % [a, b]
	if _cache.has(key):
		return _cache[key]
	var result := false
	for r in 4:
		var dm := dims(r)
		for x in range(0, N - int(dm.x) + 1):
			for y in range(0, N - int(dm.y) + 1):
				if check({"x": x, "y": y, "rot": r, "a": a, "b": b}).ok:
					result = true
					break
			if result:
				break
		if result:
			break
	_cache[key] = result
	return result


## Can the hand domino at index i be played at all right now?
func can_play(i: int) -> bool:
	return cond_ok(i) and _board_can(hand[i].a, hand[i].b)


func playable_any() -> bool:
	for i in hand.size():
		if can_play(i):
			return true
	return false


func place(m: Dictionary, who: String) -> void:
	uid += 1
	var cs := cells_of(m)
	var pips := [m.a, m.b]
	for k in 2:
		occ[cs[k]] = {"id": uid, "owner": who, "pip": pips[k]}
	placed.append({"x": m.x, "y": m.y, "rot": m.rot, "a": m.a, "b": m.b, "owner": who})
	_cache.clear()


# ---- text for the UI ------------------------------------------------------

## One line of text per effect, with your current Power / Boost / Fury already added to damage.
func fx_lines(d) -> Array:
	var out := []
	for e in d.data.effects:
		out.append(e.shown_text(self, d))
	return out


## The same lines, each with the kind of effect (for its icon): [{k, text}].
func fx_entries(d) -> Array:
	var out := []
	for e in d.data.effects:
		out.append({"k": e.icon(), "text": e.shown_text(self, d)})
	return out


## Icon + number chips shown under a hand domino. A red X ("x") replaces the icon when the
## play condition is not met, and for Garbage.
func caps(i: int) -> Array:
	var d = hand[i]
	if d.data.is_garbage():
		return [{"k": "x", "num": ""}]
	var chips := []
	for e in d.data.effects:
		chips.append({"k": e.icon(), "num": e.shown_caption(self, d)})
	if not cond_ok(i):
		return [{"k": "x", "num": chips[0].num if chips.size() > 0 else ""}]
	return chips


func intent_text(it: Dictionary) -> String:
	match it.k:
		"atk":
			return "Attack %d" % DamageCmd.attack_value(self, foe, pl, it.v)
		"lifeatk":
			return "Attack %d (lose a life if unblocked)" % DamageCmd.attack_value(self, foe, pl, it.v)
		"blk":
			return "Block %d" % it.v
		"discH":
			return "Discard a domino from your hand"
		"mill":
			return "Discard your top stack domino, add Garbage"
	return "Shuffle 3 Garbage into your stack"


## What the hand domino at index i would do to the enemy's HP if you played it now:
## {attack, hp (HP the enemy would lose), absorbed (damage its shield would soak)}. Statuses that
## the domino gives itself first (Fury before a hit ...) are counted, relics are not.
func preview_player_attack(i: int) -> Dictionary:
	var out := {"attack": false, "hp": 0, "absorbed": 0}
	if i < 0 or i >= hand.size():
		return out
	var d = hand[i]
	if not d.data.has_attack() or not cond_ok(i):
		return out
	var sim := {"pl": pl.snapshot(), "foe": foe.snapshot()}
	for e in d.data.effects:
		e.preview(self, d, e.size_for(d), sim)
	out.attack = true
	out.hp = foe.hp - sim.foe.hp
	out.absorbed = foe.shield - sim.foe.shield
	return out


## The enemy's planned actions with what each one would do to you if the turn ended now (your
## current shield soaks first, one attack after another, and its Fury / Impair ticks down after each):
## {entries: [{k, text}], loss (total HP you would lose), attacks (how many attacks), absorbed}.
## With with_loss false the texts only say how hard each attack is (the "show damage taken" option).
func preview_intents(with_loss: bool = true) -> Dictionary:
	var sim_pl = pl.snapshot()
	var sim_foe = foe.snapshot()
	var out := {"entries": [], "loss": 0, "attacks": 0, "absorbed": 0}
	for it in foe.intent:
		var text := intent_text(it)
		if it.k == "atk" or it.k == "lifeatk":
			var dmg: int = DamageCmd.attack_value(self, sim_foe, sim_pl, it.v)
			var r: Dictionary = DamageCmd.deal(self, sim_foe, sim_pl, dmg, true)
			DamageCmd.finish_attack(self, sim_foe, true)
			out.attacks += 1
			out.loss += r.taken
			out.absorbed += r.absorbed
			text = "Attack %d" % dmg
			if not with_loss:
				if it.k == "lifeatk":
					text += " (lose a life if unblocked)"
			elif r.taken > 0:
				text += ": -%d HP" % r.taken
				if it.k == "lifeatk":
					text += " and a life"
			elif dmg > 0:
				text += ": blocked"
			else:
				text += ": no damage"
		out.entries.append({"k": it.k, "text": text})
	return out


# ---- combat ---------------------------------------------------------------

func hit_foe(n: int) -> void:
	DamageCmd.deal(self, pl, foe, n)


## Returns the damage that got through the shield.
func hit_pl(n: int) -> int:
	return DamageCmd.deal(self, foe, pl, n).taken


## "" while you are alive. At 0 HP or 0 lives artifacts get one chance to save you (the on_death hook:
## the Lizard Tail gives lives and heals you); if they do not, this says why the run is over.
func _death_reason() -> String:
	if pl.hp > 0 and lives > 0:
		return ""
	dispatch("on_death")
	if pl.hp > 0 and lives > 0:
		ui.refresh()
		return ""
	return "You were defeated" if pl.hp <= 0 else "You ran out of lives"


## An artifact that breaks (a row with "breaks": true) leaves your inventory for good.
func break_relic(r) -> void:
	relics.erase(r)
	stored_relics.erase(r)
	history.add("relic_broken", {"relic": r.id})
	ui.toast("%s crumbles to dust" % r.title)


func lose_life() -> void:
	lives -= 1
	stats.lost += 1
	ui.flash()
	ui.float_text("p", "Lost a life")


## The enemy plans 1 or 2 dominoes per turn and shows each one as its intent.
## Attacks and blocks are common; the other intents are uncommon.
func new_intent() -> void:
	# planned from the seed, the battle and the turn only: restarting gives the same plans
	var r_in := RandomNumberGenerator.new()
	r_in.seed = hash("intent:%d:%d:%d" % [seed_value, battle_no, history.turn])
	var n := 1 if r_in.randf() < 0.5 else 2
	var lv := battle_no - 1
	var out := []
	for i in n:
		var r := r_in.randf()
		if r < 0.62:
			out.append({"k": "atk", "v": 4 + lv + r_in.randi() % (8 + lv)})
		elif r < 0.75:
			out.append({"k": "blk", "v": 4 + lv + r_in.randi() % 5})
		elif r < 0.82:
			out.append({"k": "lifeatk", "v": 5 + lv + r_in.randi() % (6 + lv)})
		elif r < 0.88:
			out.append({"k": "discH"})
		elif r < 0.94:
			out.append({"k": "mill"})
		else:
			out.append({"k": "junk"})
	foe.intent = out


## The computer plays one domino built to match the board. Returns true on success.
func cpu_play() -> bool:
	var rare := rng.randf() < 0.12      # rarely plays a domino that touches no other domino
	var own := false
	for p in placed:
		if p.owner == "c":
			own = true
			break
	for _attempt in 500:
		var m := {"x": rng.randi() % N, "y": rng.randi() % N, "rot": rng.randi() % 4, "a": 0, "b": 0}
		clamp_m(m)
		var cs := cells_of(m)
		var req := [-1, -1]
		var touch := false
		var bad := false
		var stem := false
		for k in 2:
			for d in DIRS:
				var nb: Vector2 = cs[k] + d
				if chars.has(nb):
					if chars[nb] == "c":
						stem = true
					continue
				if occ.has(nb):
					var o: Dictionary = occ[nb]
					touch = true
					if o.owner == "c":
						stem = true
					if req[k] != -1 and req[k] != o.pip:
						bad = true
					req[k] = o.pip
		if bad or not stem:
			continue
		if own and not rare and not touch:
			continue
		if rare and touch:
			continue
		m.a = req[0] if req[0] != -1 else rng.randi() % 7
		m.b = req[1] if req[1] != -1 else rng.randi() % 7
		if not check(m, true, "c").ok:
			continue
		place(m, "c")
		stats.cpu += 1
		ui.swing("c")
		return true
	return false


# ---- playing a domino -----------------------------------------------------

## Plays the pending domino m (m.i is its index in hand): place it, pay energy, resolve its effects.
func play_domino(m: Dictionary) -> void:
	if busy != 0 or ended:
		return
	var ck := check_p(m)
	if not ck.ok:
		ui.toast(ck.why)
		return
	place(m, "p")
	energy -= ck.cost
	stats.played += 1
	stats.spent += ck.cost
	stats.pips += m.a + m.b
	if m.a == m.b:
		stats.doubles += 1
	if ck.cost == 0:
		stats.free += 1
	stats.max_cost = maxi(stats.max_cost, ck.cost)
	played_this_turn = true
	ui.swing("p")
	# the played domino stays on the board: it does not go to the discard pile
	var d = hand[m.i]
	hand.remove_at(m.i)
	Library.use(d.data.title, history.turn - d.hand_turn)       # the library: how long it waited in your hand
	var played := history.add("domino_played", {"a": m.a, "b": m.b, "cost": ck.cost,
			"attack": d.data.has_attack()})
	var ctx := played.duplicate()
	ctx["domino"] = d
	busy = 2
	_cache.clear()
	ui.note_play()
	ui.refresh()
	await ui.pause(0.25)
	dispatch("on_domino_played", ctx)
	await run_fx(d)
	busy = 0
	ui.note_play()
	var dead := _death_reason()
	if dead != "":
		finish(dead)
		return
	if foe.hp <= 0:
		await battle_won()
		return
	if end_turn_after_play:       # the domino said "ends your turn"
		end_turn_after_play = false
		ui.refresh()
		await end_turn()
		return
	ui.refresh()


## Play every effect of a domino in order. The effects themselves live in scripts/effects/.
func run_fx(d) -> void:
	for e in d.data.effects:
		if foe.hp <= 0 or pl.hp <= 0:
			break
		await e.apply(self, d, e.size_for(d))
		_cache.clear()
		ui.refresh()
		await ui.pause(0.16)
	if d.data.has_attack():
		DamageCmd.finish_attack(self, pl)     # Fury / Impair tick down, Boost is used up (Power stays until the battle ends)
	_cache.clear()


# ---- turn flow ------------------------------------------------------------

func end_turn() -> void:
	if busy != 0 or ended:
		return
	busy = 1
	_discard_ephemeral()
	emit("turn_ended", "on_turn_end", {"hand_empty": hand.is_empty()})
	stats.wasted += energy
	energy = 0
	_cache.clear()
	ui.refresh()
	if not played_this_turn:
		# skipped the turn: lose a life
		ui.flash()
		lives -= 1
		stats.lost += 1
		ui.refresh()
		await ui.pause(1.1)
		var skipped_dead := _death_reason()
		if skipped_dead != "":
			finish(skipped_dead)
			return
	foe.shield = 0
	for it in foe.intent.duplicate():
		await ui.pause(0.5)
		cpu_play()
		_enemy_act(it)
		_cache.clear()
		ui.refresh()
		var down := _death_reason()
		if down != "":
			finish(down)
			return
	await ui.pause(0.45)
	_new_turn_state()
	ui.refresh()
	for i in draws_per_turn():
		if draw_one():
			announce_new_card()
		ui.refresh()
		await ui.pause(0.38)
	ui.fresh(-1)
	busy = 0
	snapshot_turn()
	ui.note_play()
	ui.refresh()
	await stuck_check()


## One planned enemy action. A normal function (no waiting) on purpose, see announce_new_card.
func _enemy_act(it: Dictionary) -> void:
	match it.k:
		"atk", "lifeatk":
			var taken: int = DamageCmd.attack(self, foe, pl, it.v).taken
			DamageCmd.finish_attack(self, foe)
			if it.k == "lifeatk" and taken > 0:
				lose_life()
		"blk":
			CreatureCmd.gain_shield(self, foe, it.v)
		"discH":
			if discard_random_from_hand():
				ui.float_text("p", "Domino discarded")
		"mill":
			if stack.size() > 0:
				discard.append(stack.pop_back())
			stack.append(garbage())
			ui.float_text("p", "Garbage on your stack")
		"junk":
			for i in 3:
				stack.append(garbage())
			rshuffle(stack)
			ui.float_text("p", "3 Garbage shuffled in")


## Start-of-turn bookkeeping, in a normal function for the same reason.
func _new_turn_state() -> void:
	stats.turn += 1
	history.next_turn()
	bat.extra_draw = 0
	_roll_volatile_pips()
	energy = energy_cap()
	played_this_turn = false
	_weapon_turn()
	emit("turn_started", "on_turn_start")        # before the excess shield is cut, so relics can look at it
	if pl.shield > pl.max_shield:
		pl.shield = pl.max_shield
		ui.float_text("p", "Excess shield lost")
	new_intent()
	_cache.clear()


## At the start of a battle or a turn, if nothing in hand can be played you lose a life and the turn passes.
func stuck_check() -> void:
	if ended or busy != 0 or playable_any():
		return
	busy = 1
	ui.toast("No playable dominoes: you lose a life")
	ui.refresh()
	await ui.pause(1.3)
	busy = 0
	await end_turn()


## Heal fully, clear every status, offer 3 dominoes (take one or skip), then start the next battle.
## The work after the wait is kept in normal (non-coroutine) helpers on purpose: a longer version of
## this function hit a Godot 4.1 to 4.4 compiler bug that corrupted battle_no after the await.
func battle_won() -> void:
	busy = 3
	_strip_temporary_dominoes()
	ui.refresh()
	await ui.pause(1.0)      # a second for the last animations before the victory screen
	var opts := _begin_reward()
	await ui.victory(self, victory_summary)
	await _reward_step(opts)
	await ui.intermission(self)
	_start_next_battle()
	await stuck_check()


## Dominoes made by equipment or by other dominoes belong to what made them: they never stay in your collection.
func _strip_temporary_dominoes() -> void:
	collection = collection.filter(func(d): return d.origin == "collection")


## Counters that count up (and reset every turn) start from 0 again when a turn is restarted.
func _reset_counters() -> void:
	for r in relics:
		r.reset_up_counter()


## The reward. Usually: pick a domino (or skip). With RELIC_CHANCE it is a choice first: a domino
## (pick 1 of 3) or a random artifact.
func _reward_step(opts: Array) -> void:
	if not artifact_offered:
		_take_domino(await ui.pick("Victory!", "Choose a domino to add to your stack, or skip.", opts, "Skip"), opts)
		return
	var which: int = await ui.pick("Victory!", "Choose your reward.", _reward_cards(opts.size()), "Skip")
	await _after_choice(which, opts)


func _after_choice(which: int, opts: Array) -> void:
	if which == 1:
		_give_random_relic()
	elif which == 0:
		_take_domino(await ui.pick("Victory!", "Choose a domino to add to your stack, or skip.", opts, "Skip"), opts)
	else:
		reward_note = "You skipped the reward."


## The two cards of the "domino or artifact" choice (plain dictionaries with a bbcode text).
func _reward_cards(n: int) -> Array:
	return [
		{"text": "[b]A domino[/b]\nChoose 1 of %d new dominoes." % n},
		{"text": "[b]An artifact[/b]\nGain a random artifact. It is equipped if a slot is free."},
	]


func _begin_reward() -> Array:
	stats.battles += 1
	victory_summary = _victory_numbers()
	gems += victory_summary.gems
	dispatch("on_victory")
	pl = fresh_player()      # statuses and shield are cleared, HP is kept
	shop_pending = battle_no == 1 or rng.randf() < SHOP_CHANCE
	shop = generate_shop() if shop_pending else []
	shop_note = ""
	ui.refresh()
	var opts := []
	var taken := []        # a domino offered here is not in the shop, and the choices are all different
	for it in shop:
		if it.kind == "domino":
			taken.append(it.item.data.id)
	for i in 3 + relic_sum("rewards"):
		var d = new_domino(taken)
		taken.append(d.data.id)
		opts.append(d)
	for d in opts:
		Library.offer("domino", d.data.title, "reward")
	reward_note = ""
	artifact_offered = rng.randf() < relic_chance and not Relics.roll(relic_ids(), 1, rng).is_empty()
	return opts


func _take_domino(c: int, opts: Array) -> void:
	for i in opts.size():
		if i != c:
			Library.skip("domino", opts[i].data.title, "reward")      # offered and not taken
	if c >= 0:
		var d = opts[c].copy()
		collection.append(d)
		reward_note = "New domino: %s %s" % [d.display_name(), d.pips_text()]
	else:
		reward_note = "You skipped the reward."


func _give_random_relic() -> void:
	var got: Array = Relics.roll(relic_ids(), 1, rng)
	if got.is_empty():
		reward_note = "No artifacts left to find."
		return
	Library.offer("artifact", got[0].id, "reward")
	var equipped := add_relic(got[0])
	reward_note = "New artifact: %s (%s)" % [got[0].title, "equipped" if equipped else "unequipped, no free slot"]


func _start_next_battle() -> void:
	battle_no += 1
	pl = fresh_player()      # again: you may have changed your artifacts since the reward
	foe = Foe.new(battle_no)
	start_battle()
	ui.refresh()


func finish(r: String) -> void:
	reason = r
	ended = true
	busy = 0
	stats.t1 = Time.get_ticks_msec()
	ui.autosave_point()      # a run that ends is saved too (at the start of the turn you lost in)
	ui.finished()
