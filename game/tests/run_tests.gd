extends SceneTree
## Testes do núcleo. Rodar com:
##   godot --headless --path game -s res://tests/run_tests.gd

const PACK_DIR := "res://content/placeholder"
const PARODY_DIR := "res://content/parody"

var _failures := 0
var _checks := 0


func _initialize() -> void:
	var pack := ContentPack.load_dir(PACK_DIR)
	_test_rng()
	_test_clock(pack)
	_test_graph(pack)
	_test_warrant(pack)
	_test_layout(pack)
	_test_languages(pack)
	_test_dossier(pack)
	_test_clue_rotation(pack)
	_test_hideout_any_slot(pack)
	for language in pack.languages:
		pack.set_language(language)
		for seed in range(1, 41):
			_test_full_case(pack, seed)
		_test_wrong_city(pack)
	pack.set_language("pt_BR")
	_test_switch_language_mid_case(pack)
	_test_boss(pack)
	_test_clue_weight(pack)
	_test_rank_defaults(pack)
	_test_no_repeat(pack)
	_test_shortcut(pack)
	_test_trait_clues_factor(pack)
	_test_career_save()
	_test_saved_case(pack)
	_test_warrant_hours()
	_test_no_money(pack)
	_test_pack_consistency(pack, "provisório")
	_test_parody()
	_test_scripts_compile()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FALHOU: " + what)


func _test_rng() -> void:
	# Mesma sequência do rand() do Microsoft C com semente 1 (sem a máscara de 15 bits).
	var r := MscRng.new(1)
	var got := []
	for i in 5:
		got.append(r.roll(65535))
	check(got == [41, 51235, 6334, 59268, 51937], "sequência do MscRng: %s" % [got])
	var r2 := MscRng.new(7)
	for i in 200:
		var v := r2.roll(3)
		check(v >= 0 and v <= 3, "roll(3) fora do intervalo")


func _test_clock(pack: ContentPack) -> void:
	var c := GameClock.new(pack.rules.clock)
	check(c.day == 0 and c.hour == 9, "começa segunda às 9h")
	var t := c.advance(5)
	check(c.hour == 14 and not t.slept, "5 horas sem dormir")
	t = c.advance(10)
	check(t.slept and c.day == 1 and c.hour == 9, "dorme 9 horas depois das 23h: dia %d %dh" % [c.day, c.hour])
	c.day = 6
	c.hour = 15
	t = c.advance(1)
	check(not t.expired, "domingo 16h ainda vale")
	t = c.advance(1)
	check(t.expired, "domingo 17h acabou o prazo")


func _test_graph(pack: ContentPack) -> void:
	var g := WorldGraph.generate(pack.city_ids(), MscRng.new(99), 4, 2)
	var total := 0
	for id in g.links:
		check(g.degree(id) <= 4, "no máximo 4 vizinhos")
		check(not (id in g.links[id]), "cidade ligada a si mesma")
		for n in g.links[id]:
			check(id in g.links[n], "ligação não é simétrica")
		total += g.degree(id)
	check(total > 0, "o grafo tem ligações")


func _test_warrant(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 3)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	check(s.issue_warrant({}).matches.size() == pack.suspects.size(), "sem traços, todos são suspeitos")
	check(s.warrant_id == "", "sem traços não sai mandado")
	var marks := {}
	for t in pack.warrant_traits():
		marks[t.id] = s.suspect.traits[t.id]
	var m := s.issue_warrant(marks)
	check(m.issued and m.matches.size() == 1 and s.warrant_id == s.suspect.id, "todos os traços identificam o suspeito")


