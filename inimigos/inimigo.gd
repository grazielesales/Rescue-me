extends CharacterBody2D
## Monstro posicionado nos andares (GDD 6).
## - entra nos grupos "inimigos" (as salas-arena contam quem está dentro delas)
##   e "atingiveis" (o ataque do Pai procura esse grupo);
## - fica parado até o Pai aparecer: se o monstro está numa sala, quando o Pai
##   entra na sala acesa; fora de salas, quando ele chega a `raio_alerta` e
##   não há parede entre os dois (depois persegue até ele se afastar muito);
## - persegue contornando paredes e móveis (malha de navegação que o andar.gd
##   cria) e ataca corpo a corpo, ou mantém distância e atira (criatura
##   mágica, feiticeiro). Não ataca através de paredes;
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
## A colisão física usa no máximo LARGURA_MAX_COLISAO, para o monstro caber
## nos mesmos vãos e corredores que o Pai (a malha de navegação conta com isso).
@export var largura_corpo := 0.0

const LARGURA_MAX_COLISAO := 8.0  # um pouco menor que a do Pai (10)

@export_group("Combate")
## 0 = usa a tabela Itens.INIMIGOS.
@export var vida_maxima := 0
@export var dano := 0
@export var velocidade := 0.0
## Fora de salas: distância em que o monstro percebe o Pai.
@export var raio_alerta := 90.0
## Fora de salas: depois de perceber, desiste se o Pai passar de
## raio_alerta x este valor.
@export var multiplicador_perseguicao := 2.5
## Distância mínima que ele tenta manter dos outros monstros (do centro até a
## borda dele). 0 = automático, pelo tamanho do corpo.
@export var raio_separacao := 0.0

@export_group("Em grupo")
## Quando há vários monstros, só MAX_ATACANTES partem para cima do Pai ao
## mesmo tempo; os outros rondam a esta distância dele, esperando a vez.
@export var raio_ronda := 48.0

@export_group("Vagar")
## Anda sozinho pela própria sala (ou em volta de onde nasceu, fora de salas)
## enquanto não percebe o Pai, parando de vez em quando. Ligado em todos por
## padrão; desmarque para um monstro ficar parado esperando (ex.: guarda).
@export var vagar := true
## Velocidade ao vagar, como fração da velocidade normal.
@export_range(0.1, 1.0) var velocidade_vagar := 0.35
## Fora de salas: até onde ele se afasta de onde nasceu.
@export var raio_vagar := 48.0
## Pausa entre uma andada e outra (segundos, mínimo e máximo).
@export var pausa_vagar := Vector2(0.6, 2.2)
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
var _alertado := false
var _agente: NavigationAgent2D
var _recalcular := 0.0
## Sem colisão (fantasmas, feiticeiro): vai direto, atravessando tudo.
var _atravessa := false
var _perseguindo := false
## Revezamento do ataque em grupo (ver _tem_vez).
const MAX_ATACANTES := 1
static var _com_a_vez: Array = []
var _vez_t := 0.0
var _descanso := 0.0
var _reacao := 0.0
var _angulo_ronda := 0.0
var _sentido_ronda := 1.0
var _casa := Vector2.ZERO
var _destino := Vector2.ZERO
var _tem_destino := false
var _espera := randf() * 1.5
var _tempo_andando := 0.0

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
	_preparar_navegacao.call_deferred()

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
			r.size = Vector2(minf(largura_corpo, LARGURA_MAX_COLISAO), 6)
			cs.shape = r
			cs.position = Vector2.ZERO  # centrada nos pés, como a malha de navegação supõe
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


## Depois do _ready (que pode criar a colisão): quem colide usa navegação.
func _preparar_navegacao() -> void:
	_casa = global_position
	_atravessa = collision_mask == 0 or not _tem_colisao()
	if _atravessa:
		return
	_agente = NavigationAgent2D.new()
	_agente.path_desired_distance = 6.0
	_agente.target_desired_distance = 6.0
	_agente.path_max_distance = 48.0
	add_child(_agente)


