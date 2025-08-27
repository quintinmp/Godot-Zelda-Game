# Main scene script
extends Node2D

func _ready():
	var tilemap = $WorldContainer/SpiritTown/WallsAndObjects
	print("Tilemap found: ", tilemap != null)
	if tilemap:
		print("Tilemap name: ", tilemap.name)
	ToolSystem.set_main_tilemap(tilemap)

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
