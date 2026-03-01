extends Node
## Global inventory manager — autoload singleton.
##
## Tracks hotbar slot selection, item counts, and block metadata.
## All inventory changes go through this singleton so the UI stays in sync.
##
## KEY GODOT CONCEPTS:
## - Signals with parameters: `inventory_changed` passes the block_type and
##   new count so listeners can update efficiently without polling.
## - Dictionary: GDScript's hash map. We use it for inventory counts and
##   for mapping block type IDs to display names/colors.

## Emitted when the player switches hotbar slots.
signal selection_changed(slot_index: int)
## Emitted when any item count changes (mining, placing, crafting).
signal inventory_changed(block_type: int, new_count: int)

const SLOT_COUNT := 6

## Currently selected hotbar slot (0-based index).
var selected_slot: int = 0

## What block type each slot holds. -1 means empty.
## Block type IDs match the TileSet atlas columns in world.gd.
var slot_block_types: Array[int] = [1, 2, 4, 5, 6, 7]
# Slot 0 = Dirt   (tile 1)
# Slot 1 = Stone  (tile 2)
# Slot 2 = Wood   (tile 4)
# Slot 3 = Sand   (tile 5)
# Slot 4 = Brick  (tile 6) — craftable
# Slot 5 = Glass  (tile 7) — craftable

## Item counts: {block_type_id: count}. Missing keys = 0 items.
var inventory: Dictionary = {}

## Display names for each block type, used by Hotbar and CraftingMenu.
var block_names := {
	1: "Dirt",
	2: "Stone",
	4: "Wood",
	5: "Sand",
	6: "Brick",
	7: "Glass",
}

## Colors for each block type, used by Hotbar and CraftingMenu.
var block_colors := {
	1: Color(0.55, 0.36, 0.16),   # Dirt
	2: Color(0.50, 0.50, 0.50),   # Stone
	4: Color(0.65, 0.50, 0.30),   # Wood
	5: Color(0.85, 0.78, 0.45),   # Sand
	6: Color(0.70, 0.33, 0.22),   # Brick
	7: Color(0.65, 0.85, 0.95),   # Glass
}


func _ready() -> void:
	_give_starting_inventory()


func _give_starting_inventory() -> void:
	## Give the player some items to start with so they can experiment
	## immediately. Wood and Sand don't spawn in the world naturally,
	## so starting items are the only source for now.
	inventory = {
		1: 10,   # 10 Dirt
		2: 10,   # 10 Stone
		4: 10,   # 10 Wood
		5: 10,   # 10 Sand
	}


func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	if index == selected_slot:
		return
	selected_slot = index
	selection_changed.emit(selected_slot)


func get_selected_block_type() -> int:
	## Returns the tile type ID of the currently selected slot, or -1 if empty.
	return slot_block_types[selected_slot]


# --- Inventory Management ---

func add_item(block_type: int, count: int = 1) -> void:
	## Add items to inventory (e.g., after mining or crafting).
	if not inventory.has(block_type):
		inventory[block_type] = 0
	inventory[block_type] += count
	inventory_changed.emit(block_type, inventory[block_type])


func remove_item(block_type: int, count: int = 1) -> bool:
	## Remove items from inventory (e.g., after placing or crafting).
	## Returns false if not enough items available.
	if get_count(block_type) < count:
		return false
	inventory[block_type] -= count
	inventory_changed.emit(block_type, inventory[block_type])
	return true


func get_count(block_type: int) -> int:
	## Returns how many of this block type the player has.
	return inventory.get(block_type, 0)


func has_item(block_type: int, count: int = 1) -> bool:
	## Check if the player has at least `count` of this block type.
	return get_count(block_type) >= count
