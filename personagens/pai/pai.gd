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
## Ponto do cabo dentro do ícone (o ícone fica na diagonal, ponta para
## cima/direita). Vem de Itens.cabo_arma(): (3, 13) nos ícones 16x16 ou o
## "sprite_cabo" da arma.
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
## Distância andada (px) entre um som de passo e outro; na escada, mais curta
## (ele anda devagar subindo os degraus).
const DISTANCIA_PASSO := 22.0
const DISTANCIA_PASSO_ESCADA := 12.0
## Altura do sprite em pixels do mundo (64 px da folha x escala 0.5). O sprite
## é deslocado para girar/esticar a partir dos PÉS (squash e queda na morte).
const ALTURA_SPRITE := 32.0
## Golpe: o corpo recua (preparo) e avança (golpe) esses pixels na direção do ataque.
const RECUO_ATAQUE := 1.0
const AVANCO_ATAQUE := 2.0
## Dano: quanto o corpo inclina para longe do golpe (graus) e o tremor da câmera.
const INCLINACAO_DANO := 12.0
const TREMOR_DANO := 2.0
const TREMOR_ACERTO := 0.8
## Esquiva (GDD 3.2 e 3.4): rolamento curto com invulnerabilidade, na direção
## do movimento (ou para onde ele olha), com recarga antes da próxima.
const DURACAO_ESQUIVA := 0.25
const VELOCIDADE_ESQUIVA := 230.0
const RECARGA_ESQUIVA := 0.8

var facing := "down"
var vision_radius: float  ## raio atual da luz

## true enquanto outro nó (ex.: a escada) controla o Pai; o jogador não move.
var controle_externo := false

var vida := 0
var morto := false

var _recarga := 0.0
var _recarga_esquiva := 0.0
var _esquivando := 0.0  ## tempo restante do rolamento (> 0 = rolando)
var _dir_esquiva := Vector2.ZERO
var _invulneravel := 0.0
var _empurrao := Vector2.ZERO
var _golpe: Golpe
var _arma: Node2D  ## pivô na mão; gira no ataque
var _arma_sprite: Sprite2D
var _balanco: Tween
var _balancando := false
var _luz_tween: Tween
var _corpo_tween: Tween  ## squash/stretch, inclinação e queda do sprite
var _cor_tween: Tween  ## flashes de cor (dano, cura, morte)
var _escala_sprite := Vector2.ONE  ## escala original do sprite (0.5)
var _pos_sprite := Vector2.ZERO  ## posição de repouso do sprite (nos pés)
var _passo_acumulado := 0.0
var _pos_anterior := Vector2.INF

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision: PointLight2D = $Visao
@onready var camera: Camera2D = get_node_or_null("Camera2D")


func _ready() -> void:
	add_to_group("player")  # as portas (door.gd) procuram esse grupo
	vida = vida_maxima
	# pivô do sprite nos pés: mesma imagem no mesmo lugar, mas escala e rotação
	# agora partem do chão (o offset é em pixels da folha, antes da escala)
	_escala_sprite = sprite.scale
	sprite.position.y += ALTURA_SPRITE * 0.5
	sprite.offset.y -= ALTURA_SPRITE * 0.5 / _escala_sprite.y
	_pos_sprite = sprite.position
	_golpe = Golpe.new()
	_golpe.position = Vector2(0, -8)
	add_child(_golpe)
	_criar_arma()
	aplicar_melhorias()
	Jogo.registrar_pai(self)
	vida_mudou.emit(vida, vida_maxima)


func _physics_process(delta: float) -> void:
	_recarga = maxf(0.0, _recarga - delta)
	_recarga_esquiva = maxf(0.0, _recarga_esquiva - delta)
	if _invulneravel > 0.0:
		_invulneravel -= delta
		sprite.visible = _invulneravel <= 0.0 or int(_invulneravel * 14.0) % 2 == 0
		_arma_sprite.visible = sprite.visible
	if morto:
		return
	_passos()  # antes do controle_externo: na escada ele também pisa
	if controle_externo:
		return
	if _esquivando > 0.0:
		_esquivando -= delta
		velocity = _dir_esquiva * VELOCIDADE_ESQUIVA
		move_and_slide()
		return
	if Input.is_action_just_pressed("esquivar") and _recarga_esquiva <= 0.0:
		_iniciar_esquiva()
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


