# How the Godot game is put together

```
dominoes.gd      the catalogue table (80 dominoes + Garbage) and build(), which turns each row into:
  domino_data.gd   DominoData   a KIND of domino: title, rarity, condition, effects
    effects/       Effect       one class per kind of effect (damage, shield, draw, ...)
    conditions/    Condition    one class per play condition ("you have no shield", ...)
domino.gd        Domino       one domino you hold: its DominoData plus its own pips (a, b)

model.gd         AbstractModel  the one base class of everything that reacts to combat: Relic, Status, Domino.
                              Empty event hooks (on_turn_end, after_damage ...) and damage math hooks
combat_log.gd    CombatLog    what has happened this battle, as a list of events you can query
cmd/             DamageCmd, PowerCmd, CreatureCmd: the only code that changes HP, shield and statuses

combatant.gd     Combatant    HP, shield, max shield and statuses. The player is one, the enemy is a Foe
foe.gd             Foe        a Combatant with a level, a name and the intents it has planned
status/          Status       one class per status: Fury (and Impair), Power, Boost

game.gd          Game         the rules and turn flow. No nodes, so tests run it headless
null_ui.gd       NullUI       stand-in for the screen in tests. game.gd calls ui.refresh(), ui.pause(),
                              ui.pick() ... and main.gd answers them
main.gd          the board     draws the isometric board, dominoes and characters, handles the board side
                              of the input, and answers the hooks game.gd calls
hud.gd           the HUD       scenes/hud.tscn: containers for the top bar, bottom bar, hand tray, tags,
                              floating numbers, toast and the windows. main.gd calls hud.refresh()
icons.gd         icons: your PNG from img/icons/<name>.png if it exists, else a built-in 8x8 pixel icon
elements.gd      pip number -> element (1 light, 2 earth, 3 water, 4 fire, 5 lightning, 6 darkness)
relics/          relics.gd = the 30 relics (a table), relic.gd = what a relic does (hook, condition, action)
hp_preview.gd    the dark block on an HP bar that shows HP about to be lost
```

## Models, hooks and commands
Game is plain data and rules (no nodes). Three rules keep it easy to extend:

1. **One list of models.** `Game.active_models()` is every relic, every status on both combatants and every
   domino in your hand. `Game.dispatch("after_damage", ctx)` calls that hook on each, lowest `priority` first,
   then in list order, so the result never depends on who was added first. Hooks are listed in
   `AbstractModel.HOOKS`; override only what you need. A hook gets `game == null` in a preview.
2. **Commands change state.** An effect or relic says what it wants (`DamageCmd.attack(game, game.pl, game.foe, 6)`,
   `PowerCmd.apply(game, game.pl, "fury", 2)`, `CreatureCmd.gain_shield(game, game.pl, 4)`). The command runs the
   math hooks, changes the Combatant, writes the history, updates stats, shows the floating text and runs the
   after hooks. A Combatant only stores numbers and does basic subtraction. Pass `silent = true` to run a command on
   preview copies: nothing is logged or shown. `tests/test_architecture.gd` fails if an effect, condition or relic
   writes to a Combatant directly.
3. **Ask the history, do not keep counters.** `game.history` holds events like `domino_played {attack, cost}`,
   `hp_lost {who, amount}`, `turn_ended {hand_empty}`. `history.count("domino_played", {"turn": history.prev(),
   "attack": true})` answers "attacks last turn". `game.bat` only keeps `extra_draw`, which is not history.

Damage is worked out in three passes (`DamageCmd.calculate`): additive (`modify_damage_additive`, summed),
multiplicative (`modify_damage_multiplicative`, multiplied), then cap/override (`modify_damage_cap`, by priority).
Only the last pass cares about order, and priority sets it. A status checks `is_source(ctx)` or `ctx.target == owner`
so it only acts for its own side.

### Add a model that reacts (a new relic kind, status or domino power)
Extend `model.gd` (or `status.gd`), override a hook, and add it to the list `active_models()` builds. To change damage,
override a `modify_damage_*` hook. To react to something that has no hook yet, add the hook to `model.gd` and
`HOOKS`, then call `game.emit(type, "your_hook", data)` where it happens.

