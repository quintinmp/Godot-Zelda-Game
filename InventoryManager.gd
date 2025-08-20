# InventoryManager.gd - Autoload Singleton
extends Node

# Signals for UI updates
signal inventory_changed
signal hotbar_changed(slot_index: int)
signal selected_slot_changed(new_slot: int)

# Inventory data
var hotbar: Array[ItemStack] = []
var backpack: Array[ItemStack] = []
var selected_hotbar_slot: int = 0
var item_icon_atlas: Texture2D

var icon_mapping = {
	# Row 0: Tools (y=0)
	"hoe": Vector2i(0, 0),
	"wateringcan": Vector2i(1, 0), 
	"pickaxe": Vector2i(2, 0),
	"axe": Vector2i(3, 0),
	
	# Row 1: Seeds (y=1) 
	"carrot_seeds": Vector2i(0, 1),
	"potato_seeds": Vector2i(1, 1),
	"radish_seeds": Vector2i(2, 1),
	"strawberry_seeds": Vector2i(3, 1),
	"corn_seeds": Vector2i(4, 1),
	
	# Row 2: Crops (y=2)
	"carrot": Vector2i(0, 2),
	"potato": Vector2i(1, 2), 
	"radish": Vector2i(2, 2),
	"strawberry": Vector2i(3, 2),
	"corn": Vector2i(4, 2),
	
	# Row 3: Resources (y=3)
	"wood": Vector2i(0, 3),
	"stone": Vector2i(1, 3),
	"coal": Vector2i(2, 3),
	"fiber": Vector2i(3, 3)
}

# Constants
const HOTBAR_SIZE = 12  # 1-9, 0, -, +
const BACKPACK_SIZE = 24  # 2 rows of 12
const MAX_STACK_SIZE = 99
const ICON_SIZE = 16 


# ItemStack class definition
class ItemStack:
	var item_id: String
	var quantity: int
	var quality: int = 0  # 0=normal, 1=silver, 2=gold, 3=iridium
	var metadata: Dictionary = {}
	
	func _init(id: String = "", qty: int = 0, qual: int = 0):
		item_id = id
		quantity = qty
		quality = qual

func _ready():
	print("InventoryManager: Initialized")
	item_icon_atlas = load("res://Assets/Textures/ItemIcons/item_icons.png")
	initialize_inventory()
	setup_test_inventory()

func initialize_inventory():
	# Initialize arrays with null values
	hotbar.resize(HOTBAR_SIZE)
	backpack.resize(BACKPACK_SIZE)
	
	# Fill with nulls
	for i in range(HOTBAR_SIZE):
		hotbar[i] = null
	for i in range(BACKPACK_SIZE):
		backpack[i] = null

# === CORE INVENTORY OPERATIONS ===

func try_add_item(item_id: String, quantity: int) -> bool:
	var remaining = quantity
	
	# First try to stack with existing items in hotbar
	for i in range(HOTBAR_SIZE):
		if hotbar[i] != null and hotbar[i].item_id == item_id:
			var space_available = MAX_STACK_SIZE - hotbar[i].quantity
			var amount_to_add = min(remaining, space_available)
			hotbar[i].quantity += amount_to_add
			remaining -= amount_to_add
			hotbar_changed.emit(i)
			if remaining <= 0:
				return true
	
	# Then try backpack stacking
	for i in range(BACKPACK_SIZE):
		if backpack[i] != null and backpack[i].item_id == item_id:
			var space_available = MAX_STACK_SIZE - backpack[i].quantity
			var amount_to_add = min(remaining, space_available)
			backpack[i].quantity += amount_to_add
			remaining -= amount_to_add
			inventory_changed.emit()
			if remaining <= 0:
				return true
	
	# Finally try empty slots in hotbar
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == null:
			var amount_to_add = min(remaining, MAX_STACK_SIZE)
			hotbar[i] = ItemStack.new(item_id, amount_to_add)
			remaining -= amount_to_add
			hotbar_changed.emit(i)
			if remaining <= 0:
				return true
	
	# Then empty slots in backpack
	for i in range(BACKPACK_SIZE):
		if backpack[i] == null:
			var amount_to_add = min(remaining, MAX_STACK_SIZE)
			backpack[i] = ItemStack.new(item_id, amount_to_add)
			remaining -= amount_to_add
			inventory_changed.emit()
			if remaining <= 0:
				return true
	
	# Couldn't fit everything
	return remaining == 0

