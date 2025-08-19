extends Control

@onready var time_label: Label = $TimeLabel


func _ready():
	TimeSystem.minute_changed.connect(_on_time_changed)
	TimeSystem.hour_changed.connect(_on_time_changed)
	TimeSystem.day_changed.connect(_on_time_changed)
	TimeSystem.year_changed.connect(_on_time_changed)
	update_display()
	
func _on_time_changed(_old, _new):
	update_display()
	
func update_display():
	var time_text = TimeSystem.get_time_string()
	var date_text = TimeSystem.get_date_string()
	time_label.text = "%s\n%s" % [time_text, date_text]