## Um "agente perfeito" segue a rota, emite o mandado certo e prende o suspeito.
func _test_full_case(pack: ContentPack, seed: int) -> void:
	var s := CaseSession.new(pack, seed)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	var hops := 0
	var marks := {}
	for t in pack.warrant_traits():
		marks[t.id] = s.suspect.traits[t.id]
	s.issue_warrant(marks)
	while not s.is_final_city() and s.outcome == CaseSession.ONGOING:
		check(s.next_city in s.destinations(), "a próxima cidade da rota é sempre um destino de voo")
		for i in s.places.size():
			var text := s.place_text(i)
			check(not text.contains("{"), "pronome sem substituir (%s): %s" % [pack.locale, text])
		s.investigate(0)
		if s.outcome != CaseSession.ONGOING:
			break
		s.travel(s.next_city)
		hops += 1
	if s.outcome == CaseSession.ESCAPED_TIME:
		return
	var steps: int = pack.rank_rules(0).route_steps
	check(hops == steps, "rota de %d saltos (semente %d deu %d)" % [steps, seed, hops])
	var r := {}
	for slot in 3:
		r = s.investigate(slot)
		if r.event == "capture" or s.outcome != CaseSession.ONGOING:
			break
	check(r.event == "capture", "achou o esconderijo (semente %d)" % seed)
	check(s.outcome == CaseSession.ARRESTED, "prendeu com mandado certo (semente %d): %s" % [seed, s.outcome])
	var rank := pack.rank_for_cases(1)
	check(s.detective.cases == 1 and s.detective.rank == rank and s.promoted == (rank > 0), "ganhou um caso (e a promoção, se for o caso)")
	check(s.detective.caught == [s.suspect.id], "o preso entra na lista da carreira")


## Na cidade final, qualquer um dos três locais pode ser o esconderijo, inclusive o primeiro visitado.
func _test_hideout_any_slot(pack: ContentPack) -> void:
	var seen := {}
	for seed in range(1, 200):
		var s := CaseSession.new(pack, seed)
		s.start({"name": "Teste", "cases": 0, "rank": 0})
		while not s.is_final_city() and s.outcome == CaseSession.ONGOING:
			s.travel(s.next_city)
		if s.outcome != CaseSession.ONGOING:
			continue
		for slot in 3:
			if s.investigate(slot).event == "capture":
				seen[slot] = true
				break
	check(seen.size() == 3, "o esconderijo cai em qualquer um dos três locais: %s" % [seen.keys()])


func _test_wrong_city(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 11)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	s.travel(s.next_city)
	var wrong := ""
	for d in s.destinations():
		if d != s.next_city:
			wrong = d
	if wrong == "":
		return
	s.travel(wrong)
	for i in s.places.size():
		var type := pack.location_type(s.places[i].type)
		check(s.place_text(i) in type.not_seen, "fora da rota a testemunha não viu nada: " + s.place_text(i))


func _test_boss(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 5)
	s.start({"name": "Teste", "cases": 29, "rank": 4})
	check(s.suspect.get("boss", false), "com 29 casos o alvo é a chefe")
	check(s.steps_left == 4 + 4 - 1, "rota de patente + 4 saltos")


func _test_layout(pack: ContentPack) -> void:
	check(pack._raw.format_version == ContentPack.FORMAT_VERSION, "format_version do pacote")
	check(pack.cities.size() == 12 and pack.suspects.size() == 6, "um arquivo por cidade e por suspeito")
	check(pack.city("mexico_city").id == "mexico_city", "o id vem do nome do arquivo")
	var ids := pack.city_ids()
	var sorted := ids.duplicate()
	sorted.sort()
	check(ids == sorted, "cidades em ordem alfabética")


## As pistas sobre uma cidade não se repetem no caso enquanto houver outras, e as
## gerais (clues.any) entram no sorteio de qualquer tipo de local.
func _test_clue_rotation(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 5)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	var rome := pack.city("rome")
	var pool := s._clue_pool(rome, "bank")
	check(pool.size() == rome.clues.bank.size() + rome.clues.any.size(), "banco usa as pistas do tipo e as gerais")
	var seen := {}
	for i in pool.size():
		seen[str(s._pick_clue(rome, "bank"))] = true
	check(seen.size() == pool.size(), "nenhuma pista repetida antes de usar todas: %d de %d" % [seen.size(), pool.size()])
	check(s._pick_clue(rome, "bank") != null, "depois de usar todas, volta a sortear")
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	check(s._used_clues.size() <= 3, "caso novo esquece as pistas usadas")


