@tool
class_name Escada
extends Node2D
## Escada entre andares. Quando o Pai chega no pé da escada e anda na direção
## de subir, ele passa a andar POR CIMA dos degraus seguindo `caminho`
## (o jogador controla: cima sobe, baixo desce). No topo ele some no escuro,
## a tela escurece e o jogo carrega o andar de destino.
##
## No andar de destino, a escada com id == `chegada_no_destino` faz o caminho
## inverso: o Pai aparece no topo e desce os degraus sozinho.
##
## Selecione o nó no editor para ver o caminho (linha laranja) e a área do pé.

@export var id := ""
@export_file("*.tscn") var destino := ""
## id da escada onde o Pai aparece no andar de destino.
@export var chegada_no_destino := ""
## Pontos por onde os PÉS do Pai passam, em pixels locais.
## [0] = chão no pé da escada ... último = topo, onde ele some.
@export var caminho := PackedVector2Array():
	set(v):
		caminho = v
		queue_redraw()
## Onde o Pai precisa estar para começar a subir (local).
@export var area_pe := Rect2(-12, -8, 24, 16):
	set(v):
		area_pe = v
		queue_redraw()
## Direção do controle que significa "subir" nesta escada.
@export var direcao_subir := Vector2(0, -1)
## Velocidade em pixels por segundo ao longo dos degraus.
@export var velocidade := 30.0
## Parte final do caminho (0–1) em que o Pai vai sumindo no escuro.
@export_range(0.05, 0.9) var trecho_que_some := 0.3
## Animação do Pai ao avançar no caminho ("up" para escada que sobe,
## "down" para escada que desce). Ao voltar, usa a oposta.
@export_enum("up", "down") var animacao_avancar := "up"
## Nó (ex.: um TileMapLayer com o chão) que aparece POR CIMA do Pai só enquanto
## ele está na escada, para ele sumir atrás da borda de um poço que desce.
@export var cobertura: NodePath
## Mostrada se não houver destino (ex.: andar ainda não feito).
@export var mensagem_sem_destino := "Esta escada ainda não leva a lugar nenhum."

const PES := 0.0  # a origem do Pai já fica nos pés

var _pai  # o Pai (sem tipo para acessar as funções do pai.gd)
var _no_pe := false
var _subindo := false
var _chegando := false
var _saindo := false
var _t := 0.0
var _avisou := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("escadas")
	var area := Area2D.new()
	area.collision_layer = 0
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = area_pe.size
	cs.shape = shape
	cs.position = area_pe.get_center()
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_pe_entrou)
	area.body_exited.connect(_on_pe_saiu)


func _on_pe_entrou(body: Node) -> void:
	if body.is_in_group("player"):
		_pai = body
		_no_pe = true


func _on_pe_saiu(body: Node) -> void:
	if body.is_in_group("player"):
		_no_pe = false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or caminho.size() < 2 or _saindo:
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var subir := input.dot(direcao_subir.normalized())

	if _chegando:
		_t -= velocidade * delta
		if _t <= 0.0:
			_t = 0.0
			_chegando = false
			_soltar()
			return
		_posicionar(true, false)
		return

	if not _subindo:
		if _no_pe and _pai and subir > 0.5:
			_comecar()
		return

	if absf(subir) > 0.3:
		_t += signf(subir) * velocidade * delta
	var total := _comprimento()
	var limite := total if destino != "" else total * (1.0 - trecho_que_some)
	if _t >= limite:
		_t = limite
		if destino != "":
			_saindo = true
			Jogo.trocar_andar(destino, chegada_no_destino)
		elif not _avisou:
			_avisou = true
			Jogo.mostrar_mensagem(mensagem_sem_destino)
	if _t <= 0.0:
		_t = 0.0
		_soltar()
		return
	_posicionar(absf(subir) > 0.3, subir > 0.0)


## Chamado pelo andar quando o Pai veio por esta escada.
func chegar(pai) -> void:
	_pai = pai
	_pegar()
	_t = _comprimento()
	_chegando = true
	_posicionar(true, false)


func _comecar() -> void:
	_pegar()
	_subindo = true
	_avisou = false
	_t = 0.0


func _pegar() -> void:
	_mostrar_cobertura(true)
	_pai.controle_externo = true
	_pai.velocity = Vector2.ZERO
	_pai.set_colisao(false)


func _mostrar_cobertura(sim: bool) -> void:
	var c := get_node_or_null(cobertura)
	if c:
		c.visible = sim


func _soltar() -> void:
	_mostrar_cobertura(false)
	_subindo = false
	_pai.controle_externo = false
	_pai.set_colisao(true)
	_pai.modulate = Color.WHITE
	_pai.global_position = to_global(caminho[0]) - Vector2(0, PES)


func _posicionar(andando: bool, para_cima: bool) -> void:
	var p := _ponto_em(_t)
	_pai.global_position = to_global(p) - Vector2(0, PES)
	var total := _comprimento()
	var inicio_sumir := total * (1.0 - trecho_que_some)
	var k := clampf((_t - inicio_sumir) / max(total - inicio_sumir, 0.001), 0.0, 1.0)
	var luz := 1.0 - 0.7 * k
	_pai.modulate = Color(luz, luz, luz, 1.0 - k)
	var volta := "down" if animacao_avancar == "up" else "up"
	_pai.animar(animacao_avancar if para_cima or not andando else volta, andando)


func _comprimento() -> float:
	var total := 0.0
	for i in range(1, caminho.size()):
		total += caminho[i - 1].distance_to(caminho[i])
	return total


func _ponto_em(dist: float) -> Vector2:
	for i in range(1, caminho.size()):
		var seg := caminho[i - 1].distance_to(caminho[i])
		if dist <= seg:
			return caminho[i - 1].lerp(caminho[i], dist / max(seg, 0.001))
		dist -= seg
	return caminho[caminho.size() - 1]


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(area_pe, Color(0.2, 1, 0.4, 0.25))
	draw_rect(area_pe, Color(0.2, 1, 0.4, 0.9), false, 1.0)
	if caminho.size() >= 2:
		draw_polyline(caminho, Color(1, 0.6, 0.1), 1.5)
		for p in caminho:
			draw_circle(p, 2.0, Color(1, 0.6, 0.1))
