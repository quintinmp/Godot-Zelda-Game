# CropRenderer.gd - Handles visual rendering of crops on tiles
extends Node2D

# Crop textures
var crops_regular_texture: Texture2D
var crops_tall_texture: Texture2D

# References
var crop_system
var main_tilemap: TileMapLayer

# Constants
const TILE_SIZE = 64
const SPRITE_SCALE = 4.0
const SOURCE_TILE_SIZE = 16

func _ready():
	crop_system = get_node("/root/CropSystem")
	
	# Load crop textures
	load_crop_textures()
	
	# Connect to crop system signals
	if crop_system:
		crop_system.crop_planted.connect(_on_crop_planted)
		crop_system.crop_grown.connect(_on_crop_grown)
		crop_system.crop_harvested.connect(_on_crop_harvested)
	
	print("CropRenderer: Ready")

func load_crop_textures():
	# Try to load crop textures
	if ResourceLoader.exists("res://Assets/Textures/Crops/crops_regular.png"):
		crops_regular_texture = load("res://Assets/Textures/Crops/crops_regular.png")
		print("Loaded regular crops texture")
	else:
		print("Warning: crops_regular.png not found")
	
	if ResourceLoader.exists("res://Assets/Textures/Crops/crops_tall.png"):
		crops_tall_texture = load("res://Assets/Textures/Crops/crops_tall.png")
		print("Loaded tall crops texture")
	else:
		print("Warning: crops_tall.png not found")

func set_main_tilemap(tilemap: TileMapLayer):
	main_tilemap = tilemap
	print("CropRenderer: Connected to tilemap")

func _draw():
	if not crop_system or not main_tilemap:
		return
	
	# Render all crops
	var all_crops = crop_system.get_all_crops()
	for position in all_crops:
		var crop = all_crops[position]
		draw_crop(crop, position)

func draw_crop(crop: Dictionary, position: Vector2i):
	var crop_def = crop_system.get_crop_definition(crop.crop_id)
	if not crop_def:
		return
	
	# Choose appropriate texture based on crop size
	var texture: Texture2D
	var source_height = SOURCE_TILE_SIZE
	
	if crop_def.size == "tall":
		texture = crops_tall_texture
		source_height = SOURCE_TILE_SIZE * 2
	else:
		texture = crops_regular_texture
	
	if not texture:
		# Fallback: draw colored square
		draw_crop_fallback(position, crop)
		return
	
	# Calculate source rectangle for current growth stage
	var source_rect = Rect2(
		crop.growth_stage * SOURCE_TILE_SIZE,
		crop_def.tileset_row * source_height,
		SOURCE_TILE_SIZE,
		source_height
	)
	
	# Convert tile position to world position, then to local
	var world_pos = main_tilemap.to_global(main_tilemap.map_to_local(position))
	var local_pos = to_local(world_pos)
	
	# For tall crops, anchor bottom to tile
	if crop_def.size == "tall":
		local_pos.y -= (source_height * SPRITE_SCALE) - TILE_SIZE
	
	# Calculate destination rectangle
	var dest_rect = Rect2(
		local_pos,
		Vector2(SOURCE_TILE_SIZE * SPRITE_SCALE, source_height * SPRITE_SCALE)
	)
	
	# Get tint color based on crop state
	var tint_color = get_crop_tint_color(crop)
	
	# Draw the crop sprite
	draw_texture_rect_region(texture, dest_rect, source_rect, tint_color)

func draw_crop_fallback(position: Vector2i, crop: Dictionary):
	# Get the world position of the tile from the tilemap
	var world_pos = main_tilemap.to_global(main_tilemap.map_to_local(position))
	
	# Since we're drawing in world coordinates, convert to our local space
	var local_pos = to_local(world_pos)
	
	# Choose color based on growth stage
	var colors = [
		Color.BROWN,      # Stage 0: seeds
		Color.LIGHT_GREEN, # Stage 1: sprout  
		Color.GREEN,       # Stage 2: small plant
		Color.DARK_GREEN,  # Stage 3: mature plant
		Color.YELLOW       # Stage 4: harvestable
	]
	
	var color = colors[min(crop.growth_stage, 4)]
	# Match your game's 4x scaling, centered on tile
	var size = Vector2(48, 48)  # Slightly smaller than full tile
	var rect = Rect2(local_pos - size/2, size)
	
	draw_rect(rect, color)
	
	# Draw growth stage number centered
	var font = ThemeDB.fallback_font
	var text_pos = local_pos - Vector2(8, -8)  # Offset for centering
	draw_string(font, text_pos, str(crop.growth_stage), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func get_crop_tint_color(crop: Dictionary) -> Color:
	# Visual feedback based on crop state
	if crop.growth_stage >= 4:
		return Color.WHITE  # Harvestable - normal color
	
	if not crop.was_watered_today and crop.growth_stage > 0:
		return Color(1.0, 1.0, 0.8)  # Needs water - slight yellow tint
	
	if crop.is_watered:
		return Color(0.9, 0.9, 1.0)  # Watered - slight blue tint
	
	return Color.WHITE  # Normal

# === SIGNAL HANDLERS ===
func _on_crop_planted(position: Vector2i, crop_id: String):
	queue_redraw()

func _on_crop_grown(position: Vector2i, crop_id: String, new_stage: int):
	queue_redraw()

func _on_crop_harvested(position: Vector2i, crop_id: String, quantity: int):
	queue_redraw()

# Force redraw when crops change
func _process(_delta):
	if crop_system and crop_system.get_all_crops().size() > 0:
		queue_redraw()