func _test_languages(pack: ContentPack) -> void:
	check(pack.missing_translations().is_empty(), "textos sem tradução: %s" % [pack.missing_translations()])
	check(pack.best_language("en_US") == "en", "en_US usa inglês")
	check(pack.best_language("pt") == "pt_BR", "pt usa pt_BR")
	check(pack.best_language("fr_FR") == pack.default_language, "idioma desconhecido usa o padrão")
	pack.set_language("en")
	check(pack.city("tokyo").name == "Tokyo", "nome da cidade em inglês")
	check(typeof(pack.location_types[0].name) == TYPE_STRING, "texto traduzido virou String")
	pack.set_language("pt_BR")
	check(pack.city("tokyo").name == "Tóquio", "nome da cidade em português")


func _test_dossier(pack: ContentPack) -> void:
	var trait_ids := pack.traits.map(func(t): return t.id)
	for s in pack.suspects:
		var d := pack.dossier(s.id)
		check(d.traits.size() == pack.warrant_traits().size(), "dossiê de %s com um campo por traço do mandado" % s.id)
		for row in d.traits:
			check(typeof(row.value) == TYPE_STRING and row.value != "", "campo vazio no dossiê de %s" % s.id)
		for id in s.get("dossier", {}).get("traits", {}):
			check(id in trait_ids, "dossiê de %s cita traço desconhecido: %s" % [s.id, id])
	pack.set_language("en")
	var rows := {}
	for row in pack.dossier("light_fingers").traits:
		rows[row.id] = row.value
	check(rows.sex == "Male", "traço sem texto próprio mostra o valor: %s" % rows.sex)
	check(rows.vehicle == "Muddy dirt bike", "texto próprio do traço: %s" % rows.vehicle)
	pack.set_language("pt_BR")


## Trocar de idioma no meio do caso muda o texto, mas não a fala sorteada.
func _test_switch_language_mid_case(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 21)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	s.travel(s.next_city)
	var pt := s.place_text(0)
	var treasure_pt := s.treasure()
	s.set_language("en")
	var en := s.place_text(0)
	check(pt != en and not en.contains("{"), "fala traduzida: %s / %s" % [pt, en])
	check(s.treasure() != treasure_pt, "tesouro traduzido")
	s.set_language("pt_BR")
	check(s.place_text(0) == pt, "voltar ao português devolve a mesma fala")


## O peso de um valor (clue_weight) multiplica a chance de a testemunha falar daquele traço.
func _test_clue_weight(pack: ContentPack) -> void:
	var counts := {}
	for weight in [1.0, 0.0]:
		for t in pack.traits:
			if t.id == "vehicle":
				t.clue_weight = {"motorcycle": weight}
		var hits := 0
		for seed in range(1, 300):
			var s := CaseSession.new(pack, seed)
			s.start({"name": "Teste", "cases": 0, "rank": 0})
			s.suspect = pack.suspect("baroness")
			s.travel(s.next_city)
			for slot in s.places.size():
				if s.places[slot].statement.get("trait", "") == "vehicle":
					hits += 1
			s.places.clear()
			s._build_places()
			for slot in s.places.size():
				if s.places[slot].statement.get("trait", "") == "vehicle":
					hits += 1
		counts[weight] = hits
	for t in pack.traits:
		t.erase("clue_weight")
	check(counts[1.0] > 0 and counts[0.0] < counts[1.0] / 4, "peso 0 quase zera a pista do traço: %s" % [counts])