func try_remove_item(item_id: String, quantity: int) -> bool:
	# First check if we have enough
	var total_count = get_item_count(item_id)
	if total_count < quantity:
		return false
	
	var remaining = quantity
	
	# Remove from hotbar first
	for i in range(HOTBAR_SIZE):
		if remaining <= 0:
			break
		if hotbar[i] != null and hotbar[i].item_id == item_id:
			var to_remove = min(remaining, hotbar[i].quantity)
			hotbar[i].quantity -= to_remove
			remaining -= to_remove
			
			if hotbar[i].quantity <= 0:
				hotbar[i] = null
			hotbar_changed.emit(i)
	
	# Remove from backpack if needed
	for i in range(BACKPACK_SIZE):
		if remaining <= 0:
			break
		if backpack[i] != null and backpack[i].item_id == item_id:
			var to_remove = min(remaining, backpack[i].quantity)
			backpack[i].quantity -= to_remove
			remaining -= to_remove
			
			if backpack[i].quantity <= 0:
				backpack[i] = null
			inventory_changed.emit()
	
	return true

func get_item_count(item_id: String) -> int:
	var total = 0
	
	# Count in hotbar
	for stack in hotbar:
		if stack != null and stack.item_id == item_id:
			total += stack.quantity
	
	# Count in backpack
	for stack in backpack:
		if stack != null and stack.item_id == item_id:
			total += stack.quantity
	
	return total

# === HOTBAR OPERATIONS ===

func get_selected_item_id() -> String:
	var selected_stack = hotbar[selected_hotbar_slot]
	return selected_stack.item_id if selected_stack != null else ""

func get_selected_stack() -> ItemStack:
	return hotbar[selected_hotbar_slot]

func set_selected_slot(slot: int):
	if slot >= 0 and slot < HOTBAR_SIZE:
		selected_hotbar_slot = slot
		selected_slot_changed.emit(slot)

# === ITEM MANAGEMENT (for drag/drop - we'll implement this later) ===

func get_item_at_slot(slot_pos: Vector2i) -> ItemStack:
	if slot_pos.y == 0:  # Hotbar
		if slot_pos.x >= 0 and slot_pos.x < HOTBAR_SIZE:
			return hotbar[slot_pos.x]
	else:  # Backpack
		var backpack_index = (slot_pos.y - 1) * 12 + slot_pos.x
		if backpack_index >= 0 and backpack_index < BACKPACK_SIZE:
			return backpack[backpack_index]
	return null

func set_item_at_slot(slot_pos: Vector2i, item: ItemStack):
	if slot_pos.y == 0:  # Hotbar
		if slot_pos.x >= 0 and slot_pos.x < HOTBAR_SIZE:
			hotbar[slot_pos.x] = item
			hotbar_changed.emit(slot_pos.x)
	else:  # Backpack
		var backpack_index = (slot_pos.y - 1) * 12 + slot_pos.x
		if backpack_index >= 0 and backpack_index < BACKPACK_SIZE:
			backpack[backpack_index] = item
			inventory_changed.emit()

# === INPUT HANDLING ===

func _input(event):
	# Handle hotbar switching (1-9, 0, -, +)
	if event is InputEventKey and event.pressed:
		var slot = -1
		match event.keycode:
			KEY_1: slot = 0
			KEY_2: slot = 1
			KEY_3: slot = 2
			KEY_4: slot = 3
			KEY_5: slot = 4
			KEY_6: slot = 5
			KEY_7: slot = 6
			KEY_8: slot = 7
			KEY_9: slot = 8
			KEY_0: slot = 9
			KEY_MINUS: slot = 10
			KEY_EQUAL: slot = 11  # + key
		
		if slot >= 0:
			set_selected_slot(slot)

# === TEST DATA ===

func setup_test_inventory():
	# Tools
	hotbar[0] = ItemStack.new("hoe", 1)
	hotbar[1] = ItemStack.new("wateringcan", 1)
	hotbar[2] = ItemStack.new("pickaxe", 1)
	hotbar[3] = ItemStack.new("axe", 1)
	
	# Seeds
	hotbar[4] = ItemStack.new("carrot_seeds", 10)
	hotbar[5] = ItemStack.new("potato_seeds", 10)
	hotbar[6] = ItemStack.new("radish_seeds", 10)
	hotbar[7] = ItemStack.new("strawberry_seeds", 10)
	hotbar[8] = ItemStack.new("corn_seeds", 10)
	
	print("Test inventory setup complete")
