extends SceneTree
## Testes do núcleo. Rodar com:
##   godot --headless --path game -s res://tests/run_tests.gd

const PACK_DIR := "res://content/placeholder"

var _failures := 0
var _checks := 0


func _initialize() -> void:
	var pack := ContentPack.load_dir(PACK_DIR)
	_test_rng()
	_test_clock(pack)
	_test_graph(pack)
	_test_warrant(pack)
	_test_languages(pack)
	for language in pack.languages:
		pack.set_language(language)
		for seed in range(1, 41):
			_test_full_case(pack, seed)
		_test_wrong_city(pack)
	pack.set_language("pt_BR")
	_test_switch_language_mid_case(pack)
	_test_boss(pack)
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
	check(s.compute_warrant({}).size() == pack.suspects.size(), "sem traços, todos são suspeitos")
	check(s.warrant_id == "", "sem traços não sai mandado")
	var marks := {}
	for t in pack.warrant_traits():
		marks[t.id] = s.suspect.traits[t.id]
	var m := s.compute_warrant(marks)
	check(m.size() == 1 and s.warrant_id == s.suspect.id, "todos os traços identificam o suspeito")


## Um "agente perfeito" segue a rota, emite o mandado certo e prende o suspeito.
func _test_full_case(pack: ContentPack, seed: int) -> void:
	var s := CaseSession.new(pack, seed)
	s.start({"name": "Teste", "cases": 0, "rank": 0})
	var hops := 0
	var marks := {}
	for t in pack.warrant_traits():
		marks[t.id] = s.suspect.traits[t.id]
	s.compute_warrant(marks)
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
	check(hops == pack.rules.route_base_steps, "rota de %d saltos (semente %d deu %d)" % [pack.rules.route_base_steps, seed, hops])
	var r := {}
	for slot in 3:
		r = s.investigate(slot)
		if r.event == "capture" or s.outcome != CaseSession.ONGOING:
			break
	check(r.event == "capture", "achou o esconderijo (semente %d)" % seed)
	check(s.outcome == CaseSession.ARRESTED, "prendeu com mandado certo (semente %d): %s" % [seed, s.outcome])
	check(s.detective.cases == 1 and s.promoted and s.detective.rank == 1, "ganhou um caso e foi promovido")


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


func _test_languages(pack: ContentPack) -> void:
	check(pack.missing_translations().is_empty(), "textos sem tradução: %s" % [pack.missing_translations()])
	check(pack.best_language("en_US") == "en", "en_US usa inglês")
	check(pack.best_language("pt") == "pt_BR", "pt usa pt_BR")
	check(pack.best_language("fr_FR") == pack.default_language, "idioma desconhecido usa o padrão")
	pack.set_language("en")
	check(pack.city("toquio").name == "Tokyo", "nome da cidade em inglês")
	check(typeof(pack.location_types[0].name) == TYPE_STRING, "texto traduzido virou String")
	pack.set_language("pt_BR")
	check(pack.city("toquio").name == "Tóquio", "nome da cidade em português")


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


## Scripts que os testes não usam direto também precisam compilar.
func _test_scripts_compile() -> void:
	for path in ["res://ui/main.gd"]:
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "script não compila: " + path)
