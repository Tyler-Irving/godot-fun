class_name CraftingSystem
extends RefCounted
## Defines crafting recipes and handles the craft action.
##
## KEY GODOT CONCEPTS:
## - class_name: Registers this as a global type, usable anywhere without
##   preload. CraftingMenu creates an instance with CraftingSystem.new().
## - RefCounted: Lightweight base class that auto-frees when unreferenced.
##   Good for data/logic objects that don't need to be in the scene tree.
## - Dictionary: Each recipe is a Dictionary with named keys — GDScript's
##   flexible alternative to structs.

## Recipe format:
##   name         — display name for the UI
##   inputs       — Dictionary {block_type: required_count, ...}
##   output_type  — block type ID of the crafted item
##   output_count — how many you get per craft
var recipes: Array = []


func _init() -> void:
	recipes = [
		{
			"name": "Brick",
			"inputs": {2: 2, 4: 1},     # 2 Stone + 1 Wood
			"output_type": 6,
			"output_count": 1,
		},
		{
			"name": "Glass",
			"inputs": {5: 2, 2: 1},      # 2 Sand + 1 Stone
			"output_type": 7,
			"output_count": 1,
		},
		{
			"name": "Torch",
			"inputs": {4: 1, 1: 1},      # 1 Wood + 1 Dirt
			"output_type": 8,
			"output_count": 2,
		},
	]


func can_craft(recipe_index: int) -> bool:
	## Check if the player has enough materials for a recipe.
	var recipe: Dictionary = recipes[recipe_index]
	var inputs: Dictionary = recipe["inputs"]
	for block_type in inputs:
		if InventoryManager.get_count(block_type) < inputs[block_type]:
			return false
	return true


func craft(recipe_index: int) -> bool:
	## Attempt to craft: deduct inputs, add outputs. Returns false if
	## the player doesn't have enough materials.
	if not can_craft(recipe_index):
		return false

	var recipe: Dictionary = recipes[recipe_index]
	var inputs: Dictionary = recipe["inputs"]

	# Deduct ingredients
	for block_type in inputs:
		InventoryManager.remove_item(block_type, inputs[block_type])

	# Add crafted item
	InventoryManager.add_item(recipe["output_type"], recipe["output_count"])
	return true
