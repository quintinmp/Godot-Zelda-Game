# CropSystem.gd - Singleton for managing all crop growth and farming mechanics
extends Node

# Crop storage - Dictionary keyed by Vector2i position
var crops = {}

# Crop definitions loaded from JSON or defined here
var crop_definitions = {}

# References to other systems
var time_system
var tool_system

# Signals for other systems
signal crop_grown(position, crop_id, new_stage)
signal crop_harvested(position, crop_id, quantity)
signal crop_planted(position, crop_id)

func _ready():
	name = "CropSystem"
	
	# Get references to other singletons
	time_system = get_node("/root/TimeSystem")
	tool_system = get_node("/root/ToolSystem")
	
	# Load crop definitions
	load_crop_definitions()
	
	# Connect to other systems
	connect_to_systems()
	
	print("CropSystem: Ready")

func connect_to_systems():
	# Connect to ToolSystem signals
	if tool_system:
		tool_system.crop_planted.connect(_on_crop_planted)
		tool_system.crop_watered.connect(_on_crop_watered)
	
	# Connect to TimeSystem signals for daily growth
	if time_system:
		time_system.day_changed.connect(_on_new_day)
		time_system.hour_changed.connect(_on_hour_changed)

# === CROP DEFINITIONS ===
func load_crop_definitions():
	# For now, define crops in code - we can move to JSON later
	crop_definitions = {
		"carrot": {
			"id": "carrot",
			"name": "Carrot",
			"size": "regular",
			"tileset_row": 0,
			"growth_days": 3,
			"sell_price": 35,
			"seed_id": "carrot_seeds",
			"season": 0  # 0=Spring, 1=Summer, 2=Fall, 3=Winter, -1=All seasons
		},
		"potato": {
			"id": "potato", 
			"name": "Potato",
			"size": "regular",
			"tileset_row": 1,
			"growth_days": 4,
			"sell_price": 45,
			"seed_id": "potato_seeds",
			"season": 0
		},
		"radish": {
			"id": "radish",
			"name": "Radish", 
			"size": "regular",
			"tileset_row": 2,
			"growth_days": 2,
			"sell_price": 30,
			"seed_id": "radish_seeds",
			"season": 0
		},
		"corn": {
			"id": "corn",
			"name": "Corn",
			"size": "tall",
			"tileset_row": 0,
			"growth_days": 5,
			"sell_price": 120,
			"seed_id": "corn_seeds", 
			"season": 0
		}
	}

# === CROP PLANTING ===
func _on_crop_planted(position: Vector2i, seed_id: String):
	print("DEBUG: Attempting to plant seed: ", seed_id)
	# Convert seed to crop ID
	var crop_id = get_crop_from_seed(seed_id)
	print("DEBUG: Converted to crop_id: ", crop_id)
	if crop_id == "":
		print("Unknown seed: ", seed_id)
		return
	
	# Check if crop can grow in current season
	if not can_grow_in_season(crop_id):
		print("Crop cannot grow in current season")
		return
	
	# Create new crop data
	var crop_data = create_crop(crop_id, position)
	crops[position] = crop_data
	
	crop_planted.emit(position, crop_id)
	print("Planted ", crop_id, " at ", position)

func create_crop(crop_id: String, position: Vector2i) -> Dictionary:
	# Calculate total game hours from your TimeSystem
	var current_time = calculate_total_hours()
	
	return {
		"crop_id": crop_id,
		"position": position,
		"growth_stage": 0,
		"planted_time": current_time,
		"hours_watered": 0.0,
		"is_watered": false,
		"was_watered_today": false,
		"is_harvestable": false
	}

func calculate_total_hours() -> float:
	# Calculate total game hours using your TimeSystem properties
	return ((time_system.year - 1) * 4 * 28 * 24) + \
		   (time_system.season * 28 * 24) + \
		   ((time_system.day - 1) * 24) + \
		   time_system.hour + \
		   (time_system.minute / 60.0)

# === CROP WATERING ===
func _on_crop_watered(position: Vector2i):
	if crops.has(position):
		var crop = crops[position]
		if not crop.is_watered:
			crop.is_watered = true
			crop.was_watered_today = true
			print("Watered crop at ", position)