## Regras que todo pacote precisa seguir para o núcleo funcionar.
func _test_pack_consistency(pack: ContentPack, where: String) -> void:
	var trait_ids := pack.traits.map(func(t): return t.id)
	var groups := {}
	for t in pack.location_types:
		groups[int(t.group)] = true
		for id in t.clue_chance:
			check(id in trait_ids, "%s: %s usa traço desconhecido %s" % [where, t.id, id])
	for t in pack.traits:
		for value in t.get("clues", {}):
			check(value in t.values, "%s: pista de valor desconhecido %s.%s" % [where, t.id, value])
		for value in t.get("clue_weight", {}):
			check(value in t.values, "%s: peso de valor desconhecido %s.%s" % [where, t.id, value])
	var combos := {}
	var bosses := 0
	for s in pack.suspects:
		bosses += 1 if s.get("boss", false) else 0
		var combo := []
		for t in pack.traits:
			check(s.traits.get(t.id, "") in t.values, "%s: %s sem valor válido para %s" % [where, s.id, t.id])
			if t.warrant:
				combo.append(s.traits.get(t.id, ""))
		check(not combos.has(str(combo)), "%s: %s e %s têm os mesmos traços do mandado" % [where, s.id, combos.get(str(combo), "")])
		combos[str(combo)] = s.id
	check(bosses == 1, "%s: um único chefe" % where)
	for c in pack.cities:
		var here := {}
		for type_id in c.locations:
			check(pack._types_by_id.has(type_id), "%s: %s tem local desconhecido %s" % [where, c.id, type_id])
			if not pack._types_by_id.has(type_id):
				continue
			here[int(pack.location_type(type_id).group)] = true
		check(here.size() == groups.size(), "%s: %s sem local de algum grupo" % [where, c.id])
		check(not c.description.is_empty() and not c.treasures.is_empty(), "%s: %s sem descrição ou tesouro" % [where, c.id])
		for region in c.get("regions", []):
			var others := pack.cities.filter(func(o): return o.id != c.id and region in o.get("regions", []))
			check(not others.is_empty(), "%s: região %s só tem %s" % [where, region, c.id])
		for list in c.clues:
			check(list == CaseSession.ANY_CLUES or pack._types_by_id.has(list), "%s: %s tem pistas de tipo desconhecido %s" % [where, c.id, list])


func _test_parody() -> void:
	var pack := ContentPack.load_dir(PARODY_DIR)
	check(pack.missing_translations().is_empty(), "paródia: textos sem tradução: %s" % [pack.missing_translations()])
	check(pack.boss().id == "jair", "paródia: o chefe é o Jair")
	for language in pack.languages:
		pack.set_language(language)
		_test_pack_consistency(pack, "paródia " + language)
		for seed in range(1, 41):
			_test_full_case(pack, seed)
	_test_hideout_any_slot(pack)
	_test_no_repeat(pack)
	check(pack.rules.boss_after_cases == pack.henchmen().size(), "paródia: o Jair vem depois de todos os comparsas")
	for rank in pack.ranks.size():
		var s := CaseSession.new(pack, 100 + rank)
		s.start({"name": "Teste", "cases": pack.ranks[rank].cases, "rank": rank})
		var r := pack.rank_rules(rank)
		check(s.clock.rules.deadline_day == r.deadline.day and s.clock.rules.deadline_hour == r.deadline.hour, "paródia: prazo da patente %d" % rank)
		var hops := 0
		while not s.is_final_city() and s.outcome == CaseSession.ONGOING:
			s.travel(s.next_city)
			hops += 1
		check(hops == r.route_steps, "paródia: patente %d com %d voos (deu %d)" % [rank, r.route_steps, hops])
	var top := pack.rank_rules(pack.ranks.size() - 1)
	var low := pack.rank_rules(0)
	check(top.trait_clues < low.trait_clues and top.shortcut_chance > low.shortcut_chance, "paródia: patente alta dá menos pistas e mais atalho")
	_test_money(pack)
	check(pack.cases_to_next_rank(0) == 2 and pack.cases_to_next_rank(3) == 1, "paródia: casos até a próxima patente")
	check(pack.cases_to_next_rank(9) == 0 and pack.cases_to_next_rank(10) == 0, "paródia: na última patente não falta nada")
	_test_shortcut_min_flights(pack)
	_test_lookalike(pack)


