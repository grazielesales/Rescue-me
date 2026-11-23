extends CharacterBody2D
## Monstro posicionado nos andares (GDD 6).
## - entra nos grupos "inimigos" (as salas-arena contam quem está dentro delas)
##   e "atingiveis" (o ataque do Pai procura esse grupo);
## - enquanto não percebe o Pai, vaga pela própria sala (ou em volta de onde
##   nasceu, fora de salas), parando de vez em quando (grupo "Vagar");
## - percebe o Pai quando ele entra na sala acesa do monstro; fora de salas,
##   quando ele chega a `raio_alerta` e não há parede entre os dois (depois
##   persegue até ele se afastar muito);
## - em grupo, só MAX_ATACANTES partem para cima ao mesmo tempo; os outros
##   rondam o Pai esperando a vez (grupo "Em grupo");
## - `dormindo`: fica parado no primeiro quadro, sem vagar nem perceber o Pai,
##   até a `flag_acordar` existir no Jogo ou levar um golpe (ex.: esqueletos
##   da tumba, acordados pelo baú);
## - campos opcionais de Itens.INIMIGOS (ver o comentário lá): `fixo` com
##   olho que fecha (olho maligno), `escala`, `apagar_luz` no projétil e
##   `furia_*`/`rastro_*` (chama sombria: abaixo de metade da vida fica mais
##   rápida e deixa um rastro de fogo, a classe RastroFogo no fim do arquivo);
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

@export_group("Dormindo")
## Começa dormindo: não vaga e não percebe o Pai.
@export var dormindo := false
## Flag do Jogo que acorda o monstro (ex.: "tumba_aberta"). Vazio = só um
## golpe acorda.
@export var flag_acordar := ""
## Flag do Jogo que faz o monstro aparecer (ex.: "tumba_aberta"). Até lá ele
## fica invisível, sem colisão, sem levar golpe e parado. Vazio = já começa à vista.
@export var flag_aparecer := ""

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
var _fixo := false
## Olho fixo: fechado (invulnerável, sem atirar) e tempos de fechar/abrir.
var _fechado := false
var _fechado_t := 0.0
var _aberto_t := 0.0
var _furia := false
var _rastro_t := 0.0
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
## Escondido até a flag_aparecer existir (camada de colisão guardada aqui).
var _escondido := false
var _camada := 0
## Carregado de energia (campo "energia" da tabela): não leva dano até todas
## as flags das alavancas existirem.
var _carregado := false
var _brilho_carga: PointLight2D
## Atordoado pelo choque da "Arma eletrificada".
var _atordoado_t := 0.0
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
	_fixo = _dados.get("fixo", false)
	if _fixo:
		vagar = false
	scale *= float(_dados.get("escala", 1.0))
	_achar_sala.call_deferred()
	_preparar_navegacao.call_deferred()
	if flag_aparecer != "" and not Jogo.get_flag(flag_aparecer, false):
		_esconder()
	if not _energia_ok():
		_carregar()

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
	if dormindo:
		if flag_acordar != "" and Jogo.get_flag(flag_acordar, false):
			dormindo = false  # já acordou antes (estado do save)
		else:
			_sprite.pause()
			_sprite.frame = 0


## Acorda (flag, golpe): volta a animar e passa a vagar e perceber o Pai.
func acordar() -> void:
	if not dormindo:
		return
	dormindo = false
	if _sprite and _sprite.sprite_frames:
		_sprite.play(_anim_base)


## Some até a flag_aparecer: invisível, sem colisão para o Pai e fora do
## grupo "atingiveis" (continua em "inimigos", para a arena contar com ele).
func _esconder() -> void:
	_escondido = true
	visible = false
	_camada = collision_layer
	collision_layer = 0
	remove_from_group("atingiveis")


## Aparece aos poucos e já acorda.
func _aparecer() -> void:
	_escondido = false
	visible = true
	collision_layer = _camada
	add_to_group("atingiveis")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	acordar()


