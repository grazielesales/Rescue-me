extends CanvasLayer
## Autoload "Jogo": estado que precisa sobreviver à troca de andar
## (salas já visitadas, por qual escada o Pai chegou) + fade e mensagens na tela.

## Chave "cena:sala" de cada sala que o Pai já visitou.
var salas_visitadas := {}
## id da escada onde o Pai deve aparecer no próximo andar ("" = posição da cena).
var escada_de_chegada := ""

var _fade: ColorRect
var _titulo: Label
var _msg: Label
var _msg_tween: Tween
var _dica: Label
var _painel: PanelContainer
var _texto: Label
var _trocando := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	_titulo = _label(28, Control.PRESET_CENTER_TOP, Vector2(0, 40))
	_msg = _label(16, Control.PRESET_CENTER_BOTTOM, Vector2(0, -60))
	_dica = _label(14, Control.PRESET_CENTER_BOTTOM, Vector2(0, -30))

	_painel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	estilo.border_color = Color(0.75, 0.66, 0.48)
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(14)
	_painel.add_theme_stylebox_override("panel", estilo)
	_painel.set_anchors_preset(Control.PRESET_CENTER)
	_painel.custom_minimum_size = Vector2(420, 0)
	_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_painel.visible = false
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 15)
	_texto.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	_painel.add_child(_texto)
	add_child(_painel)


func _label(tamanho: int, preset: int, deslocamento: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position += deslocamento
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- salas ----------------------------------------------------------------------

func sala_visitada(chave: String) -> bool:
	return salas_visitadas.has(chave)


func marcar_sala(chave: String) -> void:
	salas_visitadas[chave] = true


# --- troca de andar ----------------------------------------------------------------

## Escurece a tela, troca de cena e clareia. `chegada` é o id da escada
## onde o Pai vai aparecer na cena nova.
func trocar_andar(cena: String, chegada: String) -> void:
	if _trocando:
		return
	_trocando = true
	escada_de_chegada = chegada
	await fade(1.0, 0.45)
	get_tree().change_scene_to_file(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 0.45)
	_trocando = false


func fade(alvo: float, tempo: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alvo, tempo)
	await t.finished


# --- textos ----------------------------------------------------------------------

func mostrar_titulo(texto: String) -> void:
	_titulo.text = texto
	var t := create_tween()
	t.tween_property(_titulo, "modulate:a", 1.0, 0.6)
	t.tween_interval(1.8)
	t.tween_property(_titulo, "modulate:a", 0.0, 0.8)


## Mensagem curta no centro-baixo da tela (GDD 7.4).
func mostrar_mensagem(texto: String, duracao := 2.5) -> void:
	_msg.text = texto
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg, "modulate:a", 1.0, 0.2)
	_msg_tween.tween_interval(duracao)
	_msg_tween.tween_property(_msg, "modulate:a", 0.0, 0.4)


func mostrar_dica(texto: String) -> void:
	_dica.text = texto
	_dica.modulate.a = 1.0


func esconder_dica() -> void:
	_dica.modulate.a = 0.0


## Texto longo (bilhetes). Fica na tela até esconder_texto().
func mostrar_texto(texto: String) -> void:
	_texto.text = texto
	_painel.visible = true


func esconder_texto() -> void:
	_painel.visible = false
