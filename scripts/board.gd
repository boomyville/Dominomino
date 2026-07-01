tool
extends Control

var previewed_slots: Array = []

onready var grid_container = $GridContainer

var board_matrix = []
var cached_grid_origin: Vector2 = Vector2.ZERO

const TILE_A = preload("res://assets/ui/empty_board_tile.png")
const TILE_B = preload("res://assets/ui/empty_board_tile2.png")
const TILE_PREVIEW = preload("res://assets/ui/empty_board_tile3.png")
const TILE_INVALID = preload("res://assets/ui/empty_board_tile4.png")

# MULTI_MATCH: each pip-end of the candidate can touch one board domino independently
#              (up to 2 matches, one per candidate cell).
# SINGLE_MATCH: the entire candidate domino may only touch ONE board domino in total.
#              If either cell is adjacent to a second distinct board domino → blocked.
enum MatchMode { MULTI_MATCH, SINGLE_MATCH, ANY_MATCH }
var match_mode: int = MatchMode.SINGLE_MATCH

export var grid_size = 10

func _ready() -> void:
	_initialise_empty_matrix()
	_generate_visual_grid_slots()
	cached_grid_origin = grid_container.get_global_transform_with_canvas().origin
	print("Cached grid origin: ", cached_grid_origin)

func _initialise_empty_matrix() -> void:
	board_matrix = []
	for _y in range(grid_size):
		var row = []
		for _x in range(grid_size):
			row.append(null)
		board_matrix.append(row)

func _generate_visual_grid_slots() -> void:
	if grid_container == null:
		grid_container = get_node_or_null("GridContainer")
	
	grid_container.columns = grid_size
	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_container.set("custom_constants/hseparation", 0)
	grid_container.set("custom_constants/vseparation", 0)

	for child in grid_container.get_children():
		child.queue_free()

	for i in range(grid_size * grid_size):
		var slot = TextureRect.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.rect_min_size = Vector2(24, 24)
		slot.expand = true
		slot.stretch_mode = TextureRect.STRETCH_SCALE

		var slot_x = i % grid_size
		var slot_y = int(i / grid_size)
		slot.set_meta("grid_pos", Vector2(slot_x, slot_y))

		var check_val = (slot_x + slot_y) % 2
		if check_val == 0:
			slot.texture = TILE_A
		else:
			slot.texture = TILE_B

		grid_container.add_child(slot)

func get_domino_at(x: int, y: int) -> Area2D:
	if x >= 0 and x < grid_size and y >= 0 and y < grid_size:
		return board_matrix[y][x] as Area2D
	return null

# Returns the pip value carried by the placed domino's cell at (cx, cy).
# Each cell carries exactly one pip: left/right for horizontal, top/bottom for vertical.
func get_pip_at_cell(domino: Area2D, cx: int, cy: int) -> int:
	if domino == null:
		return -99  # shouldn't happen

	if domino.is_vertical():
		# Find whether this is the top or bottom cell
		var top_y = cy
		if cy > 0 and board_matrix[cy - 1][cx] == domino:
			top_y = cy - 1
		return domino.get_top_pip() if cy == top_y else domino.get_bottom_pip()
	else:
		# Find whether this is the left or right cell
		var left_x = cx
		if cx > 0 and board_matrix[cy][cx - 1] == domino:
			left_x = cx - 1
		return domino.get_left_pip() if cx == left_x else domino.get_right_pip()

# Returns the pip value the candidate domino carries at cell (cx, cy)
# when placed at (start_x, start_y) with its current rotation.
func get_candidate_pip_at_cell(candidate: Area2D, start_x: int, start_y: int, cx: int, cy: int) -> int:
	if candidate.is_vertical():
		return candidate.get_top_pip() if cy == start_y else candidate.get_bottom_pip()
	else:
		return candidate.get_left_pip() if cx == start_x else candidate.get_right_pip()