## Todas as flags de "energia" (alavancas) já foram marcadas?
func _energia_ok() -> bool:
	for f in _dados.get("energia", []):
		if not Jogo.get_flag(f, false):
			return false
	return true


## Fica carregado: brilho azul em volta e golpes sem efeito.
func _carregar() -> void:
	_carregado = true
	_brilho_carga = PointLight2D.new()
	_brilho_carga.texture = Projetil._textura_luz()
	_brilho_carga.color = Color(0.5, 0.8, 1.0)
	_brilho_carga.energy = 0.8
	_brilho_carga.texture_scale = 1.4
	_brilho_carga.position = Vector2(0, -10)
	add_child(_brilho_carga)
	if _sprite:
		_sprite.self_modulate = Color(0.8, 0.95, 1.3)


## Chamado pelas alavancas (alavanca.gd, `alvo`). `silencioso` = estado do save.
func destrancar(silencioso := false) -> void:
	if not _carregado:
		return
	if not _energia_ok():
		if not silencioso:
			Jogo.mostrar_mensagem("Ainda falta desligar um gerador.", 2.0, true)
		return
	_carregado = false
	if is_instance_valid(_brilho_carga):
		_brilho_carga.queue_free()
	if _sprite:
		_sprite.self_modulate = Color.WHITE
	if not silencioso:
		_piscar(Color(0.5, 0.8, 1.0))
		Jogo.mostrar_mensagem("A energia caiu! Agora dá para machucar o Frankie.", 2.5, true)


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
	if _escondido:
		if Jogo.get_flag(flag_aparecer, false):
			_aparecer()
		return
	if _atordoado_t > 0.0:
		_atordoado_t -= delta
		velocity = _empurrao
		_empurrao = _empurrao.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	_recarga = maxf(0.0, _recarga - delta)
	_travado_t = maxf(0.0, _travado_t - delta)
	_tick_veneno(delta)
	if morto:
		return

	if dormindo:
		if flag_acordar != "" and Jogo.get_flag(flag_acordar, false):
			acordar()
		else:
			velocity = _empurrao
			_empurrao = _empurrao.move_toward(Vector2.ZERO, 500.0 * delta)
			move_and_slide()
			return

	var pai: Node2D = Jogo.pai if Jogo._pai_ativo() else null
	if _fixo:
		_tick_fixo(delta, pai)
		return
	_tick_furia(delta)
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


## Monstro fixo (olho na parede): não anda. Atira quando vê o Pai; fecha
## quando ele chega perto demais e abre de novo depois de um tempo.
func _tick_fixo(delta: float, pai: Node2D) -> void:
	if _ataque_t > 0.0:
		_tick_ataque(delta, pai)
	var dist_fechar: float = _dados.get("distancia_fechar", 0.0)
	var perto := pai != null and dist_fechar > 0.0 \
			and global_position.distance_to(pai.global_position) <= dist_fechar
	if _fechado:
		_fechado_t -= delta
		if _fechado_t <= 0.0:
			_fechado = false
			_aberto_t = _dados.get("tempo_aberto", 1.5)
	else:
		_aberto_t = maxf(0.0, _aberto_t - delta)
		if perto and _aberto_t <= 0.0 and _ataque_t <= 0.0:
			_fechado = true
			_fechado_t = _dados.get("tempo_fechado", 2.5)
	if not _fechado and _ataque_t <= 0.0 and pai and _percebe(pai):
		_virar(pai.global_position.x - global_position.x)
		if _recarga <= 0.0 and _ve(pai) \
				and global_position.distance_to(pai.global_position) <= _alcance:
			_comecar_ataque()
	velocity = Vector2.ZERO
	_animar(Vector2.ZERO)