## Som de passo a cada DISTANCIA_PASSO andados com a animação de andar
## tocando (pelo controle ou levado pela escada). Pulos grandes de posição
## (checkpoint, chegada pela escada) não contam.
func _passos() -> void:
	var andou := global_position.distance_to(_pos_anterior) if _pos_anterior != Vector2.INF else 0.0
	_pos_anterior = global_position
	if andou > 6.0 or not sprite.is_playing() or not String(sprite.animation).begins_with("walk_"):
		return
	_passo_acumulado += andou
	var passo := DISTANCIA_PASSO_ESCADA if controle_externo else DISTANCIA_PASSO
	if _passo_acumulado >= passo:
		_passo_acumulado = fmod(_passo_acumulado, passo)
		Som.tocar("pai/passo", -6.0, 1.0, 0.08)


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
	if Jogo.melhorias.has("choque"):
		# melhoria "Arma eletrificada": o golpe atordoa o monstro por um instante
		arma = arma.duplicate()
		arma["choque"] = Itens.TEMPO_CHOQUE
	_recarga = arma.recarga
	Som.tocar("armas/" + Jogo.id_arma_atual())  # o golpe no ar; o acerto toca no alvo
	var centro := global_position + _golpe.position
	var dir := mira if mira != Vector2.ZERO else get_global_mouse_position() - centro
	dir = dir.normalized() if dir.length() > 0.5 else _vetor_facing()
	_olhar_para(dir)
	_golpe.scale.y = _sentido_golpe(dir)  # o arco gira no mesmo sentido da arma
	_golpe.mostrar(dir, arma)
	_balancar_arma(dir, arma)
	_animar_corpo_ataque(dir)
	var acertou := false
	for alvo in get_tree().get_nodes_in_group("atingiveis"):
		if not is_instance_valid(alvo):
			continue
		var v: Vector2 = (alvo.global_position + Vector2(0, -6)) - centro
		if v.length() > arma.alcance + 8.0:
			continue
		if v.length() > 8.0 and absf(rad_to_deg(dir.angle_to(v))) > arma.angulo:
			continue
		# não acerta através de parede ou porta fechada (linha na altura dos pés)
		if not Jogo.linha_livre(global_position + Vector2(0, -2.5), alvo.global_position):
			continue
		var dano: int = arma.dano + arma.get("bonus", {}).get(alvo.get("tipo"), 0)
		alvo.levar_dano(dano, dir, arma)
		acertou = true
	if acertou:
		_tremer(TREMOR_ACERTO, 0.12)  # um "peso" leve quando o golpe pega


## Dano vindo de um monstro. `origem` = de onde veio o golpe (empurra o Pai).
func levar_dano(qtd: int, origem: Vector2) -> void:
	if morto or _invulneravel > 0.0 or _esquivando > 0.0 or controle_externo:
		return
	var perdeu := mini(qtd, vida)
	vida = maxi(0, vida - qtd)
	vida_mudou.emit(vida, vida_maxima)
	Jogo.pai_levou_dano(perdeu)  # cada ponto de vida perdido apaga um pouco da luz do filho
	_invulneravel = tempo_invulneravel
	var recuo := (global_position - origem).normalized()
	_empurrao = recuo * 150.0
	if vida == 0:
		_morrer(recuo)
		return
	Som.tocar("pai/dano")
	_animar_dano(recuo)


func curar(qtd: int) -> void:
	vida = mini(vida_maxima, vida + qtd)
	vida_mudou.emit(vida, vida_maxima)
	Som.tocar("pai/cura", 0.0, 1.0, 0.0)
	_novo_tween_cor()
	sprite.modulate = Color(0.5, 1, 0.5)
	_cor_tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)


## Reaplica melhorias criadas no livro e acerta a luz
## (a melhoria "tocha" é a Luz reforçada; o id ficou o mesmo).
func aplicar_melhorias() -> void:
	vision_radius = base_vision_radius * (multiplicador_luz_reforcada if Jogo.melhorias.has("tocha") else 1.0)
	vision.color = vision_color
	vision.energy = vision_energy
	vision.texture_scale = vision_radius / LIGHT_TEXTURE_RADIUS


## Apaga a luz que acompanha o Pai por `segundos` (chama sombria). As luzes
## das salas continuam. Outro acerto enquanto está apagada renova o tempo.
func apagar_luz(segundos: float) -> void:
	if _luz_tween:
		_luz_tween.kill()
	_luz_tween = create_tween()
	_luz_tween.tween_property(vision, "energy", 0.0, 0.15)
	_luz_tween.tween_interval(segundos)
	_luz_tween.tween_property(vision, "energy", vision_energy, 0.6)


