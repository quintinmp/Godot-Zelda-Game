extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		# Make the foreground walls transparent
		get_parent().modulate.a = 0.3

func _on_body_exited(body):
	if body.name == "Player":
		# Make the foreground walls opaque
		get_parent().modulate.a = 1.0