## Animations
Game never knows about animations. It tells the ui object two things (main.gd forwards them to hud.gd; NullUI just
records them in tests):
- `card_entered(domino, source)` when a domino goes into the hand. `source` is `"stack"` (drawn, or found in the draw
  pile: it flies from the Stack button) or `"top"` (made by an effect or added by a weapon: it flies in from the top of
  the screen). Every entry goes through `Game._enter_hand`. An effect that makes a domino calls `game.add_to_hand(d)`.
- `card_discarded(domino)` when a domino leaves the hand for the discard pile (a discard effect, or an ephemeral
  domino at the end of the turn): it is flung off the screen.

hud.gd turns these into `FlyingDomino` nodes (`scripts/flying_domino.gd`, on the fly layer). An arriving domino's
slot in the tray exists at once but is **locked** (`DominoView.locked`): it draws nothing and ignores the mouse until
the flyer lands, so it cannot be selected or dragged. The flyer asks for its slot's position every frame, so it still
lands right when the hand re-centres. Dominoes drawn together leave the pile one after the other. A domino discarded
while it is still flying in is flung from where it is. New game, restart and rewind cancel every flight.

The **Discard** button next to Stack opens the stack window with only the discard pile (`StackWindow.open_discard`).
**Animation speed** (Settings window: Slow, Medium, Fast, Instant) is `Settings.anim_speed`, saved with the other
options. `Settings.speed_scale()` scales the flights and every wait in `main.pause()`. Medium is the original pacing and
Instant skips flying and waiting. To animate something new, use `Settings.speed_scale()` (0 means do not animate).

## Pips: stable, unstable and volatile
Every kind of domino has two core pips, one for each half, written in `dominoes.gd` as `"p": [left, right]` (the pips are
also what the domino costs in energy, so stronger dominoes have higher pips). Each pip has a stability (`pip_spec.gd`):
- **stable** (nearly every pip): a number from 0 to 6.
- **unstable**: `[lo, hi, "u"]`, a range such as 1-6. Rolled when the battle starts and kept all battle.
- **volatile** (extremely rare): `[lo, hi, "v"]`. Rolled at the start of the battle and again at the start of every turn,
  even in the stack and the discard pile (`Game._roll_volatile_pips`). Once played on the board its pips never change.

A `Domino` holds both **core** pips (`specs`, from the kind) and **current** pips (`a`, `b`, what it shows and costs).
Rerolls, Uptick and the volatile re-rolls only change the current pips, and a battle works on copies of your collection,
so they all end with the battle. Dominoes in your collection, the shop and rewards show ranges (`1-6|6`, and effect
numbers such as `Deal 9-36 damage`) until `roll_all` gives them values at the start of a battle (`Domino.unsettled()`).
`Domino.shift_core()` changes the core pips for good (for later events). The rewind snapshot stores the current pips.

An effect row can take its number from something other than the pip total with `"src"` (`pip_metric.gd`): `sum` (default),
`max`, `min`, `diff` or `prod`. The effect text says where the number comes from. Add a pip-based effect by giving the row
a `src`, for example Product Smash: `{"k": "dmg", "src": "prod", "m": "S", "a": 1, "b": 0}`.
`tests/test_pips.gd` checks the rolls, the core/current split and the balance rules (rarer dominoes have higher pips).

## Levels: upgrades and downgrades
A domino has a level: 1 is normal, 0 is downgraded, and it can go up to 4 (common), 3 (uncommon) or 2 (rare). Weapon dominoes
and Garbage have one level. `Domino.level()`, `upgrade()`, `downgrade()` and `display_name()` ("Slash", "Slash-", "Slash+",
"Slash++") work on the domino; the level is stored by pointing `Domino.data` at that level's `DominoData`
(`DominoData.at_level(n)`, built the first time it is asked for and cached).

`scripts/upgrades.gd` works out every level from the level 1 catalogue row, so no domino needs its levels written out:
- **Upgrade** (level 2 and up): helpful numbers (damage, shield, draw, heal ...) rise by about a third of their value per level
  (Slash 7, 9, 12, 14). From level 3 a small extra effect is added: draw 1, gain 1 max shield or heal 1. A domino with no
  number to raise gets an extra effect on every level.
- **Downgrade** (level 0), chosen from the domino's name so it never changes: usually lower numbers (about 6 in 10); otherwise a
  drawback (lose 1 HP, discard 1 at random, 2 Impair on yourself, lose 1 energy: the effects `selfdmg`, `discR`, `impS`,
  `energy`) or a restriction (needs 4 dominoes in hand `hand4`, ends your turn `endturn`, ephemeral, not on turn 1 `turn2`,
  only with no shield `noShield`, only if you lost no HP this battle `noHpLost`).
