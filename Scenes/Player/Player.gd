extends CharacterBody2D

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var attack_area: Area2D = $AttackArea
@onready var swing_sound: AudioStreamPlayer = $SwingSound
@onready var hit_sound: AudioStreamPlayer = $HitSound

enum Direction {UP, DOWN, LEFT, RIGHT}
var speed: float = 250.0
var last_direction: Direction = Direction.DOWN
var is_attacking = false
var enemies_hit_this_attack = [] 

# Animation name mappings
var walk_anims = {
	Direction.UP: "walk_up",
	Direction.DOWN: "walk_down", 
	Direction.LEFT: "walk_left",
	Direction.RIGHT: "walk_right"
}

var idle_anims = {
	Direction.UP: "idle_up",
	Direction.DOWN: "idle_down",
	Direction.LEFT: "idle_left", 
	Direction.RIGHT: "idle_right"
}

var attack_anims = {
	Direction.UP: "attack_up",
	Direction.DOWN: "attack_down",
	Direction.LEFT: "attack_left",
	Direction.RIGHT: "attack_right"
}

# Attack area configurations
var attack_configs = {
	Direction.DOWN: {"position": Vector2(-14, 52), "rotation": 0},
	Direction.UP: {"position": Vector2(14, -10), "rotation": PI},
	Direction.LEFT: {"position": Vector2(-15, 20), "rotation": PI/2},
	Direction.RIGHT: {"position": Vector2(15, 20), "rotation": -PI/2}
}

func _ready():
	add_to_group("player")
	attack_area.monitoring = false
	attack_area.area_entered.connect(_on_attack_area_entered) 
	player_sprite.animation_finished.connect(_on_attack_finished)

func _physics_process(_delta: float) -> void:
	var input_vector = Vector2()
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	# Always handle movement (even during attacks)
	velocity = input_vector * speed
	if is_attacking:
		velocity *= 0.7
	move_and_slide()
	
	# Update direction and animations
	if input_vector.length() > 0:
		update_direction(input_vector)
		if not is_attacking:
			player_sprite.play(walk_anims[last_direction])
	elif not is_attacking:
		player_sprite.play(idle_anims[last_direction])
	
	if Input.is_action_just_pressed("attack"):
		attack()  # Remove the "and input_vector.length() == 0" condition

func update_direction(input_vector: Vector2):
	if abs(input_vector.x) > abs(input_vector.y):
		last_direction = Direction.RIGHT if input_vector.x > 0 else Direction.LEFT
	else:
		last_direction = Direction.DOWN if input_vector.y > 0 else Direction.UP

func attack():
	swing_sound.pitch_scale = randf_range(0.8, 1.2)
	swing_sound.play()
	enemies_hit_this_attack.clear()
	is_attacking = true
	player_sprite.play(attack_anims[last_direction])
	
	# Add forward momentum based on direction
	var lunge_distance = 15
	var lunge_vector = Vector2.ZERO
	
	match last_direction:
		Direction.DOWN:
			lunge_vector = Vector2(0, lunge_distance)
		Direction.UP:
			lunge_vector = Vector2(0, -lunge_distance)
		Direction.LEFT:
			lunge_vector = Vector2(-lunge_distance, 0)
		Direction.RIGHT:
			lunge_vector = Vector2(lunge_distance, 0)
	
	# Apply the lunge movement
	var tween = create_tween()
	var target_position = global_position + lunge_vector
	tween.tween_property(self, "global_position", target_position, 0.2)
	
	# Set up attack area
	var config = attack_configs[last_direction]
	attack_area.position = config.position
	attack_area.rotation = config.rotation
	attack_area.monitoring = true
	
# In player's _on_attack_area_entered:
func _on_attack_area_entered(area: Area2D):
	if area.name == "HitBox":
		var slime = area.get_parent()
		
		if not is_instance_valid(slime) or slime.is_queued_for_deletion():
			return
		
		if slime in enemies_hit_this_attack:
			return
		
		enemies_hit_this_attack.append(slime)
		
		var hit_effect = preload("res://Scenes/Effects/HitEffect.tscn").instantiate()
		get_tree().current_scene.add_child(hit_effect)
		hit_effect.global_position = slime.global_position
		hit_effect.get_child(0).restart()
		
		hit_sound.pitch_scale = randf_range(0.9, 1.1)
		hit_sound.play()
		await get_tree().create_timer(0.1).timeout
		# Now do the hit stop
		Engine.time_scale = 0.1
		await get_tree().create_timer(0.01).timeout
		Engine.time_scale = 1.0
		
		if is_instance_valid(slime) and not slime.is_queued_for_deletion():
			slime.take_damage(1)

func _on_attack_finished():
	if is_attacking:
		attack_area.monitoring = false
		is_attacking = false
