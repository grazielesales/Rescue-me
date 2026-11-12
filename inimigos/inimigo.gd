extends CharacterBody2D
## Monstro posicionado nos andares (GDD 6).
## - entra nos grupos "inimigos" (as salas-arena contam quem está dentro delas)
##   e "atingiveis" (o ataque do Pai procura esse grupo);
## - fica parado até o Pai aparecer: se o monstro está numa sala, quando o Pai
##   entra na sala acesa; fora de salas, quando ele chega a `raio_alerta`;
## - persegue e ataca corpo a corpo, ou mantém distância e atira (criatura
##   mágica, feiticeiro);
## - ao morrer solta os materiais da tabela Itens.INIMIGOS e não volta mais.
## Vida, dano, velocidade e drops vêm de Itens.INIMIGOS pelo `tipo`;
## os campos abaixo com 0 usam a tabela.

signal morreu(inimigo: Node)

## Nome do monstro no GDD (seção 6), ex.: "Aranha grande", "Esqueleto".
@export var tipo := ""
## Animação que fica tocando parado. Vazio = "idle" (ou a primeira que existir).
@export var animacao := ""
## Flutua para cima e para baixo (fantasmas e o feiticeiro).
@export var flutuar := false
## Distância (px, antes da escala do nó) do centro do sprite até os pés.
## Usada para pôr a origem nos pés (ordem de desenho) e posicionar a colisão.
@export var altura_pes := 0.0
## Largura da colisão no chão (px). 0 = sem colisão (fantasmas atravessam).
@export var largura_corpo := 0.0

@export_group("Combate")
## 0 = usa a tabela Itens.INIMIGOS.
@export var vida_maxima := 0
@export var dano := 0
@export var velocidade := 0.0
## Fora de salas: distância em que o monstro percebe o Pai.
@export var raio_alerta := 90.0
## O desenho original do sprite olha para a direita?
@export var sprite_olha_direita := true

var vida := 0
var morto := false

var _dados := {}
var _alcance := 16.0
var _recarga_max := 1.2
var _distancia := 0.0
var _projetil := false
var _recarga := 0.5
var _ataque_t := 0.0
var _acertou := false
var _travado_t := 0.0  # animação de dano/ataque tocando
var _empurrao := Vector2.ZERO
var _veneno_t := 0.0
var _veneno_tick := 0.0
var _sala: Node = null
var _chave := ""
var _anim_base := ""

var _t := randf() * TAU
var _base_y := 0.0
@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	_chave = "%s:%s" % [owner.scene_file_path if owner else "", owner.get_path_to(self) if owner else NodePath(name)]
	if Jogo.esta_morto(_chave):
		queue_free()
		return
	add_to_group("inimigos")
	add_to_group("atingiveis")
	_dados = Itens.dados_inimigo(tipo)
	vida = vida_maxima if vida_maxima > 0 else _dados.vida
	vida_maxima = vida
	if dano <= 0:
		dano = _dados.dano
	if velocidade <= 0.0:
		velocidade = _dados.velocidade
	_alcance = _dados.alcance
	_recarga_max = _dados.recarga
	_distancia = _dados.get("distancia", 0.0)
	_projetil = _dados.get("projetil", false)
	_achar_sala.call_deferred()

	if _sprite == null:
		return
	# origem nos pés: o sprite sobe e o nó desce a mesma distância
	_sprite.position.y -= altura_pes
	position.y += altura_pes * scale.y
	_base_y = _sprite.position.y
	if largura_corpo > 0.0 and collision_layer != 0:
		var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
		if cs and cs.shape == null:
			var r := RectangleShape2D.new()
			r.size = Vector2(largura_corpo, 6)
			cs.shape = r
			cs.position = Vector2(0, -3)
	if _sprite.sprite_frames == null:
		return
	# cópia própria: mudar o loop das animações não afeta outros monstros iguais
	_sprite.sprite_frames = _sprite.sprite_frames.duplicate()
	for a in ["attack", "hurt", "death"]:
		if _sprite.sprite_frames.has_animation(a):
			_sprite.sprite_frames.set_animation_loop(a, false)
	var nomes := _sprite.sprite_frames.get_animation_names()
	var anim := animacao
	if anim == "" or not _sprite.sprite_frames.has_animation(anim):
		anim = "idle" if _sprite.sprite_frames.has_animation("idle") else (nomes[0] if nomes.size() > 0 else "")
	_anim_base = anim
	if anim != "":
		_sprite.sprite_frames.set_animation_loop(anim, true)
		_sprite.play(anim)
		_sprite.frame = randi() % max(1, _sprite.sprite_frames.get_frame_count(anim))
	if _sprite.sprite_frames.has_animation("walk"):
		_sprite.sprite_frames.set_animation_loop("walk", true)


