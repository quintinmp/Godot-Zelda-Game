extends CharacterBody2D

@onready var slime_sprite: AnimatedSprite2D = $SlimeSprite
@onready var hit_box: Area2D = $HitBox
@onready var death_sound: AudioStreamPlayer = $DeathSound

var health: int = 3
var max_health: int = 3

func _ready():
	# Play idle animation
	slime_sprite.play("idle")  # Assuming you have an idle animation
	slime_sprite.scale = Vector2(4, 4)  # Scale to match your player

func take_damage(damage: int):
	health -= damage
	
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
	
	
