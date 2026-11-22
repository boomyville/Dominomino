# How the Godot game is put together

```
dominoes.gd      the catalogue table (80 dominoes + Garbage) and build(), which turns each row into:
  domino_data.gd   DominoData   a KIND of domino: title, rarity, condition, effects
    effects/       Effect       one class per kind of effect (damage, shield, draw, ...)
    conditions/    Condition    one class per play condition ("you have no shield", ...)
domino.gd        Domino       one domino you hold: its DominoData plus its own pips (a, b)

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
3. Give it an effect that calls `game.pl.add("<id>", n)`.

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
`relics/relics.gd` is a table. Each row: when (`on`: battle, turn, turn_end, play, passive), an optional
condition (`if`), one action (`do`) and an amount (`v`). Add a row and it works; new conditions or actions go in
`relic.gd`. `game.gd` calls `fire_relics(hook)` at those moments. Only EQUIPPED relics (`game.relics`, at most `EQUIP_SLOTS` = 8) do anything; the rest sit in
`game.stored_relics` until you equip them in the inventory.

## Previews
`game.preview_player_attack(i)` runs a domino's effects on copies of the combatants (`Effect.preview`) to get the
HP the enemy would lose. `game.preview_intents()` does the same for the enemy's attacks against your shield.
Both feed the tags in `hud.update_tags`. A new effect that changes damage should override `preview`.

## More tests
```
godot --headless -s tests/test_features.gd   # relics, new dominoes, previews, icons
godot --headless -s tests/test_ui.gd         # tags, previews on the bars, relic bar and cards
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
