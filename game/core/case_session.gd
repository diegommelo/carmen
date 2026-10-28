class_name CaseSession
extends RefCounted
## Um caso do começo ao fim: rota do ladrão, testemunhas, viagens, relógio e mandado.
## Segue as regras do original descritas em docs/spec-original.md (seções 3 e 4).
## Não depende de interface: a tela chama os métodos e mostra o que eles devolvem.

const ONGOING := ""
const ESCAPED_TIME := "escaped_time"
const NO_WARRANT := "no_warrant"
const WRONG_WARRANT := "wrong_warrant"
const ARRESTED := "arrested"

var pack: ContentPack
var rng: MscRng
var graph: WorldGraph
var clock: GameClock
## {name, cases, rank}
var detective: Dictionary

var suspect: Dictionary
var crime_city: String
var treasure: String
var current_city: String
## Próxima cidade da rota (no original, 399c). Quando é igual à atual, é o esconderijo.
var next_city: String
## Cidade da rota em que o ladrão passou por último (39a0).
var trail_city: String
var steps_left: int
## Os locais da cidade atual: [{type, witness, text}]
var places: Array = []
var arrival_text: String
var outcome: String = ONGOING
var promoted: bool = false
var warrant_id: String = ""

var _investigate_cost: int
var _hideout_slot: int = -1
var _last_trail_visited: String = ""
var _henchman_seen: bool = false


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
	treasure = rng.pick(pack.city(crime_city).treasures)
	steps_left = detective.rank + rules.route_base_steps
	next_city = crime_city
	trail_city = ""
	outcome = ONGOING
	warrant_id = ""
	_arrive(crime_city)


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
		if _hideout_slot < 0:
			var others := range(places.size()).filter(func(i): return i != slot)
			_hideout_slot = rng.pick(others)
			event = "danger"
		elif slot == _hideout_slot:
			_resolve_capture()
			return {"witness": place.witness, "text": "", "hours": 0, "slept": false, "event": "capture"}
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
	return {"witness": place.witness, "text": place.text, "hours": hours, "slept": tick.slept, "event": event}


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
	arrival_text = rng.pick(pack.city(city_id).description)
	_investigate_cost = int(pack.rules.investigate.first_hours)
	_hideout_slot = -1
	_build_places()


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
		var valid := present.filter(func(t): return there.clues.has(t.id))
		var chosen: Dictionary = rng.pick(valid if not valid.is_empty() else (present if not present.is_empty() else candidates))
		places.append({"type": chosen.id, "witness": rng.pick(chosen.witnesses), "text": _statement(chosen, there)})


func _statement(type: Dictionary, there: Dictionary) -> String:
	var texts := pack.texts
	var sex: String = suspect.traits[pack.rules.sex_trait]
	if is_final_city():
		return pack.with_pronouns(rng.pick(texts.final_warnings), sex)
	if current_city != trail_city:
		return pack.with_pronouns(rng.pick(type.not_seen), sex)
	var text: String = rng.pick(texts.openers) + " " + rng.pick(there.clues[type.id]) + "."
	var clue_traits := pack.traits.filter(func(t): return t.has("clues"))
	var start := rng.roll(clue_traits.size() - 1)
	var c := start
	while true:
		var trait_def: Dictionary = clue_traits[c]
		if rng.roll(255) <= int(type.clue_chance.get(trait_def.id, 0)):
			var phrases: Array = trait_def.clues.get(suspect.traits[trait_def.id], [])
			text += " " + (rng.pick(phrases) if not phrases.is_empty() else texts.nothing_more) + "."
			break
		c = (c + 1) % clue_traits.size()
		if c == start:
			break
	return pack.with_pronouns(text, sex)


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
