extends Node2D
## Manages the game world: creates the TileSet, generates terrain, paints
## tiles, and provides interaction visuals (cursor, mining progress).
##
## KEY GODOT CONCEPTS:
## - TileMapLayer: A node that efficiently renders a grid of tiles from a
##   TileSet. In Godot 4.3+, each layer is its own node (replacing the old
##   multi-layer TileMap node). Great for tile-based games.
## - TileSet: A resource that defines what tiles are available — their textures,
##   collision shapes, and metadata. We build ours in code using an atlas.
## - TileSetAtlasSource: Defines tiles as regions within a single texture atlas.
##   Each tile is identified by its grid position in the atlas (e.g., (0,0) for
##   the first tile, (1,0) for the second, etc.).
## - z_index: Controls draw order. Higher z_index = drawn on top. We use this
##   to render the cursor and mining indicator above the terrain.

const TILE_SIZE := 32
const WORLD_WIDTH := 64
const WORLD_HEIGHT := 64

## Tile type IDs — must match WorldGenerator constants and atlas column indices.
const TILE_GRASS := 0
const TILE_DIRT := 1
const TILE_STONE := 2
const TILE_WATER := 3
const TILE_WOOD := 4
const TILE_SAND := 5
const TILE_BRICK := 6
const TILE_GLASS := 7
const NUM_TILE_TYPES := 8

## Reference to the TileMapLayer child node where we paint terrain.
@onready var terrain_layer: TileMapLayer = $TerrainLayer

## Stores the tile type for every cell [x][y]. We keep this around so other
## systems (mining, placement) can query what's at a given position.
var world_data: Array = []

## Visual overlay nodes for interaction feedback
var cursor_sprite: Sprite2D
var mining_overlay: Sprite2D
var mining_bar_bg: Sprite2D
var mining_bar_fill: Sprite2D


func _ready() -> void:
	_setup_tileset()
	_generate_world()
	_create_cursor()
	_create_mining_indicator()


# --- TileSet Setup ---

func _setup_tileset() -> void:
	## Build a TileSet entirely in code so we don't need external image files.
	## We create a texture atlas (N tiles in a row) with colored squares.
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var atlas_img := Image.create(
		TILE_SIZE * NUM_TILE_TYPES, TILE_SIZE, false, Image.FORMAT_RGBA8
	)

	# Define the color palette for each terrain type
	var colors: Array[Color] = [
		Color(0.30, 0.65, 0.20),   # 0 Grass — medium green
		Color(0.55, 0.36, 0.16),   # 1 Dirt  — earthy brown
		Color(0.50, 0.50, 0.50),   # 2 Stone — neutral gray
		Color(0.20, 0.40, 0.80),   # 3 Water — deep blue
		Color(0.65, 0.50, 0.30),   # 4 Wood  — tan/light brown
		Color(0.85, 0.78, 0.45),   # 5 Sand  — sandy yellow
		Color(0.70, 0.33, 0.22),   # 6 Brick — reddish brown
		Color(0.65, 0.85, 0.95),   # 7 Glass — light cyan
	]

	for tile_index in range(NUM_TILE_TYPES):
		_paint_tile(atlas_img, tile_index, colors[tile_index])

	var atlas_texture := ImageTexture.create_from_image(atlas_img)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for i in range(NUM_TILE_TYPES):
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)
	terrain_layer.tile_set = tileset


func _paint_tile(img: Image, tile_index: int, base_color: Color) -> void:
	## Paint a single tile region in the atlas image.
	## Adds subtle pixel variation and a thin border for visual clarity.
	var x_offset := tile_index * TILE_SIZE
	var border_color := base_color.darkened(0.25)

	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var px := x_offset + x

			# 1px border on all edges so individual tiles are visible
			if x == 0 or x == TILE_SIZE - 1 or y == 0 or y == TILE_SIZE - 1:
				img.set_pixel(px, y, border_color)
			else:
				# Deterministic per-pixel variation for a textured look
				var hash_val := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
				var variation := (hash_val - floorf(hash_val) - 0.5) * 0.08
				var color := Color(
					clampf(base_color.r + variation, 0.0, 1.0),
					clampf(base_color.g + variation, 0.0, 1.0),
					clampf(base_color.b + variation, 0.0, 1.0),
				)
				img.set_pixel(px, y, color)


# --- World Generation ---

func _generate_world() -> void:
	## Use WorldGenerator to create terrain data, then paint it onto the tilemap.
	var generator := WorldGenerator.new(WORLD_WIDTH, WORLD_HEIGHT)
	world_data = generator.generate()

	for x in range(WORLD_WIDTH):
		for y in range(WORLD_HEIGHT):
			var tile_type: int = world_data[x][y]
			terrain_layer.set_cell(
				Vector2i(x, y), 0, Vector2i(tile_type, 0)
			)


# --- Interaction Visuals ---