To change how levels work edit `Upgrades.level_row`; to hand-write a level for one domino, return your own row for it there.
A battle copies your dominoes with their level, so all of this is part of a battle automatically.

Every shop has one **upgrade** item (picked at random): choose a domino for 5 gems (`Game.buy(i, domino)`; the shop window
shows the dominoes you can upgrade as they will look), a random domino for 3 gems, or two different random dominoes for 6.
`Game.upgradable_dominoes()` lists what can still go up. A domino with a level other than 1 shows a small tag above its top-right
corner (`+`, `++`, `+++`, or a red `-`), see `DominoArt.sides`.

## Weapon levels, breaking artifacts, no repeated dominoes
- **Weapons have levels** like dominoes (`Relic.level`, `upgrade()`, `downgrade()`, `display_name()`): a common weapon can go up 3 times
  (level 4), an uncommon one twice, a rare one once, and down to level 0. The dominoes a weapon adds are made at the weapon's level
  (`Game._weapon_dominoes`, as far as they can go; a weapon domino has the tier of its weapon). A shop has a 10% chance of also offering
  "upgrade a weapon" for 6 gems (`Game.WEAPON_UPGRADE_CHANCE`): you choose from the weapons you own, equipped or stored.
- **A shop never sells the same domino twice, and the reward screen never offers a domino the shop sells** (nor the same one twice):
  `Dominoes.rand_type(rng, exclude)`, `Game.new_domino(exclude)`.
- **New hooks and statuses:** `on_death` (called by `Game._death_reason` when HP or lives run out: an artifact can save you),
  `modify_shield_multiplicative` and `modify_heal_multiplicative` (used by `CreatureCmd.gain_shield` / `heal`). The statuses
  **Stalwart** (doubles shield you gain) and **Regenerative** (doubles healing) use them and go down by 1 each time you end a turn.
- **Artifacts:** Loose Grip (`ignore_hand`: ignores every "hold N dominoes" condition, `Condition.hand_size`), Stalwart Charm and
  Phial of Renewal (start a battle with 1 Stalwart / Regenerative), and artifacts that **break**: a row with `"breaks": true`
  does its action once and then `Game.break_relic` removes it (Lizard Tail on death: +3 lives and half your HP; Last Meal;
  Emergency Bulwark; Fragile Gauntlet).

## Balance
`scripts/balance.gd` scores every domino in "damage points" (damage 1, shield 0.9, draw 2, Power 4, Fury 1.8 ...) and divides by
its energy cost. The target per energy by rarity is common 1.4, uncommon 2.0, rare 3.0 (weapons 2.6); a condition or ephemeral
domino may be 20% / 30% stronger, and every domino must be within 35% of its target (`tests/test_balance.gd` checks this, the
upgrade levels, and plays every domino at every level once). For a table of everything run
`godot --headless -s tools/balance_report.gd` (add `-- all` for every level). To change numbers on purpose, edit `dominoes.gd`, run the
report until nothing says TOO STRONG or TOO WEAK, then run `tools/dump_domino_values.gd` to rewrite
`tests/fixtures/domino_values.json` (the test in test_rules.gd that stops accidental changes).

## Attack and skill dominoes, counters, equipment dominoes
- **Types:** every domino is an **attack** (it has a damage effect, a hit, pip damage ...) or a **skill** (everything else). `DominoData.type()`,
  `Domino.type()`. Weapon, regular and created dominoes all count. The info card says it ("Common attack").
- **Weapon dominoes** have rarity `w` and a `"tier"` (c, u, r): the rarity of their weapon. The tier sets how far they level up (common 4, uncommon 3,
  rare 2, the same as the weapon) and their balance target, which is 20% above a regular domino of that rarity (`Balance.WEAPON_BONUS`).
  A weapon's `adds` list can mix weapon-only dominoes and regular ones (the Short Sword adds Sword Slash, a better Slash).
- **Equipment tag:** `Domino.origin` is `"collection"` (yours), `"equipment"` (made by a weapon or artifact) or `"created"` (made by a domino, like a Phantom Shiv).
  Only the first stays: `Game._strip_temporary_dominoes()` removes the others from the collection when a battle ends or starts.
  `Domino.is_equipment()` is what Dual Wield looks for.
