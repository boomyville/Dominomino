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
(one rare), 2 artifacts, 1 weapon (`generate_shop()`), prices: domino c 2-3 / u 4-5 / r 6-8, artifacts x2, weapons x1.5.
