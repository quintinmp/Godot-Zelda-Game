# InventoryUI.gd - Attach this to the Control node under CanvasLayer
extends Control

# UI Components
var hotbar_container: HBoxContainer
var inventory_panel: Panel
var inventory_grid: GridContainer
var cursor_overlay: Control  # New overlay for cursor item

# Drag & Drop State
var held_item: InventoryManager.ItemStack = null
var held_item_origin: Vector2i = Vector2i(-1, -1)
var is_dragging: bool = false

# State
var is_inventory_open: bool = false
var slot_buttons: Array[Button] = []

# Constants
const SLOT_SIZE = 64
const HOTBAR_SLOTS = 12

func _ready():
	print("InventoryUI: Initializing...")
	
	# Set up full screen coverage for input handling
	anchor_left = 0
	anchor_top = 0  
	anchor_right = 1
	anchor_bottom = 1
	
	# Create UI components
	create_hotbar()
	create_inventory_panel()
	create_cursor_overlay()
	
	# Connect to inventory manager signals
	InventoryManager.hotbar_changed.connect(_on_hotbar_changed)
	InventoryManager.selected_slot_changed.connect(_on_selected_slot_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	
	# Initialize display
	update_hotbar_display()
	
	print("InventoryUI: Ready")

func create_cursor_overlay():
	# Create a separate overlay control for cursor items that draws on top
	cursor_overlay = Control.new()
	cursor_overlay.name = "CursorOverlay"
	cursor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse events
	cursor_overlay.anchor_left = 0
	cursor_overlay.anchor_top = 0  
	cursor_overlay.anchor_right = 1
	cursor_overlay.anchor_bottom = 1
	cursor_overlay.z_index = 1000  # Very high z-index to ensure it's on top
	
	# Connect the draw function to the overlay
	cursor_overlay.draw.connect(_draw_cursor_item)
	
	add_child(cursor_overlay)

func _draw_cursor_item():
	# Draw the held item following the cursor on the overlay
	if is_dragging and held_item != null:
		var mouse_pos = cursor_overlay.get_local_mouse_position()
		var icon_texture = get_item_icon(held_item.item_id)
		
		if icon_texture:
			# Draw icon at cursor position
			var draw_pos = mouse_pos - Vector2(SLOT_SIZE/2, SLOT_SIZE/2)
			cursor_overlay.draw_texture_rect(icon_texture, Rect2(draw_pos, Vector2(SLOT_SIZE, SLOT_SIZE)), false)
			
			# Draw quantity if > 1
			if held_item.quantity > 1:
				var font = ThemeDB.fallback_font
				var text_pos = draw_pos + Vector2(SLOT_SIZE - 20, SLOT_SIZE - 5)
				cursor_overlay.draw_string(font, text_pos, str(held_item.quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _process(_delta):
	# Update cursor overlay when dragging
	if is_dragging and cursor_overlay:
		cursor_overlay.queue_redraw()

func create_hotbar():
	hotbar_container = HBoxContainer.new()
	hotbar_container.name = "HotbarContainer"
	add_child(hotbar_container)
	
	# Create hotbar slots first
	for i in range(HOTBAR_SLOTS):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_button.text = get_slot_key_text(i)
		slot_button.pressed.connect(_on_hotbar_slot_pressed.bind(i))
		
		# Scale icons to 4x size (64x64 from 16x16)
		slot_button.expand_icon = true
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		hotbar_container.add_child(slot_button)
		slot_buttons.append(slot_button)
	
	# Position manually at bottom center after creation
	await get_tree().process_frame  # Wait for layout
	
	var viewport_size = get_viewport().size
	hotbar_container.position = Vector2(
		viewport_size.x / 2 - hotbar_container.size.x / 2,
		viewport_size.y - 100
	)
	
	print("Hotbar created with ", slot_buttons.size(), " slots")

func create_inventory_panel():
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	
	# Make panel wider to fit 12 slots properly and center the grid
	var panel_width = (HOTBAR_SLOTS * SLOT_SIZE) + 100  # Slots + padding
	inventory_panel.size = Vector2(panel_width, 400)
	var viewport_size = get_viewport().size
	inventory_panel.position = Vector2(
		viewport_size.x / 2 - inventory_panel.size.x / 2,
		viewport_size.y / 2 - inventory_panel.size.y / 2
	)
	
	# Hide by default
	inventory_panel.visible = false
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Inventory"
	title_label.position = Vector2(20, 20)
	inventory_panel.add_child(title_label)
	
	# Add close button
	var close_button = Button.new()
	close_button.text = "Close [Tab]"
	close_button.position = Vector2(inventory_panel.size.x - 120, 20)
	close_button.size = Vector2(100, 30)
	close_button.pressed.connect(close_inventory)
	inventory_panel.add_child(close_button)
	
	# Create the inventory grid
	create_inventory_grid()
	
	print("Inventory panel created")

func create_inventory_grid():
	inventory_grid = GridContainer.new()
	inventory_grid.columns = HOTBAR_SLOTS  # 12 columns
	
	# Center the grid in the panel
	var grid_width = HOTBAR_SLOTS * SLOT_SIZE
	var start_x = (inventory_panel.size.x - grid_width) / 2
	inventory_grid.position = Vector2(start_x, 70)  # Centered horizontally, below title
	
	inventory_panel.add_child(inventory_grid)
	
	# Create 3 rows of slots (hotbar + 2 backpack rows)
	var total_slots = HOTBAR_SLOTS * 3  # 36 total slots
	
	for i in range(total_slots):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_button.expand_icon = true
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Connect to slot press handler
		slot_button.pressed.connect(_on_inventory_slot_pressed.bind(i))
		
		inventory_grid.add_child(slot_button)
	
	print("Created inventory grid with ", total_slots, " slots")

func get_slot_key_text(slot_index: int) -> String:
	if slot_index < 9:
		return str(slot_index + 1)
	else:
		return ["0", "-", "+"][slot_index - 9]

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_TAB:
				if is_dragging:
					# Cancel drag when opening/closing inventory
					cancel_drag()
				toggle_inventory()
			KEY_I:
				# Test function - add wood
				InventoryManager.try_add_item("wood", 5)
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_dragging:
				# Right-click to cancel drag and return item to origin
				cancel_drag()

func cancel_drag():
	if is_dragging and held_item != null:
		# Return item to its origin
		InventoryManager.set_item_at_slot(held_item_origin, held_item)
		clear_held_item()
		print("Cancelled drag, returned item to origin")

func toggle_inventory():
	is_inventory_open = !is_inventory_open
	inventory_panel.visible = is_inventory_open
	
	# Hide/show hotbar based on inventory state (like Stardew Valley)
	hotbar_container.visible = !is_inventory_open
	
	if is_inventory_open:
		update_inventory_grid()  # Refresh the grid when opening
	
	print("Inventory toggled: ", is_inventory_open)

func close_inventory():
	is_inventory_open = false
	inventory_panel.visible = false
	hotbar_container.visible = true  # Make sure to show hotbar when closing

# === SIGNAL HANDLERS ===

func _on_hotbar_slot_pressed(slot_index: int):
	if is_dragging:
		# Try to drop held item in this hotbar slot
		handle_item_drop(Vector2i(slot_index, 0))
	else:
		# Pick up item or select slot
		if Input.is_key_pressed(KEY_SHIFT):
			# Shift-click quick move (we'll implement this later)
			pass
		else:
			var item_at_slot = InventoryManager.hotbar[slot_index]
			if item_at_slot != null:
				# Pick up the item
				handle_item_pickup(Vector2i(slot_index, 0))
			else:
				# Just select the slot
				InventoryManager.set_selected_slot(slot_index)

func _on_inventory_slot_pressed(slot_index: int):
	# Convert grid index to slot position
	var row = slot_index / HOTBAR_SLOTS
	var col = slot_index % HOTBAR_SLOTS
	var slot_pos = Vector2i(col, row)
	
	if is_dragging:
		# Try to drop held item
		handle_item_drop(slot_pos)
	else:
		# Try to pick up item
		var item_at_slot = InventoryManager.get_item_at_slot(slot_pos)
		if item_at_slot != null:
			handle_item_pickup(slot_pos)
		elif row == 0:
			# Clicking empty hotbar slot - select it
			InventoryManager.set_selected_slot(col)

func handle_item_pickup(slot_pos: Vector2i):
	var item_at_slot = InventoryManager.get_item_at_slot(slot_pos)
	if item_at_slot == null:
		return
	
	# Store the held item and origin
	held_item = InventoryManager.ItemStack.new()
	held_item.item_id = item_at_slot.item_id
	held_item.quantity = item_at_slot.quantity
	held_item.quality = item_at_slot.quality
	
	held_item_origin = slot_pos
	is_dragging = true
	
	# Remove item from its original slot
	InventoryManager.set_item_at_slot(slot_pos, null)
	
	print("Picked up: ", held_item.item_id, " x", held_item.quantity)

func handle_item_drop(slot_pos: Vector2i):
	if not is_dragging or held_item == null:
		return
	
	var item_at_target = InventoryManager.get_item_at_slot(slot_pos)
	
	if item_at_target == null:
		# Drop in empty slot
		InventoryManager.set_item_at_slot(slot_pos, held_item)
		clear_held_item()
		print("Dropped in empty slot")
		
	elif item_at_target.item_id == held_item.item_id:
		# Try to stack
		var total_quantity = item_at_target.quantity + held_item.quantity
		var max_stack = InventoryManager.MAX_STACK_SIZE
		
		if total_quantity <= max_stack:
			# All fits in one stack
			item_at_target.quantity = total_quantity
			clear_held_item()
			print("Stacked items")
		else:
			# Partial stack
			item_at_target.quantity = max_stack
			held_item.quantity = total_quantity - max_stack
			print("Partial stack, still holding: ", held_item.quantity)
			# Keep dragging the remainder
		
	else:
		# Swap different items
		InventoryManager.set_item_at_slot(slot_pos, held_item)
		held_item = item_at_target
		print("Swapped items")
		# Continue dragging the swapped item

func clear_held_item():
	held_item = null
	held_item_origin = Vector2i(-1, -1)
	is_dragging = false
	
	# Clear cursor overlay
	if cursor_overlay:
		cursor_overlay.queue_redraw()
	
	# Update displays after dropping
	update_hotbar_display()
	if is_inventory_open:
		update_inventory_grid()

func _on_hotbar_changed(slot_index: int):
	update_hotbar_slot(slot_index)
	update_inventory_grid()  # Also update inventory grid

func _on_selected_slot_changed(new_slot: int):
	update_hotbar_selection()
	update_inventory_grid()  # Update selection in inventory too

func _on_inventory_changed():
	update_hotbar_display()
	update_inventory_grid()

# === DISPLAY UPDATE FUNCTIONS ===

func update_hotbar_display():
	for i in range(HOTBAR_SLOTS):
		update_hotbar_slot(i)
	update_hotbar_selection()

func update_inventory_grid():
	if not inventory_grid:
		return
		
	var grid_buttons = inventory_grid.get_children()
	
	# Update all 3 rows
	for i in range(grid_buttons.size()):
		var button = grid_buttons[i]
		var row = i / HOTBAR_SLOTS
		var col = i % HOTBAR_SLOTS
		
		var item_stack = null
		var is_selected = false
		
		if row == 0:
			# Hotbar row
			item_stack = InventoryManager.hotbar[col]
			is_selected = (col == InventoryManager.selected_hotbar_slot)
		else:
			# Backpack rows
			var backpack_index = (row - 1) * HOTBAR_SLOTS + col
			if backpack_index < InventoryManager.backpack.size():
				item_stack = InventoryManager.backpack[backpack_index]
		
		# Update button display
		if item_stack != null:
			set_button_item_display(button, item_stack)
			if is_selected:
				button.modulate = Color.YELLOW  # Highlight selected hotbar slot
		else:
			# Empty slot
			button.icon = null
			if row == 0:
				# Show hotkey for hotbar slots
				button.text = get_slot_key_text(col)
			else:
				button.text = ""
			button.modulate = Color.GRAY if not is_selected else Color.YELLOW
			remove_quantity_label(button)

func update_hotbar_slot(slot_index: int):
	if slot_index >= slot_buttons.size():
		return
	
	var button = slot_buttons[slot_index]
	var item_stack = InventoryManager.hotbar[slot_index]
	
	if item_stack != null:
		# Set button icon and text
		set_button_item_display(button, item_stack)
	else:
		# Empty slot
		button.icon = null
		button.text = get_slot_key_text(slot_index)
		button.modulate = Color.GRAY
		remove_quantity_label(button)  # Clean up quantity label

func update_hotbar_selection():
	for i in range(slot_buttons.size()):
		var button = slot_buttons[i]
		if i == InventoryManager.selected_hotbar_slot:
			# Highlight selected slot
			button.modulate = Color.YELLOW if InventoryManager.hotbar[i] == null else Color.WHITE
			# Add yellow border/glow effect could go here
		else:
			button.modulate = Color.WHITE if InventoryManager.hotbar[i] != null else Color.GRAY

func set_button_item_display(button: Button, item_stack):
	# Get the icon from InventoryManager
	var icon_texture = get_item_icon(item_stack.item_id)
	
	if icon_texture:
		button.icon = icon_texture
		button.text = ""  # Clear text when we have an icon
		
		# Add quantity label as overlay if > 1
		if item_stack.quantity > 1:
			add_quantity_label(button, item_stack.quantity)
		else:
			remove_quantity_label(button)
	else:
		# Fallback to text display
		button.icon = null
		var display_text = item_stack.item_id
		if item_stack.quantity > 1:
			display_text += "\n" + str(item_stack.quantity)
		button.text = display_text
		remove_quantity_label(button)
	
	button.modulate = Color.WHITE

func add_quantity_label(button: Button, quantity: int):
	# Check if we already have a quantity label
	var quantity_label = button.get_node_or_null("QuantityLabel")
	
	if quantity_label:
		# Just update the existing label
		quantity_label.text = str(quantity)
	else:
		# Create new quantity label
		quantity_label = Label.new()
		quantity_label.name = "QuantityLabel"
		quantity_label.text = str(quantity)
		quantity_label.add_theme_color_override("font_color", Color.WHITE)
		quantity_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		quantity_label.add_theme_constant_override("shadow_offset_x", 1)
		quantity_label.add_theme_constant_override("shadow_offset_y", 1)
		
		# Position at bottom right
		quantity_label.anchor_left = 1.0
		quantity_label.anchor_top = 1.0
		quantity_label.anchor_right = 1.0
		quantity_label.anchor_bottom = 1.0
		quantity_label.offset_left = -20
		quantity_label.offset_top = -16
		quantity_label.size = Vector2(18, 14)
		
		button.add_child(quantity_label)

func remove_quantity_label(button: Button):
	# Find ALL labels with QuantityLabel name (in case there are duplicates)
	var labels_to_remove = []
	for child in button.get_children():
		if child.name == "QuantityLabel":
			labels_to_remove.append(child)
	
	# Remove all quantity labels immediately
	for label in labels_to_remove:
		label.queue_free()

func get_item_icon(item_id: String) -> Texture2D:
	# Check if InventoryManager has the atlas loaded
	if not InventoryManager.item_icon_atlas:
		return null
	
	# Check if we have mapping for this item
	if not InventoryManager.icon_mapping.has(item_id):
		return null
	
	# Create AtlasTexture for this specific icon
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = InventoryManager.item_icon_atlas
	
	var icon_pos = InventoryManager.icon_mapping[item_id]
	atlas_texture.region = Rect2(
		icon_pos.x * InventoryManager.ICON_SIZE,
		icon_pos.y * InventoryManager.ICON_SIZE,
		InventoryManager.ICON_SIZE,
		InventoryManager.ICON_SIZE
	)
	
	return atlas_texture
