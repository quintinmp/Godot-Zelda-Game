# OutdoorLighting.gd
extends CanvasModulate

func _ready():
	TimeSystem.minute_changed.connect(_on_time_changed)
	TimeSystem.hour_changed.connect(_on_time_changed)
	update_lighting()

func _on_time_changed(_old, _new):
	update_lighting()

func update_lighting():
	var time_color = get_time_color()
	
	# Smooth 2-second transition
	var tween = create_tween()
	tween.tween_property(self, "color", time_color, 2.0)

func get_time_color() -> Color:
	var hour = TimeSystem.hour
	
	# Simple day/night color shifts
	if hour >= 6 and hour < 12:      # Morning
		return Color(1.0, 1.0, 0.9)  # Slight warm tint
	elif hour >= 12 and hour < 17:   # Afternoon  
		return Color(1.0, 1.0, 1.0)  # Normal
	elif hour >= 17 and hour < 20:   # Evening
		return Color(1.0, 0.8, 0.6)  # Orange sunset
	else:                            # Night
		return Color(0.3, 0.3, 0.6)  # Dark blue
