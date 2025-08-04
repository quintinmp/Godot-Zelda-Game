extends CharacterBody2D

@onready var slime_sprite: AnimatedSprite2D = $SlimeSprite
@onready var hit_box: Area2D = $HitBox

var health: int = 3
var max_health: int = 3

func _ready():
	# Connect the hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	
	# Play idle animation
	slime_sprite.play("idle")  # Assuming you have an idle animation
	slime_sprite.scale = Vector2(4, 4)  # Scale to match your player
	
	print("Slime spawned with health: ", health)

func _on_hit_box_area_entered(area: Area2D):
	# Check if it's the player's attack
	if area.name == "AttackArea":
		take_damage(1)

func take_damage(damage: int):
	health -= damage
	print("Slime took ", damage, " damage! Health: ", health)
	
	# Flash red or play hurt animation here if you want
	
	if health <= 0:
		die()

func die():
	print("Slime died!")
	# You could play a death animation here
	queue_free()  # Remove the slime from the scene
