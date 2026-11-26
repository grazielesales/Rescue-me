extends TelaPixel
## Créditos que sobem pela tela (criados pelo autoload Jogo). Aparecem no fim
## do jogo (depois do abraço no filho) e pelo botão "Créditos" do menu.
## Esc, Enter ou clique pulam. `await mostrar()` volta quando acabam.

signal _acabou

## Integrantes do grupo (GDD).
const GRUPO := ["Graziele Sales", "Otavio Scalari", "Fernanda Italiano", "Miguel Veloso"]
## Arte de terceiros: [obra, autor, licença]. Alguns pacotes só podem ser
## usados com o crédito no jogo: toda arte nova de assets/ entra aqui.
## (Lista de autores e licenças: tarefa do Otavio.)
const ARTE := [
	["Pixel UI Fantasy Free", "heyheythere", "CC BY 4.0"],
	["Evil Eye | Pixel Monsters Vol. 13", "elesrech", ""],
	["Wizard sheet", "GandalfHardcore", ""],
]
## Pixels da TELA por segundo.
const VELOCIDADE := 22.0

var _rolo: VBoxContainer
var _tween: Tween
var _pode_pular := false


func _ready() -> void:
	layer = 110  # acima do fade do Jogo (100), como a tela do fim
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar_base(Color(0.02, 0.015, 0.03))
	raiz.clip_contents = true

	_rolo = VBoxContainer.new()
	_rolo.add_theme_constant_override("separation", 3)
	_rolo.custom_minimum_size.x = TELA.x  # largura da tela: as linhas centralizam
	raiz.add_child(_rolo)
	_titulo("Rescue Me", 30)
	_espaco(18)
	_secao("Um jogo de")
	for nome in GRUPO:
		_linha(nome, COR_CLARA)
	_espaco(16)
	_secao("Sons e música")
	_linha("feitos pelo grupo, por síntese", COR_CLARA_FRACA)
	if not ARTE.is_empty():
		_espaco(16)
		_secao("Arte")
		for a in ARTE:
			_linha(a[0], COR_CLARA)
			_linha("de %s%s" % [a[1], "  -  " + a[2] if a[2] != "" else ""], COR_CLARA_FRACA)
			_espaco(4)
	_espaco(16)
	_secao("Feito com")
	_linha("Godot Engine", COR_CLARA)
	_espaco(40)
	_linha("Obrigado por jogar.", COR_CLARA, 20)

	var dica := _rotulo("Esc: pular", COR_CLARA_FRACA)
	dica.position = Vector2(TELA.x - 60, TELA.y - 14)
	raiz.add_child(dica)


## Rola os créditos de baixo até sumirem em cima.
func mostrar() -> void:
	visible = true
	_pode_pular = false
	get_tree().create_timer(0.8, true, false, true).timeout.connect(func(): _pode_pular = true)
	_rolo.reset_size()
	_rolo.position = Vector2(0, TELA.y)
	var fim := -_rolo.size.y
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rolo, "position:y", fim, (TELA.y - fim) / VELOCIDADE)
	_tween.finished.connect(_terminar)
	await _acabou
	var tw := create_tween()
	tw.tween_property(raiz, "modulate:a", 0.0, 0.4)
	await tw.finished
	visible = false
	raiz.modulate.a = 1.0


func _terminar() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_acabou.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()  # nada passa para o que está por baixo
	if not _pode_pular or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel") or event.is_action("ui_accept") or event is InputEventMouseButton:
		_pode_pular = false
		_terminar()


func _titulo(texto: String, tamanho: int) -> void:
	var l := _linha(texto, COR_CLARA, tamanho)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.06))
	l.add_theme_constant_override("outline_size", 2)


func _secao(texto: String) -> void:
	_linha(texto.to_upper(), Color(0.85, 0.55, 0.35))


func _linha(texto: String, cor: Color, tamanho := 10) -> Label:
	var l := _rotulo(texto, cor, tamanho)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rolo.add_child(l)
	return l


func _espaco(altura: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, altura)
	_rolo.add_child(c)
