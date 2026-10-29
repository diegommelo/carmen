class_name Career
extends RefCounted
## Carreira do agente salva entre partidas: {name, cases, rank, caught}.
## No navegador, user:// fica guardado pelo próprio navegador.

const PATH := "user://career.json"


static func fresh(agent_name: String) -> Dictionary:
	return {"name": agent_name, "cases": 0, "rank": 0, "caught": []}


## Lê a carreira salva. Sem arquivo (ou com arquivo estragado), devolve {}.
static func load_saved(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("cases"):
		return {}
	return {
		"name": str(data.get("name", "")),
		"cases": int(data.cases),
		"rank": int(data.get("rank", 0)),
		"caught": Array(data.get("caught", [])),
	}


static func save(detective: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(detective))
	return true


static func erase(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
