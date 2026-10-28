class_name ContentPack
extends RefCounted
## Pacote de conteúdo em JSON: regras, tipos de local, traços, suspeitos e cidades.
## O formato está descrito em docs/content-format.md.

var rules: Dictionary
var texts: Dictionary
var ranks: Array
## Cada tipo: {id, name, group, witnesses, not_seen, clue_chance}
var location_types: Array
## Categorias de traço: {id, name, values, warrant, clues: {valor: [frases]}}
var traits: Array
var suspects: Array
var cities: Array
var _cities_by_id: Dictionary = {}
var _types_by_id: Dictionary = {}


static func load_dir(path: String) -> ContentPack:
	var p := ContentPack.new()
	var pack: Dictionary = _read_json(path.path_join("pack.json"))
	p.rules = pack.rules
	p.texts = pack.texts
	p.ranks = pack.ranks
	p.location_types = pack.location_types
	p.traits = pack.traits
	p.suspects = _read_json(path.path_join("suspects.json")).suspects
	p.cities = _read_json(path.path_join("cities.json")).cities
	for c in p.cities:
		p._cities_by_id[c.id] = c
	for t in p.location_types:
		p._types_by_id[t.id] = t
	return p


static func _read_json(file: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(file)
	if text.is_empty():
		push_error("Não consegui ler %s" % file)
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON inválido em %s" % file)
		return {}
	return data


func city(id: String) -> Dictionary:
	return _cities_by_id[id]


func location_type(id: String) -> Dictionary:
	return _types_by_id[id]


func city_ids() -> Array:
	return _cities_by_id.keys()


func warrant_traits() -> Array:
	return traits.filter(func(t): return t.warrant)


func boss() -> Dictionary:
	for s in suspects:
		if s.get("boss", false):
			return s
	return {}


func henchmen() -> Array:
	return suspects.filter(func(s): return not s.get("boss", false))


func rank_for_cases(cases: int) -> int:
	var r := 0
	for i in ranks.size():
		if cases >= ranks[i].cases:
			r = i
	return r


## Substitui {chave} pelos pronomes do sexo do suspeito ({ele}, {Ele}, {dele}...).
func with_pronouns(text: String, sex: String) -> String:
	var out := text
	var table: Dictionary = texts.pronouns[sex]
	for key in table:
		out = out.replace("{%s}" % key, table[key])
	return out
