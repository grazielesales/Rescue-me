extends CharacterBody2D
## O Pai: movimento, animação, combate e a luz que o acompanha.
## A luz é sempre a mesma (não existe mais tocha): um círculo de raio
## base_vision_radius, que a melhoria "Luz reforçada" aumenta.

signal vida_mudou(vida: int, maxima: int)
signal morreu

@export var speed := 80.0

@export_group("Combate")
## Vida do Pai (GDD 3.4). Só volta com curativos.
@export var vida_maxima := Itens.VIDA_PAI
## Segundos sem levar dano depois de um golpe.
@export var tempo_invulneravel := 0.8

@export_group("Luz")
## Raio da luz que acompanha o Pai, em pixels do mundo. Diminua por andar (GDD 5.2).
## (115 = o círculo grande da antiga tocha erguida: 64 x 1.8.)
@export var base_vision_radius: float = 115.0
## Quanto a melhoria "Luz reforçada" aumenta o raio (1.3 = +30%).
@export var multiplicador_luz_reforcada: float = 1.3
@export var vision_color: Color = Color(1.0, 0.7, 0.4)
@export var vision_energy: float = 1.25

const LIGHT_TEXTURE_RADIUS := 128.0  # a textura da luz tem 256 px de largura
## A origem do Pai fica nos PÉS (ordem de desenho correta com móveis e monstros).
## Onde fica a mão da ARMA em cada quadro de cada animação (pixels do mundo),
## medida nas folhas do personagem; assim a arma balança junto com o braço.
## "side" está virado para a esquerda (sem flip); virado para a direita o x inverte.
const MAO_ARMA := {
	"idle_down": [Vector2(6, -7)],
	"walk_down": [Vector2(5, -6), Vector2(6, -7), Vector2(6.5, -9)],
	"idle_up": [Vector2(-6.5, -7)],
	"walk_up": [Vector2(-6.25, -7.25), Vector2(-6.5, -7), Vector2(-5.75, -11.25)],
	"idle_side": [Vector2(0, -4.75)],
	"walk_side": [Vector2(0, -5.25), Vector2(-1, -4.75), Vector2(-4.25, -6.25)],
}
## Ponto do cabo dentro do ícone 16x16 (o ícone fica na diagonal, ponta para cima/direita).
const CABO_ARMA := Vector2(3, 13)
## Pose de ataque: o personagem não tem animação de golpe, então usamos os
## quadros de andar onde o braço da arma está para trás (preparo) e para a
## frente (golpe). Índices dos quadros de walk_<direção>.
const POSE_ATAQUE := {
	"down": [0, 2],
	"up": [0, 2],
	"side": [1, 2],
}
## Duração do golpe (s): preparo + golpe, e quanto tempo a pose fica parada no fim.
const TEMPO_PREPARO := 0.04
const TEMPO_GOLPE := 0.09
const TEMPO_POSE := 0.1
## De lado, quantos graus a arma inclina para a frente.
const INCLINACAO_LADO := 20.0
## Escala do ícone (igual à do sprite do Pai, para os pixels baterem).
const ESCALA_ARMA := 0.5

var facing := "down"
var vision_radius: float  ## raio atual da luz

## true enquanto outro nó (ex.: a escada) controla o Pai; o jogador não move.
var controle_externo := false

var vida := 0
var morto := false

var _recarga := 0.0
var _invulneravel := 0.0
var _empurrao := Vector2.ZERO
var _golpe: Golpe
var _arma: Node2D  ## pivô na mão; gira no ataque
var _arma_sprite: Sprite2D
var _balanco: Tween
var _balancando := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision: PointLight2D = $Visao


func _ready() -> void:
	add_to_group("player")  # as portas (door.gd) procuram esse grupo
	vida = vida_maxima
	_golpe = Golpe.new()
	_golpe.position = Vector2(0, -8)
	add_child(_golpe)
	_criar_arma()
	aplicar_melhorias()
	Jogo.registrar_pai(self)
	vida_mudou.emit(vida, vida_maxima)


func _physics_process(delta: float) -> void:
	_recarga = maxf(0.0, _recarga - delta)
	if _invulneravel > 0.0:
		_invulneravel -= delta
		sprite.visible = _invulneravel <= 0.0 or int(_invulneravel * 14.0) % 2 == 0
		_arma_sprite.visible = sprite.visible
	if morto:
		return
	if controle_externo:
		return
	if Input.is_action_just_pressed("atacar"):
		atacar()
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed + _empurrao
	_empurrao = _empurrao.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	_update_animation(dir)


func _update_animation(dir: Vector2) -> void:
	if _balancando:
		return  # durante o golpe a pose de ataque manda no sprite
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			facing = "side"
			sprite.flip_h = dir.x > 0
		elif dir.y > 0:
			facing = "down"
		else:
			facing = "up"
		sprite.play("walk_" + facing)
	else:
		sprite.play("idle_" + facing)
	_posicionar_arma()


# --- API pública (inimigos, HUD, armas) --------------------------------------

## Raio de visão atual em pixels do mundo.
func get_vision_radius() -> float:
	return vision_radius


