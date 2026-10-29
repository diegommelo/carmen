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
const OUT_OF_MONEY := "out_of_money"
## Lista de pistas da cidade que qualquer tipo de local pode dar.
const ANY_CLUES := "any"

var pack: ContentPack
var rng: MscRng
var graph: WorldGraph
var clock: GameClock
## {name, cases, rank, caught: [ids dos suspeitos já presos]}
var detective: Dictionary
## Regras da patente em que o caso começou (ContentPack.rank_rules).
var difficulty: Dictionary

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
var boss_arrested: bool = false
var warrant_id: String = ""
## Verba que sobra para passagens; -1 quando o pacote não usa dinheiro.
var budget: int = -1

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


func start(agent: Dictionary) -> void:
	detective = agent
	if not detective.has("caught"):
		detective.caught = []
	var rules := pack.rules
	difficulty = pack.rank_rules(detective.rank)
	graph = WorldGraph.generate(pack.city_ids(), rng, rules.graph.max_links, rules.graph.min_hops)
	var clock_rules: Dictionary = rules.clock.duplicate()
	clock_rules.deadline_day = difficulty.deadline.day
	clock_rules.deadline_hour = difficulty.deadline.hour
	clock = GameClock.new(clock_rules)
	suspect = _pick_suspect()
	crime_city = rng.pick(pack.city_ids())
	treasure_index = rng.index(pack.city(crime_city).treasures)
	steps_left = difficulty.route_steps
	budget = difficulty.budget
	next_city = crime_city
	trail_city = ""
	outcome = ONGOING
	promoted = false
	boss_arrested = false
	warrant_id = ""
	_used_clues.clear()
	_arrive(crime_city)


## O alvo é sorteado entre os comparsas que o detetive ainda não prendeu; o original
## repetia. Com todos presos (ou com `boss_after_cases` casos), o alvo é o chefe.
func _pick_suspect() -> Dictionary:
	var free := pack.henchmen().filter(func(s): return not (s.id in detective.caught))
	if detective.cases >= int(pack.rules.boss_after_cases) or free.is_empty():
		return pack.boss()
	return rng.pick(free)


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


## 0 quando o pacote não usa dinheiro.
func ticket_price(to_city: String) -> int:
	if budget < 0:
		return 0
	return travel_hours(to_city) * int(pack.rules.money.ticket_per_hour)


func can_afford(to_city: String) -> bool:
	return budget < 0 or ticket_price(to_city) <= budget


## Voa para um vizinho. Devolve {hours, price, slept, expired, shortcut}. `shortcut` diz
## que o mandado certo encurtou a rota: a cidade de chegada já é o esconderijo.
## Se depois do voo não der para pagar nenhuma passagem fora do esconderijo, o caso
## acaba em OUT_OF_MONEY.
func travel(to_city: String) -> Dictionary:
	assert(outcome == ONGOING, "o caso já terminou")
	assert(to_city in destinations())
	assert(can_afford(to_city), "sem verba para a passagem")
	var hours := travel_hours(to_city)
	var price := ticket_price(to_city)
	if budget >= 0:
		budget -= price
	var tick := clock.advance(hours, true)
	if tick.expired:
		outcome = ESCAPED_TIME
		return {"hours": hours, "price": price, "slept": tick.slept, "expired": true, "shortcut": false}
	var shortcut := _try_shortcut(to_city)
	_arrive(to_city)
	if not is_final_city() and not destinations().any(can_afford):
		outcome = OUT_OF_MONEY
	return {"hours": hours, "price": price, "slept": tick.slept, "expired": false, "shortcut": shortcut}


## Com o mandado certo emitido, cada voo certo da rota tem `shortcut_chance` de levar
## direto ao esconderijo. Não existe no original. Os primeiros `rules.shortcut_min_flights`
## voos da rota nunca encurtam, para quem acerta o suspeito logo na cidade do crime.
func _try_shortcut(to_city: String) -> bool:
	if to_city != next_city or steps_left <= 0 or warrant_id != suspect.id:
		return false
	if difficulty.route_steps - 1 - steps_left < int(pack.rules.get("shortcut_min_flights", 0)):
		return false
	if rng.roll(999) >= int(difficulty.shortcut_chance * 1000.0):
		return false
	steps_left = 0
	return true


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
		var value: String = suspect.traits[trait_def.id]
		var chance := int(type.clue_chance.get(trait_def.id, 0) * float(trait_def.get("clue_weight", {}).get(value, 1.0)) * difficulty.trait_clues)
		if rng.roll(255) <= chance:
			var phrases: Array = trait_def.clues.get(value, [])
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
		if not (suspect.id in detective.caught):
			detective.caught.append(suspect.id)
		boss_arrested = suspect.get("boss", false)
		var new_rank := pack.rank_for_cases(detective.cases)
		promoted = new_rank > detective.rank
		detective.rank = new_rank
