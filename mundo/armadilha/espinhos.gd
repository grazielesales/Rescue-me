@tool
class_name Espinhos
extends Node2D
## Armadilha de espinhos no chão (arte: assets/tile/Tiled_files/trap_animation.png).
## Fica recolhida um tempo, avisa (as pontas aparecem), sobe e machuca o Pai que
## estiver em cima, desce e recomeça. Só o Pai se machuca; monstros passam por cima.
##
## A posição do nó é o canto superior esquerdo da área, e `tamanho` é a área em
## tiles de 16 px (mínimo 2 x 2). No editor ela aparece com as pontas de fora e
## um contorno vermelho.

const FOLHA := preload("res://assets/tile/Tiled_files/trap_animation.png")
const TILE := 16
## Colunas da folha: borda esquerda, meio e borda direita do bloco.
const COL_ESQ := 5
const COL_MEIO := 6
const COL_DIR := 7
## Linhas da folha no quadro 0: sobra das pontas (acima do bloco), topo, meio e base.
const LIN_SOBRA := 1
const LIN_TOPO := 2
const LIN_MEIO := 3
const LIN_BASE := 5
## Cada quadro da animação fica 6 linhas abaixo do anterior na folha.
const PASSO_QUADRO := 6
## A partir deste quadro os espinhos estão de fora e machucam.
const QUADRO_PERIGO := 3
## Duração de cada quadro de subida e descida (s).
const TEMPO_QUADRO := 0.08

@export var tamanho := Vector2i(3, 2):
	set(v):
		tamanho = Vector2i(maxi(2, v.x), maxi(2, v.y))
		queue_redraw()
@export var dano := 1
## Segundos recolhida: dá para passar.
@export var tempo_recolhida := 1.6
## Segundos com as pontas aparecendo, antes de subir.
@export var tempo_aviso := 0.5
## Segundos erguida: machuca.
@export var tempo_erguida := 0.7
## Atraso antes do primeiro ciclo, para armadilhas vizinhas não subirem juntas.
@export var atraso := 0.0

var _quadro := 0
var _t := 0.0
var _area: Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_t = -atraso
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitorable = false
	var cs := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(tamanho * TILE) - Vector2(6, 6)
	cs.shape = forma
	cs.position = Vector2(tamanho * TILE) / 2.0
	_area.add_child(cs)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var novo := _quadro_no_tempo(_t)
	if novo != _quadro:
		_quadro = novo
		queue_redraw()
	if _quadro < QUADRO_PERIGO:
		return
	for corpo in _area.get_overlapping_bodies():
		if corpo.is_in_group("player") and corpo.has_method("levar_dano"):
			# o empurrão sai do centro da armadilha: o Pai é jogado para fora dela
			corpo.levar_dano(dano, global_position + Vector2(tamanho * TILE) / 2.0)


## Espinhos de fora agora? (para sons ou outros sistemas)
func erguida() -> bool:
	return _quadro >= QUADRO_PERIGO


## Quadro da animação `t` segundos depois do começo:
## recolhida (0) -> aviso (1, 2) -> sobe (3) -> erguida (4) -> desce (3, 2, 1).
func _quadro_no_tempo(t: float) -> int:
	if t < 0.0:
		return 0
	var ciclo := tempo_recolhida + tempo_aviso + tempo_erguida + TEMPO_QUADRO * 4.0
	t = fmod(t, ciclo)
	if t < tempo_recolhida:
		return 0
	t -= tempo_recolhida
	if t < tempo_aviso:
		return 1 if t < tempo_aviso * 0.5 else 2
	t -= tempo_aviso
	if t < TEMPO_QUADRO:
		return 3
	t -= TEMPO_QUADRO
	if t < tempo_erguida:
		return 4
	t -= tempo_erguida
	return 3 - mini(2, int(t / TEMPO_QUADRO))


func _draw() -> void:
	var q := 2 if Engine.is_editor_hint() else _quadro
	for linha in range(-1, tamanho.y):
		for coluna in tamanho.x:
			var cx := COL_MEIO
			if coluna == 0:
				cx = COL_ESQ
			elif coluna == tamanho.x - 1:
				cx = COL_DIR
			var cy := LIN_MEIO + (linha - 1) % 2
			if linha == -1:
				cy = LIN_SOBRA
			elif linha == 0:
				cy = LIN_TOPO
			elif linha == tamanho.y - 1:
				cy = LIN_BASE
			var origem := Rect2(cx * TILE, (cy + q * PASSO_QUADRO) * TILE, TILE, TILE)
			draw_texture_rect_region(FOLHA, Rect2(coluna * TILE, linha * TILE, TILE, TILE), origem)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(tamanho * TILE)), Color(1, 0.3, 0.3, 0.9), false, 1.0)