## O ponto está dentro do círculo de visão? Para monstros que "só aparecem
## quando se aproximam" ou que reagem à luz (GDD 3.3 e 6.1).
func is_point_visible(world_point: Vector2) -> bool:
	return vision.global_position.distance_to(world_point) <= vision_radius


## Usado pela escada: toca a animação de andar/parado numa direção
## ("down", "up", "side") sem mover o corpo.
func animar(direcao: String, andando: bool, virado_direita := false) -> void:
	facing = direcao
	if direcao == "side":
		sprite.flip_h = virado_direita
	sprite.play(("walk_" if andando else "idle_") + direcao)
	_posicionar_arma()


## Liga/desliga a colisão do Pai (a escada desliga enquanto ele sobe).
func set_colisao(ativa: bool) -> void:
	$CollisionShape2D.set_deferred("disabled", not ativa)


# --- combate (GDD 3.4) ---------------------------------------------------------------

## Ataca com a arma equipada na direção do mouse (ou em `mira`, se passada).
func atacar(mira := Vector2.ZERO) -> void:
	if _recarga > 0.0:
		return
	var arma := Jogo.arma_atual()
	_recarga = arma.recarga
	var centro := global_position + _golpe.position
	var dir := mira if mira != Vector2.ZERO else get_global_mouse_position() - centro
	dir = dir.normalized() if dir.length() > 0.5 else _vetor_facing()
	_olhar_para(dir)
	_golpe.scale.y = _sentido_golpe(dir)  # o arco gira no mesmo sentido da arma
	_golpe.mostrar(dir, arma)
	_balancar_arma(dir, arma)
	for alvo in get_tree().get_nodes_in_group("atingiveis"):
		if not is_instance_valid(alvo):
			continue
		var v: Vector2 = (alvo.global_position + Vector2(0, -6)) - centro
		if v.length() > arma.alcance + 8.0:
			continue
		if v.length() > 8.0 and absf(rad_to_deg(dir.angle_to(v))) > arma.angulo:
			continue
		var dano: int = arma.dano + arma.get("bonus", {}).get(alvo.get("tipo"), 0)
		alvo.levar_dano(dano, dir, arma)


## Dano vindo de um monstro. `origem` = de onde veio o golpe (empurra o Pai).
func levar_dano(qtd: int, origem: Vector2) -> void:
	if morto or _invulneravel > 0.0 or controle_externo:
		return
	vida = maxi(0, vida - qtd)
	vida_mudou.emit(vida, vida_maxima)
	_invulneravel = tempo_invulneravel
	_empurrao = (global_position - origem).normalized() * 150.0
	sprite.modulate = Color(1, 0.35, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if vida == 0:
		_morrer()


func curar(qtd: int) -> void:
	vida = mini(vida_maxima, vida + qtd)
	vida_mudou.emit(vida, vida_maxima)
	sprite.modulate = Color(0.5, 1, 0.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.4)


## Reaplica melhorias criadas no livro e acerta a luz
## (a melhoria "tocha" é a Luz reforçada; o id ficou o mesmo).
func aplicar_melhorias() -> void:
	vision_radius = base_vision_radius * (multiplicador_luz_reforcada if Jogo.melhorias.has("tocha") else 1.0)
	vision.color = vision_color
	vision.energy = vision_energy
	vision.texture_scale = vision_radius / LIGHT_TEXTURE_RADIUS


func _morrer() -> void:
	morto = true
	velocity = Vector2.ZERO
	sprite.visible = true
	sprite.play("idle_" + facing)
	_arma.visible = false
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(0.6, 0.15, 0.15), 0.4)
	tw.parallel().tween_property(sprite, "rotation", deg_to_rad(90), 0.4)
	set_colisao(false)
	morreu.emit()
	Jogo.pai_morreu()


func _vetor_facing() -> Vector2:
	match facing:
		"up":
			return Vector2.UP
		"side":
			return Vector2.RIGHT if sprite.flip_h else Vector2.LEFT
	return Vector2.DOWN