## Fúria (furia_vida): mais rápido, atira mais e deixa rastro de fogo.
func _tick_furia(delta: float) -> void:
	var limite: float = _dados.get("furia_vida", 0.0)
	if limite <= 0.0:
		return
	if not _furia and vida <= vida_maxima * limite:
		_furia = true
		Som.tocar_em("inimigos/furia", _ponto_som(), 0.0, _tom_som())
		velocidade *= float(_dados.get("furia_velocidade", 1.5))
		_recarga_max *= float(_dados.get("furia_recarga", 1.0))
		_piscar(Color(0.8, 0.4, 1.0))
		if _sprite:
			_sprite.self_modulate = Color(1.15, 0.85, 1.25)
	if not _furia or _dados.get("rastro_dano", 0) <= 0:
		return  # sem rastro_dano na tabela: a fúria só acelera (ex.: redemoinho)
	_rastro_t -= delta
	if _rastro_t <= 0.0:
		_rastro_t = _dados.get("rastro_intervalo", 0.3)
		var r := RastroFogo.new()
		r.dano = _dados.get("rastro_dano", 1)
		r.duracao = _dados.get("rastro_duracao", 3.0)
		get_parent().add_child(r)
		r.global_position = global_position


func _comecar_ataque() -> void:
	_ataque_t = 0.6
	_acertou = false
	_recarga = _recarga_max
	_tocar("attack", 0.6)
	if not _projetil:
		_som("ataque")  # corpo a corpo: o som avisa que o golpe vem aí


## Ataque com "aviso": o golpe só acerta no meio da animação.
func _tick_ataque(delta: float, pai: Node2D) -> void:
	_ataque_t -= delta
	if _acertou or _ataque_t > 0.3:
		return
	_acertou = true
	if pai == null:
		return
	if _projetil:
		_som("ataque")  # de longe: o som sai junto com o projétil
		var origem := global_position + Vector2(0, -10)
		var p := Projetil.new()
		p.direcao = ((pai.global_position + Vector2(0, -8)) - origem).normalized()
		p.dano = dano
		p.velocidade = _dados.get("velocidade_projetil", p.velocidade)
		p.cor = _dados.get("cor_projetil", p.cor)
		p.apagar_luz = _dados.get("apagar_luz", 0.0)
		get_parent().add_child(p)
		p.global_position = origem
	elif global_position.distance_to(pai.global_position) <= _alcance + 6.0 and _ve(pai):
		pai.levar_dano(dano, global_position)


## Chamado pelo ataque do Pai.
func levar_dano(qtd: int, direcao: Vector2, arma := {}) -> void:
	if morto:
		return
	if _fechado:
		_piscar(Color(0.55, 0.55, 0.6))  # "tink": fechado não leva dano
		Som.tocar_em("armas/bloqueado", _ponto_som())
		return
	if _carregado:
		_piscar(Color(0.45, 0.75, 1.0))  # "tink" azul: carregado de energia
		Som.tocar_em("armas/bloqueado", _ponto_som())
		Som.tocar_em("armas/choque", _ponto_som(), -6.0)
		acordar()
		return
	vida -= qtd
	acordar()
	Som.tocar_em("armas/impacto", _ponto_som())
	if vida > 0:
		_som("dano")
	if not _fixo:
		_empurrao = direcao * (60.0 if _projetil else 120.0)
	_piscar(Color(1, 0.35, 0.35))
	if arma.has("veneno"):
		_veneno_t = arma.veneno
		_veneno_tick = 1.0
	if arma.has("choque") and vida > 0:
		Som.tocar_em("armas/choque", _ponto_som(), -3.0)
		_atordoado_t = arma.choque
		_ataque_t = 0.0  # o golpe que ele preparava não sai
		_piscar(Color(0.6, 0.85, 1.0))
	if vida <= 0:
		morrer()
		return
	if _ataque_t <= 0.0:
		_tocar("hurt", 0.25)


func _tick_veneno(delta: float) -> void:
	if _veneno_t <= 0.0 or _fechado:
		return
	_veneno_t -= delta
	_veneno_tick -= delta
	if _veneno_tick <= 0.0:
		_veneno_tick = 1.0
		vida -= 1
		_piscar(Color(0.5, 1, 0.4))
		Som.tocar_em("armas/veneno", _ponto_som(), -2.0)
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
	_som("morte")
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
	if _fechado and _sprite.sprite_frames.has_animation("closed"):
		anim = "closed"
	elif vel.length() > 2.0 and _sprite.sprite_frames.has_animation("walk"):
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


