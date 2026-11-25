extends Node2D
## O filho do Pai, preso pelo Feiticeiro espectral.
## - Preso: fica numa bolha de magia roxa (não dá para encostar) e, com E,
##   chama o Pai. A luz dele (o dom do filho) está fraca e treme.
## - Quando a `sala` do chefe é vencida (sinal `concluiu`), a bolha estoura
##   e a luz dele cresce. Isso avisa o Jogo (libertar_filho), que para de
##   apagar a "luz do filho" da barra do HUD. Enquanto preso, a luz dele no
##   mundo enfraquece junto com a barra.
## - Livre: com E, Pai e filho se reencontram (texto na tela). Ao fechar o
##   texto, marca a flag `flag_resgatado` e salva.
## Arte: o próprio Pai (Modern tiles_Free/Old: idle_32x32_2 e
## mv/Character_2_32x32_RPGMAKER) reduzido a 75% e com o cabelo castanho escuro,
## em filho_parado.png e filho_andando.png. Fica com escala 0,5, como o Pai.

## Sala do chefe. Vazio = começa livre.
@export var sala: NodePath
@export var flag_resgatado := "filho_resgatado"
@export var raio := 34.0
@export var falas_preso: PackedStringArray = [
	"Pai! Eu tô aqui!",
	"Pai, cuidado com o homem de capa!",
	"Pai... eu sabia que você vinha.",
]
@export_multiline var texto_reencontro := "O menino corre e se agarra na sua cintura.

— Pai! Eu fiquei com medo, mas eu deixei a luz acesa, igual você ensinou.

A luz em volta dele fica mais forte. Agora vocês precisam sair daqui."
@export var fala_depois := "Vamos pra casa, pai."

const COR_BOLHA := Color(0.68, 0.32, 1.0)
const COR_LUZ := Color(1.0, 0.86, 0.55)

var preso := true
var _perto := false
var _lendo := false
var _fala := 0
var _t := 0.0
var _bolha_a := 1.0  # some quando a bolha estoura
var _bolha_escala := 1.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _luz: PointLight2D = $Luz
@onready var _corpo: StaticBody2D = $Bolha


func _ready() -> void:
	_sprite.play("parado")
	_sprite.modulate = Color(0.85, 0.75, 1.0)  # tingido pela magia
	_sprite.speed_scale = 0.6
	var area := Area2D.new()
	area.collision_layer = 0
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = raio
	cs.shape = shape
	cs.position = Vector2(0, -8)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_entrou)
	area.body_exited.connect(_on_saiu)
	var s := get_node_or_null(sala)
	if s == null:
		_soltar(true)
	else:
		s.concluiu.connect(_soltar.bind(false))
		_checar_sala.call_deferred(s)  # a sala só sabe se já foi vencida depois do _ready dela


func _checar_sala(s: Node) -> void:
	if s.get("concluida"):
		_soltar(true)


func _soltar(silencioso: bool) -> void:
	if not preso:
		return
	preso = false
	Jogo.libertar_filho()  # a luz dele para de se apagar (barra do HUD)
	_corpo.queue_free()
	_sprite.modulate = Color.WHITE
	_sprite.speed_scale = 1.0
	if silencioso:
		_bolha_a = 0.0
		_luz.energy = 0.9
		_luz.texture_scale = 1.6
		queue_redraw()
		return
	Som.tocar_em("mundo/bolha_estoura", global_position + Vector2(0, -11))
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_bolha_escala", 1.8, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_bolha_a", 0.0, 0.45)
	tw.tween_property(_luz, "energy", 0.9, 1.2)
	tw.tween_property(_luz, "texture_scale", 1.6, 1.2)
	Jogo.mostrar_mensagem("A magia que prendia o seu filho se desfez!", 3.0, true)
	if _perto:
		Jogo.mostrar_dica("E: abraçar")


func _on_entrou(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = true
		Jogo.mostrar_dica(_dica())


func _on_saiu(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = false
		Jogo.esconder_dica()
		if _lendo:
			_lendo = false
			Jogo.esconder_texto()
			_marcar_resgate()


func _dica() -> String:
	if preso:
		return "E: falar"
	if Jogo.get_flag(flag_resgatado, false):
		return "E: falar"
	return "E: abraçar"


func _process(delta: float) -> void:
	_t += delta
	if preso:
		# a luz fraca treme, como uma vela, e vai sumindo junto com a barra
		# "luz do filho" do HUD (Jogo.luz_filho)
		var resta := Jogo.fracao_luz_filho()
		var tremor := 1.0 + (1.0 - resta) * 1.5  # treme mais quando está no fim
		_luz.energy = (0.3 + (0.08 * sin(_t * 7.0) + 0.05 * sin(_t * 13.0)) * tremor) * lerpf(0.35, 1.0, resta)
	if _bolha_a > 0.0:
		queue_redraw()
	if _perto and Input.is_action_just_pressed("interagir"):
		interagir()


func interagir() -> void:
	if preso:
		Jogo.mostrar_mensagem(falas_preso[_fala % falas_preso.size()], 2.0)
		_fala += 1
		return
	if Jogo.get_flag(flag_resgatado, false):
		Jogo.mostrar_mensagem(fala_depois, 2.0)
		return
	_lendo = not _lendo
	if _lendo:
		Som.tocar("mundo/achado", 0.0, 0.8, 0.0)
		Jogo.esconder_dica()
		Jogo.mostrar_texto(texto_reencontro)
	else:
		Jogo.esconder_texto()
		_marcar_resgate()
		Jogo.mostrar_dica(_dica())


func _marcar_resgate() -> void:
	if Jogo.get_flag(flag_resgatado, false):
		return
	Jogo.set_flag(flag_resgatado, true)
	Jogo.salvar_progresso()


## Bolha de magia: disco roxo transparente, contorno que pulsa e faíscas girando.
func _draw() -> void:
	if _bolha_a <= 0.0:
		return
	var c := Vector2(0, -11)
	var r := (14.0 + sin(_t * 3.0) * 0.6) * _bolha_escala
	draw_circle(c, r, Color(COR_BOLHA, 0.18 * _bolha_a))
	draw_arc(c, r, 0, TAU, 40, Color(COR_BOLHA.lightened(0.3), (0.55 + 0.2 * sin(_t * 4.0)) * _bolha_a), 1.0)
	draw_arc(c, r - 3.0, -2.4, -1.4, 8, Color(1, 1, 1, 0.35 * _bolha_a), 1.0)  # brilho
	for i in 4:
		var a := _t * 1.3 + i * TAU / 4.0
		var p := c + Vector2(cos(a), sin(a) * 0.9) * r
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color(0.9, 0.75, 1.0, 0.8 * _bolha_a))
