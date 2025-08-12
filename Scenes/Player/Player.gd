extends CharacterBody2D

@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var head_sprite: AnimatedSprite2D = $HeadSprite
@onready var weapon_sprite: Sprite2D = $WeaponSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

enum Direction {DOWN_LEFT, DOWN_RIGHT, UP_LEFT, UP_RIGHT}
var speed: float = 250.0
var last_direction: Direction = Direction.DOWN_LEFT
var health = 100
var is_attacking = false
var i_frame_timer: float = 1.5

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

func _ready():
	add_to_group("player")
	weapon_sprite.visible = false
	animation_player.animation_finished.connect(_on_animation_finished)
	# Connect to see what happens during animation
	animation_player.animation_changed.connect(_on_animation_changed)
	
	
func _on_animation_changed():
	print("Animation changed to: ", animation_player.current_animation)

func _physics_process(_delta: float) -> void:
	if is_attacking:
		return
		
	var input_vector = Vector2()
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	velocity = input_vector * speed
	if input_vector.length() > 1:
		velocity = velocity.normalized() * speed
	move_and_slide()
	
	if input_vector.length() > 0:
		update_direction(input_vector)
		body_sprite.play(walk_anims[last_direction])
		head_sprite.play(walk_anims[last_direction])
	else:
		body_sprite.play(idle_anims[last_direction])
		head_sprite.play(idle_anims[last_direction])
	
	if Input.is_action_just_pressed("attack"):
		swing_weapon()
	
	i_frame_timer = max(0, i_frame_timer - _delta)

func update_direction(input_vector: Vector2):
	var is_up = input_vector.y < 0
	var is_right = true
	
	if abs(input_vector.x) > 0.1:
		is_right = input_vector.x > 0
	else:
		is_right = (last_direction == Direction.DOWN_RIGHT or last_direction == Direction.UP_RIGHT)
	
	var new_direction
	if is_up:
		new_direction = Direction.UP_RIGHT if is_right else Direction.UP_LEFT
	else:
		new_direction = Direction.DOWN_RIGHT if is_right else Direction.DOWN_LEFT
		
	last_direction = new_direction

func swing_weapon():
	if is_attacking:
		return
		
	is_attacking = true
	weapon_sprite.visible = true
	body_sprite.stop()
	head_sprite.stop()
	
	print("=== SWING DEBUG ===")
	print("Direction: ", last_direction)
	print("BEFORE setting flip - Body: ", body_sprite.flip_h, " Head: ", head_sprite.flip_h)
	
	# Set flip states based on direction
	match last_direction:
		Direction.DOWN_RIGHT:
			animation_player.play("right_axe_swing")
			print("Set RIGHT - Body: false, Head: false")
		Direction.DOWN_LEFT:
			animation_player.play("left_axe_swing")
			print("Set LEFT - Body: true, Head: true")
	
	print("AFTER setting flip - Body: ", body_sprite.flip_h, " Head: ", head_sprite.flip_h)
	print("=== END SWING DEBUG ===")

func _on_animation_finished(anim_name: String):
	var attack_animations = ["right_axe_swing", "left_axe_swing"]
	if anim_name in attack_animations:
		is_attacking = false
		weapon_sprite.visible = false

func take_damage(damage: int, attacker):
	if i_frame_timer <= 0:
		health -= damage
		i_frame_timer = 1.5
		print("player health: ", health)
		
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
	body_sprite.modulate = flash_color
	head_sprite.modulate = flash_color
