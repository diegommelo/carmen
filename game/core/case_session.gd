class_name CaseSession
extends RefCounted
## Um caso do começo ao fim: rota do ladrão, testemunhas, viagens, relógio e mandado.
## Segue as regras do original descritas em docs/spec-original.md (seções 3 e 4).
## Não depende de interface: a tela chama os métodos e mostra o que eles devolvem.
## As falas são guardadas como "receitas" (índices nas listas do pacote) e viram
## texto só na hora de mostrar, para que a troca de idioma valha no meio do caso.

const ONGOING := ""
const ESCAPED_TIME := "escaped_time"
const NO_WARRANT := "no_warrant"
const WRONG_WARRANT := "wrong_warrant"
const ARRESTED := "arrested"
## Lista de pistas da cidade que qualquer tipo de local pode dar.
const ANY_CLUES := "any"

var pack: ContentPack
var rng: MscRng
var graph: WorldGraph
var clock: GameClock
## {name, cases, rank}
var detective: Dictionary

var suspect: Dictionary
var crime_city: String
var treasure_index: int
var current_city: String
## Próxima cidade da rota (no original, 399c). Quando é igual à atual, é o esconderijo.
var next_city: String
## Cidade da rota em que o ladrão passou por último (39a0).
var trail_city: String
var steps_left: int
## Os locais da cidade atual: [{type, witness, statement}], com índices nas listas do pacote.
var places: Array = []
var arrival_index: int
var outcome: String = ONGOING
var promoted: bool = false
var warrant_id: String = ""

var _investigate_cost: int
## Local do esconderijo na cidade final, sorteado na chegada entre os três.
## O original sorteava só depois da primeira visita e nunca no local visitado;
## aqui o jogador pode acertar de primeira.
var _hideout_slot: int = -1
var _last_trail_visited: String = ""
var _henchman_seen: bool = false
## Pistas de destino já usadas no caso, como "cidade/lista/índice", para não repetir.
var _used_clues: Dictionary = {}


func _init(content: ContentPack, seed: int) -> void:
	pack = content
	rng = MscRng.new(seed)


## Começa um caso novo para o detetive {name, cases, rank}.
func start(agent: Dictionary) -> void:
	detective = agent
	var rules := pack.rules
	graph = WorldGraph.generate(pack.city_ids(), rng, rules.graph.max_links, rules.graph.min_hops)
	clock = GameClock.new(rules.clock)
	if detective.cases < rules.boss_after_cases:
		suspect = rng.pick(pack.henchmen())
	else:
		suspect = pack.boss()
	crime_city = rng.pick(pack.city_ids())
	treasure_index = rng.index(pack.city(crime_city).treasures)
	steps_left = detective.rank + rules.route_base_steps
	next_city = crime_city
	trail_city = ""
	outcome = ONGOING
	warrant_id = ""
	_used_clues.clear()
	_arrive(crime_city)


## Troca o idioma dos textos, inclusive no meio do caso.
func set_language(language: String) -> void:
	pack.set_language(language)
	suspect = pack.suspect(suspect.id)


func treasure() -> String:
	return pack.city(crime_city).treasures[treasure_index]


func arrival_text() -> String:
	return pack.city(current_city).description[arrival_index]


func place_witness(slot: int) -> String:
	var place: Dictionary = places[slot]
	return pack.location_type(place.type).witnesses[place.witness]


func place_text(slot: int) -> String:
	return _render(places[slot].statement)


func destinations() -> Array:
	return graph.neighbors(current_city)


func is_final_city() -> bool:
	return current_city == next_city


func travel_hours(to_city: String) -> int:
	var a: Dictionary = pack.city(current_city).map
	var b: Dictionary = pack.city(to_city).map
	var d := absi(int(a.x) - int(b.x)) + absi(int(a.y) - int(b.y)) + 1
	var t: Dictionary = pack.rules.travel
	return mini(d / int(t.distance_per_hour) + int(t.base_hours), int(t.max_hours))


## Voa para um vizinho. Devolve {hours, slept, expired}.
func travel(to_city: String) -> Dictionary:
	assert(outcome == ONGOING, "o caso já terminou")
	assert(to_city in destinations())
	var hours := travel_hours(to_city)
	var tick := clock.advance(hours, true)
	if tick.expired:
		outcome = ESCAPED_TIME
		return {"hours": hours, "slept": tick.slept, "expired": true}
	_arrive(to_city)
	return {"hours": hours, "slept": tick.slept, "expired": false}


## Interroga a testemunha do local `slot` (0..2).
## Devolve {witness, text, hours, slept, event}, onde event é "", "danger", "henchman" ou "capture".
func investigate(slot: int) -> Dictionary:
	assert(outcome == ONGOING, "o caso já terminou")
	var place: Dictionary = places[slot]
	var event := ""
	if is_final_city():
		if slot == _hideout_slot:
			_resolve_capture()
			return {"witness": place_witness(slot), "text": "", "hours": 0, "slept": false, "event": "capture"}
		else:
			event = "danger"
	elif current_city == trail_city:
		if _last_trail_visited != "" and _last_trail_visited != current_city:
			event = "danger"
			if not _henchman_seen:
				_henchman_seen = true
				event = "henchman"
		_last_trail_visited = current_city
	var hours := _investigate_cost
	_investigate_cost = mini(_investigate_cost + 1, int(pack.rules.investigate.max_hours))
	var tick := clock.advance(hours, true)
	if tick.expired:
		outcome = ESCAPED_TIME
	return {"witness": place_witness(slot), "text": place_text(slot), "hours": hours, "slept": tick.slept, "event": event}