- **Counters on artifacts** (`"count"` in a relic row, see relic.gd): a **down** counter (`{"mode": "down", "start": 3}`) goes down by 1 each time the
  artifact works and breaks it at 0; with `"vc": true` the amount is `v` times the counter (Fragile Gauntlet gives 3, 2, then 1 Power). An **up** counter
  (`{"mode": "up", "every": 3, "event": "attack", "reset": "turn"}`) counts the attacks, skills or dominoes you play, works every 3 and resets to 0 at the start
  of every turn (Spiked Buckler: every 3 attacks, 3 shield). The number shows on the artifact's icon (`Relic.counter_text()`).
- **Berserk** is a status (`only attack dominoes can be played`, checked in `Game.cond_ok`) that goes down 1 at the start of each turn.
  The Berserk domino spells its levels out with `"levels"` in its row. **Dual Wield** and **Barrage** use the `replay` effect (`Game.replay_domino`: play a
  domino from your hand for free, it does not go on the board, then discard it). Others: `addhand` (Phantom Blades), `typedmg`, `playeddmg`, `scrap`, `drawattack`.

## The screen
Everything except the board is a scene made of containers, styled by one theme (`themes/main_theme.tres`):

```
scenes/hud.tscn              Hud (hud.gd)
  Layout (VBox)                top bar | gap | bottom bar | Tray (the hand: one DominoView each)
  Tags                         EnemyTag, PlayerTag      scenes/combatant_tag.tscn   HP bar, status, intents
  Floats                       FloatingText labels that rise and fade (floating_text.gd)
  Windows (CenterContainer)    PickWindow               scenes/pick_window.tscn     cards in a grid, Skip
                               GameOver                 scenes/game_over_window.tscn  statistics table
scenes/domino_view.tscn      one hand domino: draws itself, turns mouse/touch into tap / drag signals
scenes/domino_card.tscn      a choice in the pick window: a flat domino picture + a RichTextLabel
scenes/flat_domino.tscn      a flat domino picture (cards, and the ghost that follows the pointer)
```
Text about a domino (name, effect lines with icons, condition) is built in `domino_text.gd` for a RichTextLabel.
To change how something looks, edit the scene in the editor or the theme file; to change what it shows,
edit the matching script. The board stays in `_draw` on purpose: isometric depth sorting does not fit containers.

## Add a new effect
1. Copy a small file in `scripts/effects/` (for example `effect_heal.gd`) and change `text()` and `apply()`.
2. Add it to `KINDS` in `effects/effect_factory.gd`.
3. Use its id as `"k"` in a row of `dominoes.gd`. Add an icon with the same id in `icons.gd`.

## Add a new status
1. Copy `status/status_power.gd` (or `status_fury.gd` if it should tick down).
2. Add it to `_make_status` and `STATUS_ORDER` in `combatant.gd`.
3. Give it an effect that calls `PowerCmd.apply(game, game.pl, "<id>", n)`.
Override `modify_damage_additive` / `modify_damage_multiplicative` for damage and `after_attack` for ticking.

## Add a new play condition
Copy a file in `scripts/conditions/`, register it in `conditions/condition_factory.gd`, and put its id in the
`"c"` field of a row in `dominoes.gd`.

## A Godot 4.1 to 4.4 gotcha
Arithmetic written right after an `await` can read a stale value. Keep code after an `await` to plain calls
(see `announce_new_card()`, `_new_turn_state()` and `_start_next_battle()` in `game.gd`).

## Tests
(The UI scripts are not covered by these tests yet, only the rules.)
```
godot --headless -s tests/test_rules.gd
```
`tests/fixtures/domino_values.json` holds every effect size from the web build; the test checks that the Godot
numbers match it.

## Icons
Every icon has a name (`Max Shield` -> `max_shield`). Put `res://img/icons/<name>.png` in the project and it
replaces the built-in icon. `Icons.NAME` maps effect/intent kinds to names; full list in `img/icons/README.md`.
In any RichTextLabel text, `:fury:` shows that icon (`DominoText.append_rich`). `Icons.SIZE` sets the draw size.

## Relics
`relics/relics.gd` is a table. Each row: when (`on`: battle, turn, turn_end, play, victory, passive), an optional
condition (`if`), one action (`do`) and an amount (`v`). Add a row and it works; new conditions or actions go in
`relic.gd`. `game.gd` dispatches the matching model hook (`on_battle_start`, `on_turn_start`, `on_turn_end`, `on_domino_played`, `on_victory`) at those moments.
"once" and conditions about earlier turns ask `game.history`. Only EQUIPPED relics (`game.relics`, at most `EQUIP_SLOTS` = 8) do anything; the rest sit in
`game.stored_relics` until you equip them in the inventory.

