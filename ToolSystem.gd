# ToolSystem.gd - Singleton for managing all tool interactions
extends Node

# Tool definitions loaded from JSON or defined here
var tool_definitions = {}
var selected_tool_id = ""
var is_using_tool = false
var tool_animation_timer = 0.0
var tool_animation_duration = 0.0
var current_tool_type = ""

# References to other systems
var inventory_manager
var time_system

# Signals for other systems to connect to
signal tool_used(tool_id, position, result)
signal crop_planted(position, seed_id)
signal crop_watered(position)
signal crop_harvested(position, item_id, quantity)

func _ready():
	name = "ToolSystem"
	# Get references to other singletons
	inventory_manager = get_node("/root/InventoryManager")
	time_system = get_node("/root/TimeSystem")
	
	# Load tool definitions
	load_tool_definitions()
	
	print("ToolSystem: Ready")

func _process(delta):
	update_tool_animation(delta)
	handle_tool_input()
	update_cursor_overlay()

# === TOOL DEFINITIONS ===
func load_tool_definitions():
	# For now, define tools in code - we can move to JSON later
	tool_definitions = {
		"hoe": {
			"id": "hoe",
			"name": "Hoe", 
			"tool_type": "hoe",
			"energy_cost": 2,
			"use_time": 0.6,
			"sound_effect": "hoe_use"
		},
		"wateringcan": {
			"id": "wateringcan",
			"name": "Watering Can",
			"tool_type": "wateringcan", 
			"energy_cost": 2,
			"use_time": 0.5,
			"sound_effect": "water_use"
		},
		"pickaxe": {
			"id": "pickaxe",
			"name": "Pickaxe",
			"tool_type": "pickaxe",
			"energy_cost": 4,
			"use_time": 0.7,
			"sound_effect": "pickaxe_use"
		},
		"carrot_seeds": {
			"id": "carrot_seeds",
			"name": "Carrot Seeds",
			"tool_type": "seeds",
			"energy_cost": 1,
			"use_time": 0.4,
			"sound_effect": "plant_seeds"
		},
		"potato_seeds": {
			"id": "potato_seeds", 
			"name": "Potato Seeds",
			"tool_type": "seeds",
			"energy_cost": 1,
			"use_time": 0.4,
			"sound_effect": "plant_seeds"
		}
	}

# === INPUT HANDLING ===
func handle_tool_input():
	if is_using_tool:
		return # Don't handle input while using tool
	
	# Get selected tool from inventory
	selected_tool_id = inventory_manager.get_selected_item_id()
	
	# Handle tool use on mouse click
	if Input.is_action_just_pressed("tool_use"):
		print("=== TOOL USE PRESSED ===")
		print("Selected tool: ", selected_tool_id)
		if selected_tool_id != "":
			use_tool_at_cursor()
		else:
			print("No tool selected - trying harvest")
			try_harvest_at_cursor()

# === TOOL USAGE ===
func use_tool_at_cursor():
	var target_position = get_cursor_tile_position()
	print("Target position: ", target_position)
	
	if !is_valid_tool_target(target_position):
		print("Invalid target position")
		return
		
	if !can_use_tool(selected_tool_id, target_position):
		print("Cannot use ", selected_tool_id, " at ", target_position)
		var tile_type = get_tile_type_at(target_position)
		print("Tile type at position: ", tile_type)
		return
	
	var result = execute_tool_use(selected_tool_id, target_position)
	print("Tool use result: ", result)
	
	if result.success:
		start_tool_animation(selected_tool_id)
		tool_used.emit(selected_tool_id, target_position, result)
		print("Tool used: ", result.message)

func execute_tool_use(tool_id: String, target_pos: Vector2i):
	var tool_data = tool_definitions.get(tool_id)
	if !tool_data:
		return {"success": false, "message": "Tool not found"}
	
	var tool_type = tool_data.tool_type
	var tile_type = get_tile_type_at(target_pos)
	
	match tool_type:
		"hoe":
			return use_hoe(target_pos, tile_type)
		"wateringcan":
			return use_watering_can(target_pos, tile_type)
		"pickaxe":
			return use_pickaxe(target_pos, tile_type)
		"seeds":
			return plant_seeds(tool_id, target_pos, tile_type)
		_:
			return {"success": false, "message": "Unknown tool type"}

# === INDIVIDUAL TOOL LOGIC ===
func use_hoe(pos: Vector2i, tile_type: int):
	if tile_type == 1: # Plain dirt
		set_tile_type_at(pos, 2) # Tilled soil
		return {"success": true, "message": "Tilled soil at " + str(pos)}
	return {"success": false, "message": "Can only till plain dirt"}

func use_watering_can(pos: Vector2i, tile_type: int):
	if tile_type == 2: # Tilled soil only
		set_tile_type_at(pos, 3) # Watered/tilled soil
		crop_watered.emit(pos)
		return {"success": true, "message": "Watered soil at " + str(pos)}
	return {"success": false, "message": "Can only water tilled soil"}

