extends Control
## Crafting menu UI — toggled with 'C' key.
##
## Shows available recipes, required materials with current counts, and
## a Craft button for each recipe. Updates live as inventory changes.
##
## KEY GODOT CONCEPTS:
## - Visibility toggle: We show/hide this Control with `visible`. When hidden,
##   it doesn't process input or render, but stays in the scene tree.
## - set_input_as_handled(): Prevents an input event from propagating further.
##   We use this so the 'C' key doesn't trigger other actions while toggling.
## - Button.pressed signal: Emitted when a button is clicked. We connect it
##   to a crafting callback using a Callable with bind() to pass the recipe index.
## - preload(): Loads a script/scene at compile time. More reliable than
##   class_name for cross-script references since it doesn't depend on
##   Godot's global class scanning order.

const CraftingSystemScript = preload("res://scripts/systems/crafting_system.gd")

var crafting_system
var craft_buttons: Array[Button] = []
var ingredient_labels: Array[Label] = []


func _ready() -> void:
	crafting_system = CraftingSystemScript.new()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	InventoryManager.inventory_changed.connect(_on_inventory_changed)


func _build_ui() -> void:
	# Semi-transparent dark overlay behind the menu
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game world
	add_child(bg)

	# Centered panel
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -130
	panel.offset_bottom = 130
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.45)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Recipe rows
	for i in range(crafting_system.recipes.size()):
		var recipe: Dictionary = crafting_system.recipes[i]
		_build_recipe_row(vbox, i, recipe)

	# Hint
	var hint := Label.new()
	hint.text = "Press C to close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _build_recipe_row(parent: VBoxContainer, index: int, recipe: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Output color swatch
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.color = InventoryManager.block_colors.get(recipe["output_type"], Color.WHITE)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)

	# Recipe info (name + ingredients)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = "%s (x%d)" % [recipe["name"], recipe["output_count"]]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	info_vbox.add_child(name_label)

	var ingredients_label := Label.new()
	ingredients_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(ingredients_label)
	ingredient_labels.append(ingredients_label)

	# Craft button
	var button := Button.new()
	button.text = "Craft"
	button.custom_minimum_size = Vector2(60, 30)
	# bind() attaches the recipe index to the callback so we know which
	# recipe to craft when the button is pressed.
	button.pressed.connect(_on_craft_pressed.bind(index))
	row.add_child(button)
	craft_buttons.append(button)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_C:
			visible = !visible
			if visible:
				_refresh_display()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			visible = false
			get_viewport().set_input_as_handled()


func _on_craft_pressed(recipe_index: int) -> void:
	crafting_system.craft(recipe_index)
	_refresh_display()


func _on_inventory_changed(_block_type: int, _new_count: int) -> void:
	if visible:
		_refresh_display()


func _refresh_display() -> void:
	## Update ingredient text and button states based on current inventory.
	for i in range(crafting_system.recipes.size()):
		var recipe: Dictionary = crafting_system.recipes[i]
		var inputs: Dictionary = recipe["inputs"]

		# Build ingredients string like "2× Stone (5), 1× Wood (3)"
		var parts: Array[String] = []
		for block_type in inputs:
			var needed: int = inputs[block_type]
			var have: int = InventoryManager.get_count(block_type)
			var bname: String = InventoryManager.block_names.get(block_type, "?")
			var have_str := str(have) if have >= needed else str(have)
			parts.append("%d× %s (have %s)" % [needed, bname, have_str])

		ingredient_labels[i].text = ", ".join(parts)

		var can_do = crafting_system.can_craft(i)
		craft_buttons[i].disabled = not can_do
		ingredient_labels[i].add_theme_color_override(
			"font_color",
			Color(0.6, 0.8, 0.6) if can_do else Color(0.8, 0.4, 0.4)
		)