# Core adjacency-matching evaluator.
#
# BOTH MODES:
#   Every pair of adjacent cells must have matching pip values (or wild).
#   No direction restrictions — pip value of each cell is what matters.
#
# SINGLE_MATCH additionally:
#   Candidate may only touch ONE distinct board domino in total.
#   (Each board pip-end can only have one neighbour — automatically enforced by geometry
#   since you can't place on an occupied cell. The only extra rule is no bridging.)
#
# MULTI_MATCH:
#   Candidate may touch multiple board dominoes / same pip-end multiple times,
#   as long as all adjacent cell pairs match.
# SINGLE_MATCH helper: returns true if board cell (bx,by) already has any placed
# domino adjacent to it, excluding cells in candidate_occupied (the candidate's own cells).
# This enforces "each board cell may only have one touching neighbour at a time."
func _board_cell_has_existing_neighbour(bx: int, by: int, candidate_occupied: Dictionary) -> bool:
	var check_cells = [
		Vector2(bx - 1, by), Vector2(bx + 1, by),
		Vector2(bx, by - 1), Vector2(bx, by + 1)
	]
	for nb in check_cells:
		var nx = int(nb.x)
		var ny = int(nb.y)
		if nx < 0 or ny < 0 or nx >= grid_size or ny >= grid_size:
			continue
		if candidate_occupied.has(nb):
			continue
		if board_matrix[ny][nx] != null:
			# Check it's not the same domino as the one at (bx,by)
			if board_matrix[ny][nx] != board_matrix[by][bx]:
				return true
	return false

func evaluate_candidate_placement(candidate: Area2D, start_x: int, start_y: int, vertical: bool) -> Dictionary:
	var result = {"valid": true, "matched_reduction": 0, "has_any_match": false}

	var candidate_cells = []
	if vertical:
		candidate_cells = [{"x": start_x, "y": start_y}, {"x": start_x, "y": start_y + 1}]
	else:
		candidate_cells = [{"x": start_x, "y": start_y}, {"x": start_x + 1, "y": start_y}]

	var candidate_occupied = {}
	for c in candidate_cells:
		candidate_occupied[Vector2(c.x, c.y)] = true

	var touched_board_dominoes = {}
	var total_contacts = 0

	for cell in candidate_cells:
		var cx = cell.x
		var cy = cell.y
		var my_pip = get_candidate_pip_at_cell(candidate, start_x, start_y, cx, cy)
		var matched_this_cell = false

		var neighbours = [
			Vector2(cx - 1, cy), Vector2(cx + 1, cy),
			Vector2(cx, cy - 1), Vector2(cx, cy + 1)
		]

		for nb in neighbours:
			var nx = int(nb.x)
			var ny = int(nb.y)

			if nx < 0 or ny < 0 or nx >= grid_size or ny >= grid_size:
				continue
			if candidate_occupied.has(nb):
				continue

			var nb_domino = board_matrix[ny][nx]
			if nb_domino == null:
				continue

			var nb_pip = get_pip_at_cell(nb_domino, nx, ny)

			if match_mode == MatchMode.ANY_MATCH:
				# Free placement — no pip restrictions, placement always valid.
				# has_any_match = true whenever adjacent (for chain increment).
				# matched_reduction only increases when pip values actually match.
				touched_board_dominoes[nb_domino] = true
				total_contacts += 1
				result.has_any_match = true
				if nb_pip >= 0 and my_pip >= 0 and nb_pip == my_pip and not matched_this_cell:
					matched_this_cell = true
					result.matched_reduction += my_pip
				continue

			# Wild pip — always matches, no cost reduction
			if nb_pip == -1 or my_pip == -1:
				touched_board_dominoes[nb_domino] = true
				total_contacts += 1
				# SINGLE_MATCH: check board cell (nx,ny) isn't already neighboured
				if match_mode == MatchMode.SINGLE_MATCH:
					if _board_cell_has_existing_neighbour(nx, ny, candidate_occupied):
						result.valid = false
						return result
				matched_this_cell = true
				continue

			# Unplayable pip — hard block
			if nb_pip == -2 or my_pip == -2:
				result.valid = false
				return result

			# Pip value mismatch — hard block
			if nb_pip != my_pip:
				result.valid = false
				return result

			# Match confirmed
			# SINGLE_MATCH: check board cell (nx,ny) isn't already neighboured
			if match_mode == MatchMode.SINGLE_MATCH:
				if _board_cell_has_existing_neighbour(nx, ny, candidate_occupied):
					result.valid = false
					return result
			touched_board_dominoes[nb_domino] = true
			total_contacts += 1
			if not matched_this_cell:
				matched_this_cell = true
				result.matched_reduction += my_pip
				result.has_any_match = true

	# SINGLE_MATCH: only 1 candidate cell may touch 1 board cell total
	if match_mode == MatchMode.SINGLE_MATCH and total_contacts > 1:
		result.valid = false
		return result

	return result

	return result

