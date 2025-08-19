extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		# Smooth transition to transparent
		var tween = create_tween()
		tween.tween_property(get_parent(), "modulate:a", 0.3, 0.5)  # 0.5 second fade

func _on_body_exited(body):
	if body.name == "Player":
		# Smooth transition to opaque
		var tween = create_tween()
		tween.tween_property(get_parent(), "modulate:a", 1.0, 0.5)  # 0.5 second fade
