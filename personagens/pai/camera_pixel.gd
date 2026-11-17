extends Camera2D
## Câmera do Pai com pixel art nítida.
##
## - Escala inteira: cada pixel do mundo vira um número inteiro de pixels da
##   tela, em qualquer tamanho de janela (sem pixels de larguras diferentes).
##   O zoom é ajustado em volta de `zoom_base`, para a área visível ficar
##   parecida com a de antes.
## - Movimento suave, mas a posição final sempre cai num pixel inteiro da
##   tela, então o cenário não treme quando a câmera anda.

## Zoom pensado para a janela base do projeto (1152x648).
@export var zoom_base := 3.0
## Quanto mais alto, mais rápido a câmera alcança o Pai.
@export var suavidade := 8.0
## Acima dessa distância (teleporte, recomeço) a câmera pula direto.
@export var distancia_pulo := 160.0

var _alvo_local := Vector2.ZERO
var _pos := Vector2.ZERO
var _escala := 3.0  # pixels da tela por pixel do mundo


func _ready() -> void:
	_alvo_local = position
	position_smoothing_enabled = false
	top_level = true
	get_tree().root.size_changed.connect(_ajustar_zoom)
	_ajustar_zoom()
	_pos = _alvo()
	_aplicar()


func _process(delta: float) -> void:
	var alvo := _alvo()
	if _pos.distance_to(alvo) > distancia_pulo:
		_pos = alvo
	else:
		_pos = _pos.lerp(alvo, 1.0 - exp(-suavidade * delta))
	_aplicar()


func _alvo() -> Vector2:
	var pai := get_parent() as Node2D
	return pai.global_position + _alvo_local if pai else global_position


func _aplicar() -> void:
	global_position = (_pos * _escala).round() / _escala


## Com stretch "canvas_items", a tela é escalada por `fator`; o zoom total é
## fator x zoom. Arredondamos esse total para um inteiro.
func _ajustar_zoom() -> void:
	var base := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var janela := Vector2(get_tree().root.size)
	var fator := minf(janela.x / base.x, janela.y / base.y)
	fator *= float(ProjectSettings.get_setting("display/window/stretch/scale", 1.0))
	if fator <= 0.0:
		return
	_escala = maxf(1.0, roundf(fator * zoom_base))
	zoom = Vector2.ONE * (_escala / fator)
