extends CharacterBody2D
@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var sword_sprite: AnimatedSprite2D = $SwordSprite
@onready var attack_area: Area2D = $AttackArea

var speed: float = 250.0

enum Direction {UP, DOWN, LEFT, RIGHT}
var last_direction: Direction = Direction.DOWN

func _ready():
	sword_sprite.visible = false
	attack_area.monitoring = false
	print("player script running")

func _physics_process(_delta: float) -> void:
	var input_vector = Vector2()
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	velocity = input_vector * speed
	move_and_slide()
	
	if input_vector.length() > 0:
		if abs(input_vector.x) > abs(input_vector.y):
			
			if input_vector.x > 0:
				player_sprite.play("walk_side")
				player_sprite.flip_h = false
				last_direction = Direction.RIGHT
			else:
				player_sprite.play("walk_side")
				player_sprite.flip_h = true
				last_direction = Direction.LEFT
		else:
			if input_vector.y > 0:
				player_sprite.play("walk_down")
				last_direction = Direction.DOWN
			else:
				player_sprite.play("walk_up")		
				last_direction = Direction.UP
	else:
		match last_direction:
			Direction.UP:
				player_sprite.play("idle_up")
			Direction.DOWN:
				player_sprite.play("idle_down")
			Direction.LEFT:
				player_sprite.play("idle_side")
				player_sprite.flip_h = true
			Direction.RIGHT:
				player_sprite.play("idle_side")
				player_sprite.flip_h = false
	
	if Input.is_action_just_pressed("attack") and input_vector.length() == 0:
		attack()
	
				
func attack():
	match last_direction:
		Direction.DOWN:
			sword_sprite.visible = true
			player_sprite.play("attack_down")
			sword_sprite.play("sword_swing_down")		

			attack_area.position = Vector2(0, 20)
			attack_area.rotation = 0
			attack_area.monitoring = true
			
			await sword_sprite.animation_finished
			sword_sprite.visible = false
			attack_area.monitoring = false