func luz_apagada() -> bool:
	return _luz_tween != null and _luz_tween.is_running()


## `recuo` = direção para onde o golpe final empurrou o Pai (ele cai para lá).
func _morrer(recuo := Vector2.ZERO) -> void:
	morto = true
	Som.tocar("pai/morte", 0.0, 1.0, 0.0)
	velocity = Vector2.ZERO
	_empurrao = Vector2.ZERO
	_invulneravel = 0.0  # para o pisca-pisca não esconder o corpo caindo
	sprite.visible = true
	_arma_sprite.visible = true
	if _balanco:
		_balanco.kill()
	_balancando = false
	sprite.play("idle_" + facing)
	sprite.pause()
	set_colisao(false)
	_animar_morte(recuo)
	morreu.emit()
	Jogo.pai_morreu()


## Começa o rolamento: enquanto `_esquivando` > 0 o Pai é invulnerável e não ataca.
## Sem direção apertada, rola para onde está olhando.
func _iniciar_esquiva() -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_dir_esquiva = dir.normalized() if dir != Vector2.ZERO else _vetor_facing()
	_esquivando = DURACAO_ESQUIVA
	_recarga_esquiva = RECARGA_ESQUIVA
	Som.tocar("pai/passo", -3.0, 1.2, 0.0)


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


## Arco do golpe desenhado na direção do ataque: um rastro que afina na cauda
## e engrossa na ponta (que acompanha a arma), e depois se fecha em direção à
## ponta até sumir.
class Golpe extends Node2D:
	const DURACAO := 0.22
	## Espera o preparo do braço antes de começar a varrer.
	const ATRASO := 0.03
	## Tempo que a ponta leva para ir de um lado do arco ao outro.
	const VARREDURA := 0.09
	## Comprimento do rastro durante a varredura (fração do arco).
	const RASTRO := 0.8
	const SEGMENTOS := 14

	var _t := 0.0
	var _ativo := false
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
		_t = 0.0
		_ativo = true
		visible = true
		queue_redraw()

	func _process(delta: float) -> void:
		if not _ativo:
			return
		_t += delta
		if _t >= DURACAO:
			_ativo = false
			visible = false
		queue_redraw()

	func _draw() -> void:
		# ponta: 0 -> 1 ao longo do arco, com aceleração no começo (golpe forte)
		var cabeca := clampf((_t - ATRASO) / VARREDURA, 0.0, 1.0)
		if cabeca <= 0.0:
			return
		cabeca = 1.0 - pow(1.0 - cabeca, 2.0)
		# depois da varredura, a cauda alcança a ponta e o rastro some
		var sumir := clampf((_t - ATRASO - VARREDURA) / (DURACAO - ATRASO - VARREDURA), 0.0, 1.0)
		var cauda := maxf(0.0, cabeca - RASTRO)
		cauda = lerpf(cauda, 1.0, sumir)
		if cabeca - cauda <= 0.01:
			return
		var a := deg_to_rad(_ang)
		var r_fora := _raio * 0.85
		var r_dentro := _raio * 0.6
		var alfa := 1.0 - sumir * 0.5
		for i in SEGMENTOS:
			var k0 := float(i) / SEGMENTOS
			var k1 := float(i + 1) / SEGMENTOS
			var ang0 := -a + 2.0 * a * lerpf(cauda, cabeca, k0)
			var ang1 := -a + 2.0 * a * lerpf(cauda, cabeca, k1)
			var c := Color(_cor, 0.9 * k1 * alfa)  # some na cauda
			var d0 := Vector2.from_angle(ang0)
			var d1 := Vector2.from_angle(ang1)
			draw_line(d0 * r_fora, d1 * r_fora, c, lerpf(0.5, 3.0, k1))
			draw_line(d0 * r_dentro, d1 * r_dentro, Color(c, c.a * 0.45), lerpf(0.5, 1.5, k1))
		# brilho na ponta enquanto a arma ainda está varrendo
		if sumir < 1.0:
			var ponta := Vector2.from_angle(-a + 2.0 * a * cabeca) * r_fora
			draw_circle(ponta, 1.5, Color(Color.WHITE, 0.9 * (1.0 - sumir)))


