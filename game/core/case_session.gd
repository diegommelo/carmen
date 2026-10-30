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
## Cópia do agente no início do caso: {name, cases, caught: [ids dos suspeitos já presos]}.
## O caso não mexe na carreira; quem aplica o resultado é Career.apply_outcome().
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
var warrant_id: String = ""
## Traços marcados no mandado, {id_do_traço: valor}. Marcar não gasta tempo, então não
## entra nas ações: vai para o save à parte.
var marks: Dictionary = {}
## Ids do resultado da última busca ou pedido de mandado; vazio antes da primeira.
var last_matches: Array = []
## Cidades visitadas, da cena do crime até a atual.
var route: Array = []
## Verba que sobra para passagens; -1 quando o pacote não usa dinheiro.
var budget: int = -1
## Semente do caso e as ações do jogador desde o início. Com as duas, replay() refaz
## o caso igualzinho; é isso que vai para o save.
var case_seed: int
var actions: Array = []

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
	case_seed = seed
	rng = MscRng.new(seed)


func start(agent: Dictionary) -> void:
	detective = {"name": agent.get("name", ""), "cases": int(agent.get("cases", 0)),
		"caught": agent.get("caught", []).duplicate()}
	var rules := pack.rules
	difficulty = pack.rank_rules(pack.rank_for_cases(detective.cases))
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
	warrant_id = ""
	marks.clear()
	last_matches.clear()
	route = [crime_city]
	actions.clear()
	_used_clues.clear()
	_arrive(crime_city)


## Recria um caso salvo por save_state(). Devolve null se o save não serve mais.
static func resume(content: ContentPack, agent: Dictionary, saved: Dictionary) -> CaseSession:
	var s := CaseSession.new(content, int(saved.get("seed", 0)))
	s.start(agent)
	if typeof(saved.get("actions")) != TYPE_ARRAY or not s.replay(saved.actions):
		return null
	if typeof(saved.get("marks")) == TYPE_DICTIONARY:
		for trait_id in saved.marks:
			s.set_mark(str(trait_id), str(saved.marks[trait_id]))
	return s


## Refaz as ações de um caso salvo, depois de start(). Devolve false se alguma não
## couber no caso (por exemplo, um save de outra versão do pacote) ou se o caso acabar.
func replay(saved: Array) -> bool:
	for a in saved:
		if outcome != ONGOING or typeof(a) != TYPE_ARRAY or a.size() != 2:
			return false
		match a[0]:
			"investigate":
				var slot := int(a[1])
				if slot < 0 or slot >= places.size():
					return false
				investigate(slot)
			"travel":
				var city_id := str(a[1])
				if not (city_id in destinations()) or not can_afford(city_id):
					return false
				travel(city_id)
			"search", "warrant":
				if typeof(a[1]) != TYPE_DICTIONARY:
					return false
				if a[0] == "search":
					search(a[1])
				else:
					issue_warrant(a[1])
			_:
				return false
	return outcome == ONGOING


func save_state() -> Dictionary:
	return {"seed": case_seed, "actions": actions.duplicate(true), "marks": marks.duplicate()}


## Marca (ou desmarca, com valor "") um traço do mandado. Traço ou valor que o pacote
## não conhece é ignorado, para que um save antigo não quebre o caso.
func set_mark(trait_id: String, value: String) -> void:
	if value == "":
		marks.erase(trait_id)
		return
	var t := pack.trait_def(trait_id)
	if t.get("warrant", false) and t.values.has(value):
		marks[trait_id] = value


## Fração do prazo que ainda resta: 1 no início do caso, 0 no fim.
func time_left() -> float:
	var rules: Dictionary = pack.rules.clock
	var start := int(rules.start_day) * 24 + int(rules.start_hour)
	var end := int(difficulty.deadline.day) * 24 + int(difficulty.deadline.hour)
	var now := clock.day * 24 + clock.hour
	return float(end - now) / float(maxi(end - start, 1))


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
	actions.append(["travel", to_city])
	var hours := travel_hours(to_city)
	var price := ticket_price(to_city)
	if budget >= 0:
		budget -= price
	route.append(to_city)
	var tick := clock.advance(hours)
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


