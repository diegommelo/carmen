class_name Career
extends RefCounted
## Fichário de agentes salvo entre partidas, como o ACME.DAT do original:
## {"current": índice, "agents": [{name, cases, rank, caught}]}. O caso em andamento de
## cada agente fica no próprio agente, em "case" ({seed, actions, marks}).
## No navegador, user:// fica guardado pelo próprio navegador.

const PATH := "user://agents.json"
## Save de antes do fichário, com um agente só: vira o primeiro agente do fichário.
const LEGACY_PATH := "user://career.json"
## O original guardava 12; aqui cabem 8 no painel de texto sem rolar.
const MAX_AGENTS := 8
const MAX_NAME := 16


static func fresh(agent_name: String) -> Dictionary:
	return {"name": agent_name, "cases": 0, "rank": 0, "caught": []}


static func empty_roster() -> Dictionary:
	return {"current": -1, "agents": []}


## Sem arquivo (ou com arquivo estragado), devolve um fichário vazio. Agentes estragados
## ficam de fora.
static func load_roster(path: String = PATH, legacy_path: String = LEGACY_PATH) -> Dictionary:
	var roster := empty_roster()
	if not FileAccess.file_exists(path):
		var old := _parse_agent(_read_json(legacy_path))
		if old.is_empty():
			return roster
		roster = {"current": 0, "agents": [old]}
		if save_roster(roster, path):
			erase(legacy_path)
		return roster
	var data = _read_json(path)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("agents")) != TYPE_ARRAY:
		return roster
	for entry in data.agents:
		var agent := _parse_agent(entry)
		if not agent.is_empty():
			roster.agents.append(agent)
	roster.current = clampi(int(data.get("current", -1)), -1, roster.agents.size() - 1)
	return roster


static func save_roster(roster: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(roster))
	return true


## O agente escolhido, o mesmo dicionário que está no fichário; {} se não há.
static func current(roster: Dictionary) -> Dictionary:
	var i: int = roster.current
	return roster.agents[i] if i >= 0 and i < roster.agents.size() else {}


static func add(roster: Dictionary, agent: Dictionary) -> bool:
	if roster.agents.size() >= MAX_AGENTS:
		return false
	roster.agents.append(agent)
	roster.current = roster.agents.size() - 1
	return true


## Apagar o agente escolhido deixa o fichário sem ninguém escolhido.
static func remove(roster: Dictionary, index: int) -> void:
	roster.agents.remove_at(index)
	if roster.current == index:
		roster.current = -1
	elif roster.current > index:
		roster.current -= 1


static func erase(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _parse_agent(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or not data.has("cases"):
		return {}
	var agent := {
		"name": str(data.get("name", "")),
		"cases": int(data.cases),
		"rank": int(data.get("rank", 0)),
		"caught": Array(data.get("caught", [])),
	}
	if typeof(data.get("case")) == TYPE_DICTIONARY:
		agent.case = data.case
	return agent
