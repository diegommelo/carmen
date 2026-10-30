class_name WorldGraph
extends RefCounted
## Mapa de voos sorteado a cada partida (1fb4:00b6).
## Cada cidade ganha até `max_links` ligações, e só se liga a cidades que
## não estão a `min_hops` saltos ou menos no grafo já montado.

## id da cidade -> Array de ids vizinhos, na ordem em que foram ligados.
var links: Dictionary = {}


static func generate(city_ids: Array, rng: MscRng, max_links: int, min_hops: int) -> WorldGraph:
	var g := WorldGraph.new()
	for id in city_ids:
		g.links[id] = []
	var n := city_ids.size()
	for round_limit in range(1, max_links + 1):
		for ai in n:
			var a = city_ids[ai]
			if g.degree(a) >= round_limit:
				continue
			var start := (ai + rng.roll(n)) % n
			for step in n:
				var b = city_ids[(start + step) % n]
				if g.degree(b) < round_limit and not g.within_hops(a, b, min_hops):
					g.link(a, b)
					break
	return g


func link(a, b) -> void:
	links[a].append(b)
	links[b].append(a)


func degree(id) -> int:
	return links[id].size()


func neighbors(id) -> Array:
	return links[id]


## Verdadeiro se `b` está a até `depth` saltos de `a` (inclui a própria cidade).
func within_hops(a, b, depth: int) -> bool:
	if a == b:
		return true
	if depth == 0:
		return false
	for n in links[b]:
		if within_hops(a, n, depth - 1):
			return true
	return false
