extends RefCounted
## The boons: at the start of a new run you choose 1 of 3 random boons, then you get 3 reward screens that only offer
## common dominoes. apply() does what the boon says (some of them ask you to choose something). To add a boon, add a
## row to LIST and a branch to apply().

const Dominoes = preload("res://scripts/dominoes.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const Library = preload("res://scripts/library.gd")

const LIST := [
	{"id": "upgrade3", "name": "Upgrade 3 dominoes", "text": "Three random dominoes in your collection go up a level."},
	{"id": "remove2", "name": "Remove 2 dominoes", "text": "Choose 2 dominoes to take out of your collection."},
	{"id": "maxhp", "name": "+20 max HP", "text": "Your maximum HP goes up by 20 for the whole run."},
	{"id": "rare3", "name": "A rare domino", "text": "A reward screen with 3 rare dominoes. You may skip it."},
	{"id": "weapon2", "name": "A common weapon", "text": "A reward screen with 2 common weapons (not the one you have). The one you pick is equipped."},
	{"id": "artifact2", "name": "A common artifact", "text": "A reward screen with 2 common artifacts."},
	{"id": "weapon_u", "name": "An uncommon weapon", "text": "Gain a random uncommon weapon. It is equipped."},
	{"id": "artifact_u", "name": "An uncommon artifact", "text": "Gain a random uncommon artifact."},
	{"id": "luck", "name": "Beginner's Luck", "text": "Add the legendary domino Beginner's Luck to your stack: gain 6 energy (ephemeral)."},
]


## n different random boons.
static func pick(rng: RandomNumberGenerator, n: int) -> Array:
	var pool := LIST.duplicate()
	var out := []
	for i in n:
		if pool.is_empty():
			break
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## The boon as a card for the pick window.
static func card(boon: Dictionary) -> Dictionary:
	return {"text": "[b]%s[/b]\n%s" % [boon.name, boon.text]}


static func apply(g, boon: Dictionary) -> void:
	match boon.id:
		"upgrade3":
			var pool: Array = g.upgradable_dominoes()
			g.rshuffle(pool)
			var done := []
			for d in pool.slice(0, 3):
				var before: String = d.display_name()
				d.upgrade()
				done.append("%s to %s" % [before, d.display_name()])
			g.reward_note = "Upgraded: " + ", ".join(done)
		"remove2":
			for i in 2:
				if g.collection.size() <= 1:
					break
				var c: int = await g.ui.pick("Remove a domino (%d of 2)" % (i + 1), "Choose a domino to take out of your collection.", g.collection.duplicate())
				g.collection.remove_at(clampi(c, 0, g.collection.size() - 1))
		"maxhp":
			g.max_hp_bonus += 20
			g.pl = g.fresh_player()
			g.pl.hp = g.pl.max_hp
		"rare3":
			var taken := []
			var opts := []
			for i in 3:
				var d = g.make_domino(Dominoes.rand_type_of("r", g.rng, taken))
				taken.append(d.data.id)
				opts.append(d)
			await offer_dominoes(g, "A rare domino", "Choose a rare domino to add to your stack, or skip.", opts)
		"weapon2":
			await offer_relics(g, Relics.roll_of("c", g.relic_ids(), 2, g.rng, true), true, "A common weapon", "Choose a weapon. It replaces your equipped one, which goes to your inventory.")
		"artifact2":
			await offer_relics(g, Relics.roll_of("c", g.relic_ids(), 2, g.rng, false), false, "A common artifact", "Choose an artifact, or skip.")
		"weapon_u":
			var got: Array = Relics.roll_of("u", g.relic_ids(), 1, g.rng, true)
			if not got.is_empty():
				Library.offer("weapon", got[0].id, "reward")
				_take_weapon(g, got[0])
		"artifact_u":
			var got2: Array = Relics.roll_of("u", g.relic_ids(), 1, g.rng, false)
			if not got2.is_empty():
				Library.offer("artifact", got2[0].id, "reward")
				g.add_relic(got2[0])
		"luck":
			g.collection.append(g.make_named("Beginner's Luck"))


## A reward screen of dominoes (you may skip). The library counts what was offered and what you left.
static func offer_dominoes(g, title: String, sub: String, opts: Array) -> void:
	for d in opts:
		Library.offer("domino", d.data.title, "reward")
	var c: int = await g.ui.pick(title, sub, opts, "Skip")
	g._take_domino(c, opts)


## A reward screen of artifacts or weapons (you may skip).
static func offer_relics(g, opts: Array, weapons: bool, title: String, sub: String) -> void:
	if opts.is_empty():
		return
	var kind := "weapon" if weapons else "artifact"
	for r in opts:
		Library.offer(kind, r.id, "reward")
	var c: int = await g.ui.pick(title, sub, opts, "Skip")
	for i in opts.size():
		if i != c:
			Library.skip(kind, opts[i].id, "reward")
	if c < 0:
		return
	if weapons:
		_take_weapon(g, opts[c])
	else:
		g.add_relic(opts[c])


## A weapon you win is equipped at once (the old one goes to your inventory).
static func _take_weapon(g, w) -> void:
	g.stored_weapons.append(w)
	g.equip_weapon(w)
