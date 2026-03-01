extends Control
## Hotbar UI — displays block slots at the bottom of the screen with
## item counts from the inventory.
##
## KEY GODOT CONCEPTS:
## - Signal connections: We connect to both selection_changed and
##   inventory_changed on InventoryManager so the hotbar updates
##   automatically — no polling needed.
## - Dynamic slot count: reads SLOT_COUNT from InventoryManager so
##   adding new block types only requires changing one place.

const SLOT_SIZE := 52
const SLOT_MARGIN := 4

var slot_panels: Array[Panel] = []
var count_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hotbar()
	InventoryManager.selection_changed.connect(_on_selection_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	_update_selection()
	_update_all_counts()


func _build_hotbar() -> void:
	var slot_count := InventoryManager.SLOT_COUNT
	var total_width := slot_count * (SLOT_SIZE + SLOT_MARGIN) - SLOT_MARGIN

	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -total_width / 2.0
	offset_right = total_width / 2.0
	offset_top = -(SLOT_SIZE + 20)
	offset_bottom = -10

	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", SLOT_MARGIN)
	add_child(container)

	for i in range(slot_count):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		container.add_child(panel)
		slot_panels.append(panel)

		var block_type: int = InventoryManager.slot_block_types[i]

		# Block color preview square
		if block_type >= 0 and InventoryManager.block_colors.has(block_type):
			var icon := ColorRect.new()
			icon.position = Vector2(10, 4)
			icon.size = Vector2(SLOT_SIZE - 20, SLOT_SIZE - 26)
			icon.color = InventoryManager.block_colors[block_type]
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(icon)

		# Keyboard shortcut number (top-left)
		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.position = Vector2(3, 1)
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(key_label)

		# Item count label (bottom of slot)
		var c_label := Label.new()
		c_label.position = Vector2(3, SLOT_SIZE - 16)
		c_label.add_theme_font_size_override("font_size", 10)
		c_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(c_label)
		count_labels.append(c_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var slot_count := InventoryManager.SLOT_COUNT
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + slot_count:
			InventoryManager.select_slot(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _on_selection_changed(_slot_index: int) -> void:
	_update_selection()


func _on_inventory_changed(_block_type: int, _new_count: int) -> void:
	_update_all_counts()


func _update_selection() -> void:
	for i in range(InventoryManager.SLOT_COUNT):
		var panel := slot_panels[i]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)

		if i == InventoryManager.selected_slot:
			style.bg_color = Color(0.22, 0.22, 0.22, 0.9)
			style.border_color = Color(1.0, 0.95, 0.3)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.75)
			style.border_color = Color(0.35, 0.35, 0.35, 0.6)
			style.set_border_width_all(1)

		panel.add_theme_stylebox_override("panel", style)


func _update_all_counts() -> void:
	## Refresh count labels from the inventory.
	for i in range(InventoryManager.SLOT_COUNT):
		var block_type: int = InventoryManager.slot_block_types[i]
		var label := count_labels[i]
		if block_type < 0:
			label.text = ""
			continue
		var count := InventoryManager.get_count(block_type)
		var bname: String = InventoryManager.block_names.get(block_type, "?")
		label.text = "%s:%d" % [bname, count]
		if count > 0:
			label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		else:
			label.add_theme_color_override("font_color", Color(0.45, 0.35, 0.35))
