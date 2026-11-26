extends TelaPixel
## Pausa (Esc durante o jogo; criada pelo autoload Jogo). O jogo para e a tela
## mostra as teclas e o volume (geral, música e efeitos, os barramentos do
## default_bus_layout.tres). O volume fica guardado em user://config.cfg e é
## aplicado ao abrir o jogo. Esc ou "Continuar" voltam ao jogo.

signal fechou

const CONFIG := "user://config.cfg"
## Barramento -> nome na tela.
const VOLUMES := [["Master", "Geral"], ["Musica", "Música"], ["Efeitos", "Efeitos"]]
const CONTROLES := [
	["WASD / setas", "andar"],
	["Clique", "atacar (mira no mouse)"],
	["Espaço", "esquivar"],
	["E", "interagir / ler"],
	["R", "livro de receitas"],
	["Tab", "inventário"],
	["1  2  3", "trocar de arma"],
	["Q", "usar curativo"],
	["Esc", "pausa"],
]

var _sliders := {}
var _valores := {}
var _continuar: Button


func _ready() -> void:
	layer = 101  # acima dos textos do Jogo (100); fecha antes de qualquer fade
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar_base(Color(0, 0, 0, 0.6))

	var janela := _painel(10)
	raiz.add_child(janela)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	janela.add_child(col)

	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 14)
	col.add_child(colunas)

	# controles
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 1)
	esq.add_child(_rotulo("Controles", COR_TINTA))
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 0)
	for c in CONTROLES:
		grade.add_child(_rotulo(c[0], COR_TINTA))
		grade.add_child(_rotulo(c[1], COR_TINTA_FRACA))
	esq.add_child(grade)
	colunas.add_child(esq)

	var lombada := ColorRect.new()
	lombada.color = COR_TINTA_FRACA
	lombada.custom_minimum_size = Vector2(1, 0)
	colunas.add_child(lombada)

	# volume
	var dir := VBoxContainer.new()
	dir.add_theme_constant_override("separation", 2)
	dir.add_child(_rotulo("Volume", COR_TINTA))
	for v in VOLUMES:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 4)
		var nome := _rotulo(v[1], COR_TINTA_FRACA)
		nome.custom_minimum_size.x = 48
		linha.add_child(nome)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(70, 12)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha.add_child(s)
		var pct := _rotulo("", COR_TINTA)
		pct.custom_minimum_size.x = 24
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		linha.add_child(pct)
		s.value_changed.connect(_mudou_volume.bind(v[0], pct))
		_sliders[v[0]] = s
		dir.add_child(linha)
	colunas.add_child(dir)

	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 6)
	_continuar = _botao("Continuar", fechar, 76)
	botoes.add_child(_continuar)
	botoes.add_child(_botao("Menu inicial", _ir_menu, 76))
	botoes.add_child(_botao("Sair do jogo", _sair, 76))
	col.add_child(botoes)

	var faixa := CenterContainer.new()
	faixa.size = Vector2(TELA.x, 18)
	raiz.add_child(faixa)
	faixa.add_child(_faixa("Pausa"))

	# centraliza a janela e põe a faixa em cima dela
	janela.reset_size()
	janela.position = ((TELA - janela.size) / 2.0).floor() + Vector2(0, 4)
	faixa.position = Vector2(0, janela.position.y - 9)

	_carregar_volumes()


func abrir() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	Som.tocar("interface/livro_abrir", 0.0, 1.0, 0.0)
	for bus in _sliders:
		_sliders[bus].set_value_no_signal(_valores[bus])
		_mudou_volume(_valores[bus], bus, _sliders[bus].get_parent().get_child(2))
	_continuar.grab_focus()


func fechar() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	_salvar_volumes()
	Som.tocar("interface/livro_fechar", 0.0, 1.0, 0.0)
	fechou.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()


func _ir_menu() -> void:
	fechar()
	Jogo.ir_para_menu()


func _sair() -> void:
	_salvar_volumes()
	Jogo.sair_do_jogo()


# --- volume -----------------------------------------------------------------------

func _mudou_volume(valor: float, bus: String, pct: Label) -> void:
	_valores[bus] = valor
	pct.text = "%d%%" % roundi(valor * 100.0)
	_aplicar(bus, valor)


func _aplicar(bus: String, valor: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, valor <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(valor, 0.001)))


func _carregar_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)  # sem arquivo: tudo em 100%
	for v in VOLUMES:
		_valores[v[0]] = clampf(float(cfg.get_value("volume", v[0], 1.0)), 0.0, 1.0)
		_aplicar(v[0], _valores[v[0]])


func _salvar_volumes() -> void:
	var cfg := ConfigFile.new()
	for bus in _valores:
		cfg.set_value("volume", bus, _valores[bus])
	cfg.save(CONFIG)
