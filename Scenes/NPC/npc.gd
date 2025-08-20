# NPC.gd
extends CharacterBody2D

@onready var npc_sprite: AnimatedSprite2D = $NPCSprite
@onready var npc_area: Area2D = $NPCArea
@onready var dialogue_label = get_node("/root/MainScene/UILayer/DialogueLabel")


var speed = 100.0
var target_position: Vector2
var is_moving = false
var player_nearby = false

# Simple 4-point schedule: hour -> world position
var schedule = {
	6: Vector2(-2918, -1272),   # 6 AM: Morning spot
	12: Vector2(-1970, -3095),  # 12 PM: Noon spot  
	18: Vector2(-3226, -4313),  # 6 PM: Evening spot
	22: Vector2(-3753, 170)   # 10 PM: Night spot
}

func _ready():
	npc_sprite.play("idle")
	
	# npc interaction
	npc_area.body_entered.connect(_on_player_entered)
	npc_area.body_exited.connect(_on_player_exited)
	
	#TimeSystem.hour_changed.connect(_on_time_changed)
	#update_schedule()

func _on_player_entered(body):
	print("player entered npc area")
	player_nearby = true
	
func _on_player_exited(body):
	print("player exited npc area")
	player_nearby = false
	
func start_interaction():
	dialogue_label.text = "GHOSTY: Hello, traveler! Welcome to Spirit Town."
	dialogue_label.visible = true
	await get_tree().create_timer(3.0).timeout
	dialogue_label.visible = false

func _input(event):
	if Input.is_action_just_pressed("interact") && player_nearby:
		start_interaction()

#func _on_time_changed(_old, _new):
	#update_schedule()

#func update_schedule():
	#var target_pos = get_schedule_position()
	## Only move if we're far from target
	#if global_position.distance_to(target_pos) > 20:
		#target_position = target_pos
		#is_moving = true

#func get_schedule_position() -> Vector2:
	#var hour = TimeSystem.hour
	#
	## Find the correct schedule time for current hour
	#var schedule_times = schedule.keys()
	#schedule_times.sort()
	#
	#var current_schedule_time = 6  # Default to morning
	#for time in schedule_times:
		#if hour >= time:
			#current_schedule_time = time
	#
	#return schedule[current_schedule_time]

func _physics_process(delta):
	if is_moving:
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		# Stop when close enough
		if global_position.distance_to(target_position) < 15:
			is_moving = false
			velocity = Vector2.ZERO