# === CROP GROWTH ===
func _on_hour_changed(old_hour: int, new_hour: int):
	# Increment watered hours for all watered crops
	for position in crops:
		var crop = crops[position]
		if crop.is_watered:
			crop.hours_watered += 1.0

func _on_new_day(old_day: int, new_day: int):
	# Reset daily watering status
	reset_daily_watering()
	
	# Check all crops for growth
	check_all_crops_growth()

func reset_daily_watering():
	for position in crops:
		var crop = crops[position]
		crop.was_watered_today = false
		crop.is_watered = false

func check_all_crops_growth():
	for position in crops:
		var crop = crops[position]
		check_crop_growth(position, crop)

func check_crop_growth(position: Vector2i, crop: Dictionary):
	var crop_def = crop_definitions.get(crop.crop_id)
	if not crop_def:
		return
	
	# Calculate what stage the crop should be at
	var total_hours_needed = crop_def.growth_days * 24.0
	var hours_per_stage = total_hours_needed / 4.0
	var target_stage = min(4, int(crop.hours_watered / hours_per_stage))
	
	# Only grow if watered
	if not crop.was_watered_today and crop.growth_stage < 4:
		return
	
	# Check if crop should advance to next stage
	if target_stage > crop.growth_stage:
		var old_stage = crop.growth_stage
		crop.growth_stage = target_stage
		
		if target_stage >= 4:
			crop.is_harvestable = true
		
		crop_grown.emit(position, crop.crop_id, target_stage)
		
		var stage_name = get_stage_name(target_stage)
		print(crop_def.name, " grew to stage ", target_stage, " (", stage_name, ")")

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "seeds"
		1: return "sprout"
		2: return "small plant"
		3: return "mature plant"
		4: return "ready to harvest"
		_: return "unknown"

# === CROP HARVESTING ===
func can_harvest_at(position: Vector2i) -> bool:
	if not crops.has(position):
		return false
	
	var crop = crops[position]
	return crop.is_harvestable

func harvest_crop_at(position: Vector2i) -> Dictionary:
	if not can_harvest_at(position):
		return {"success": false, "message": "No harvestable crop"}
	
	var crop = crops[position]
	var crop_def = crop_definitions.get(crop.crop_id)
	
	if not crop_def:
		return {"success": false, "message": "Unknown crop"}
	
	# Calculate harvest yield
	var quantity = 1  # Could add randomness/quality later
	
	# Remove crop
	crops.erase(position)
	
	crop_harvested.emit(position, crop.crop_id, quantity)
	
	return {
		"success": true,
		"item_id": crop.crop_id,
		"quantity": quantity,
		"message": "Harvested " + crop_def.name
	}

# === VALIDATION HELPERS ===
func get_crop_from_seed(seed_id: String) -> String:
	# Find crop that uses this seed
	for crop_id in crop_definitions:
		var crop_def = crop_definitions[crop_id]
		if crop_def.seed_id == seed_id:
			return crop_id
	return ""

func can_grow_in_season(crop_id: String) -> bool:
	var crop_def = crop_definitions.get(crop_id)
	if not crop_def:
		return false
	
	var current_season = time_system.season
	# -1 means all seasons
	return crop_def.season == -1 or crop_def.season == current_season

func has_crop_at(position: Vector2i) -> bool:
	return crops.has(position)

func get_crop_at(position: Vector2i) -> Dictionary:
	return crops.get(position, {})

# === DEBUG FUNCTIONS ===
func instant_grow_crop(position: Vector2i):
	if crops.has(position):
		var crop = crops[position]
		crop.growth_stage = 4
		crop.is_harvestable = true
		crop_grown.emit(position, crop.crop_id, 4)
		print("Instantly grew crop at ", position)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_O: # Debug: grow all crops
				for position in crops:
					instant_grow_crop(position)
				print("Instantly grew all crops")

# === PUBLIC API ===
func get_crop_definition(crop_id: String):
	return crop_definitions.get(crop_id)

func get_all_crops() -> Dictionary:
	return crops.duplicate()