func _achar_sala() -> void:
	for s in get_tree().get_nodes_in_group("salas"):
		if s.contem(global_position):
			_sala = s
			return


func _process(delta: float) -> void:
	if flutuar and _sprite:
		_t += delta * 2.2
		_sprite.position.y = _base_y + sin(_t) * 2.0


func _physics_process(delta: float) -> void:
	if morto:
		return
	_recarga = maxf(0.0, _recarga - delta)
	_travado_t = maxf(0.0, _travado_t - delta)
	_tick_veneno(delta)
	if morto:
		return

	var pai: Node2D = Jogo.pai if Jogo._pai_ativo() else null
	var vel := Vector2.ZERO
	if _ataque_t > 0.0:
		_tick_ataque(delta, pai)
	elif pai and _percebe(pai):
		var dif := pai.global_position - global_position
		var d := dif.length()
		var dir := dif / maxf(d, 0.001)
		_virar(dif.x)
		if _projetil:
			if d > _distancia + 12.0:
				vel = dir * velocidade
			elif d < _distancia - 18.0:
				vel = -dir * velocidade * 0.8
			if d <= _alcance and _recarga <= 0.0:
				_comecar_ataque()
		elif d > _alcance - 2.0:
			vel = dir * velocidade
		elif _recarga <= 0.0:
			_comecar_ataque()

	velocity = vel + _empurrao
	_empurrao = _empurrao.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	_animar(vel)


## O monstro já "viu" o Pai?
func _percebe(pai: Node2D) -> bool:
	if is_instance_valid(_sala):
		return _sala.acesa and _sala.contem(pai.global_position)
	return global_position.distance_to(pai.global_position) <= raio_alerta


func _comecar_ataque() -> void:
	_ataque_t = 0.6
	_acertou = false
	_recarga = _recarga_max
	_tocar("attack", 0.6)


## Ataque com "aviso": o golpe só acerta no meio da animação.
func _tick_ataque(delta: float, pai: Node2D) -> void:
	_ataque_t -= delta
	if _acertou or _ataque_t > 0.3:
		return
	_acertou = true
	if pai == null:
		return
	if _projetil:
		var origem := global_position + Vector2(0, -10)
		var p := Projetil.new()
		p.direcao = ((pai.global_position + Vector2(0, -8)) - origem).normalized()
		p.dano = dano
		get_parent().add_child(p)
		p.global_position = origem
	elif global_position.distance_to(pai.global_position) <= _alcance + 6.0:
		pai.levar_dano(dano, global_position)


## Chamado pelo ataque do Pai.
func levar_dano(qtd: int, direcao: Vector2, arma := {}) -> void:
	if morto:
		return
	vida -= qtd
	_empurrao = direcao * (60.0 if _projetil else 120.0)
	_piscar(Color(1, 0.35, 0.35))
	if arma.has("veneno"):
		_veneno_t = arma.veneno
		_veneno_tick = 1.0
	if vida <= 0:
		morrer()
		return
	if _ataque_t <= 0.0:
		_tocar("hurt", 0.25)


func _tick_veneno(delta: float) -> void:
	if _veneno_t <= 0.0:
		return
	_veneno_t -= delta
	_veneno_tick -= delta
	if _veneno_tick <= 0.0:
		_veneno_tick = 1.0
		vida -= 1
		_piscar(Color(0.5, 1, 0.4))
		if vida <= 0:
			morrer()


func morrer() -> void:
	if morto:
		return
	morto = true
	remove_from_group("inimigos")
	remove_from_group("atingiveis")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	morreu.emit(self)
	Jogo.registrar_morte(_chave, tipo)
	for d in _dados.get("drops", []):
		if randf() <= d[3]:
			Coletavel.soltar(get_parent(), global_position, d[0], randi_range(d[1], d[2]))
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")
		await _sprite.animation_finished
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(queue_free)
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)


# --- animação -----------------------------------------------------------------------

func _tocar(anim: String, trava: float) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_travado_t = trava


func _animar(vel: Vector2) -> void:
	if _sprite == null or _sprite.sprite_frames == null or _travado_t > 0.0:
		return
	var anim := _anim_base
	if vel.length() > 2.0 and _sprite.sprite_frames.has_animation("walk"):
		anim = "walk"
	if anim != "" and _sprite.animation != anim:
		_sprite.play(anim)


func _virar(dx: float) -> void:
	if _sprite == null or absf(dx) < 1.0:
		return
	_sprite.flip_h = (dx < 0.0) if sprite_olha_direita else (dx > 0.0)


func _piscar(cor: Color) -> void:
	if _sprite == null:
		return
	_sprite.modulate = cor
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
