extends SceneTree
## Simulação de balanceamento da paródia. Rodar com:
##   godot --headless --path game -s res://tests/balance_sim.gd -- 0,0.4 4,0.4
## Cada argumento é "patente,taxa_de_voo_errado[,verba]"; sem verba vale a do pacote.
## O agente simulado investiga os três locais de cada cidade da rota, emite o mandado
## assim que os traços ouvidos bastam e, com a taxa dada, voa antes para uma cidade
## errada e volta.

const PACK_DIR := "res://content/parody"
const CASES := 1000


func _initialize() -> void:
	var pack := ContentPack.load_dir(PACK_DIR)
	for spec in OS.get_cmdline_user_args():
		var p := spec.split(",")
		_simulate(pack, int(p[0]), float(p[1]), int(p[2]) if p.size() > 2 else -2)
	quit()


func _simulate(pack: ContentPack, rank: int, wrong_rate: float, budget: int) -> void:
	var broke := 0
	var spent := []
	var warrants := 0
	var arrests := 0
	var shortcuts := 0
	var hours := []
	for seed in range(1, CASES + 1):
		var s := CaseSession.new(pack, seed)
		var dice := MscRng.new(seed * 7 + 3)
		s.start({"name": "Sim", "cases": pack.ranks[rank].cases, "caught": []})
		if budget != -2:
			s.budget = budget
		var start_budget := s.budget
		var marks := {}
		var issued := false
		while not s.is_final_city() and s.outcome == CaseSession.ONGOING:
			for i in s.places.size():
				var st: Dictionary = s.places[i].statement
				s.investigate(i)
				if st.kind == "trail" and st.trait != "" and st.trait_i >= 0:
					marks[st.trait] = s.suspect.traits[st.trait]
				if s.outcome != CaseSession.ONGOING:
					break
			if s.outcome != CaseSession.ONGOING:
				break
			if not issued:
				var warrant_marks := {}
				for t in pack.warrant_traits():
					if marks.has(t.id):
						warrant_marks[t.id] = marks[t.id]
				issued = s.issue_warrant(warrant_marks).issued
			if dice.roll(999) < int(wrong_rate * 1000.0):
				var others := s.destinations().filter(func(d): return d != s.next_city)
				if not others.is_empty() and s.can_afford(others[0]):
					var back := s.current_city
					s.travel(others[0])
					if s.outcome == CaseSession.ONGOING:
						s.investigate(0)
					if s.outcome == CaseSession.ONGOING and s.can_afford(back):
						s.travel(back)
					if s.outcome != CaseSession.ONGOING or s.current_city != back:
						break
			if not s.can_afford(s.next_city):
				break
			if s.travel(s.next_city).get("shortcut", false):
				shortcuts += 1
		warrants += 1 if issued else 0
		for slot in 3:
			if s.outcome != CaseSession.ONGOING:
				break
			s.investigate(slot)
		arrests += 1 if s.outcome == CaseSession.ARRESTED else 0
		broke += 1 if s.outcome == CaseSession.OUT_OF_MONEY or (s.outcome == CaseSession.ONGOING and not s.is_final_city()) else 0
		spent.append(start_budget - s.budget)
		if s.outcome != CaseSession.ESCAPED_TIME:
			hours.append(s.clock.day * 24 + s.clock.hour - int(pack.rules.clock.start_hour))
	hours.sort()
	spent.sort()
	var median = hours[hours.size() / 2] if not hours.is_empty() else -1
	print("patente %d, voo errado %.0f%%: mandado %.0f%%, presos %.0f%%, horas (mediana) %s, atalhos %d, sem verba %.0f%%, gasto mediano %d, p90 %d" % [
		rank, wrong_rate * 100.0, 100.0 * warrants / CASES, 100.0 * arrests / CASES, median, shortcuts,
		100.0 * broke / CASES, spent[CASES / 2], spent[CASES * 9 / 10]])