# --- som ------------------------------------------------------------------------------

## Som do monstro para `evento` ("ataque", "dano", "morte"), pela família do
## campo "som" da tabela (ex.: "aranha" -> res://sons/inimigos/aranha_morte.wav).
## Sem a família ou sem o arquivo, usa o genérico.
func _som(evento: String) -> void:
	var nome := "inimigos/%s_%s" % [_dados.get("som", "generico"), evento]
	if not Som.existe(nome):
		nome = "inimigos/generico_" + evento
	Som.tocar_em(nome, _ponto_som(), 0.0, _tom_som())


## Monstro maior = som mais grave (aranha grande x aranha pequena).
func _tom_som() -> float:
	return clampf(1.0 / sqrt(maxf(absf(scale.x), 0.01)), 0.75, 1.3)


func _ponto_som() -> Vector2:
	return global_position + Vector2(0, -8)



## Chama do rastro da fúria: uma chama sombria em miniatura no chão, que dá
## dano ao Pai que pisar nela (ele fica invulnerável um instante depois de cada
## golpe) e se desfaz depois de `duracao` segundos.
class RastroFogo extends Area2D:
	const FOLHA_IDLE := "res://assets/32x32_Pixel_Art_Monsters_Pack/02_Elementals_And_Magic/03_Shadow_Flame/ShadowFlame_Idle_6f.png"
	const FOLHA_MORTE := "res://assets/32x32_Pixel_Art_Monsters_Pack/02_Elementals_And_Magic/03_Shadow_Flame/ShadowFlame_Death_6f.png"
	const QUADRO := 64
	const ESCALA := 0.4

	var dano := 1
	var duracao := 3.0
	var _sprite: AnimatedSprite2D
	var _sumindo := false
	static var _frames: SpriteFrames

	static func _quadros() -> SpriteFrames:
		if _frames:
			return _frames
		_frames = SpriteFrames.new()
		_frames.add_animation("arde")
		_frames.set_animation_speed("arde", 10.0)
		var idle: Texture2D = load(FOLHA_IDLE)
		for i in 6:
			var at := AtlasTexture.new()
			at.atlas = idle
			at.region = Rect2(i * QUADRO, 0, QUADRO, QUADRO)
			_frames.add_frame("arde", at)
		_frames.add_animation("some")
		_frames.set_animation_speed("some", 10.0)
		_frames.set_animation_loop("some", false)
		var morte: Texture2D = load(FOLHA_MORTE)
		for i in range(3, 6):  # quadros finais: a chama se desfaz em fagulhas
			var at := AtlasTexture.new()
			at.atlas = morte
			at.region = Rect2(i * QUADRO, 0, QUADRO, QUADRO)
			_frames.add_frame("some", at)
		return _frames

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		monitorable = false
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 5.0
		cs.shape = shape
		cs.position = Vector2(0, -2)
		add_child(cs)
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = _quadros()
		_sprite.scale = Vector2.ONE * ESCALA
		_sprite.offset = Vector2(0, -QUADRO * 0.3)  # base da chama nos pés
		_sprite.play("arde")
		_sprite.frame = randi() % 6
		add_child(_sprite)
		var luz := PointLight2D.new()
		luz.texture = Projetil._textura_luz()
		luz.color = Color(0.6, 0.3, 1.0)
		luz.energy = 0.5
		luz.texture_scale = 0.6
		add_child(luz)
		get_tree().create_timer(duracao).timeout.connect(_sumir)

	func _physics_process(_delta: float) -> void:
		if _sumindo:
			return
		for b in get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("levar_dano"):
				b.levar_dano(dano, global_position)

	func _sumir() -> void:
		if not is_inside_tree():
			return
		_sumindo = true
		_sprite.play("some")
		await _sprite.animation_finished
		queue_free()