# Raw geometry check only — are the target cells empty and in bounds?
# Used by the hand-playability scanner in game.gd which needs to try positions
# without triggering pip-rule validation (it evaluates pips separately).
func is_geometry_valid(start_x: int, start_y: int, vertical: bool) -> bool:
	if start_x < 0 or start_y < 0:
		return false
	if vertical:
		if start_x >= grid_size or start_y + 1 >= grid_size:
			return false
		return board_matrix[start_y][start_x] == null and board_matrix[start_y + 1][start_x] == null
	else:
		if start_x + 1 >= grid_size or start_y >= grid_size:
			return false
		return board_matrix[start_y][start_x] == null and board_matrix[start_y][start_x + 1] == null

# Full validity check: geometry + pip adjacency rules.
# candidate must be passed explicitly — do not rely on _get_game_node().
func is_placement_valid(start_x: int, start_y: int, vertical: bool = false, candidate: Area2D = null) -> bool:
	if not is_geometry_valid(start_x, start_y, vertical):
		return false
	if candidate == null:
		return true  # geometry-only fallback (e.g. editor tool mode)
	var eval = evaluate_candidate_placement(candidate, start_x, start_y, vertical)
	return eval.valid

func _get_game_node() -> Node:
	return get_tree().get_root().find_node("Game", true, false)

func place_domino_on_matrix(domino_instance: Area2D, target_x: int, target_y: int) -> void:
	if not is_geometry_valid(target_x, target_y, domino_instance.is_vertical()):
		return
	board_matrix[target_y][target_x] = domino_instance
	if domino_instance.is_vertical():
		board_matrix[target_y + 1][target_x] = domino_instance
		print("Domino registered at col: ", target_x, " rows: ", target_y, "-", target_y + 1)
	else:
		board_matrix[target_y][target_x + 1] = domino_instance
		print("Domino registered at row: ", target_y, " cols: ", target_x, "-", target_x + 1)

func remove_domino_from_matrix(domino_instance: Area2D) -> void:
	for y in range(grid_size):
		for x in range(grid_size):
			if board_matrix[y][x] == domino_instance:
				board_matrix[y][x] = null

func highlight_preview(start_x: int, start_y: int, vertical: bool = false, candidate: Area2D = null) -> void:
	clear_preview()

	if not is_geometry_valid(start_x, start_y, vertical):
		return

	var pip_valid = true
	if candidate != null:
		var eval = evaluate_candidate_placement(candidate, start_x, start_y, vertical)
		pip_valid = eval.valid
		
		if pip_valid:
			# Also check affordability before showing as valid
			var cost = GameState.calculate_domino_cost_discounted(
				candidate.left_pip_value,
				candidate.right_pip_value,
				eval.get("matched_reduction", 0)
			)
			if GameState.current_player_energy < cost:
				pip_valid = false
	var highlight_texture = TILE_PREVIEW if pip_valid else TILE_INVALID

	for child in grid_container.get_children():
		var gp = child.get_meta("grid_pos")
		var highlight = false
		if vertical:
			highlight = gp.x == start_x and (gp.y == start_y or gp.y == start_y + 1)
		else:
			highlight = gp.y == start_y and (gp.x == start_x or gp.x == start_x + 1)
		if highlight:
			child.texture = highlight_texture
			previewed_slots.append(child)

func clear_preview() -> void:
	for slot in previewed_slots:
		if is_instance_valid(slot):
			var gp = slot.get_meta("grid_pos")
			var check_val = (int(gp.x) + int(gp.y)) % 2
			if check_val == 0:
				slot.texture = TILE_A
			else:
				slot.texture = TILE_B
	previewed_slots.clear()

func world_to_grid(world_pos: Vector2) -> Vector2:
	var local_pos = world_pos - cached_grid_origin
	return Vector2(int(local_pos.x / 24), int(local_pos.y / 24))

func grid_to_world(cell_x: int, cell_y: int) -> Vector2:
	print("Converting grid to world | cell: (", cell_x, ", ", cell_y, ") | cached origin: ", cached_grid_origin)
	print("Calculated world position: ", cached_grid_origin + Vector2(cell_x * 24, cell_y * 24))
	return cached_grid_origin + Vector2(cell_x * 24, cell_y * 24)
