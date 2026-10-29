class_name MscRng
extends RefCounted
## Gerador aleatório do Microsoft C usado pelo jogo original (2356:0a89).
## semente = semente * 214013 + 2531011 (32 bits); roll(n) = (semente >> 16) mod (n + 1).

var seed: int = 0


func _init(initial_seed: int = 0) -> void:
	seed = initial_seed & 0xFFFFFFFF


## Número inteiro de 0 a n, inclusive, como no original.
func roll(n: int) -> int:
	seed = (seed * 214013 + 2531011) & 0xFFFFFFFF
	return ((seed >> 16) & 0xFFFF) % (n + 1)


## Elemento aleatório de um Array (vazio devolve null).
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[index(items)]


func index(items: Array) -> int:
	return roll(items.size() - 1)
