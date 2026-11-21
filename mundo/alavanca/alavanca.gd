extends AnimatedSprite2D
## Alavanca na parede. Perto dela aparece "E: puxar alavanca"; apertar E
## vira a alavanca e chama destrancar() no nó `alvo` (ex.: um portão).
## Usa a animação "default" (quadro 0 = desligada, último = ligada).
## Com `flag`, o estado fica no save: ao voltar ao jogo a alavanca já aparece
## puxada e o alvo já destrancado.

@export var alvo: NodePath
@export var raio := 20.0
@export var mensagem := "Algo pesado se mexeu..."
## Flag do Jogo marcada ao puxar (ex.: "portao_aranha_aberto"). Vazio = não salva.
@export var flag := ""
## Caixa/barril (quebrável) que esconde a alavanca: até ela quebrar, a alavanca
## fica invisível e não dá para puxar. Vazio = sempre à mostra.
@export var escondida_atras: NodePath
@export var mensagem_revelada := "Tinha uma alavanca escondida atrás da caixa!"

var _perto := false
var _usada := false
var _escondida := false
var _area: Area2D


func _ready() -> void:
	sprite_frames.set_animation_loop(animation, false)
	stop()
	frame = 0
	var area := Area2D.new()
	_area = area
	area.collision_layer = 0
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = raio
	cs.shape = shape
	var tam := sprite_frames.get_frame_texture(animation, 0).get_size()
	cs.position = offset + (Vector2.ZERO if centered else tam / 2.0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_entrou)
	area.body_exited.connect(_on_saiu)
	if flag != "" and Jogo.get_flag(flag, false):
		_ja_puxada.call_deferred()
	elif not escondida_atras.is_empty():
		_esconder()


## Fica invisível até a caixa da frente quebrar. A checagem espera um quadro
## porque o andar.gd só monta os quebráveis (e apaga os já quebrados) depois.
func _esconder() -> void:
	_escondida = true
	visible = false
	_area.monitoring = false
	_ligar_caixa.call_deferred()


func _ligar_caixa() -> void:
	var caixa := get_node_or_null(escondida_atras)
	if caixa == null or caixa.is_queued_for_deletion():
		_revelar(true)  # já foi quebrada num jogo anterior
		return
	for c in caixa.get_children():
		if c.has_signal("quebrou"):
			c.quebrou.connect(_revelar)
			return
	_revelar(true)  # não é quebrável: não deixa a alavanca presa escondida


func _revelar(silencioso := false) -> void:
	if not _escondida:
		return
	_escondida = false
	visible = true
	_area.set_deferred("monitoring", true)
	if silencioso:
		return
	Jogo.mostrar_mensagem(mensagem_revelada, 2.5)
	modulate = Color(2, 2, 2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.5)


## Estado salvo: alavanca puxada e alvo destrancado, sem animação nem mensagem.
func _ja_puxada() -> void:
	_usada = true
	frame = sprite_frames.get_frame_count(animation) - 1
	var n := get_node_or_null(alvo)
	if n and n.has_method("destrancar"):
		n.destrancar(true)


func _on_entrou(body: Node) -> void:
	if body.is_in_group("player") and not _usada and not _escondida:
		_perto = true
		Jogo.mostrar_dica("E: puxar alavanca")


func _on_saiu(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = false
		Jogo.esconder_dica()


func _process(_delta: float) -> void:
	if _perto and not _usada and Input.is_action_just_pressed("interagir"):
		puxar()


func puxar() -> void:
	_usada = true
	_perto = false
	Jogo.esconder_dica()
	if flag != "":
		Jogo.set_flag(flag, true)
		Jogo.salvar_progresso()
	play()
	await animation_finished
	var n := get_node_or_null(alvo)
	if n and n.has_method("destrancar"):
		n.destrancar()
		Jogo.mostrar_mensagem(mensagem)
