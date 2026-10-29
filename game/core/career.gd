class_name Career
extends RefCounted
## Carreira do agente salva entre partidas: {name, cases, rank, caught} e, quando o
## jogador salva ao sair, o caso em andamento em "case" ({seed, actions, marks}).
## No navegador, user:// fica guardado pelo próprio navegador.

const PATH := "user://career.json"


static func fresh(agent_name: String) -> Dictionary:
	return {"name": agent_name, "cases": 0, "rank": 0, "caught": []}


## Sem arquivo (ou com arquivo estragado), devolve {}.
static func load_saved(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("cases"):
		return {}
	var career := {
		"name": str(data.get("name", "")),
		"cases": int(data.cases),
		"rank": int(data.get("rank", 0)),
		"caught": Array(data.get("caught", [])),
	}
	if typeof(data.get("case")) == TYPE_DICTIONARY:
		career.case = data.case
	return career


## Sem `case_state`, o caso salvo antes (se havia) é descartado.
static func save(detective: Dictionary, path: String = PATH, case_state: Dictionary = {}) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var data := detective.duplicate()
	data.erase("case")
	if not case_state.is_empty():
		data.case = case_state
	f.store_string(JSON.stringify(data))
	return true


static func erase(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
