class_name Telhado
extends Node2D
## Telhado que cobre uma sala ainda não visitada (no lugar do bloco preto).
## Desenha, sobre os retângulos da névoa da sala.gd, os tiles de teto do mesmo
## pacote das paredes: miolo escuro e borda de pedra em volta.

const TEX := preload("res://assets/tile/PNG/walls_floor.png")
const TAM := 16
## Quanto o fundo passa das bordas (as paredes não encostam no chão da sala).
const FRESTA := 4.0
## Camada de luz própria: só a luz do Pai (Visao, no pai.tscn) ilumina o telhado.
## Assim as tochas e a luz do filho não denunciam o que está embaixo.
const CAMADA_LUZ := 4

var _celulas := {}


func montar(retangulos: Array[Rect2]) -> void:
	light_mask = CAMADA_LUZ
	for r in retangulos:
		var a := Vector2i((r.position / TAM).floor())
		var b := Vector2i((r.end / TAM).ceil())
		for y in range(a.y, b.y):
			for x in range(a.x, b.x):
				_celulas[Vector2i(x, y)] = true
	queue_redraw()


func _draw() -> void:
	var miolo := Rect2(Vector2(TAM, TAM), Vector2(TAM, TAM))
	# fundo: tampa os pixels transparentes da borda e a fresta até as paredes
	for c: Vector2i in _celulas:
		var fundo := Rect2(Vector2(c * TAM), Vector2(TAM, TAM))
		fundo = fundo.grow_individual(FRESTA, 0, FRESTA, FRESTA)
		draw_texture_rect_region(TEX, fundo, miolo)
	for c: Vector2i in _celulas:
		var destino := Rect2(Vector2(c * TAM), Vector2(TAM, TAM))
		draw_texture_rect_region(TEX, destino, Rect2(Vector2(_tile(c) * TAM), Vector2(TAM, TAM)))


func _tem(c: Vector2i, dx: int, dy: int) -> bool:
	return _celulas.has(c + Vector2i(dx, dy))


## Tile da célula conforme os vizinhos: (0..2, 0..2) é o teto com borda por fora;
## (3, 0), (5, 0), (3, 3) e (5, 3) são os cantos de dentro (salas em L).
func _tile(c: Vector2i) -> Vector2i:
	var t := Vector2i(1, 1)
	if not _tem(c, -1, 0):
		t.x = 0
	elif not _tem(c, 1, 0):
		t.x = 2
	if not _tem(c, 0, -1):
		t.y = 0
	elif not _tem(c, 0, 1):
		t.y = 2
	if t != Vector2i(1, 1):
		return t
	if not _tem(c, 1, 1):
		return Vector2i(3, 0)
	if not _tem(c, -1, 1):
		return Vector2i(5, 0)
	if not _tem(c, 1, -1):
		return Vector2i(3, 3)
	if not _tem(c, -1, -1):
		return Vector2i(5, 3)
	return t