func use_pickaxe(pos: Vector2i, tile_type: int):
	# Break tilled or watered soil back to plain dirt
	if tile_type == 2 or tile_type == 3: # Tilled or watered
		set_tile_type_at(pos, 1) # Back to plain dirt
		# TODO: Remove any crops at this position
		return {"success": true, "message": "Broke tilled soil at " + str(pos)}
	return {"success": false, "message": "Nothing to break"}

func plant_seeds(seed_id: String, pos: Vector2i, tile_type: int):
	if tile_type == 2 or tile_type == 3: # Tilled or watered soil
		# TODO: Check if crop already exists
		crop_planted.emit(pos, seed_id)
		# Remove seed from inventory
		inventory_manager.try_remove_item(seed_id, 1)
		return {"success": true, "message": "Planted " + seed_id + " at " + str(pos)}
	return {"success": false, "message": "Can only plant on tilled soil"}

# === HARVEST HANDLING ===
func try_harvest_at_cursor():
	var target_position = get_cursor_tile_position()
	
	# Check if there's a harvestable crop at target position
	var crop_system = get_node("/root/CropSystem")
	if crop_system and crop_system.can_harvest_at(target_position):
		var result = crop_system.harvest_crop_at(target_position)
		if result.success:
			# Add harvested item to inventory
			inventory_manager.try_add_item(result.item_id, result.quantity)
			print("Harvested: ", result.message)
		else:
			print("Harvest failed: ", result.message)
	else:
		print("Nothing to harvest at: ", target_position)

# === TOOL VALIDATION ===
func can_use_tool(tool_id: String, target_pos: Vector2i) -> bool:
	var tool_data = tool_definitions.get(tool_id)
	if !tool_data:
		print("Tool data not found for: ", tool_id)
		return false
	
	var player_pos = get_player_tile_position()
	var distance = abs(target_pos.x - player_pos.x) + abs(target_pos.y - player_pos.y)
	print("Player at: ", player_pos, ", Target at: ", target_pos, ", Distance: ", distance)
	if distance > 2:
		print("Too far away - distance: ", distance)
		return false # Too far away
	
	var tile_type = get_tile_type_at(target_pos)
	var tool_type = tool_data.tool_type
	print("Tool type: ", tool_type, ", Tile type: ", tile_type)
	
	# Check if tool can be used on this tile type
	var can_use = false
	match tool_type:
		"hoe":
			can_use = tile_type == 1 # Plain dirt only
		"wateringcan": 
			can_use = tile_type == 2 # Tilled dirt only
		"pickaxe":
			can_use = tile_type == 2 or tile_type == 3 # Can break tilled/watered soil
		"seeds":
			can_use = tile_type == 2 or tile_type == 3 # Tilled or watered soil
		_:
			can_use = false
	
	print("Can use ", tool_type, " on tile type ", tile_type, ": ", can_use)
	return can_use

func is_valid_tool_target(pos: Vector2i) -> bool:
	# Since your farm is in quadrant 3 (negative coordinates), we need proper bounds
	# For now, allow a reasonable range around your farm area
	var min_x = -200
	var max_x = 50  
	var min_y = -50
	var max_y = 200
	
	print("Checking bounds for position: ", pos)
	var is_valid = pos.x >= min_x and pos.x <= max_x and pos.y >= min_y and pos.y <= max_y
	print("Position valid: ", is_valid)
	return is_valid

# === TILE SYSTEM INTEGRATION ===
# Reference to your main tilemap - you'll need to set this
var main_tilemap: TileMapLayer

func get_cursor_tile_position() -> Vector2i:
	var viewport = get_viewport()
	var mouse_screen = viewport.get_mouse_position()
	var camera = viewport.get_camera_2d()
	
	# Convert screen to world coordinates properly
	var mouse_world = camera.global_position + (mouse_screen - viewport.size / 2.0) / camera.zoom
	
	if main_tilemap:
		# Use tilemap's local_to_map for accurate conversion
		return main_tilemap.local_to_map(main_tilemap.to_local(mouse_world))
	else:
		# Fallback: assume 64x64 tiles
		var tile_x = int(mouse_world.x / 64)
		var tile_y = int(mouse_world.y / 64)
		return Vector2i(tile_x, tile_y)

func get_player_tile_position() -> Vector2i:
	var player = get_tree().get_first_node_in_group("player")
	if player and main_tilemap:
		# Convert player world position to tilemap coordinates
		return main_tilemap.local_to_map(main_tilemap.to_local(player.global_position))
	elif player:
		# Fallback
		var world_pos = player.global_position
		var tile_x = int(world_pos.x / 64)
		var tile_y = int(world_pos.y / 64)
		return Vector2i(tile_x, tile_y)
	return Vector2i(0, 0)

func get_tile_type_at(pos: Vector2i) -> int:
	if !main_tilemap:
		print("Warning: main_tilemap not set!")
		return 0
	
	# Using custom data layer
	var tile_data = main_tilemap.get_cell_tile_data(pos)
	if tile_data and tile_data.has_custom_data("tile_type"):
		return tile_data.get_custom_data("tile_type")
	
	return 0  # Default to 0 if no custom data

