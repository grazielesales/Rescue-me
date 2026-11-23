extends Node
## Autoload "Musica": a música ambiente de cada andar e a versão tensa, que
## entra quando o Pai está numa sala com monstros acordados (ou numa arena
## trancada) e sai devagar depois que a sala fica vazia.
##
## Cada andar tem res://sons/musica/<nome>_ambiente.wav e <nome>_tensao.wav,
## do mesmo tamanho e em laço. As duas tocam juntas o tempo todo; só o volume
## de cada uma muda, então a troca acontece no compasso certo, sem recomeçar.
## O andar.gd chama tocar_andar() ao abrir (o nome vem do arquivo da cena).
## Toca no barramento "Musica" (default_bus_layout.tres).

const PASTA := "res://sons/musica/"
const BARRAMENTO := &"Musica"
## Volume geral da música (fica abaixo dos efeitos).
const VOLUME_DB := -7.0
## Segundos para a tensão entrar e para sair.
const TEMPO_ENTRAR := 1.2
const TEMPO_SAIR := 3.0
## Segundos sem monstro acordado por perto antes de começar a relaxar.
const ESPERA_RELAXAR := 2.0
## Fade ao trocar de andar.
const TEMPO_TROCA := 0.6

## true enquanto a versão tensa está (ou vai ficar) por cima.
var tensa := false

var _ambiente: AudioStreamPlayer
var _tensao: AudioStreamPlayer
var _atual := ""
var _mistura := 0.0  # 0 = só ambiente, 1 = só tensa
var _volume := 1.0   # fade de troca de andar
var _relaxar_t := 0.0
var _checar_t := 0.0
var _troca: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua com o livro aberto
	var bus := BARRAMENTO if AudioServer.get_bus_index(BARRAMENTO) != -1 else &"Master"
	_ambiente = AudioStreamPlayer.new()
	_tensao = AudioStreamPlayer.new()
	for p in [_ambiente, _tensao]:
		p.bus = bus
		add_child(p)
	_aplicar_volume()


## Toca a música do andar `nome` (ex.: "andar1"). Se já é a que está tocando
## (ex.: o Pai morreu e o andar recomeçou), continua de onde estava.
func tocar_andar(nome: String) -> void:
	if nome == _atual:
		return
	_atual = nome
	var amb := _carregar(nome + "_ambiente")
	var ten := _carregar(nome + "_tensao")
	if _troca:
		_troca.kill()
	_troca = create_tween()
	if _ambiente.playing:
		_troca.tween_property(self, "_volume", 0.0, TEMPO_TROCA)
	else:
		_volume = 0.0
	_troca.tween_callback(_trocar.bind(amb, ten))
	_troca.tween_property(self, "_volume", 1.0, TEMPO_TROCA * 2.0)


## Para a música (com fade).
func parar() -> void:
	_atual = ""
	if _troca:
		_troca.kill()
	_troca = create_tween()
	_troca.tween_property(self, "_volume", 0.0, TEMPO_TROCA)
	_troca.tween_callback(_trocar.bind(null, null))


func _trocar(amb: AudioStream, ten: AudioStream) -> void:
	_ambiente.stop()
	_tensao.stop()
	_ambiente.stream = amb
	_tensao.stream = ten
	tensa = false
	_mistura = 0.0
	_relaxar_t = 0.0
	if amb:
		_ambiente.play()
	if ten:
		_tensao.play()  # junto com a ambiente: as duas andam no mesmo compasso


func _carregar(nome: String) -> AudioStream:
	var caminho := PASTA + nome + ".wav"
	if not ResourceLoader.exists(caminho):
		push_warning("Musica: não achei " + caminho)
		return null
	return load(caminho)


func _process(delta: float) -> void:
	_checar_t -= delta
	if _checar_t <= 0.0:
		_checar_t = 0.25
		if _monstros_por_perto():
			tensa = true
			_relaxar_t = ESPERA_RELAXAR
		elif tensa:
			_relaxar_t -= 0.25
			if _relaxar_t <= 0.0:
				tensa = false
	var alvo := 1.0 if tensa else 0.0
	_mistura = move_toward(_mistura, alvo, delta / (TEMPO_ENTRAR if tensa else TEMPO_SAIR))
	_aplicar_volume()


## Troca cruzada de "potência constante": o volume total não afunda no meio.
func _aplicar_volume() -> void:
	var a := cos(_mistura * PI / 2.0) * _volume
	var t := sin(_mistura * PI / 2.0) * _volume
	_ambiente.volume_db = linear_to_db(maxf(a, 0.0001)) + VOLUME_DB
	_tensao.volume_db = linear_to_db(maxf(t, 0.0001)) + VOLUME_DB


## O Pai está numa sala (sala.gd) trancada ou com algum monstro acordado,
## visível e vivo?
func _monstros_por_perto() -> bool:
	if not Jogo._pai_ativo():
		return false
	var p: Vector2 = Jogo.pai.global_position
	for s in get_tree().get_nodes_in_group("salas"):
		if not s.contem(p):
			continue
		if s.get("_trancada"):
			return true
		for m in s.inimigos():
			if m.is_in_group("inimigos") and not m.get("morto") and not m.get("dormindo") and not m.get("_escondido"):
				return true
	return false