## Sem nada na patente, valem as regras do original: rota de patente + 4, prazo do relógio.
func _test_rank_defaults(pack: ContentPack) -> void:
	for rank in pack.ranks.size():
		var r := pack.rank_rules(rank)
		check(r.route_steps == rank + pack.rules.route_base_steps, "rota padrão da patente %d" % rank)
		check(r.trait_clues == 1.0 and r.shortcut_chance == 0.0, "pistas e atalho padrão")
		check(r.deadline.day == pack.rules.clock.deadline_day and r.deadline.hour == pack.rules.clock.deadline_hour, "prazo padrão")


## Os comparsas não se repetem: a cada caso o alvo é alguém ainda não preso, e o chefe
## vem quando não sobra ninguém.
func _test_no_repeat(pack: ContentPack) -> void:
	var agent := {"name": "Teste", "cases": 0, "rank": 0, "caught": []}
	var henchmen := pack.henchmen().size()
	for i in henchmen:
		var s := CaseSession.new(pack, 300 + i)
		s.start(agent)
		check(not s.suspect.get("boss", false), "%s: o chefe só depois de todos (caso %d)" % [pack.locale, i])
		check(not (s.suspect.id in agent.caught), "%s: %s repetiu" % [pack.locale, s.suspect.id])
		agent.caught.append(s.suspect.id)
	var last := CaseSession.new(pack, 999)
	last.start(agent)
	check(last.suspect.get("boss", false), "todos presos: o alvo é o chefe")


## Com o mandado certo e chance 1, o próximo voo certo já cai no esconderijo.
func _test_shortcut(pack: ContentPack) -> void:
	for with_warrant in [true, false]:
		var s := CaseSession.new(pack, 8)
		s.start({"name": "Teste", "cases": 0, "rank": 2})
		s.difficulty.shortcut_chance = 1.0
		var marks := {}
		if with_warrant:
			for t in pack.warrant_traits():
				marks[t.id] = s.suspect.traits[t.id]
		s.issue_warrant(marks)
		var r := s.travel(s.next_city)
		check(r.shortcut == with_warrant and s.is_final_city() == with_warrant, "atalho só com o mandado certo (%s)" % with_warrant)
		if with_warrant:
			var caught := false
			for slot in 3:
				if s.investigate(slot).event == "capture":
					caught = true
					break
			check(caught and s.outcome == CaseSession.ARRESTED, "o atalho leva ao esconderijo de verdade")


## Na paródia, o primeiro voo da rota nunca encurta, mesmo com o mandado certo.
func _test_shortcut_min_flights(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 8)
	s.start({"name": "Teste", "cases": 9, "rank": 4})
	s.difficulty.shortcut_chance = 1.0
	var marks := {}
	for t in pack.warrant_traits():
		marks[t.id] = s.suspect.traits[t.id]
	s.issue_warrant(marks)
	check(not s.travel(s.next_city).shortcut and not s.is_final_city(), "paródia: sem atalho no primeiro voo")
	check(s.travel(s.next_city).shortcut and s.is_final_city(), "paródia: atalho a partir do segundo voo")


## Com `similar_destinations` 1, todo voo certo da rota tem ao lado uma cidade parecida.
func _test_lookalike(pack: ContentPack) -> void:
	for seed in range(1, 60):
		var s := CaseSession.new(pack, seed)
		s.start({"name": "Teste", "cases": 6, "rank": 3})
		check(s.difficulty.similar_destinations == 1.0, "paródia: delegado sempre tem destino parecido")
		while not s.is_final_city() and s.outcome == CaseSession.ONGOING:
			var regions: Array = pack.city(s.next_city).regions
			var lookalike := s.destinations().any(func(id): return id != s.next_city and pack.city(id).regions.any(func(r): return r in regions))
			check(lookalike, "paródia: voo parecido com %s em %s (semente %d)" % [s.next_city, s.current_city, seed])
			for id in s.destinations():
				check(s.current_city in s.graph.neighbors(id), "o mapa continua de mão dupla")
			s.travel(s.next_city)


