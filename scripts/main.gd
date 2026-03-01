extends Node2D
## Main scene script — wires up references between game systems.
##
## KEY GODOT CONCEPTS:
## - preload(): Loads a script at compile time. We use it for SaveSystem
##   since class_name can be unreliable (see error log #2).
## - notification: _notification(NOTIFICATION_WM_CLOSE_REQUEST) fires when
##   the window is closed, giving us a chance to auto-save.

const SaveSystem = preload("res://scripts/systems/save_system.gd")

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var day_night: CanvasModulate = $DayNightCycle

var time_label: Label
var save_label: Label


func _ready() -> void:
	player.world = world
	_create_time_label()
	_create_save_label()
	day_night.time_changed.connect(_on_time_changed)
	_try_load_game()


func _create_time_label() -> void:
	## Small clock label in the top-right corner of the screen.
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	$UILayer.add_child(time_label)
	time_label.anchor_left = 1.0
	time_label.anchor_right = 1.0
	time_label.offset_left = -120
	time_label.offset_right = -10
	time_label.offset_top = 10


func _on_time_changed(time_of_day: float) -> void:
	## Convert 0.0–1.0 to a clock string. 0.0 = 6:00 AM (sunrise).
	var total_minutes := int(time_of_day * 1440)  # 1440 min in a day
	var shifted := (total_minutes + 360) % 1440    # Offset so 0.0 = 6:00 AM
	var hours := shifted / 60
	var minutes := shifted % 60
	var period := "AM" if hours < 12 else "PM"
	var display_hour := hours % 12
	if display_hour == 0:
		display_hour = 12
	time_label.text = "%d:%02d %s" % [display_hour, minutes, period]


func _create_save_label() -> void:
	## Brief "Saved!" flash label, hidden by default.
	save_label = Label.new()
	save_label.add_theme_font_size_override("font_size", 16)
	save_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_label.visible = false
	$UILayer.add_child(save_label)
	save_label.anchor_left = 0.5
	save_label.anchor_right = 0.5
	save_label.offset_left = -60
	save_label.offset_right = 60
	save_label.offset_top = 10


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F5:
			_save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			_try_load_game()
			get_viewport().set_input_as_handled()


# --- Save / Load ---

func _save_game() -> void:
	var world_data = world.world_data
	var inventory = InventoryManager.inventory
	if SaveSystem.save_game(world_data, inventory):
		_flash_save_label("Saved!")


func _try_load_game() -> void:
	var data = SaveSystem.load_game()
	if data.is_empty():
		return
	# Restore world tiles
	if data.has("world"):
		var saved_world: Array = data["world"]
		world.world_data = saved_world
		# Repaint all tiles from saved data
		for x in range(saved_world.size()):
			for y in range(saved_world[x].size()):
				var tile_type := int(saved_world[x][y])
				var grid_pos := Vector2i(x, y)
				world.terrain_layer.set_cell(grid_pos, 0, Vector2i(tile_type, 0))
				# Restore torch lights
				if tile_type == world.TILE_TORCH:
					world._add_torch_light(grid_pos)
	# Restore inventory
	if data.has("inventory"):
		var saved_inv: Dictionary = data["inventory"]
		InventoryManager.inventory.clear()
		for key in saved_inv:
			# JSON parses keys as strings, convert back to int
			InventoryManager.inventory[int(key)] = int(saved_inv[key])
		InventoryManager.inventory_changed.emit(0, 0)
	_flash_save_label("Loaded!")


func _flash_save_label(text: String) -> void:
	save_label.text = text
	save_label.visible = true
	# Hide after 2 seconds using a one-shot timer
	get_tree().create_timer(2.0).timeout.connect(func(): save_label.visible = false)