## Devolve {witness, text, hours, slept, event, danger}, onde event é "", "danger",
## "henchman" ou "capture" e danger é o índice em texts.danger (-1 sem perigo).
func investigate(slot: int) -> Dictionary:
	assert(outcome == ONGOING, "o caso já terminou")
	actions.append(["investigate", slot])
	var place: Dictionary = places[slot]
	var event := ""
	if is_final_city():
		if slot == _hideout_slot:
			_resolve_capture()
			return {"witness": place_witness(slot), "text": "", "hours": 0, "slept": false, "event": "capture", "danger": -1}
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
	var tick := clock.advance(hours)
	if tick.expired:
		outcome = ESCAPED_TIME
	var danger := rng.index(pack.texts.danger) if event == "danger" else -1
	return {"witness": place_witness(slot), "text": place_text(slot), "hours": hours,
		"slept": tick.slept, "event": event, "danger": danger}


## Suspeitos compatíveis com `by` = {id_do_traço: valor}, só com os traços conhecidos.
func matching(by: Dictionary) -> Array:
	return pack.suspects.filter(func(s):
		for k in by:
			if s.traits.get(k) != by[k]:
				return false
		return true)


## Busca no sistema de mandados: lista os compatíveis e custa `rules.warrant.search_hours`.
## Devolve {matches, hours, slept}.
func search(by: Dictionary) -> Dictionary:
	assert(outcome == ONGOING, "o caso já terminou")
	actions.append(["search", by.duplicate()])
	var r := _warrant_tick("search_hours")
	r.matches = matching(by)
	last_matches = _ids(r.matches)
	return r


## Pedido de mandado. Com exatamente um compatível, o mandado sai no nome dele e custa
## `rules.warrant.issue_hours`; senão conta como busca e o mandado anterior continua.
## Devolve {matches, issued, hours, slept}.
func issue_warrant(by: Dictionary) -> Dictionary:
	assert(outcome == ONGOING, "o caso já terminou")
	actions.append(["warrant", by.duplicate()])
	var matches := matching(by)
	var issued := matches.size() == 1
	var r := _warrant_tick("issue_hours" if issued else "search_hours")
	if issued:
		warrant_id = matches[0].id
	r.matches = matches
	r.issued = issued
	last_matches = _ids(matches)
	return r


static func _ids(suspects: Array) -> Array:
	return suspects.map(func(s): return s.id)


func _warrant_tick(rule: String) -> Dictionary:
	var hours := int(pack.rules.get("warrant", {}).get(rule, 0))
	if hours == 0:
		return {"hours": 0, "slept": false}
	var tick := clock.advance(hours)
	if tick.expired:
		outcome = ESCAPED_TIME
	return {"hours": hours, "slept": tick.slept}


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
			_add_lookalike()
	arrival_index = rng.index(pack.city(city_id).description)
	_investigate_cost = int(pack.rules.investigate.first_hours)
	_build_places()
	_hideout_slot = rng.index(places) if is_final_city() else -1


## Com chance `similar_destinations`, garante entre os voos da cidade atual uma cidade
## que divide alguma região (`regions` no pacote) com a próxima da rota, para que a pista
## de destino não se resolva só por eliminação. Se não houver, liga uma no mapa.
func _add_lookalike() -> void:
	if rng.roll(999) >= int(difficulty.similar_destinations * 1000.0):
		return
	var regions: Array = pack.city(next_city).get("regions", [])
	if regions.is_empty():
		return
	var shares := func(id: String) -> bool:
		return id != next_city and pack.city(id).get("regions", []).any(func(r): return r in regions)
	var options := graph.neighbors(current_city)
	if options.any(shares):
		return
	var candidates := pack.city_ids().filter(func(id): return id != current_city and not (id in options) and shares.call(id))
	if candidates.is_empty():
		return
	graph.link(current_city, rng.pick(candidates))


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
					nothing = pack.trait_def(recipe.trait).clues[suspect.traits[recipe.trait]][recipe.trait_i]
				text += " " + nothing + "."
	return pack.with_pronouns(text, suspect.traits[pack.rules.sex_trait])


func _resolve_capture() -> void:
	if warrant_id == "":
		outcome = NO_WARRANT
	elif warrant_id != suspect.id:
		outcome = WRONG_WARRANT
	else:
		outcome = ARRESTED