## O fator de pistas da patente multiplica a chance de a testemunha falar de um traço.
## Com 0 sobra só o 1 em 256 que o sorteio do original sempre deixa.
func _test_trait_clues_factor(pack: ContentPack) -> void:
	var counts := {}
	for factor in [1.0, 0.0]:
		var traits := 0
		for seed in range(1, 60):
			var s := CaseSession.new(pack, seed)
			s.start({"name": "Teste", "cases": 0, "rank": 0})
			s.difficulty.trait_clues = factor
			s.travel(s.next_city)
			for p in s.places:
				if p.statement.get("trait", "") != "":
					traits += 1
		counts[factor] = traits
	check(counts[1.0] > 20 and counts[0.0] * 10 < counts[1.0], "fator 0 quase zera as pistas de traço: %s" % [counts])


func _test_no_money(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 4)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	check(s.budget == -1 and s.ticket_price(s.next_city) == 0 and s.can_afford(s.next_city), "sem dinheiro no pacote provisório")
	check(s.travel(s.next_city).price == 0 and s.budget == -1, "voo sem custo")


func _test_money(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 4)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	check(s.budget == pack.ranks[0].budget, "verba da patente: %d" % s.budget)
	var price := s.ticket_price(s.next_city)
	check(price == s.travel_hours(s.next_city) * int(pack.rules.money.ticket_per_hour), "preço por hora de voo")
	var before := s.budget
	var r := s.travel(s.next_city)
	check(r.price == price and s.budget == before - price, "a passagem sai da verba")
	var broke := false
	for seed in range(1, 40):
		var t := CaseSession.new(pack, seed)
		t.start({"name": "Teste", "cases": 0, "rank": 0})
		t.budget = t.ticket_price(t.next_city)
		t.travel(t.next_city)
		if t.is_final_city():
			continue
		check(t.budget == 0 and not t.destinations().any(t.can_afford), "verba zerada não paga voo")
		check(t.outcome == CaseSession.OUT_OF_MONEY, "sem verba para voar, o caso acaba")
		broke = true
		break
	check(broke, "achou um caso para testar a verba zerada")


func _test_career_save() -> void:
	var path := "user://test_agents.json"
	var legacy := "user://test_career.json"
	Career.erase(path)
	Career.erase(legacy)
	var roster := Career.load_roster(path, legacy)
	check(roster.agents.is_empty() and Career.current(roster).is_empty(), "sem arquivo, fichário vazio")
	var moro := {"name": "Moro", "cases": 3, "rank": 2, "caught": ["a", "b", "c"]}
	var dallagnol := Career.fresh("Dallagnol")
	check(Career.add(roster, moro) and Career.add(roster, dallagnol), "cadastrou dois agentes")
	check(Career.current(roster) == dallagnol, "o último cadastrado fica escolhido")
	roster.current = 0
	Career.current(roster).cases = 4
	check(Career.save_roster(roster, path), "salvou o fichário")
	var loaded := Career.load_roster(path, legacy)
	check(loaded.agents.size() == 2 and Career.current(loaded).name == "Moro", "fichário lido com o agente escolhido")
	check(Career.current(loaded).cases == 4, "mexer no agente escolhido mexe no fichário: %s" % [loaded])
	Career.remove(loaded, 0)
	check(loaded.current == -1 and loaded.agents[0].name == "Dallagnol", "apagar o escolhido não deixa ninguém escolhido")
	for i in Career.MAX_AGENTS:
		Career.add(loaded, Career.fresh("A%d" % i))
	check(loaded.agents.size() == Career.MAX_AGENTS, "o fichário tem limite")
	Career.erase(path)
	var f := FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string(JSON.stringify(moro))
	f.close()
	var migrated := Career.load_roster(path, legacy)
	check(migrated.agents.size() == 1 and Career.current(migrated) == moro, "save antigo vira o primeiro agente")
	check(FileAccess.file_exists(path) and not FileAccess.file_exists(legacy), "save antigo trocado pelo fichário")
	Career.erase(path)