## Previews
`game.preview_player_attack(i)` runs a domino's effects on copies of the combatants (`Effect.preview`) to get the
HP the enemy would lose. `game.preview_intents()` does the same for the enemy's attacks against your shield.
Both feed the tags in `hud.update_tags`. A new effect that changes damage should override `preview` and use the commands with `silent = true`.

## More tests
```
godot --headless -s tests/test_features.gd   # relics, new dominoes, previews, icons
godot --headless -s tests/test_ui.gd         # tags, previews on the bars, relic bar and cards
godot --headless -s tests/test_architecture.gd   # hook order, damage passes, history, commands, no direct writes
godot --headless -s tests/test_animation.gd      # flying dominoes and locks, discard pile, speed setting
godot --headless -s tests/test_pips.gd           # stable / unstable / volatile pips, core vs current, pip effects, balance
godot --headless -s tests/test_upgrades.gd       # levels, downgrades, the shop upgrade, level tag, deselecting, game over table
godot --headless -s tests/test_weapons.gd        # weapon levels, weapon upgrade in the shop, no repeats, new artifacts
godot --headless -s tests/test_balance.gd        # every domino near its target strength, every level plays
godot --headless -s tests/test_equipment.gd      # weapon tiers, equipment tag, types, counters, Berserk, type dominoes
```

## Rewards, healing and the screen between battles
- You do not heal between battles: HP carries over (`game.fresh_player()` clears shield and statuses only).
- Each victory is a domino pick (1 of 3). With `relic_chance` (20%) you first choose: a domino, or a random artifact
  (equipped if a slot is free, otherwise unequipped).
- After the reward `ui.intermission(game)` shows a blank screen with your stats and the buttons: Show domino stack,
  Inventory, NEXT BATTLE (`intermission_window.gd`). Equip artifacts there; the next battle uses what is equipped.

## Windows and settings
`hud.tscn` has a ModalLayer holding the settings, stack, inventory and intermission windows; it blocks the game under it
while any is open. `settings.gd` holds the options (saved to user://settings.cfg): show estimated damage taken, show
status names, show status info cards. `glossary.gd` has the text of those cards; `domino_info.gd` is the info panel
(used by the HUD and the stack window). The stack window lists `game.battle_deck_entries()` (or `collection_entries()`
between battles): not drawn = full, in hand = bordered and faded, drawn = faded more.

## Seed, restart and rewind
`game.seed_value` is set when a game starts (shown read-only in Settings). All game randomness goes through `game.rng`;
`start_battle()` reseeds it from the seed and the battle number, and the enemy plan of each turn comes only from
(seed, battle, turn). So **Restart battle** (`restart_battle()`) gives the same stack order, hand and plans, with HP,
lives and stats from the start of the battle. The **Time Pendant** (artifact, `rewind` passive) shows the Rewind turn
button: `snapshot_turn()` saves the turn start (piles, board, fighters, energy, random state) and `restart_turn()` puts it
back for 1 life (not with 1 life left).

## Weapons and ephemeral dominoes
A weapon is a relic with `weapon: true` (table `Relics.WEAPONS`); `game.weapon` holds the one equipped (own slot,
never unequipped, only replaced; spares sit in `game.stored_weapons`). Its `adds` list puts dominoes into the stack
(`pos`: stack, bottom, top) at battle start or into your hand each turn. Weapon dominoes have rarity `w` (never offered
elsewhere). A domino row with `"e": true` is ephemeral: unplayed copies go to the discard pile at end of turn.

## Gems, victory and the shop
Start with 9 gems; a win gives 2-3 (+ Jeweler's Loupe). Order after a win: victory screen (`victory_window.gd`) -> reward
-> screen between battles. After battle 1 (always) and otherwise 30% (`SHOP_CHANCE`) the last button is SHOP: 5 dominoes
(one rare, all different), 2 artifacts, 1 weapon and 1 upgrade (`generate_shop()`; 1 shop in 10 adds a weapon upgrade), prices: domino c 2-3 / u 4-5 / r 6-8, artifacts x2, weapons x1.5.