## Nuvem de poeira quando o corpo bate no chão.
class Poeira extends Node2D:
	const DURACAO := 0.45
	var _t := 0.0
	var _bolhas: Array[Vector3] = []  ## (x, y, raio) de cada bolinha

	func _ready() -> void:
		z_index = 1
		for i in 5:
			_bolhas.append(Vector3(randf_range(-6.0, 6.0), randf_range(-2.0, 1.0), randf_range(1.5, 2.8)))

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURACAO:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p := _t / DURACAO
		var c := Color(0.72, 0.66, 0.58, 0.55 * (1.0 - p))
		for b in _bolhas:
			# espalha para os lados e sobe um pouco, crescendo
			var pos := Vector2(b.x * (1.0 + p * 1.2), b.y - p * 4.0)
			draw_circle(pos, b.z * (0.6 + p * 0.8), c)


# --- interno -------------------------------------------------------------------

# --- arma na mão -------------------------------------------------------------------

func _criar_arma() -> void:
	_arma = Node2D.new()
	_arma.name = "Arma"
	add_child(_arma)
	_arma_sprite = Sprite2D.new()
	_arma_sprite.light_mask = 2  # iluminado pela Visao, como o sprite do Pai
	_arma_sprite.centered = false
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
	# ícones maiores que 16 px (ex.: 32 px) encolhem para o mesmo tamanho na mão
	_arma_sprite.offset = -Itens.cabo_arma(id)
	_arma_sprite.scale = Vector2.ONE * Itens.escala_icone_arma(id)
	# socos: sem arma na mão (só a pose de golpe e o arco)
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
	# a mão acompanha o corpo, que recua no preparo e avança no golpe
	var mao_tras := _mao(anim, quadros[0]) - (dir * RECUO_ATAQUE).round()
	var mao_frente := _mao(anim, quadros[1])
	var mao_avanco := mao_frente + (dir * AVANCO_ATAQUE).round()
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
	_balanco.parallel().tween_property(_arma, "position", mao_avanco, TEMPO_GOLPE * 0.5)
	# pose: o corpo volta do avanço e a mão vem junto
	_balanco.tween_property(_arma, "position", mao_frente, TEMPO_POSE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_balanco.tween_callback(func():
		_balancando = false
		sprite.play("idle_" + facing)
		_posicionar_arma())


# --- animações do corpo (ataque, dano, morte) -------------------------------------

func _novo_tween_corpo() -> Tween:
	if _corpo_tween:
		_corpo_tween.kill()
	_corpo_tween = create_tween()
	return _corpo_tween


func _novo_tween_cor() -> Tween:
	if _cor_tween:
		_cor_tween.kill()
	_cor_tween = create_tween()
	return _cor_tween


func _tremer(forca: float, duracao: float) -> void:
	if camera and camera.has_method("tremer"):
		camera.call("tremer", forca, duracao)


## Golpe: o corpo se encolhe e recua no preparo, estica e dá um passinho na
## direção do ataque no golpe e volta ao normal na pose final. Mesmos tempos
## do balanço da arma, para os dois baterem.
func _animar_corpo_ataque(dir: Vector2) -> void:
	var t := _novo_tween_corpo()
	var s := _escala_sprite
	var de_lado := absf(dir.x) > absf(dir.y)
	# de lado o corpo estica na horizontal; para cima/baixo, na vertical
	var esticado := Vector2(1.08, 0.95) if de_lado else Vector2(0.95, 1.07)
	sprite.rotation = 0.0
	# preparo
	t.tween_property(sprite, "scale", s * Vector2(1.07, 0.92), TEMPO_PREPARO)
	t.parallel().tween_property(sprite, "position", _pos_sprite - (dir * RECUO_ATAQUE).round(), TEMPO_PREPARO)
	# golpe
	t.tween_property(sprite, "scale", s * esticado, TEMPO_GOLPE * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, "position", _pos_sprite + (dir * AVANCO_ATAQUE).round(), TEMPO_GOLPE * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(TEMPO_GOLPE * 0.5)
	# volta (com um leve "quique" no fim)
	t.tween_property(sprite, "scale", s, TEMPO_POSE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, "position", _pos_sprite, TEMPO_POSE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Levou um golpe: flash branco rápido, depois vermelho que some; o corpo
## achata e inclina para longe do golpe e volta com um pequeno balanço.
func _animar_dano(recuo: Vector2) -> void:
	_novo_tween_cor()
	sprite.modulate = Color(2.2, 2.2, 2.2)
	_cor_tween.tween_interval(0.05)
	_cor_tween.tween_callback(func(): sprite.modulate = Color(1, 0.3, 0.3))
	_cor_tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)

	var lado := signf(recuo.x) if absf(recuo.x) > 0.2 else 0.0
	var t := _novo_tween_corpo()
	sprite.scale = _escala_sprite * Vector2(1.14, 0.86)
	sprite.rotation = deg_to_rad(INCLINACAO_DANO) * lado
	sprite.position = _pos_sprite
	t.tween_property(sprite, "scale", _escala_sprite, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tremer(TREMOR_DANO, 0.2)


## Morte: o golpe final empurra o corpo, ele cambaleia, os joelhos cedem e ele
## tomba para o lado do empurrão (girando a partir dos pés), quica de leve no
## chão levantando poeira. A arma escapa da mão e cai do outro lado.
## Tudo cabe nos ~1,6 s que o Jogo espera antes do fade.
func _animar_morte(recuo: Vector2) -> void:
	var lado := signf(recuo.x) if absf(recuo.x) > 0.2 else (-1.0 if sprite.flip_h else 1.0)
	var s := _escala_sprite
	var queda := deg_to_rad(90.0) * lado

	# cor: flash branco, vermelho, e escurece enquanto cai
	_novo_tween_cor()
	sprite.modulate = Color(2.4, 2.4, 2.4)
	_cor_tween.tween_interval(0.06)
	_cor_tween.tween_callback(func(): sprite.modulate = Color(1, 0.3, 0.3))
	_cor_tween.tween_property(sprite, "modulate", Color(0.6, 0.18, 0.18), 0.7)
	_cor_tween.tween_property(sprite, "modulate", Color(0.5, 0.2, 0.2, 0.92), 0.5)

	var t := _novo_tween_corpo()
	sprite.position = _pos_sprite
	# 1. impacto: achata e é jogado para trás
	sprite.scale = s * Vector2(1.16, 0.84)
	sprite.rotation = deg_to_rad(16.0) * lado
	# 2. cambaleia para a frente, tentando se segurar
	t.tween_property(sprite, "scale", s * Vector2(0.97, 1.03), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, "rotation", deg_to_rad(-5.0) * lado, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 3. os joelhos cedem
	t.tween_property(sprite, "scale", s * Vector2(1.06, 0.9), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(sprite, "rotation", deg_to_rad(8.0) * lado, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4. tomba, acelerando
	t.tween_property(sprite, "rotation", queda, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(sprite, "scale", s, 0.3)
	# 5. bate no chão: poeira, tremor e um quique pequeno
	t.tween_callback(func():
		_tremer(1.6, 0.22)
		_soltar_poeira(Vector2(lado * ALTURA_SPRITE * 0.7, 0.0))
		Som.tocar("pai/passo", 0.0, 0.7, 0.0))
	t.tween_property(sprite, "rotation", queda - deg_to_rad(9.0) * lado, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, "scale", s * Vector2(1.0, 0.92), 0.08)
	t.tween_property(sprite, "rotation", queda, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(sprite, "scale", s, 0.12)

	_derrubar_arma(-lado)
	_tremer(2.5, 0.3)


## A arma voa da mão para o lado `lado` (1 = direita), girando, e fica no chão.
func _derrubar_arma(lado: float) -> void:
	if not _arma.visible:
		return
	_arma_atras(false)
	var inicio := _arma.position
	var fim := Vector2(lado * 9.0, -1.0)
	var t := create_tween()
	# x anda reto; y sobe e desce (um arco)
	t.tween_property(_arma, "position:x", fim.x, 0.45).set_delay(0.05)
	t.parallel().tween_property(_arma, "position:y", inicio.y - 7.0, 0.2).set_delay(0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_arma, "position:y", fim.y, 0.25).set_delay(0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# o ícone aponta a -45°; +45° deita a arma no chão, mais uma volta no ar
	t.parallel().tween_property(_arma, "rotation", PI / 4.0 + TAU * lado, 0.45).set_delay(0.05)
	t.parallel().tween_property(_arma, "scale", Vector2(ESCALA_ARMA, ESCALA_ARMA), 0.1)
	t.tween_callback(func(): _soltar_poeira(fim, 0.6))
	t.tween_property(_arma_sprite, "modulate", _arma_sprite.modulate.darkened(0.35), 0.5)


func _soltar_poeira(pos_local: Vector2, tamanho := 1.0) -> void:
	var p := Poeira.new()
	p.position = pos_local
	p.scale = Vector2.ONE * tamanho
	add_child(p)
