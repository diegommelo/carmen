class_name TravelMap
extends Control
## Mapa-múndi provisório da viagem: só grade e pontos, na escala do campo `map` das
## cidades (x de 0 a ~300, y de 0 a ~100). Mostra a cidade atual, os destinos com nome e
## o caminho já feito, e anima o avião até o destino escolhido.

signal flight_finished

const MAP_SIZE := Vector2(300, 100)
const FLIGHT_SECONDS := 1.2

var _points: Dictionary = {}
var _names: Dictionary = {}
var _current := ""
var _destinations: Array = []
var _route: Array = []
var _highlight := ""
var _plane := Vector2.INF
## Retângulos dos nomes já desenhados neste quadro, para os próximos não caírem por cima.
var _taken: Array[Rect2] = []


## `points` e `names` vão de id da cidade para posição no mapa e nome; `route` é a
## sequência de cidades já visitadas no caso, da primeira à atual.
func setup(points: Dictionary, names: Dictionary, current: String, destinations: Array, route: Array) -> void:
	_points = points
	_names = names
	_current = current
	_destinations = destinations
	_route = route
	queue_redraw()


func highlight(id: String) -> void:
	_highlight = id
	queue_redraw()


func fly(to_id: String) -> void:
	_highlight = to_id
	var tween := create_tween()
	tween.tween_method(_move_plane.bind(_points[_current], _points[to_id]), 0.0, 1.0, FLIGHT_SECONDS)
	tween.finished.connect(func(): flight_finished.emit())


func _move_plane(t: float, from: Vector2, to: Vector2) -> void:
	_plane = from.lerp(to, t)
	queue_redraw()


func _scale() -> float:
	return minf(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)


## Converte uma posição do mapa em pixels deste controle, com o mapa centralizado.
func _at(map_pos: Vector2) -> Vector2:
	var k := _scale()
	var offset := (size - MAP_SIZE * k) / 2.0
	return (offset + map_pos * k).round()


func _draw() -> void:
	_taken.clear()
	var k := _scale()
	var origin := _at(Vector2.ZERO)
	draw_rect(Rect2(origin, MAP_SIZE * k), Palette.INK)
	for x in range(0, int(MAP_SIZE.x) + 1, 30):
		draw_line(_at(Vector2(x, 0)), _at(Vector2(x, MAP_SIZE.y)), Palette.PANEL)
	for y in range(0, int(MAP_SIZE.y) + 1, 25):
		draw_line(_at(Vector2(0, y)), _at(Vector2(MAP_SIZE.x, y)), Palette.PANEL)
	for id in _points:
		_dot(id, Palette.PANEL_BORDER, 1)
	for i in range(1, _route.size()):
		draw_line(_at(_points[_route[i - 1]]), _at(_points[_route[i]]), Palette.TEXT_DIM)
	for id in _destinations:
		var color := Palette.HIGHLIGHT if id == _highlight else Palette.PANEL_BORDER
		draw_line(_at(_points[_current]), _at(_points[id]), color)
	for id in _destinations:
		_dot(id, Palette.HIGHLIGHT if id == _highlight else Palette.TEXT, 2)
		_name(id, Palette.HIGHLIGHT if id == _highlight else Palette.TEXT)
	_dot(_current, Palette.OK, 3)
	_name(_current, Palette.OK)
	if _plane != Vector2.INF:
		draw_rect(Rect2(_at(_plane) - Vector2(3, 3), Vector2(6, 6)), Palette.HIGHLIGHT)


func _dot(id: String, color: Color, radius: int) -> void:
	draw_rect(Rect2(_at(_points[id]) - Vector2(radius, radius), Vector2(radius, radius) * 2), color)


## Nome ao lado do ponto: tenta à direita, acima, abaixo e à esquerda, e fica com a
## primeira posição que não cobre outro nome nem sai do mapa.
func _name(id: String, color: Color) -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var text: String = _names[id]
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var dot := _at(_points[id])
	var tries := [Vector2(6, -4), Vector2(6, -14), Vector2(6, 6), Vector2(-6 - text_size.x, -4)]
	var box := Rect2(dot + tries[0], text_size)
	for offset in tries:
		var candidate := Rect2(dot + offset, text_size)
		if Rect2(Vector2.ZERO, size).encloses(candidate) and not _taken.any(func(r): return r.intersects(candidate)):
			box = candidate
			break
	_taken.append(box)
	draw_string(font, box.position + Vector2(0, font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
