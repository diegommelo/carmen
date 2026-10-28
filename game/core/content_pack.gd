class_name ContentPack
extends RefCounted
## Pacote de conteúdo em JSON: regras, tipos de local, traços, suspeitos e cidades.
## O formato está descrito em docs/content-format.md.
## Textos traduzidos são objetos {"pt_BR": "...", "en": "..."}. Ao carregar (ou ao
## trocar de idioma), cada um deles vira a string do idioma escolhido.

var languages: Array
var default_language: String
var locale: String
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
var _suspects_by_id: Dictionary = {}
## O JSON como foi lido, com os textos em todos os idiomas.
var _raw: Dictionary


static func load_dir(path: String, language: String = "") -> ContentPack:
	var p := ContentPack.new()
	p._raw = _read_json(path.path_join("pack.json"))
	p._raw.suspects = _read_json(path.path_join("suspects.json")).suspects
	p._raw.cities = _read_json(path.path_join("cities.json")).cities
	p.languages = p._raw.get("languages", [])
	p.default_language = p._raw.get("default_language", p.languages[0] if not p.languages.is_empty() else "")
	p.set_language(language)
	return p


## Escolhe o idioma dos textos. Idioma desconhecido cai no padrão do pacote;
## "pt" também serve para "pt_BR".
func set_language(language: String) -> void:
	locale = best_language(language)
	var data: Dictionary = _localize(_raw)
	rules = data.rules
	texts = data.texts
	ranks = data.ranks
	location_types = data.location_types
	traits = data.traits
	suspects = data.suspects
	cities = data.cities
	_cities_by_id.clear()
	_types_by_id.clear()
	_suspects_by_id.clear()
	for c in cities:
		_cities_by_id[c.id] = c
	for t in location_types:
		_types_by_id[t.id] = t
	for s in suspects:
		_suspects_by_id[s.id] = s


func best_language(language: String) -> String:
	if language in languages:
		return language
	for l in languages:
		if language != "" and (l.begins_with(language) or language.begins_with(l.get_slice("_", 0))):
			return l
	return default_language


## Lista os textos sem tradução em algum idioma (caminho no JSON).
func missing_translations() -> Array:
	var out := []
	_find_missing(_raw, "", out)
	return out


func _is_localized(value) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.is_empty():
		return false
	for k in value:
		if not (k in languages):
			return false
	return true


func _localize(value):
	if _is_localized(value):
		return value.get(locale, value.get(default_language, value.values()[0]))
	if typeof(value) == TYPE_DICTIONARY:
		var out := {}
		for k in value:
			out[k] = _localize(value[k])
		return out
	if typeof(value) == TYPE_ARRAY:
		return value.map(func(v): return _localize(v))
	return value


func _find_missing(value, path: String, out: Array) -> void:
	if _is_localized(value):
		for l in languages:
			if not value.has(l):
				out.append("%s [%s]" % [path, l])
	elif typeof(value) == TYPE_DICTIONARY:
		for k in value:
			_find_missing(value[k], path + "/" + str(k), out)
	elif typeof(value) == TYPE_ARRAY:
		for i in value.size():
			_find_missing(value[i], path + "/" + str(i), out)


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


func suspect(id: String) -> Dictionary:
	return _suspects_by_id[id]


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
