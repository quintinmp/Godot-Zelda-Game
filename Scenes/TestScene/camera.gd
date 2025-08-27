# Main scene script
extends Node2D

func _ready():
	var tilemap = $WorldContainer/SpiritTown/WallsAndObjects
	
	# Connect ToolSystem to tilemap
	ToolSystem.set_main_tilemap(tilemap)
	
	# Add crop renderer to main scene
	var crop_renderer = preload("res://CropRenderer.gd").new()
	add_child(crop_renderer)
	crop_renderer.set_main_tilemap(tilemap)
	
	# Match the transform of your world container
	crop_renderer.position = $WorldContainer.position
	crop_renderer.scale = $WorldContainer.scale

func add_screen_shake(intensity = 5.0):
	var camera = get_viewport().get_camera_2d()
	
	var shake_tween = create_tween()
	for i in range(6):  # Shake 6 times
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(camera, "offset", random_offset, 0.05)
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)
