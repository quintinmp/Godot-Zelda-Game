extends Node

var current_area: String = ""
var game_paused: bool = false

func _ready():
	print("GameManager initialized")

func change_area(area_name: String):
	current_area = area_name
	# Scene transition logic later
