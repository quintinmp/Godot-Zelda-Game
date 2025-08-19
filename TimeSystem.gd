extends Node


signal hour_changed(old_hour, new_hour)
signal minute_changed(old_minute, new_minute)
signal day_changed(old_day, new_day)
signal year_changed(old_year, new_year)
signal season_changed(old_season, new_season)

# === TIME DATE ===
var day: int = 1
var hour: int = 6 # start at 6am
var minute: int = 0
var season: int = 0 # 0=spring, 1=summer, 2=fall, 3=winter 
var year: int = 1

var game_speed: float = 1.0 #time multiplier
var is_paused: bool = false

# === CONSTANTS ===
const MINUTES_PER_HOUR = 60
const HOURS_PER_DAY = 24
const DAYS_PER_SEASON = 28
const SEASONS_PER_YEAR = 4

func _ready():
	print("TimeSystem autload is ready!")
	
func test_time_system():
	print("TimeSystem is working!")
	print(get_time_string())
	
# === TIME PROGRESSION ===
const DEFAULT_TIME_MULTIPLIER = 7.0
const TIME_STEP_MINUTES = 1
var accumulated_minutes: float = 0.0

func _process(delta):
	if not is_paused:
		advance_time(delta)
	
func advance_time(delta_seconds: float):
	if is_paused:
		return
	# calculate game time to advance
	var game_minutes_to_add = delta_seconds * game_speed * DEFAULT_TIME_MULTIPLIER
	# accumulate fractional minutes
	accumulated_minutes += game_minutes_to_add
	# only advance when we have enough time
	var minute_steps = int(accumulated_minutes / TIME_STEP_MINUTES)
	
	if minute_steps == 0:
		return
	
	# calculate acutal time and subtract from accumulated
	var total_minutes_to_add = minute_steps * TIME_STEP_MINUTES
	accumulated_minutes -= total_minutes_to_add
	
	# advance the time
	advance_time_by_minutes(total_minutes_to_add)
	
func advance_time_by_minutes(minutes_to_add: int):
	# store old values for signals
	var old_minute = minute
	var old_hour = hour
	var old_day = day
	var old_season = season
	var old_year = year
		
	var new_minute = minute + minutes_to_add
	var new_hour = hour
	var new_day = day
	var new_season = season
	var new_year = year
	
	# handle minute overflow
	if new_minute >= MINUTES_PER_HOUR:
		var hours_to_add = new_minute / MINUTES_PER_HOUR
		new_hour += hours_to_add
		new_minute = new_minute % MINUTES_PER_HOUR
		
	# handle hour overflow
	if new_hour >= HOURS_PER_DAY:
		var days_to_add = new_hour / HOURS_PER_DAY
		new_day += days_to_add
		new_hour = new_hour % HOURS_PER_DAY
		
	# handle day overflow
	if new_day > DAYS_PER_SEASON:
		var seasons_to_add = (new_day - 1) / DAYS_PER_SEASON
		new_season += seasons_to_add
		new_day = (new_day - 1) % DAYS_PER_SEASON + 1
		
	# handle season overflow
	if new_season >= SEASONS_PER_YEAR:
		var years_to_add = new_season / SEASONS_PER_YEAR
		new_year += years_to_add
		new_season = new_season % SEASONS_PER_YEAR
	
	# apply changes
	minute = new_minute
	hour = new_hour
	day = new_day
	season = new_season
	year = new_year
	
	# emit signals
	if minute != old_minute:
		minute_changed.emit(old_minute, minute)
	if hour != old_hour:
		hour_changed.emit(old_hour, hour)
	if day != old_day:
		day_changed.emit(old_day, day)
	if season != old_season:
		season_changed.emit(old_season, season)	
	if year != old_year:
		year_changed.emit(old_year, year)
	
	
	
# === HELPERS ===
func get_season_name() -> String:
	match season:
		0: return "Spring"
		1: return "Summer"
		2: return "Fall"
		3: return "Winter"
		_: return "Unknown"
		
func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]
	
func get_date_string() -> String:
	return "%s %d, Year %d" % [get_season_name(), day, year]


# ==== DEBUG FUNCTIONS ===
func advance_one_hour():
	advance_time_by_minutes(60)

func advance_one_day():
	advance_time_by_minutes(1440)
	
func advance_one_season():
	advance_time_by_minutes(1440 * DAYS_PER_SEASON)

func advance_one_year():
	advance_time_by_minutes(1440 * DAYS_PER_SEASON * 4)
	
func toggle_pause():
	is_paused = !is_paused
	print("Time Paused: ", is_paused)

func set_speed(speed_multiplier: float):
	game_speed = speed_multiplier
	print("Game Speed set to : ", game_speed, "x")
