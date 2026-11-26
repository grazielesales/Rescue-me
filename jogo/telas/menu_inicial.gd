extends TelaPixel
## Menu inicial (primeira tela do jogo, a cena principal do projeto):
## Novo jogo, Continuar (só aparece quando existe save), Créditos e Sair.
## Novo jogo com save existente pede confirmação antes de apagar.
## Teclado: setas/WASD escolhem, Enter/Espaço confirmam, Esc fecha a pergunta.

const FimFilho := preload("res://jogo/fim_filho.gd")

var _botoes: VBoxContainer
var _continuar: Button
var _novo: Button
var _confirmar: PanelContainer
var _nao: Button


func _ready() -> void:
	layer = 20
	_montar_base(Color(0.035, 0.025, 0.045))

	# a chaminha do filho, acesa, em cima do título
	var chama := FimFilho.Chama.new()
	chama.scale = Vector2(0.5, 0.5)  # 2 px da TELA por pixel da chama
	chama.position = Vector2(TELA.x / 2.0 - 9.0, 14)
	raiz.add_child(chama)

	var titulo := _rotulo("Rescue Me", COR_CLARA, 30)
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.06))
	titulo.add_theme_constant_override("outline_size", 2)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(0, 50)
	titulo.size = Vector2(TELA.x, 40)
	raiz.add_child(titulo)
	var sub := _rotulo("Enquanto a luz dele brilhar, ainda dá tempo.", COR_CLARA_FRACA)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 88)
	sub.size = Vector2(TELA.x, 14)
	raiz.add_child(sub)

	_botoes = VBoxContainer.new()
	_botoes.add_theme_constant_override("separation", 4)
	_botoes.position = Vector2(TELA.x / 2.0 - 56, 112)
	raiz.add_child(_botoes)
	_novo = _botao("Novo jogo", _novo_jogo)
	_botoes.add_child(_novo)
	_continuar = _botao("Continuar", _continuar_jogo)
	_continuar.visible = Jogo.tem_save()
	_botoes.add_child(_continuar)
	_botoes.add_child(_botao("Créditos", func(): Jogo.mostrar_creditos(false)))
	_botoes.add_child(_botao("Sair", func(): get_tree().quit()))

	var dica := _rotulo("Setas: escolher    Enter: confirmar", COR_CLARA_FRACA)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.position = Vector2(0, TELA.y - 16)
	dica.size = Vector2(TELA.x, 14)
	raiz.add_child(dica)

	_montar_confirmacao()
	Musica.tocar_andar("andar1")
	(_continuar if _continuar.visible else _novo).grab_focus()


func _montar_confirmacao() -> void:
	_confirmar = _painel(10)
	_confirmar.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_confirmar.add_child(col)
	var pergunta := _rotulo("Começar do zero?\nO jogo salvo será apagado.", COR_TINTA)
	pergunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pergunta)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 6)
	linha.add_child(_botao("Apagar e começar", _apagar_e_comecar, 96))
	_nao = _botao("Voltar", _fechar_confirmacao, 64)
	linha.add_child(_nao)
	col.add_child(linha)
	raiz.add_child(_confirmar)


func _novo_jogo() -> void:
	if not Jogo.tem_save():
		_comecar()
		return
	for b in _botoes.get_children():
		b.disabled = true
	_confirmar.visible = true
	_confirmar.reset_size()
	_confirmar.position = ((TELA - _confirmar.size) / 2.0).floor() + Vector2(0, 24)
	_nao.grab_focus()  # o padrão é não apagar


func _fechar_confirmacao() -> void:
	_confirmar.visible = false
	for b in _botoes.get_children():
		b.disabled = false
	_novo.grab_focus()


func _apagar_e_comecar() -> void:
	_confirmar.visible = false
	_comecar()


func _comecar() -> void:
	for b in _botoes.get_children():
		b.disabled = true
	Jogo.novo_jogo("")


func _continuar_jogo() -> void:
	for b in _botoes.get_children():
		b.disabled = true
	Jogo.continuar_jogo()


func _unhandled_input(event: InputEvent) -> void:
	if _confirmar.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar_confirmacao()
