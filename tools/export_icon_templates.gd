extends SceneTree
## Writes every built-in icon to img/icons/<name>.png (black on transparent, 8x8) so you can paint
## over them. Existing files are never overwritten. Run from the project folder:
##   godot --headless -s tools/export_icon_templates.gd
const Icons = preload("res://scripts/icons.gd")
const Relics = preload("res://scripts/relics/relics.gd")


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path(Icons.DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	var names := Icons.all_names()
	for r in Relics.build() + Relics.build_weapons():
		names.append(r.id)
	for icon_name in names:
		var path: String = dir + icon_name + ".png"
		if FileAccess.file_exists(path):
			continue
		var tex: Texture2D
		var relic = Relics.by_id(icon_name)
		if relic != null:
			tex = Icons.relic_texture(relic)
		else:
			tex = Icons.texture(icon_name)
		tex.get_image().save_png(path)
		n += 1
	print("wrote ", n, " icons to ", dir)
	quit()
