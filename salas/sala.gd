@tool
class_name Sala
extends Node2D
## Uma sala do andar. Começa escura (coberta por uma "névoa" preta) e acende
## de vez quando o Pai entra nela pela porta. Fica acesa mesmo se ele sair
## e também ao voltar de outro andar (o estado fica no autoload Jogo).
##
## Os retângulos são em pixels, no espaço local deste nó. Para ver/editar no
## editor, selecione a sala: os retângulos aparecem desenhados na cena.

signal acendeu

## Área onde o Pai precisa pisar para a sala acender (o chão da sala).
@export var areas: Array[Rect2] = []:
	set(v):
		areas = v
		queue_redraw()
## Área que fica coberta de preto enquanto a sala não foi visitada.
## Vazio = usa `areas`.
@export var nevoa: Array[Rect2] = []:
	set(v):
		nevoa = v
		queue_redraw()
## Área iluminada quando a sala acende (normalmente o chão + a parede do fundo).
## Vazio = usa `areas`.
@export var luz: Array[Rect2] = []:
	set(v):
		luz = v
		queue_redraw()
@export var cor_da_luz := Color(1.0, 0.86, 0.66)
@export_range(0.0, 2.0) var energia := 0.8
## Portas desta sala: quando uma delas abre para o Pai, a sala já acende
## (assim a cabeça dele não "some" no escuro ao passar pelo vão).
@export var portas: Array[NodePath] = []
@export var tempo_para_acender := 0.35
## Luz piscando/tremendo (0 = estável). O GDD pede luzes piscando no 2º andar.
@export_range(0.0, 1.0) var piscar := 0.0
## Sala já começa acesa (ex.: o lugar onde o Pai acorda).
@export var acesa_no_inicio := false

@export_group("Sala bloqueada (GDD 3.5)")
## Marca a sala como arena. Os inimigos dentro de `areas` são contados.
@export var arena := false
## Quando existir combate: fechar as portas ao entrar e só abrir quando todos
## os inimigos da arena morrerem. Desligado por enquanto (não há combate).
@export var trancar_ao_entrar := false

var acesa := false
var _luzes: Array[PointLight2D] = []
var _nevoas: Array[ColorRect] = []
var _inimigos: Array[Node] = []
var _ruido := FastNoiseLite.new()
var _tempo := randf() * 100.0
var _acendendo := false

const TEX_LUZ := preload("res://salas/luz_sala.tres")
const TEX_TAM := 64.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("salas")
	for r in (luz if not luz.is_empty() else areas):
		var l := PointLight2D.new()
		l.texture = TEX_LUZ
		l.position = r.get_center()
		l.scale = r.size / TEX_TAM
		l.color = cor_da_luz
		l.energy = 0.0
		l.visible = false
		add_child(l)
		_luzes.append(l)
	for r in (nevoa if not nevoa.is_empty() else areas):
		var c := ColorRect.new()
		c.color = Color.BLACK
		c.position = r.position
		c.size = r.size
		c.z_index = 40  # acima de chão, móveis e monstros
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_nevoas.append(c)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 0xFFFFFFFF
	area.monitorable = false
	for r in areas:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.get_center()
		area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	for caminho in portas:
		var porta := get_node_or_null(caminho)
		if porta and porta.has_node("Area2D"):
			porta.get_node("Area2D").body_entered.connect(_on_porta.bind(porta))

	_ruido.frequency = 1.0
	set_process(false)
	if acesa_no_inicio or Jogo.sala_visitada(_chave()):
		acender(true)
	if arena:
		_contar_inimigos.call_deferred()


func _on_porta(body: Node, porta: Node) -> void:
	if body.is_in_group("player") and not acesa and porta.get("trancado") != true:
		acender()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not acesa:
		acender()


## Acende a sala. `imediato` pula o fade (usado ao voltar para o andar).
func acender(imediato := false) -> void:
	if acesa:
		return
	acesa = true
	Jogo.marcar_sala(_chave())
	var t := tempo_para_acender if not imediato else 0.0
	var tw := create_tween().set_parallel(true)
	for l in _luzes:
		l.visible = true
		tw.tween_property(l, "energy", energia, max(t, 0.01))
	for c in _nevoas:
		tw.tween_property(c, "modulate:a", 0.0, max(t * 0.8, 0.01))
	tw.chain().tween_callback(_terminou_de_acender)
	acendeu.emit()


func _terminou_de_acender() -> void:
	for c in _nevoas:
		c.visible = false
	set_process(piscar > 0.0)


func _process(delta: float) -> void:
	_tempo += delta
	var n := _ruido.get_noise_1d(_tempo * 6.0)  # -1..1
	var queda := 1.0 if randf() > piscar * 0.02 else 0.25  # apagão rápido de vez em quando
	for l in _luzes:
		l.energy = energia * (1.0 - piscar * 0.35 * (n * 0.5 + 0.5)) * queda


func contem(ponto_global: Vector2) -> bool:
	var p := to_local(ponto_global)
	for r in areas:
		if r.has_point(p):
			return true
	return false


## Inimigos (grupo "inimigos") cujo ponto de origem está dentro da sala.
func inimigos() -> Array[Node]:
	return _inimigos.filter(func(n): return is_instance_valid(n))


func _contar_inimigos() -> void:
	for n in get_tree().get_nodes_in_group("inimigos"):
		if n is Node2D and contem(n.global_position):
			_inimigos.append(n)


func _chave() -> String:
	var cena := owner.scene_file_path if owner else ""
	return "%s:%s" % [cena, name]


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for r in areas:
		draw_rect(r, Color(1, 0.8, 0.2, 0.15))
		draw_rect(r, Color(1, 0.8, 0.2, 0.9), false, 1.0)
	for r in luz:
		draw_rect(r, Color(1, 1, 0.6, 0.6), false, 1.0)
	for r in nevoa:
		draw_rect(r, Color(0.3, 0.3, 1, 0.6), false, 1.0)
