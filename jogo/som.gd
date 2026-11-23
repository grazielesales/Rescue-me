extends Node
## Autoload "Som": toca os efeitos sonoros que ficam em res://sons.
##
## - Som.tocar("pai/dano"): som "da tela", sem posição (o Pai e a interface);
## - Som.tocar_em("inimigos/aranha_morte", global_position): som no mundo, que
##   fica mais baixo longe da câmera e sai mais pela esquerda ou pela direita;
## - o nome é o caminho dentro de res://sons sem o ".wav". Se houver variações
##   (passo_1.wav, passo_2.wav...), cada vez sorteia uma, sem repetir a última;
## - cada vez o tom varia um pouquinho (`variacao`), para não cansar o ouvido;
## - no máximo MAX_IGUAIS cópias do mesmo som tocam juntas, e o mesmo som não
##   recomeça antes de INTERVALO_MINIMO (um golpe que acerta três monstros).
## Os efeitos vão no barramento "Efeitos" (res://default_bus_layout.tres);
## a música, quando entrar, vai no "Musica".
## Os sons são gerados por res://sons/gerador/gerar_sons.gd (ver sons/LEIAME.md).

const PASTA := "res://sons/"
const BARRAMENTO := &"Efeitos"
## Quantos sons de cada tipo podem tocar ao mesmo tempo.
const VOZES_TELA := 10
const VOZES_MUNDO := 20
const MAX_IGUAIS := 3
const INTERVALO_MINIMO := 30  # ms
## Distância (px do mundo) em que um som do mundo some de vez.
const DISTANCIA_MAX := 360.0

## nome -> Array de AudioStream (vazio = não existe).
var _cache := {}
## nome -> índice da última variação tocada.
var _ultima := {}
## nome -> Time.get_ticks_msec() da última vez que tocou.
var _quando := {}
var _avisados := {}
var _tela: Array[AudioStreamPlayer] = []
var _mundo: Array[AudioStreamPlayer2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # livro e inventário pausam o jogo
	var bus := BARRAMENTO if AudioServer.get_bus_index(BARRAMENTO) != -1 else &"Master"
	for i in VOZES_TELA:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_tela.append(p)
	for i in VOZES_MUNDO:
		var p := AudioStreamPlayer2D.new()
		p.bus = bus
		p.max_distance = DISTANCIA_MAX
		p.attenuation = 1.2
		p.panning_strength = 0.6
		add_child(p)
		_mundo.append(p)


## Toca sem posição. `tom` multiplica a velocidade (1 = normal, 0.8 = mais grave).
func tocar(nome: String, volume_db := 0.0, tom := 1.0, variacao := 0.05) -> void:
	var s := _escolher(nome)
	if s == null:
		return
	_disparar(_voz_livre(_tela), s, nome, volume_db, tom, variacao)


## Toca no ponto `pos` do mundo (coordenadas globais).
func tocar_em(nome: String, pos: Vector2, volume_db := 0.0, tom := 1.0, variacao := 0.05) -> void:
	var s := _escolher(nome)
	if s == null:
		return
	var p: AudioStreamPlayer2D = _voz_livre(_mundo)
	p.global_position = pos
	_disparar(p, s, nome, volume_db, tom, variacao)


## Existe esse som (ou variações dele)?
func existe(nome: String) -> bool:
	return not _variacoes(nome).is_empty()


# --- interno -----------------------------------------------------------------------------

func _variacoes(nome: String) -> Array:
	if _cache.has(nome):
		return _cache[nome]
	var lista := []
	var unico := PASTA + nome + ".wav"
	if ResourceLoader.exists(unico):
		lista.append(load(unico))
	var i := 1
	while ResourceLoader.exists("%s%s_%d.wav" % [PASTA, nome, i]):
		lista.append(load("%s%s_%d.wav" % [PASTA, nome, i]))
		i += 1
	_cache[nome] = lista
	return lista


## Sorteia a variação e aplica os limites de repetição. null = não tocar.
func _escolher(nome: String) -> AudioStream:
	var lista := _variacoes(nome)
	if lista.is_empty():
		if not _avisados.has(nome):
			_avisados[nome] = true
			push_warning("Som: não achei %s%s.wav" % [PASTA, nome])
		return null
	var agora := Time.get_ticks_msec()
	if agora - int(_quando.get(nome, -100000)) < INTERVALO_MINIMO:
		return null
	if _tocando(nome) >= MAX_IGUAIS:
		return null
	_quando[nome] = agora
	var idx := 0
	if lista.size() > 1:
		idx = randi() % (lista.size() - 1)
		if idx >= int(_ultima.get(nome, -1)):
			idx += 1  # pula a última, para não repetir seguido
	_ultima[nome] = idx
	return lista[idx]


func _tocando(nome: String) -> int:
	var n := 0
	for p in _tela:
		if p.playing and p.get_meta("nome", "") == nome:
			n += 1
	for p in _mundo:
		if p.playing and p.get_meta("nome", "") == nome:
			n += 1
	return n


## Um player parado; se todos estiverem tocando, o que está há mais tempo.
func _voz_livre(vozes: Array) -> Node:
	var mais_velho: Node = vozes[0]
	var maior := -1.0
	for p in vozes:
		if not p.playing:
			return p
		var t: float = p.get_playback_position()
		if t > maior:
			maior = t
			mais_velho = p
	return mais_velho


func _disparar(p: Node, s: AudioStream, nome: String, volume_db: float, tom: float, variacao: float) -> void:
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, tom * (1.0 + randf_range(-variacao, variacao)))
	p.set_meta("nome", nome)
	p.play()