## Um caso salvo no meio e refeito a partir da semente e das ações fica igual ao original.
func _test_saved_case(pack: ContentPack) -> void:
	var path := "user://test_case.json"
	var agent := {"name": "Moro", "cases": 2, "rank": 1, "caught": []}
	var s := CaseSession.new(pack, 4242)
	s.start(agent)
	s.investigate(0)
	var wrong: Array = s.destinations().filter(func(c): return c != s.next_city)
	if not wrong.is_empty():
		s.travel(wrong[0])
		s.investigate(1)
		s.travel(s.destinations()[0])
	s.issue_warrant({pack.rules.sex_trait: s.suspect.traits[pack.rules.sex_trait]})
	check(s.outcome == CaseSession.ONGOING, "caso de teste ainda em andamento")
	var roster := Career.empty_roster()
	Career.add(roster, agent.duplicate(true))
	Career.current(roster).case = s.save_state()
	Career.current(roster).case.marks = {"sex": "f"}
	check(Career.save_roster(roster, path), "salvou o fichário com caso")
	var loaded := Career.current(Career.load_roster(path, ""))
	Career.erase(path)
	check(loaded.has("case") and loaded.case.marks == {"sex": "f"}, "o caso volta junto com o agente")
	var saved: Dictionary = loaded.case
	loaded.erase("case")
	var t := CaseSession.new(pack, int(saved.seed))
	t.start(loaded)
	check(t.replay(saved.actions), "refez as ações salvas")
	check(t.current_city == s.current_city and t.next_city == s.next_city and t.steps_left == s.steps_left,
		"mesma cidade e mesma rota depois de refazer")
	check(t.clock.day == s.clock.day and t.clock.hour == s.clock.hour and t.budget == s.budget,
		"mesmo relógio e mesma verba depois de refazer")
	check(t.warrant_id == s.warrant_id and t.rng.seed == s.rng.seed, "mesmo mandado e mesmo sorteio depois de refazer")
	check(range(t.places.size()).all(func(i): return t.place_text(i) == s.place_text(i)), "mesmas testemunhas depois de refazer")
	var u := CaseSession.new(pack, int(saved.seed))
	u.start(loaded)
	check(not u.replay([["travel", "nowhere"]]), "ação que não cabe no caso invalida o save")


## Na paródia, busca e mandado custam horas; pedido ambíguo conta como busca.
func _test_warrant_hours() -> void:
	var pack := ContentPack.load_dir(PARODY_DIR, "pt_BR")
	var rules: Dictionary = pack.rules.warrant
	var s := CaseSession.new(pack, 7)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	var start := s.clock.day * 24 + s.clock.hour
	var r := s.search({})
	check(r.hours == int(rules.search_hours) and r.matches.size() == pack.suspects.size(), "busca sem traços lista todos e custa horas")
	r = s.issue_warrant({})
	check(not r.issued and r.hours == int(rules.search_hours) and s.warrant_id == "", "mandado ambíguo conta como busca")
	var marks := {}
	for t in pack.warrant_traits():
		marks[t.id] = s.suspect.traits[t.id]
	r = s.issue_warrant(marks)
	check(r.issued and r.hours == int(rules.issue_hours) and s.warrant_id == s.suspect.id, "mandado certo sai e custa mais horas")
	var spent := s.clock.day * 24 + s.clock.hour - start
	check(spent == 2 * int(rules.search_hours) + int(rules.issue_hours), "o relógio andou as horas do mandado: %d" % spent)
	var t := CaseSession.new(pack, 7)
	t.start({"name": "Teste", "cases": 0, "rank": 0})
	check(t.replay(s.actions) and t.warrant_id == s.warrant_id and t.clock.hour == s.clock.hour, "busca e mandado refeitos no replay")


## Scripts que os testes não usam direto também precisam compilar.
func _test_scripts_compile() -> void:
	for path in ["res://ui/main.gd", "res://ui/screens/dossier_screen.gd"]:
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "script não compila: " + path)