func _create_cursor() -> void:
	## Create a tile-sized outline sprite that follows the mouse cursor.
	## Shows yellow when in range, red when out of range.
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var outline_color := Color(1, 1, 1, 1)  # White base; we tint via modulate

	# Draw a 2px outline (hollow rectangle)
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			if x < 2 or x >= TILE_SIZE - 2 or y < 2 or y >= TILE_SIZE - 2:
				img.set_pixel(x, y, outline_color)

	cursor_sprite = Sprite2D.new()
	cursor_sprite.texture = ImageTexture.create_from_image(img)
	cursor_sprite.centered = false
	cursor_sprite.visible = false
	cursor_sprite.z_index = 10
	add_child(cursor_sprite)


func _create_mining_indicator() -> void:
	## Create the mining progress visuals:
	## 1. A dark overlay on the tile being mined (gets darker as you mine)
	## 2. A progress bar above the tile

	# Dark overlay on the tile itself
	var overlay_img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	overlay_img.fill(Color(0, 0, 0, 1))
	mining_overlay = Sprite2D.new()
	mining_overlay.texture = ImageTexture.create_from_image(overlay_img)
	mining_overlay.centered = false
	mining_overlay.visible = false
	mining_overlay.z_index = 5
	add_child(mining_overlay)

	# Progress bar background (dark gray strip)
	var bar_height := 5
	var bg_img := Image.create(TILE_SIZE, bar_height, false, Image.FORMAT_RGBA8)
	bg_img.fill(Color(0.1, 0.1, 0.1, 0.85))
	mining_bar_bg = Sprite2D.new()
	mining_bar_bg.texture = ImageTexture.create_from_image(bg_img)
	mining_bar_bg.centered = false
	mining_bar_bg.visible = false
	mining_bar_bg.z_index = 11
	add_child(mining_bar_bg)

	# Progress bar fill (orange, scaled horizontally to show progress)
	var fill_img := Image.create(TILE_SIZE, bar_height, false, Image.FORMAT_RGBA8)
	fill_img.fill(Color(0.95, 0.4, 0.1))
	mining_bar_fill = Sprite2D.new()
	mining_bar_fill.texture = ImageTexture.create_from_image(fill_img)
	mining_bar_fill.centered = false
	mining_bar_fill.visible = false
	mining_bar_fill.z_index = 12
	add_child(mining_bar_fill)


func show_cursor(grid_pos: Vector2i, in_range: bool) -> void:
	## Move the cursor highlight to the given tile. Tint it based on whether
	## the player is close enough to interact.
	if grid_pos.x < 0 or grid_pos.x >= WORLD_WIDTH \
			or grid_pos.y < 0 or grid_pos.y >= WORLD_HEIGHT:
		cursor_sprite.visible = false
		return
	cursor_sprite.visible = true
	cursor_sprite.position = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	if in_range:
		cursor_sprite.modulate = Color(1.0, 1.0, 0.3, 0.7)  # Yellow = can interact
	else:
		cursor_sprite.modulate = Color(1.0, 0.3, 0.3, 0.35)  # Red = too far


func show_mining_progress(grid_pos: Vector2i, progress: float) -> void:
	## Display mining feedback: darken the tile and fill the progress bar.
	var tile_pos := Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	var clamped := clampf(progress, 0.0, 1.0)

	# Darken the tile being mined
	mining_overlay.visible = true
	mining_overlay.position = tile_pos
	mining_overlay.modulate.a = clamped * 0.5  # Max 50% dark

	# Show progress bar just above the tile
	var bar_pos := tile_pos + Vector2(0, -7)
	mining_bar_bg.visible = true
	mining_bar_bg.position = bar_pos
	mining_bar_fill.visible = true
	mining_bar_fill.position = bar_pos
	mining_bar_fill.scale.x = clamped  # Scale from 0 to 1 horizontally


func hide_mining_progress() -> void:
	mining_overlay.visible = false
	mining_bar_bg.visible = false
	mining_bar_fill.visible = false
	mining_bar_fill.scale.x = 0.0


# --- Tile Modification API ---

func set_tile(grid_pos: Vector2i, tile_type: int) -> void:
	## Change a tile to a new type. Updates both the data array and the visual.
	if grid_pos.x < 0 or grid_pos.x >= WORLD_WIDTH:
		return
	if grid_pos.y < 0 or grid_pos.y >= WORLD_HEIGHT:
		return
	world_data[grid_pos.x][grid_pos.y] = tile_type
	terrain_layer.set_cell(grid_pos, 0, Vector2i(tile_type, 0))


func clear_tile(grid_pos: Vector2i) -> void:
	## "Mine" a tile — revert it to grass.
	set_tile(grid_pos, TILE_GRASS)


# --- Query API ---

func get_tile_type(grid_pos: Vector2i) -> int:
	## Returns the tile type at the given grid position, or -1 if out of bounds.
	if grid_pos.x < 0 or grid_pos.x >= WORLD_WIDTH:
		return -1
	if grid_pos.y < 0 or grid_pos.y >= WORLD_HEIGHT:
		return -1
	return world_data[grid_pos.x][grid_pos.y]


func world_to_grid(world_pos: Vector2) -> Vector2i:
	## Convert a world-space pixel position to a tile grid coordinate.
	return Vector2i(
		int(world_pos.x) / TILE_SIZE,
		int(world_pos.y) / TILE_SIZE
	)
