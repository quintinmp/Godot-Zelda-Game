extends CharacterBody2D

@onready var character_sprite: AnimatedSprite2D = $CharacterSprite
@onready var attack_area: Area2D = $AttackArea
@onready var swing_sound: AudioStreamPlayer = $SwingSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
var hit_effect_scene = preload("res://Scenes/Effects/HitEffect.tscn")

enum Direction {DOWN_LEFT, DOWN_RIGHT, UP_LEFT, UP_RIGHT}
var speed: float = 1250.0
var last_direction: Direction = Direction.DOWN_LEFT
var health = 100
var is_attacking = false
var i_frame_timer: float = 1.5
var original_attack_position = Vector2(-14.0, 52.0)

# Animation name mappings
var walk_anims = {
	Direction.DOWN_LEFT: "walk_down_left",
	Direction.DOWN_RIGHT: "walk_down_right", 
	Direction.UP_LEFT: "walk_up_left",
	Direction.UP_RIGHT: "walk_up_right"
}

var idle_anims = {
	Direction.DOWN_LEFT: "idle_down_left",
	Direction.DOWN_RIGHT: "idle_down_right",
	Direction.UP_LEFT: "idle_up_left", 
	Direction.UP_RIGHT: "idle_up_right"
}

var attack_anims = {
	Direction.DOWN_LEFT: "attack_down_left",
	Direction.DOWN_RIGHT: "attack_down_right",
	Direction.UP_LEFT: "attack_up_left",
	Direction.UP_RIGHT: "attack_up_right"
}

func _ready():
	add_to_group("player")
	# Connect to animation finished signal
	character_sprite.animation_finished.connect(_on_attack_finished)

func _physics_process(_delta: float) -> void:
	# Don't move during attacks
	if is_attacking:
		return
		
	var input_vector = Vector2()
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	# Handle movement with diagonal normalization
	velocity = input_vector * speed
	if input_vector.length() > 1:
		velocity = velocity.normalized() * speed
	move_and_slide()
	
	# Update direction and animations
	if input_vector.length() > 0:
		update_direction(input_vector)
		character_sprite.play(walk_anims[last_direction])
	else:
		character_sprite.play(idle_anims[last_direction])
	
	# Handle attack input
	if Input.is_action_just_pressed("attack"):
		attack()
	
	i_frame_timer = max(0, i_frame_timer - _delta)

func update_direction(input_vector: Vector2):
	var is_up = input_vector.y < 0
	var is_right = true
	
	if abs(input_vector.x) > 0.1:
		is_right = input_vector.x > 0
	else:
		is_right = (last_direction == Direction.DOWN_RIGHT or last_direction == Direction.UP_RIGHT)
	
	if is_up:
		last_direction = Direction.UP_RIGHT if is_right else Direction.UP_LEFT
	else:
		last_direction = Direction.DOWN_RIGHT if is_right else Direction.DOWN_LEFT

func attack():
	if is_attacking:
		return
		
	is_attacking = true
	position_attack_hitbox()
	character_sprite.play(attack_anims[last_direction])
	
	swing_sound.pitch_scale = randf_range(0.9, 1.1)  # Slight pitch variation
	swing_sound.play()
	
	# Add lunge in attack direction
	add_attack_lunge()
	
	# Start attack detection without awaits
	start_attack_detection()

func add_attack_lunge():
	var lunge_distance = 50.0
	var lunge_direction = Vector2.ZERO
	
	# Get the last input direction for more precise lunge
	var input_vector = Vector2()
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	# If player is actively moving, lunge in that direction
	if input_vector.length() > 0.1:
		lunge_direction = input_vector.normalized()
	else:
		# Fallback to attack direction if not moving
		match last_direction:
			Direction.DOWN_RIGHT:
				lunge_direction = Vector2(1, 0)  # Pure right
			Direction.DOWN_LEFT:
				lunge_direction = Vector2(-1, 0)  # Pure left
			Direction.UP_RIGHT:
				lunge_direction = Vector2(1, 0)   # Pure right
			Direction.UP_LEFT:
				lunge_direction = Vector2(-1, 0)  # Pure left
	
	# Apply lunge
	var lunge_tween = create_tween()
	var target_position = global_position + (lunge_direction * lunge_distance)
	lunge_tween.tween_property(self, "global_position", target_position, 0.1)

