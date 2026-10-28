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
	for seed in range(1, 41):
		_test_full_case(pack, seed)
	_test_wrong_city(pack)
	_test_boss(pack)
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
		for p in s.places:
			check(not p.text.contains("{"), "pronome sem substituir: " + p.text)
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
	for p in s.places:
		var type := pack.location_type(p.type)
		check(p.text in type.not_seen, "fora da rota a testemunha não viu nada: " + p.text)


func _test_boss(pack: ContentPack) -> void:
	var s := CaseSession.new(pack, 5)
	s.start({"name": "Teste", "cases": 29, "rank": 4})
	check(s.suspect.get("boss", false), "com 29 casos o alvo é a chefe")
	check(s.steps_left == 4 + 4 - 1, "rota de patente + 4 saltos")