func _olhar_para(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = "side"
		sprite.flip_h = dir.x > 0
	else:
		facing = "down" if dir.y > 0 else "up"
	sprite.play("idle_" + facing)
	_posicionar_arma()


## Arco do golpe desenhado na direção do ataque.
class Golpe extends Node2D:
	var _t := 0.0
	var _dur := 0.14
	var _raio := 20.0
	var _ang := 70.0
	var _cor := Color.WHITE

	func _ready() -> void:
		z_index = 6
		visible = false

	func mostrar(dir: Vector2, arma: Dictionary) -> void:
		rotation = dir.angle()
		_raio = arma.alcance
		_ang = minf(arma.angulo, 85.0)
		_cor = arma.get("cor", Color.WHITE)
		_t = _dur
		visible = true
		queue_redraw()

	func _process(delta: float) -> void:
		if _t <= 0.0:
			return
		_t -= delta
		if _t <= 0.0:
			visible = false
		queue_redraw()

	func _draw() -> void:
		var p := 1.0 - _t / _dur  # 0 -> 1 ao longo do golpe
		var a := deg_to_rad(_ang)
		var c := Color(_cor, 0.9 * (1.0 - p * 0.7))
		draw_arc(Vector2.ZERO, _raio * 0.85, -a, -a + 2.0 * a * minf(1.0, p * 2.0), 14, c, 3.0)
		draw_arc(Vector2.ZERO, _raio * 0.6, -a, -a + 2.0 * a * minf(1.0, p * 2.0), 10, Color(c, c.a * 0.5), 1.5)


# --- interno -------------------------------------------------------------------

# --- arma na mão -------------------------------------------------------------------

func _criar_arma() -> void:
	_arma = Node2D.new()
	_arma.name = "Arma"
	add_child(_arma)
	_arma_sprite = Sprite2D.new()
	_arma_sprite.light_mask = 2  # iluminado pela Visao, como o sprite do Pai
	_arma_sprite.centered = false
	_arma_sprite.offset = -CABO_ARMA
	_arma.add_child(_arma_sprite)
	sprite.frame_changed.connect(_posicionar_arma)
	Jogo.armas_mudou.connect(_atualizar_arma)
	_atualizar_arma()
	_posicionar_arma()


## Troca o ícone quando o jogador equipa outra arma.
func _atualizar_arma() -> void:
	var id := Jogo.id_arma_atual()
	var tex := Itens.sprite_arma(id)
	_arma_sprite.texture = tex
	_arma_sprite.modulate = Itens.ARMAS[id].get("sprite_cor", Color.WHITE)
	_arma.visible = tex != null and not morto


## Arma na mão, ponta para cima, seguindo o quadro atual da animação.
## Olhando para cima ela fica atrás do Pai.
func _posicionar_arma() -> void:
	if _arma == null or _balancando:
		return
	_arma.position = _mao(String(sprite.animation), sprite.frame)
	var esquerda := facing == "side" and not sprite.flip_h
	# de lado a arma inclina para a frente, para não cruzar o rosto
	_arma.rotation = 0.0 if facing != "side" else deg_to_rad(INCLINACAO_LADO) * (-1.0 if esquerda else 1.0)
	_arma.scale = Vector2(-ESCALA_ARMA if esquerda else ESCALA_ARMA, ESCALA_ARMA)
	_arma_atras(facing == "up")


## Filhos desenham na ordem da árvore: antes do sprite = atrás do Pai.
func _arma_atras(atras: bool) -> void:
	var antes := _arma.get_index() < sprite.get_index()
	if atras and not antes:
		move_child(_arma, sprite.get_index())
	elif not atras and antes:
		move_child(_arma, -1)


## Gira a arma junto com o arco do golpe e depois volta para a mão.
## Posição da mão da arma num quadro de uma animação (inverte x virado à direita).
func _mao(anim: String, quadro: int) -> Vector2:
	var maos: Array = MAO_ARMA.get(anim, MAO_ARMA.idle_down)
	var mao: Vector2 = maos[mini(quadro, maos.size() - 1)]
	if facing == "side" and sprite.flip_h:
		mao.x = -mao.x
	return mao


## 1 = gira no sentido horário; -1 = anti-horário (ataques para a esquerda).
func _sentido_golpe(dir: Vector2) -> float:
	return -1.0 if dir.x < -0.1 else 1.0


## Golpe: o braço vai para trás (preparo) e para a frente (golpe), e a arma,
## presa na mão, gira junto com o arco do ataque.
func _balancar_arma(dir: Vector2, arma: Dictionary) -> void:
	if _balanco:
		_balanco.kill()
	_balancando = true
	var anim := "walk_" + facing
	var quadros: Array = POSE_ATAQUE[facing]
	sprite.play(anim)
	sprite.pause()
	sprite.frame = quadros[0]
	var mao_tras := _mao(anim, quadros[0])
	var mao_frente := _mao(anim, quadros[1])
	# o ícone aponta a -45°; somando 45° a ponta fica na direção do golpe
	var base := dir.angle() + PI / 4.0
	# sentido do giro: para a esquerda inverte, para o golpe sempre vir de cima
	var a := deg_to_rad(minf(arma.angulo, 85.0)) * _sentido_golpe(dir)
	_arma.position = mao_tras
	_arma.scale = Vector2(ESCALA_ARMA, ESCALA_ARMA)
	_arma.rotation = base - a * 1.2
	_arma_atras(false)  # no golpe a arma fica na frente, até atacando para cima
	_balanco = create_tween()
	# preparo: recua um pouco mais
	_balanco.tween_property(_arma, "rotation", base - a * 1.35, TEMPO_PREPARO)
	# golpe: troca para o quadro do braço à frente e gira a arma
	_balanco.tween_callback(func(): sprite.frame = quadros[1])
	_balanco.tween_property(_arma, "rotation", base + a, TEMPO_GOLPE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_balanco.parallel().tween_property(_arma, "position", mao_frente, TEMPO_GOLPE * 0.5)
	_balanco.tween_interval(TEMPO_POSE)
	_balanco.tween_callback(func():
		_balancando = false
		sprite.play("idle_" + facing)
		_posicionar_arma())
