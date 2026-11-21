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
icons.gd         8x8 pixel icons (as textures) for captions, info text and intents
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
