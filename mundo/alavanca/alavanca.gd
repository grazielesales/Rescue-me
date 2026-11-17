extends AnimatedSprite2D
## Alavanca na parede. Perto dela aparece "E: puxar alavanca"; apertar E
## vira a alavanca e chama destrancar() no nó `alvo` (ex.: um portão).
## Usa a animação "default" (quadro 0 = desligada, último = ligada).

@export var alvo: NodePath
@export var raio := 20.0
@export var mensagem := "Algo pesado se mexeu..."

var _perto := false
var _usada := false


func _ready() -> void:
	sprite_frames.set_animation_loop(animation, false)
	stop()
	frame = 0
	var area := Area2D.new()
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


func _on_entrou(body: Node) -> void:
	if body.is_in_group("player") and not _usada:
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
	play()
	await animation_finished
	var n := get_node_or_null(alvo)
	if n and n.has_method("destrancar"):
		n.destrancar()
		Jogo.mostrar_mensagem(mensagem)
