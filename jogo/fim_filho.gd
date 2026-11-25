extends CanvasLayer
## Tela de quando a luz do filho apaga (Jogo._luz_filho_apagou): a chaminha
## dele treme e se apaga no escuro, sobe um fio de fumaça e aparece o aviso.
## Fica por cima de tudo (até do fade do Jogo) e funciona com o jogo pausado.
## Jogo chama `await mostrar()` (volta quando o jogador aperta uma tecla, ou
## sozinho depois de um tempo) e depois `await esconder()`.

signal _continuar

const COR_TITULO := Color(0.72, 0.1, 0.1)
const COR_TEXTO := Color(0.93, 0.88, 0.76)
const TITULO := "A luz do seu filho se apagou."
const TEXTO := "Ele esperou pelo pai até a última faísca.\nChamou baixinho, uma vez, e depois não chamou mais.\n\nNo andar de cima, o homem de capa sorriu no escuro.\n\nSeu filho não pôde ser salvo."
const DICA := "aperte qualquer tecla para recomeçar"
## Segundos até a dica aparecer (e as teclas valerem) e até seguir sozinho.
const ESPERA_DICA := 7.0
const ESPERA_MAXIMA := 30.0

var _fundo: ColorRect
var _chama: Chama
var _titulo: Label
var _texto: Label
var _dica: Label
var _esperando := false
var _t := 0.0


func _ready() -> void:
	layer = 110  # acima do Jogo (100), que tem o fade
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_fundo = ColorRect.new()
	_fundo.color = Color(0.02, 0.0, 0.0, 0.0)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 18)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(coluna)

	_chama = Chama.new()
	_chama.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coluna.add_child(_chama)
	_titulo = _label(TITULO, 30, COR_TITULO)
	coluna.add_child(_titulo)
	_texto = _label(TEXTO, 15, Color(COR_TEXTO, 0.8))
	_texto.custom_minimum_size = Vector2(520, 0)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_texto)
	_dica = _label(DICA, 12, Color(COR_TEXTO, 0.5))
	coluna.add_child(_dica)


func _label(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	return l


## Escurece, apaga a chama, mostra o aviso e espera o jogador.
func mostrar() -> void:
	visible = true
	_esperando = false
	_t = 0.0
	_fundo.color.a = 0.0
	_chama.forca = 1.0
	for l in [_titulo, _texto, _dica]:
		l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fundo, "color:a", 0.94, 2.0)
	# a chama treme mais e mais e se apaga
	tw.parallel().tween_property(_chama, "forca", 0.0, 3.2).set_delay(0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.4)
	tw.tween_property(_titulo, "modulate:a", 1.0, 1.6)
	tw.tween_interval(0.6)
	tw.tween_property(_texto, "modulate:a", 1.0, 2.0)
	await get_tree().create_timer(ESPERA_DICA, true).timeout
	create_tween().tween_property(_dica, "modulate:a", 1.0, 1.0)
	_esperando = true
	get_tree().create_timer(ESPERA_MAXIMA - ESPERA_DICA, true).timeout.connect(_seguir)
	await _continuar


## Some com a tela (o Jogo já deixou o fade preto por baixo).
func esconder(tempo := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fundo, "color:a", 1.0, tempo * 0.5)
	for l in [_chama, _titulo, _texto, _dica]:
		tw.parallel().tween_property(l, "modulate:a", 0.0, tempo)
	await tw.finished
	visible = false
	_chama.modulate.a = 1.0


func _seguir() -> void:
	if _esperando:
		_esperando = false
		_continuar.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()  # nada passa para o jogo por baixo
	if _esperando and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		_seguir()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# o título treme de leve, de vez em quando
	_titulo.position.x = round(sin(_t * 31.0) * 1.2) if fmod(_t, 2.3) < 0.25 else 0.0
	if _esperando:
		_dica.modulate.a = 0.35 + 0.25 * sin(_t * 2.5)


## Chaminha em pixel art (pixels de 4 px da tela). `forca` 1 = acesa e
## tremendo; perto de 0 fica pequena e azulada; 0 = apagada, só a fumaça.
class Chama extends Control:
	const PIXEL := 4.0
	const LARGURA := 9
	const ALTURA := 16
	var forca := 1.0:
		set(v):
			forca = v
			queue_redraw()
	var _t := 0.0
	var _fumaca := 0.0  # sobe depois que apaga

	func _init() -> void:
		custom_minimum_size = Vector2(LARGURA, ALTURA) * PIXEL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		_fumaca = _fumaca + delta if forca <= 0.01 else 0.0
		queue_redraw()

	func _px(x: float, y: float, c: Color) -> void:
		draw_rect(Rect2(Vector2(roundf(x), roundf(y)) * PIXEL, Vector2.ONE * PIXEL), c)

	func _draw() -> void:
		var base := Vector2(4, ALTURA - 2)  # pavio
		# pavio (some um pouco depois que apaga, e fica em brasa no fim)
		_px(base.x, base.y, Color(0.25, 0.2, 0.18))
		_px(base.x, base.y + 1, Color(0.25, 0.2, 0.18))
		if forca > 0.01:
			# treme mais quando está fraca; às vezes quase some
			var tremor := (1.0 - forca) * 1.6 + 0.3
			var h := 2.0 + 7.0 * forca * (0.85 + 0.15 * sin(_t * 17.0)) * (0.6 if sin(_t * 5.3) > 0.93 else 1.0)
			var desvio := sin(_t * 9.0) * tremor
			var nucleo := Color(1.0, 0.95, 0.75).lerp(Color(0.6, 0.7, 1.0), 1.0 - forca)
			var meio := Color(1.0, 0.7, 0.3).lerp(Color(0.35, 0.4, 0.9), 1.0 - forca)
			var borda := Color(0.85, 0.3, 0.1, 0.8).lerp(Color(0.2, 0.2, 0.6, 0.6), 1.0 - forca)
			for i in int(ceilf(h)):
				var k := float(i) / h  # 0 = em baixo, 1 = na ponta
				var y := base.y - 1 - i
				var x := base.x + desvio * k * k
				var meia := roundf((1.0 - k) * 2.0 * minf(1.0, forca + 0.3))
				for dx in range(-int(meia) - 1, int(meia) + 2):
					var c := borda
					if absi(dx) <= int(meia) - 1:
						c = nucleo
					elif absi(dx) <= int(meia):
						c = meio
					_px(x + dx, y, c)
		elif _fumaca < 3.0:
			# brasa no pavio e um fio de fumaça subindo e sumindo
			_px(base.x, base.y - 1, Color(0.9, 0.25, 0.1, maxf(0.0, 1.0 - _fumaca)))
			var a := 0.5 * (1.0 - _fumaca / 3.0)
			for i in 6:
				var y := base.y - 2 - i - _fumaca * 2.0
				if y < 0:
					continue
				var x := base.x + sin(i * 0.9 + _t * 2.0) * (i * 0.3)
				_px(x, y, Color(0.6, 0.6, 0.62, a * (1.0 - i / 6.0)))
