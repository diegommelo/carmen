class_name GameClock
extends RefCounted
## Relógio do caso: dia 0 = segunda-feira, horas de 0 a 23 (2356:0566).

var day: int = 0
var hour: int = 0
var rules: Dictionary


func _init(clock_rules: Dictionary) -> void:
	rules = clock_rules
	day = rules.start_day
	hour = rules.start_hour


## Avança `hours` horas. Se a ação terminar fora do horário acordado, o agente
## dorme (`sleep_hours`). Devolve {"slept": bool, "expired": bool}.
func advance(hours: int) -> Dictionary:
	_tick(hours)
	var slept := false
	if not is_awake_hour(hour):
		slept = true
		_tick(rules.sleep_hours)
	return {"slept": slept, "expired": is_expired()}


func is_awake_hour(h: int) -> bool:
	return h >= rules.wake_hour and h < rules.sleep_hour


func is_expired() -> bool:
	return day > rules.deadline_day or (day == rules.deadline_day and hour >= rules.deadline_hour)


func _tick(hours: int) -> void:
	for i in hours:
		hour += 1
		if hour > 23:
			hour = 0
			day += 1