func _tem_colisao() -> bool:
	for c in get_children():
		if c is CollisionShape2D and c.shape != null and not c.disabled:
			return true
	return false


## Direção para andar até `alvo`: segue o caminho da navegação; sem caminho
## (malha ainda não pronta) ou sem colisão, vai em linha reta.
func _direcao_para(alvo: Vector2, delta: float) -> Vector2:
	var reta := (alvo - global_position).normalized()
	if _atravessa or _agente == null:
		return reta
	_recalcular -= delta
	if _recalcular <= 0.0:
		_recalcular = 0.25
		_agente.target_position = alvo
	if _agente.is_navigation_finished():
		# chegou ao fim do caminho: se o Pai está lá, vai reto; se o caminho
		# acabou antes (Pai inalcançável, ex.: atrás de portão), espera parado
		var alcancavel := _agente.get_final_position().distance_to(alvo) < 12.0
		return reta if alcancavel else Vector2.ZERO
	var prox := _agente.get_next_path_position()
	var d := prox - global_position
	if d.length() < 0.5:
		return reta
	return d.normalized()


## Nenhuma parede entre o monstro e o Pai (na altura dos pés)?
func _ve(pai: Node2D) -> bool:
	return Jogo.linha_livre(global_position + Vector2(0, -2), pai.global_position + Vector2(0, -2))


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
		if not _perseguindo:
			_perseguindo = true
			_tem_destino = false
			_recalcular = 0.0  # recalcula o caminho já, saindo do passeio
			_reacao = randf_range(0.2, 0.9)  # cada um percebe num tempo
			_angulo_ronda = (global_position - pai.global_position).angle()
			_sentido_ronda = 1.0 if randf() < 0.5 else -1.0
		var dif := pai.global_position - global_position
		var d := dif.length()
		var dir := dif / maxf(d, 0.001)
		var ve := _ve(pai)
		_virar(dif.x)
		if _reacao > 0.0:
			_reacao -= delta
		elif not _projetil and not _tem_vez(delta, d) and not (ve and d <= _alcance):
			# esperando a vez: ronda o Pai sem atacar
			vel = _rondar(pai, delta)
		elif _projetil:
			if d > _distancia + 12.0 or not ve:
				vel = _direcao_para(pai.global_position, delta) * velocidade
			elif d < _distancia - 18.0:
				vel = -dir * velocidade * 0.8
			if ve and d <= _alcance and _recarga <= 0.0:
				_comecar_ataque()
		elif d > _alcance - 2.0 or not ve:
			vel = _direcao_para(pai.global_position, delta) * velocidade
		elif _recarga <= 0.0:
			_comecar_ataque()
	else:
		_largar_vez()
		if vagar:
			vel = _vagar(delta)

	if not morto:
		vel += _separacao() * velocidade * 1.6
	velocity = vel + _empurrao
	_empurrao = _empurrao.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	_animar(vel)


## Empurrão para longe dos outros monstros que estão perto demais
## (usa o tamanho do sprite, não só a colisão pequena dos pés).
func _separacao() -> Vector2:
	var r1 := _raio_visual()
	var soma := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("inimigos"):
		if o == self or not o.has_method("_raio_visual"):
			continue
		var d: Vector2 = global_position - o.global_position
		var r: float = r1 + o._raio_visual()
		var dist := d.length()
		if dist >= r:
			continue
		if dist < 0.01:
			d = Vector2.from_angle(randf() * TAU)
		soma += d.normalized() * (1.0 - dist / r)
	return soma.limit_length(1.0)