func start_attack_detection():
	# Enable monitoring immediately
	attack_area.monitoring = true
	print("Attack detection started")
	
	# Create a timer for attack duration instead of using await
	var attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 0.2
	attack_timer.one_shot = true
	attack_timer.timeout.connect(end_attack_detection)
	attack_timer.start()
	
	# Also connect to area detection signals
	if not attack_area.area_entered.is_connected(_on_attack_hit):
		attack_area.area_entered.connect(_on_attack_hit)

func position_attack_hitbox():
	match last_direction:
		Direction.DOWN_RIGHT:
			# Use the original position you set in the viewport
			attack_area.position = original_attack_position
		Direction.DOWN_LEFT:
			# Mirror horizontally from the original position
			attack_area.position = Vector2(original_attack_position.x - 87, original_attack_position.y)
		Direction.UP_RIGHT:
			# Adjust for up swing
			attack_area.position = Vector2(original_attack_position.x, original_attack_position.y - 50)
		Direction.UP_LEFT:
			# Up-left combination
			attack_area.position = Vector2(-original_attack_position.x - 87, original_attack_position.y - 50)

func activate_attack_hitbox():
	print("=== BEFORE MONITORING ===")
	print("AttackArea monitoring: ", attack_area.monitoring)
	print("AttackArea layer: ", attack_area.collision_layer)
	print("AttackArea mask: ", attack_area.collision_mask)
	
	attack_area.monitoring = true
	
	print("=== AFTER ENABLING MONITORING ===")
	print("AttackArea monitoring: ", attack_area.monitoring)
	
	# Wait a frame for collision detection to update
	await get_tree().process_frame
	
	print("=== COLLISION CHECK ===")
	var overlapping = attack_area.get_overlapping_bodies()
	var overlapping_areas = attack_area.get_overlapping_areas()
	
	print("Overlapping bodies: ", overlapping.size())
	print("Overlapping areas: ", overlapping_areas.size())
	
	for area in overlapping_areas:
		print("  Area: ", area.name)
		var parent = area.get_parent()
		if parent and parent.has_method("take_damage"):
			print("    Dealing damage to: ", parent.name)
			parent.take_damage(25, self)

func deactivate_attack_hitbox():
	attack_area.monitoring = false

func _on_attack_finished():
	# Only reset if we just finished an attack animation
	if character_sprite.animation.begins_with("attack"):
		is_attacking = false

func _on_attack_hit(area):
	print("HIT DETECTED: ", area.name)
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and parent != self:
		print("Dealing damage to: ", parent.name)
		parent.take_damage(25, self)
		
				# Play hit sound
		hit_sound.pitch_scale = randf_range(0.8, 1.2)
		hit_sound.play()
		
		# Add hit effect at the hit location
		spawn_hit_effect(parent.global_position)

func spawn_hit_effect(position: Vector2):
	if hit_effect_scene:
		var effect = hit_effect_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = position
		
		# Start the particle effect
		var particles = effect.get_node("HitParticles")
		if particles:
			particles.emitting = true

func end_attack_detection():
	attack_area.monitoring = false
	print("Attack detection ended")

func take_damage(damage: int, attacker):
	if i_frame_timer <= 0:
		health -= damage
		i_frame_timer = 1.5
		
		# Add player knockback
		var knockback_force = 100
		var knockback_direction = (global_position - attacker.global_position).normalized()
		
		var tween = create_tween()
		var target_pos = global_position + (knockback_direction * knockback_force)
		tween.tween_property(self, "global_position", target_pos, 0.2)
		
		start_i_frame_flash()

func start_i_frame_flash():
	var flash_tween = create_tween()
	flash_tween.set_loops(8)  
	flash_tween.tween_method(flash_red, 0.0, 1.0, 0.1)
	flash_tween.tween_method(flash_red, 1.0, 0.0, 0.1)

func flash_red(amount: float):
	var flash_color = Color(1.0, 1.0 - amount, 1.0 - amount)
	character_sprite.modulate = flash_color
