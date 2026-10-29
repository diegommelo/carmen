class_name Career
extends RefCounted
## Fichário de agentes salvo entre partidas, como o ACME.DAT do original:
## {"agents": [{name, cases, rank, caught}]}. O caso em andamento de cada agente fica no
## próprio agente, em "case" ({seed, actions, marks}). Como no original, o jogador entra
## dizendo o nome; um nome novo cadastra um agente.
## No navegador, user:// fica guardado pelo próprio navegador.

const PATH := "user://agents.json"
## Save de antes do fichário, com um agente só: vira o primeiro agente do fichário.
const LEGACY_PATH := "user://career.json"
## O original guardava 12; aqui cabem 8 na tela PF sem rolar.
const MAX_AGENTS := 8
const MAX_NAME := 16


static func fresh(agent_name: String) -> Dictionary:
	return {"name": agent_name, "cases": 0, "rank": 0, "caught": []}


static func empty_roster() -> Dictionary:
	return {"agents": []}


## Sem arquivo (ou com arquivo estragado), devolve um fichário vazio. Agentes estragados
## ficam de fora.
static func load_roster(path: String = PATH, legacy_path: String = LEGACY_PATH) -> Dictionary:
	var roster := empty_roster()
	if not FileAccess.file_exists(path):
		var old := _parse_agent(_read_json(legacy_path))
		if old.is_empty():
			return roster
		roster.agents.append(old)
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
	return roster


static func save_roster(roster: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(roster))
	return true


## O agente com esse nome (sem diferenciar maiúsculas), o mesmo dicionário que está no
## fichário; {} se não há.
static func find(roster: Dictionary, agent_name: String) -> Dictionary:
	for agent in roster.agents:
		if agent.name.to_lower() == agent_name.to_lower():
			return agent
	return {}


static func add(roster: Dictionary, agent: Dictionary) -> bool:
	if roster.agents.size() >= MAX_AGENTS:
		return false
	roster.agents.append(agent)
	return true


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