## Computador da Interpol. `marks` = {id_do_traço: valor} só com os traços conhecidos.
## Devolve os suspeitos compatíveis. Com exatamente um, o mandado sai no nome dele;
## caso contrário qualquer mandado anterior é cancelado, como no original.
func compute_warrant(marks: Dictionary) -> Array:
	var matches := pack.suspects.filter(func(s):
		for k in marks:
			if s.traits[k] != marks[k]:
				return false
		return true)
	warrant_id = matches[0].id if matches.size() == 1 else ""
	return matches


func _arrive(city_id: String) -> void:
	current_city = city_id
	if city_id == next_city and steps_left != 0:
		var options := graph.neighbors(city_id)
		if options.is_empty():
			steps_left = 0
		else:
			while true:
				next_city = rng.pick(options)
				if next_city != trail_city or options.size() <= 1:
					break
			trail_city = city_id
			steps_left -= 1
	arrival_index = rng.index(pack.city(city_id).description)
	_investigate_cost = int(pack.rules.investigate.first_hours)
	_build_places()
	_hideout_slot = rng.index(places) if is_final_city() else -1


func _build_places() -> void:
	places.clear()
	var here := pack.city(current_city)
	var there := pack.city(next_city)
	var groups := {}
	for t in pack.location_types:
		groups[int(t.group)] = groups.get(int(t.group), []) + [t]
	var keys := groups.keys()
	keys.sort()
	for g in keys:
		var candidates: Array = groups[g]
		var present := candidates.filter(func(t): return t.id in here.locations)
		var valid := present.filter(func(t): return not _clue_pool(there, t.id).is_empty())
		var chosen: Dictionary = rng.pick(valid if not valid.is_empty() else (present if not present.is_empty() else candidates))
		places.append({"type": chosen.id, "witness": rng.index(chosen.witnesses), "statement": _statement(chosen, there)})


## Sorteia a fala da testemunha e devolve a receita dela.
func _statement(type: Dictionary, there: Dictionary) -> Dictionary:
	var texts := pack.texts
	if is_final_city():
		return {"kind": "final", "i": rng.index(texts.final_warnings)}
	if current_city != trail_city:
		return {"kind": "not_seen", "type": type.id, "i": rng.index(type.not_seen)}
	var clue := _pick_clue(there, type.id)
	var recipe := {"kind": "trail", "type": type.id, "city": there.id,
		"opener": rng.index(texts.openers), "list": clue[0], "clue": clue[1], "trait": ""}
	var clue_traits := pack.traits.filter(func(t): return t.has("clues"))
	var start := rng.roll(clue_traits.size() - 1)
	var c := start
	while true:
		var trait_def: Dictionary = clue_traits[c]
		if rng.roll(255) <= int(type.clue_chance.get(trait_def.id, 0)):
			var phrases: Array = trait_def.clues.get(suspect.traits[trait_def.id], [])
			recipe.trait = trait_def.id
			recipe.trait_i = rng.index(phrases) if not phrases.is_empty() else -1
			break
		c = (c + 1) % clue_traits.size()
		if c == start:
			break
	return recipe


## Pistas sobre `there` que um local do tipo `type_id` pode dar: as do tipo e as
## gerais (`clues.any`), como pares [lista, índice].
func _clue_pool(there: Dictionary, type_id: String) -> Array:
	var pool := []
	for list in [type_id, ANY_CLUES]:
		for i in there.clues.get(list, []).size():
			pool.append([list, i])
	return pool


## Sorteia uma pista de destino que ainda não apareceu no caso. Quando todas já
## apareceram, volta a sortear entre todas.
func _pick_clue(there: Dictionary, type_id: String) -> Array:
	var pool := _clue_pool(there, type_id)
	var fresh := pool.filter(func(c): return not _used_clues.has(_clue_key(there.id, c)))
	var chosen: Array = rng.pick(fresh if not fresh.is_empty() else pool)
	_used_clues[_clue_key(there.id, chosen)] = true
	return chosen


static func _clue_key(city_id: String, clue: Array) -> String:
	return "%s/%s/%d" % [city_id, clue[0], clue[1]]


## Monta o texto de uma receita no idioma atual do pacote.
func _render(recipe: Dictionary) -> String:
	var texts := pack.texts
	var text: String
	match recipe.kind:
		"final":
			text = texts.final_warnings[recipe.i]
		"not_seen":
			text = pack.location_type(recipe.type).not_seen[recipe.i]
		_:
			text = texts.openers[recipe.opener] + " " + pack.city(recipe.city).clues[recipe.list][recipe.clue] + "."
			if recipe.trait != "":
				var nothing: String = texts.nothing_more
				if recipe.trait_i >= 0:
					for t in pack.traits:
						if t.id == recipe.trait:
							nothing = t.clues[suspect.traits[t.id]][recipe.trait_i]
				text += " " + nothing + "."
	return pack.with_pronouns(text, suspect.traits[pack.rules.sex_trait])


func _resolve_capture() -> void:
	if warrant_id == "":
		outcome = NO_WARRANT
	elif warrant_id != suspect.id:
		outcome = WRONG_WARRANT
	else:
		outcome = ARRESTED
		detective.cases += 1
		var new_rank := pack.rank_for_cases(detective.cases)
		promoted = new_rank > detective.rank
		detective.rank = new_rank
