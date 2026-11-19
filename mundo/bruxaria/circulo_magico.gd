@tool
class_name CirculoMagico
extends Node2D
## Círculo de invocação desenhado no chão (pixel art): duas elipses, um
## pentagrama, runas entre as elipses e velas nas pontas da estrela.
## As linhas pulsam devagar e as chamas das velas tremem. Não tem colisão:
## o Pai e os monstros andam por cima. Brilha no escuro (material Unshaded).
## A posição do nó é o centro do círculo. Use z_index -1 para ficar no chão.

## Raio horizontal em px. O vertical é raio x `achatamento` (chão visto de cima, meio de lado).
@export_range(8, 48) var raio := 18:
	set(v):
		raio = v
		queue_redraw()
@export_range(0.4, 1.0) var achatamento := 0.7:
	set(v):
		achatamento = v
		queue_redraw()
@export var cor := Color(0.72, 0.45, 1.0):
	set(v):
		cor = v
		queue_redraw()
## Velas nas 5 pontas da estrela.
@export var velas := true:
	set(v):
		velas = v
		queue_redraw()
## Pulsos por segundo do brilho das linhas.
@export var velocidade_pulso := 0.6

const QUADROS_POR_SEGUNDO := 12.0
const COR_VELA := Color(0.93, 0.88, 0.76)
const COR_VELA_SOMBRA := Color(0.62, 0.55, 0.47)
const COR_CHAMA := Color(1.0, 0.86, 0.42)
const COR_CHAMA_PONTA := Color(1.0, 0.55, 0.2)

var _t := 0.0
var _acumulado := 0.0
var _chamas: PackedInt32Array = [2, 1, 2, 2, 1]


func _ready() -> void:
	if material == null:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	_acumulado += delta
	if _acumulado >= 1.0 / QUADROS_POR_SEGUNDO:
		_acumulado = 0.0
		for i in _chamas.size():
			if randf() < 0.35:
				_chamas[i] = 1 + randi() % 2
		queue_redraw()


func _draw() -> void:
	var brilho := 0.75 + 0.25 * sin(_t * TAU * velocidade_pulso)
	var linha := Color(cor, 0.55 + 0.35 * brilho)
	var forte := Color(cor.lightened(0.25), 0.7 + 0.3 * brilho)
	var rx := raio
	var ry := maxi(4, roundi(raio * achatamento))
	var rx_in := rx - 3
	var ry_in := maxi(3, ry - 2)
	for p in _elipse(rx, ry):
		_px(p, linha)
	for p in _elipse(rx_in, ry_in):
		_px(p, linha)
	# runas: tracinhos entre as duas elipses
	for i in 10:
		var a := TAU * (i + 0.5) / 10.0
		var meio := Vector2(cos(a) * (rx - 1.5), sin(a) * (ry - 1.0))
		var p := Vector2i(roundi(meio.x), roundi(meio.y))
		if i % 2 == 0:
			_px(p, forte)
			_px(p + Vector2i(1, 0), forte)
		else:
			_px(p, forte)
			_px(p + Vector2i(0, -1), forte)
	# pentagrama (pontas na elipse de dentro, uma para cima)
	var pontas: Array[Vector2i] = []
	for k in 5:
		var a := -PI / 2.0 + TAU * k / 5.0
		pontas.append(Vector2i(roundi(cos(a) * rx_in), roundi(sin(a) * ry_in)))
	for k in 5:
		for p in _reta(pontas[k], pontas[(k + 2) % 5]):
			_px(p, forte)
	if not velas:
		return
	# velas nas pontas da estrela, por fora
	for k in 5:
		var a := -PI / 2.0 + TAU * k / 5.0
		var base := Vector2i(roundi(cos(a) * (rx + 2)), roundi(sin(a) * (ry + 2)))
		draw_rect(Rect2(base.x, base.y - 3, 2, 3), COR_VELA)
		draw_rect(Rect2(base.x + 1, base.y - 3, 1, 3), COR_VELA_SOMBRA)
		var h := _chamas[k] if not Engine.is_editor_hint() else 2
		draw_rect(Rect2(base.x, base.y - 3 - h, 1, h), COR_CHAMA)
		draw_rect(Rect2(base.x, base.y - 4 - h, 1, 1), COR_CHAMA_PONTA)


func _px(p: Vector2i, c: Color) -> void:
	draw_rect(Rect2(p.x, p.y, 1, 1), c)


## Pontos de uma elipse de 1 px (algoritmo do ponto médio).
func _elipse(rx: int, ry: int) -> Array[Vector2i]:
	var pts := {}
	var rx2 := float(rx * rx)
	var ry2 := float(ry * ry)
	var x := 0
	var y := ry
	var dx := 0.0
	var dy := 2.0 * rx2 * y
	var p := ry2 - rx2 * ry + 0.25 * rx2
	while dx < dy:
		_quatro(pts, x, y)
		x += 1
		dx += 2.0 * ry2
		if p < 0.0:
			p += ry2 + dx
		else:
			y -= 1
			dy -= 2.0 * rx2
			p += ry2 + dx - dy
	p = ry2 * (x + 0.5) * (x + 0.5) + rx2 * (y - 1) * (y - 1) - rx2 * ry2
	while y >= 0:
		_quatro(pts, x, y)
		y -= 1
		dy -= 2.0 * rx2
		if p > 0.0:
			p += rx2 - dy
		else:
			x += 1
			dx += 2.0 * ry2
			p += rx2 - dy + dx
	var out: Array[Vector2i] = []
	for k in pts:
		out.append(k)
	return out


func _quatro(pts: Dictionary, x: int, y: int) -> void:
	pts[Vector2i(x, y)] = true
	pts[Vector2i(-x, y)] = true
	pts[Vector2i(x, -y)] = true
	pts[Vector2i(-x, -y)] = true


## Pontos de uma reta de 1 px (Bresenham).
func _reta(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		out.append(p)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return out