func set_tile_type_at(pos: Vector2i, tile_type: int):
	if !main_tilemap:
		print("Warning: main_tilemap not set!")
		return
	
	var atlas_coords = map_tile_type_to_atlas(tile_type)
	main_tilemap.set_cell(pos, 0, atlas_coords) # 0 = source_id, usually 0 for single tileset

func map_tile_type_to_atlas(tile_type: int) -> Vector2i:
	# Since we're using custom data, we need to map types to your actual atlas coordinates
	match tile_type:
		1: return Vector2i(8, 10)  # Plain dirt
		2: return Vector2i(1, 31)  # Tilled dirt
		3: return Vector2i(2, 31)  # Watered/tilled dirt
		4: return Vector2i(3, 31)  # Watered only dirt
		_: return Vector2i(8, 10)  # Default to dirt

# Helper functions for atlas coordinate mapping (kept for reference)
func map_atlas_to_tile_type(atlas_coords: Vector2i) -> int:
	# This function is no longer used since we're using custom data
	# But keeping it for reference or fallback
	if atlas_coords == Vector2i(8, 10): return 1   # Plain dirt
	if atlas_coords == Vector2i(1, 31): return 2   # Tilled dirt
	if atlas_coords == Vector2i(2, 31): return 3   # Watered/tilled dirt
	if atlas_coords == Vector2i(3, 31): return 4   # Watered only dirt
	return 1  # Default to dirt

# Call this from your main scene to set up the tilemap reference
func set_main_tilemap(tilemap: TileMapLayer):
	main_tilemap = tilemap
	print("ToolSystem: Connected to tilemap")

# === TOOL ANIMATION ===
func start_tool_animation(tool_id: String):
	var tool_data = tool_definitions.get(tool_id)
	if !tool_data:
		return
	
	is_using_tool = true
	tool_animation_timer = 0.0
	tool_animation_duration = tool_data.use_time
	current_tool_type = tool_data.tool_type
	
	# Tell player to start tool animation
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("start_tool_animation"):
		player.start_tool_animation(current_tool_type, tool_animation_duration)

func update_tool_animation(delta: float):
	if is_using_tool:
		tool_animation_timer += delta
		
		if tool_animation_timer >= tool_animation_duration:
			is_using_tool = false
			tool_animation_timer = 0.0
			current_tool_type = ""
			
			# Tell player animation finished
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("end_tool_animation"):
				player.end_tool_animation()

# === DEBUG FUNCTIONS ===
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_U: # Debug: give tools
				inventory_manager.try_add_item("hoe", 1)
				inventory_manager.try_add_item("watering_can", 1) 
				inventory_manager.try_add_item("pickaxe", 1)
				inventory_manager.try_add_item("carrot_seeds", 10)
				print("Added tools to inventory")

# === CURSOR OVERLAY FOR DEBUG ===
func update_cursor_overlay():
	if !main_tilemap:
		return
	
	var target_pos = get_cursor_tile_position()
	var selected_tool = inventory_manager.get_selected_item_id()
	
	# Only show overlay when a tool is selected
	if selected_tool != "" and tool_definitions.has(selected_tool):
		var can_use = can_use_tool_silent(selected_tool, target_pos)
		show_tile_overlay(target_pos, can_use)
	else:
		# Hide overlay when no tool selected
		hide_tile_overlay()

func can_use_tool_silent(tool_id: String, target_pos: Vector2i) -> bool:
	# Same as can_use_tool but without debug prints
	var tool_data = tool_definitions.get(tool_id)
	if !tool_data:
		return false
	
	var player_pos = get_player_tile_position()
	var distance = abs(target_pos.x - player_pos.x) + abs(target_pos.y - player_pos.y)
	if distance > 2:
		return false
	
	var tile_type = get_tile_type_at(target_pos)
	var tool_type = tool_data.tool_type
	
	match tool_type:
		"hoe":
			return tile_type == 1
		"wateringcan": 
			return tile_type == 2
		"pickaxe":
			return tile_type == 2 or tile_type == 3
		"seeds":
			return tile_type == 2 or tile_type == 3
		_:
			return false

# Create a simple overlay indicator
var overlay_sprite: Sprite2D = null

func show_tile_overlay(tile_pos: Vector2i, can_use: bool):
	if !overlay_sprite:
		create_overlay_sprite()
	
	if overlay_sprite:
		# Convert tile position to world position
		var world_pos = main_tilemap.to_global(main_tilemap.map_to_local(tile_pos))
		overlay_sprite.global_position = world_pos
		
		# Set color based on usability
		overlay_sprite.modulate = Color.GREEN if can_use else Color.RED
		overlay_sprite.modulate.a = 0.5  # Semi-transparent
		overlay_sprite.visible = true

func hide_tile_overlay():
	if overlay_sprite:
		overlay_sprite.visible = false

func create_overlay_sprite():
	overlay_sprite = Sprite2D.new()
	
	# Create a simple colored square texture
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	overlay_sprite.texture = texture
	overlay_sprite.visible = false
	
	# Add to the scene tree
	get_tree().current_scene.add_child(overlay_sprite)
func get_tool_definition(tool_id: String):
	return tool_definitions.get(tool_id)

func is_tool(item_id: String) -> bool:
	return tool_definitions.has(item_id)
