@tool
class_name CaldeiraoBruxa
extends Sprite2D
## Caldeirão da bruxa: desenha a poção borbulhando na boca do caldeirão
## (Medieval Free Pack, recorte Rect2(211, 100, 26, 16) com offset (0, -8),
## origem na base). Bolhas estouram na superfície e um vapor sobe.
## A colisão é o filho Colisao; a luz verde é o filho Luz.

@export var cor_pocao := Color(0.42, 0.92, 0.32):
	set(v):
		cor_pocao = v
		queue_redraw()
## Centro da superfície da poção, em px a partir da base do caldeirão.
@export var centro := Vector2i(0, -11)

const QUADROS_POR_SEGUNDO := 10.0
## Meia largura de cada linha da superfície, de cima para baixo.
const LINHAS := [4, 6, 7, 7, 6, 4]

var _t := 0.0
var _acumulado := 0.0


func _ready() -> void:
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	_acumulado += delta
	if _acumulado >= 1.0 / QUADROS_POR_SEGUNDO:
		_acumulado = 0.0
		queue_redraw()


func _draw() -> void:
	var escura := cor_pocao.darkened(0.45)
	var media := cor_pocao.darkened(0.15)
	var clara := cor_pocao.lightened(0.45)
	var topo := centro.y - 2
	# superfície: a linha de cima fica na sombra da borda do fundo
	for i in LINHAS.size():
		var y: int = topo + i
		var hw: int = LINHAS[i]
		var c := escura if i == 0 else (media if i == LINHAS.size() - 1 else cor_pocao)
		draw_rect(Rect2(centro.x - hw, y, hw * 2, 1), c)
	# reflexo que anda devagar
	var rx := int(fposmod(_t * 3.0, 9.0)) - 4
	draw_rect(Rect2(centro.x + rx, topo + 2, 2, 1), clara)
	# bolhas: crescem na superfície e estouram
	for i in 3:
		var fase := fposmod(_t * 0.9 + i * 0.37, 1.0)
		var bx: int = centro.x + [-4, 2, -1][i]
		var by: int = topo + [3, 2, 4][i]
		if fase < 0.45:
			draw_rect(Rect2(bx, by, 1, 1), clara)
		elif fase < 0.7:
			draw_rect(Rect2(bx - 1, by, 1, 1), clara)
			draw_rect(Rect2(bx + 1, by, 1, 1), clara)
			draw_rect(Rect2(bx, by - 1, 1, 1), clara)
			draw_rect(Rect2(bx, by, 1, 1), escura)
	# vapor: pontinhos que sobem e somem
	for i in 4:
		var fase := fposmod(_t * 0.55 + i * 0.25, 1.0)
		var vx: int = centro.x + [-3, 1, 4, -1][i] + roundi(sin((_t + i) * 3.0))
		var vy: int = topo - 1 - roundi(fase * 10.0)
		draw_rect(Rect2(vx, vy, 1, 1), Color(clara, 0.75 * (1.0 - fase)))