## Pode partir para cima do Pai agora? No máximo MAX_ATACANTES ao mesmo
## tempo; cada um fica com a vez 2,5 a 4 s (contados só depois de chegar
## perto do Pai, `d` = distância até ele) e depois descansa um pouco.
func _tem_vez(delta: float, d: float) -> bool:
	_descanso = maxf(0.0, _descanso - delta)
	_com_a_vez = _com_a_vez.filter(func(m): return is_instance_valid(m) and not m.morto and m._perseguindo)
	if self in _com_a_vez:
		if d <= _alcance + 16.0:
			_vez_t -= delta
		if _vez_t <= 0.0 and _ataque_t <= 0.0:
			_largar_vez()
			_descanso = randf_range(1.0, 2.0)
			return false
		return true
	if _descanso > 0.0 or _com_a_vez.size() >= MAX_ATACANTES:
		return false
	_com_a_vez.append(self)
	_vez_t = randf_range(2.5, 4.0)
	return true


func _largar_vez() -> void:
	_com_a_vez.erase(self)


## Anda devagar em volta do Pai, a raio_ronda dele, olhando para ele.
func _rondar(pai: Node2D, delta: float) -> Vector2:
	_angulo_ronda += _sentido_ronda * 0.5 * delta
	var alvo := pai.global_position + Vector2.from_angle(_angulo_ronda) * raio_ronda
	var mapa := get_world_2d().navigation_map
	if not _atravessa and NavigationServer2D.map_get_iteration_id(mapa) > 0:
		alvo = NavigationServer2D.map_get_closest_point(mapa, alvo)
	if global_position.distance_to(alvo) < 5.0:
		return Vector2.ZERO
	return _direcao_para(alvo, delta) * velocidade * 0.6


func _raio_visual() -> float:
	if raio_separacao > 0.0:
		return raio_separacao
	return maxf(5.0, largura_corpo * 0.8 * absf(scale.x))


## Passeio sem o Pai por perto: escolhe um ponto da própria sala, anda até
## lá devagar, espera um pouco e escolhe outro.
func _vagar(delta: float) -> Vector2:
	_perseguindo = false
	if _espera > 0.0:
		_espera -= delta
		return Vector2.ZERO
	if not _tem_destino:
		_destino = _sortear_destino()
		_tem_destino = true
		_tempo_andando = 0.0
		if _agente:
			_agente.target_position = _destino
	_tempo_andando += delta
	var dif := _destino - global_position
	if dif.length() < 4.0 or _tempo_andando > 6.0:
		_tem_destino = false
		_espera = randf_range(pausa_vagar.x, pausa_vagar.y)
		return Vector2.ZERO
	var dir := dif.normalized()
	if _agente and not _atravessa and not _agente.is_navigation_finished():
		var passo := _agente.get_next_path_position() - global_position
		if passo.length() > 0.5:
			dir = passo.normalized()
	_virar(dir.x)
	return dir * velocidade * velocidade_vagar


func _sortear_destino() -> Vector2:
	var mapa := get_world_2d().navigation_map
	for i in 8:
		var p: Vector2
		if is_instance_valid(_sala) and not _sala.areas.is_empty():
			var r: Rect2 = _sala.areas.pick_random()
			p = _sala.to_global(Vector2(randf_range(r.position.x + 6.0, r.end.x - 6.0), randf_range(r.position.y + 6.0, r.end.y - 2.0)))
		else:
			p = _casa + Vector2.from_angle(randf() * TAU) * randf_range(8.0, raio_vagar)
		if not _atravessa and NavigationServer2D.map_get_iteration_id(mapa) > 0:
			p = NavigationServer2D.map_get_closest_point(mapa, p)
		if not is_instance_valid(_sala) or _sala.contem(p):
			return p
	return _casa


## O monstro já "viu" o Pai?
func _percebe(pai: Node2D) -> bool:
	if is_instance_valid(_sala):
		return _sala.acesa and _sala.contem(pai.global_position)
	var d := global_position.distance_to(pai.global_position)
	if _alertado:
		if d > raio_alerta * multiplicador_perseguicao:
			_alertado = false
	elif d <= raio_alerta and _ve(pai):
		_alertado = true
	return _alertado


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
	elif global_position.distance_to(pai.global_position) <= _alcance + 6.0 and _ve(pai):
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
	_largar_vez()
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
