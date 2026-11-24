# Custom icons

Drop a PNG here named `<name>.png` and the game uses it instead of the built-in 8x8 icon.
Names are lowercase, spaces become underscores. Any size works (scaled to `Icons.SIZE`, 8 by default;
relics to `Icons.RELIC_SIZE`, 16). In any text you can also write `:name:` to show an icon.

Run `godot --headless -s tools/export_icon_templates.gd` to write every built-in icon here as a PNG you can paint over.

## Effect, status, intent and element icons

- `attack.png`
- `attack_life.png`
- `block.png`
- `boost.png`
- `damage.png`
- `darkness.png`
- `discard.png`
- `discard_random.png`
- `draw.png`
- `earth.png`
- `energy.png`
- `fire.png`
- `fury.png`
- `garbage.png`
- `generate.png`
- `heal.png`
- `impair.png`
- `life.png`
- `light.png`
- `lightning.png`
- `lose_life.png`
- `max_shield.png`
- `mill.png`
- `multi_hit.png`
- `power.png`
- `reroll.png`
- `reroll_all.png`
- `self_damage.png`
- `shield.png`
- `tutor.png`
- `uptick.png`
- `water.png`

Kind -> name (what the code uses inside): `dmg`=`damage`, `hit`=`multi_hit`, `shield`=`shield`, `maxs`=`max_shield`, `draw`=`draw`, `discR`=`discard_random`, `discP`=`discard`, `tutor`=`tutor`, `power`=`power`, `boost`=`boost`, `heal`=`heal`, `rerollA`=`reroll_all`, `rerollP`=`reroll`, `fury`=`fury`, `impS`=`impair`, `impE`=`impair`, `selfdmg`=`self_damage`, `gen`=`generate`, `life`=`life`, `paylife`=`lose_life`, `atk`=`attack`, `lifeatk`=`attack_life`, `blk`=`block`, `discH`=`discard`, `junk`=`garbage`

## Artifact icons

- `overcharged_core.png` (Overcharged Core)
- `starter_spark.png` (Starter Spark)
- `reserve_tank.png` (Reserve Tank)
- `quiet_mind.png` (Quiet Mind)
- `deep_well.png` (Deep Well)
- `open_palm.png` (Open Palm)
- `banked_charge.png` (Banked Charge)
- `iron_cloak.png` (Iron Cloak)
- `safety_net.png` (Safety Net)
- `brimming_cup.png` (Brimming Cup)
- `bulwark_seed.png` (Bulwark Seed)
- `seedling_plate.png` (Seedling Plate)
- `overflow_valve.png` (Overflow Valve)
- `ember_heart.png` (Ember Heart)
- `war_drum.png` (War Drum)
- `venom_fang.png` (Venom Fang)
- `gamblers_purse.png` (Gambler's Purse)
- `heartwood.png` (Heartwood)
- `whetstone.png` (Whetstone)
- `phoenix_feather.png` (Phoenix Feather)
- `tile_armor.png` (Tile Armor)
- `dawn_lantern.png` (Dawn Lantern)
- `pebble_sling.png` (Pebble Sling)
- `frost_shard.png` (Frost Shard)
- `kindling.png` (Kindling)
- `storm_charm.png` (Storm Charm)
- `midnight_vial.png` (Midnight Vial)
- `double_vision.png` (Double Vision)
- `hollow_bone.png` (Hollow Bone)
- `bandage_roll.png` (Bandage Roll)
- `time_pendant.png` (Time Pendant)
- `spare_heart.png` (Spare Heart)
- `warm_hearth.png` (Warm Hearth)
- `bottomless_satchel.png` (Bottomless Satchel)
- `jewelers_loupe.png` (Jeweler's Loupe)
- `hagglers_tongue.png` (Haggler's Tongue)

## Weapon icons

- `short_sword.png` (Short Sword)
- `long_sword.png` (Long Sword)
- `rapier.png` (Rapier)
- `sawtooth_blade.png` (Sawtooth Blade)
- `shining_blade.png` (Shining Blade)
