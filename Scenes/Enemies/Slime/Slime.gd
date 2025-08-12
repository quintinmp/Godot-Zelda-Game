extends CharacterBody2D

@onready var slime_sprite: AnimatedSprite2D = $SlimeSprite
@onready var hit_box: Area2D = $HitBox
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var shadow_sprite: Sprite2D = $ShadowSprite

var health: int = 3
var max_health: int = 3
var slime_speed: float = 100.0 
var player
var detection_range: float = 300.0
var lose_target_range: float = 500.0
var attack_range: float = 150.0
var is_chasing: bool = false
var patrol_center: Vector2
var patrol_radius: float = 150.0
var patrol_speed: float = 50.0
var patrol_target: Vector2
var patrol_timer: float = 0.0
var patrol_wait_time: float = 2.0
var avoid_distance: float = 60.0
var jump_timer: float = 0.0
var jump_cooldown: float = 5.0
var is_jumping: bool = false
var jump_target: Vector2
var jump_height: float = 150.0
var jump_duration: float = 0.8
var jump_start_pos: Vector2
var normal_shadow_scale: Vector2 = Vector2(1, 1)


func _ready():
	player = get_tree().get_first_node_in_group("player")
	slime_sprite.play("idle") 
	slime_sprite.scale = Vector2(4, 4)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	patrol_center = global_position
	set_new_patrol_target()
	add_to_group("slimes")
	slime_sprite.animation_finished.connect(_on_animation_finished)
	if shadow_sprite:
		normal_shadow_scale = shadow_sprite.scale
	else:
		print("ERROR: shadow_sprite is null!")
	# slime_sprite.visible = false

func set_new_patrol_target():
	# Pick random point within patrol radius
	var angle = randf() * 2 * PI
	var distance = randf() * patrol_radius
	patrol_target = patrol_center + Vector2(cos(angle), sin(angle)) * distance
	patrol_timer = 0.0

func _on_hit_box_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(1, self)
		
		# Add slime knockback too
		var knockback_force = 100
		var knockback_direction = (global_position - body.global_position).normalized()
		var tween = create_tween()
		var target_pos = global_position + (knockback_direction * knockback_force)
		tween.tween_property(self, "global_position", target_pos, 0.2)
		

func _physics_process(delta: float) -> void:
	if player:	
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if is_chasing and not is_jumping:
			jump_timer += delta
			if jump_timer >= jump_cooldown and distance_to_player <= attack_range:
				start_jump()
		
		if not is_jumping:
			if not is_chasing and distance_to_player <= detection_range:
				is_chasing = true
			elif is_chasing and distance_to_player >= lose_target_range:
				is_chasing = false
			
			var base_velocity = Vector2.ZERO
			
			if is_chasing:
				var direction_to_player = (player.global_position - global_position).normalized()
				var current_speed = slime_speed
				if distance_to_player <= attack_range:
					current_speed = slime_speed * 1.8
				base_velocity = direction_to_player * current_speed
			else:
				 # Patrol behavior
				var distance_to_patrol_target = global_position.distance_to(patrol_target)
				
				if distance_to_patrol_target > 20:  # Move toward patrol target
					var direction_to_patrol = (patrol_target - global_position).normalized()
					base_velocity = direction_to_patrol * patrol_speed
				else:  # Reached patrol point, wait then pick new target
					velocity = Vector2.ZERO
					patrol_timer += delta
					if patrol_timer >= patrol_wait_time:
						set_new_patrol_target()
			
			var avoidance = get_avoidance_force()
			velocity = base_velocity + avoidance * 0.9	
				
			move_and_slide()

				# Handle wall collisions
			if get_slide_collision_count() > 0:
				# If we hit a wall while patrolling, pick a new patrol target
				if not is_chasing:
					set_new_patrol_target()
				# If chasing and hit wall, try to move around it
				else:
					var collision = get_slide_collision(0)
					var wall_normal = collision.get_normal()
					# Deflect movement along the wall
					velocity = velocity.slide(wall_normal)

			if velocity.length() > 0:
				slime_sprite.play("walk")
				if velocity.x > 0:
					slime_sprite.flip_h = false
				elif velocity.x < 0:
					slime_sprite.flip_h = true
			else:
				slime_sprite.play("idle")
	if not is_jumping:
		shadow_sprite.scale = normal_shadow_scale
		shadow_sprite.position = Vector2.ZERO


func take_damage(damage: int):
	health -= damage
	
	# Flash white then back to normal
	slime_sprite.self_modulate = Color(100, 100, 100, 1)  # Very bright white
	var flash_tween = create_tween()
	flash_tween.tween_property(slime_sprite, "self_modulate", Color(1, 1, 1, 1), 0.4)
	
	# Knockback effect
	var knockback_force = 100
	var player = get_tree().get_first_node_in_group("player")
	var knockback_direction = (global_position - player.global_position).normalized()
	
	var tween = create_tween()
	var target_pos = global_position + (knockback_direction * knockback_force)
	tween.tween_property(self, "global_position", target_pos, 0.2)
	
	# Trigger screen shake
	get_tree().current_scene.add_screen_shake(1.0)
	
	if health <= 0:
		die()


func die():
	death_sound.pitch_scale = randf_range(0.8, 1.2)
	death_sound.play()
	await death_sound.finished
	queue_free()	


func get_avoidance_force() -> Vector2:
	var avoidance = Vector2.ZERO
	var nearby_slimes = get_tree().get_nodes_in_group("slimes")
	
	for slime in nearby_slimes:
		if slime != self:
			var distance = global_position.distance_to(slime.global_position)
			if distance < avoid_distance:
				var direction_away = (global_position - slime.global_position).normalized()
				avoidance += direction_away * (avoid_distance - distance)
	
	return avoidance


func start_jump():
	is_jumping = true
	jump_timer = 0.0
	jump_target = player.global_position
	var direction_to_player = (player.global_position - global_position).normalized()
	var jump_distance = 250.0
	jump_target = global_position + (direction_to_player * jump_distance)
	slime_sprite.play("jump_start")


func _on_animation_finished():
	if is_jumping:
		if slime_sprite.animation == "jump_start":
			slime_sprite.play("jump_air")
			start_jump_arc()
		elif slime_sprite.animation == "jump_land":
			is_jumping = false
			jump_timer = 0.0


func start_jump_arc():
	hit_box.monitoring = false
	jump_start_pos = global_position
	var jump_tween = create_tween()
	jump_tween.tween_method(update_jump_position, 0.0, 1.0, jump_duration)


func update_jump_position(progress: float):
	var arc_progress = 4 * progress * (1 - progress)
	# Interpolate horizontal position
	var current_pos = Vector2()
	current_pos.x = lerp(jump_start_pos.x, jump_target.x, progress)
	current_pos.y = lerp(jump_start_pos.y, jump_target.y, progress)
	
	# shadow on ground during jump
	var ground_position = current_pos
	
	# Add vertical arc offset
	current_pos.y -= arc_progress * jump_height  # Up is negative
	
	global_position = current_pos
	slime_sprite.position.y = 0

	# shadow during jump
	var height_ratio = arc_progress
	var shadow_scale = normal_shadow_scale * (1.0 - height_ratio * 0.7)
	shadow_sprite.scale = shadow_scale
	
	shadow_sprite.position.y = arc_progress * jump_height
	shadow_sprite.position.x = height_ratio * 10
	
	if progress > 0.85 and slime_sprite.animation == "jump_air":
		land_jump()


func land_jump():
	hit_box.monitoring = true
	slime_sprite.play("jump_land")
