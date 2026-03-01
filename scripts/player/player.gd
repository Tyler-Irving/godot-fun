extends CharacterBody2D
## Player controller — handles movement, block placement, and mining.
##
## KEY GODOT CONCEPTS:
## - _physics_process(delta): Called every physics frame. `delta` is the time
##   in seconds since the last frame (~0.0167 at 60fps). Multiply by delta
##   for frame-rate-independent timers and movement.
## - _unhandled_input(event): Called for input events that weren't consumed by
##   the GUI. Perfect for gameplay input — if the player clicks a UI button,
##   this method won't fire, so we won't accidentally place a block.
## - get_global_mouse_position(): Returns the mouse position in world space,
##   accounting for Camera2D zoom and offset. Essential for clicking on tiles.

## Movement speed in pixels per second.
@export var speed: float = 200.0
## Maximum distance (pixels) the player can interact with tiles.
@export var interaction_range: float = 128.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

## Reference to the World node — set by main.gd during _ready().
## We use this to query tiles, place blocks, and update the cursor.
var world: Node2D

# --- Mining state ---
var mining_target: Vector2i = Vector2i(-1, -1)
var mining_progress: float = 0.0
var mining_duration: float = 0.5

## How long (seconds) it takes to mine each block type.
## Harder materials take longer.
var mining_times := {
	1: 0.4,   # Dirt   — soft, fast to mine
	2: 0.8,   # Stone  — hard, slow to mine
	4: 0.3,   # Wood   — easy to break
	5: 0.3,   # Sand   — easy to break
	6: 1.0,   # Brick  — hard, slow to mine
	7: 0.2,   # Glass  — fragile, very fast
	8: 0.2,   # Torch  — instant pickup
}


func _ready() -> void:
	_create_player_sprite()


func _create_player_sprite() -> void:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	var body_color := Color(0.85, 0.25, 0.25)
	var outline_color := Color(0.55, 0.12, 0.12)

	for x in range(size):
		for y in range(size):
			if x < 2 or x >= size - 2 or y < 2 or y >= size - 2:
				img.set_pixel(x, y, outline_color)
			else:
				img.set_pixel(x, y, body_color)

	# Two white "eyes" near the top
	for dx in [10, 20]:
		for dy in [8, 9]:
			img.set_pixel(dx, dy, Color.WHITE)

	sprite.texture = ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	_handle_movement()
	_update_cursor()
	_handle_mining(delta)


func _unhandled_input(event: InputEvent) -> void:
	## Handle discrete click events (one action per press).
	## We use _unhandled_input so clicks on UI elements (hotbar panels)
	## are consumed first and don't trigger block placement.
	if not world:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_block()


# --- Movement ---

func _handle_movement() -> void:
	var direction := Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")

	if direction.length() > 0.0:
		direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()


# --- Cursor ---

func _update_cursor() -> void:
	if not world:
		return
	var grid_pos := _get_hovered_grid_pos()
	var in_range := _is_in_range(grid_pos)
	world.show_cursor(grid_pos, in_range)


# --- Block Placement ---

func _try_place_block() -> void:
	var grid_pos := _get_hovered_grid_pos()
	if not _is_in_range(grid_pos):
		return

	# Don't place a block on the tile the player is standing on
	var player_grid = world.world_to_grid(global_position)
	if grid_pos == player_grid:
		return

	var tile_type = world.get_tile_type(grid_pos)
	# Can only place on grass tiles (empty ground)
	if tile_type != 0:
		return

	var block_type := InventoryManager.get_selected_block_type()
	if block_type < 0:
		return  # Empty hotbar slot selected

	# Check that the player actually has this block in inventory
	if not InventoryManager.has_item(block_type):
		return

	InventoryManager.remove_item(block_type)
	world.set_tile(grid_pos, block_type)


# --- Mining ---

func _handle_mining(delta: float) -> void:
	## Mining is continuous: hold right-click to mine the tile under the cursor.
	## Progress resets if you move the mouse to a different tile or release.
	if not world:
		return

	var grid_pos := _get_hovered_grid_pos()
	var in_range := _is_in_range(grid_pos)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and in_range:
		var tile_type = world.get_tile_type(grid_pos)
		if _is_mineable(tile_type):
			# If we started mining a new tile, reset progress
			if grid_pos != mining_target:
				mining_target = grid_pos
				mining_progress = 0.0
				mining_duration = mining_times.get(tile_type, 0.5)

			mining_progress += delta
			var progress_pct := mining_progress / mining_duration
			world.show_mining_progress(grid_pos, progress_pct)

			# Mining complete — destroy the block and collect it
			if mining_progress >= mining_duration:
				InventoryManager.add_item(tile_type)
				world.clear_tile(grid_pos)
				_reset_mining()
			return

	# If we reach here, stop mining (released button, out of range, or bad tile)
	_reset_mining()


func _is_mineable(tile_type: int) -> bool:
	## Grass (0) and water (3) can't be mined. Everything else can.
	return tile_type > 0 and tile_type != 3


func _reset_mining() -> void:
	if mining_target != Vector2i(-1, -1):
		if world:
			world.hide_mining_progress()
		mining_target = Vector2i(-1, -1)
		mining_progress = 0.0


# --- Helpers ---

func _get_hovered_grid_pos() -> Vector2i:
	## Get the grid coordinates of the tile under the mouse cursor.
	## get_global_mouse_position() accounts for camera zoom/offset.
	var mouse_pos := get_global_mouse_position()
	return world.world_to_grid(mouse_pos)


func _is_in_range(grid_pos: Vector2i) -> bool:
	## Check if a tile is within the player's interaction range.
	var tile_center := Vector2(
		grid_pos.x * 32 + 16,
		grid_pos.y * 32 + 16
	)
	return global_position.distance_to(tile_center) <= interaction_range
