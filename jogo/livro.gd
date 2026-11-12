extends CanvasLayer
## Livro de receitas (R), GDD 4.2 e 7.4, com a arte do Pixel UI Fantasy (tema parchment).
## Abre por cima do jogo, com o jogo pausado. Esc ou R fecham.
## - página esquerda: lista de receitas; as não descobertas aparecem como "???";
## - página direita: a receita escolhida, com ícone, efeito, materiais
##   (tem/precisa) e o botão Criar, ativo só com tudo disponível;
## - fitas na lateral: filtram por categoria (todas, armas, cura, melhorias).
## Teclado: setas cima/baixo escolhem a receita, esquerda/direita trocam a fita,
## Enter/Espaço criam.
## Arte: Pixel UI Fantasy Free by heyheythere - https://heyheythere.itch.io/pixel-ui-fantasy-free - CC BY 4.0

const UI := "res://addons/pixel_ui_fantasy/"
## A arte é 1x: o livro é desenhado num espaço de TELA pixels e a camada inteira
## é ampliada pela maior escala INTEIRA que cabe na janela (pixels nítidos),
## e centralizada. Ex.: 2x em 1152x648 ou 1280x720, 4x em 1920x1080.
const TELA := Vector2(428, 242)
## A capa deixa 30 px à direita para as fitas.
const CAPA := Rect2(14, 16, 384, 212)
const LARGURA_PAGINA := 178
## Largura útil do texto dentro de uma página (página menos as margens).
const LARGURA_TEXTO := 158

const COR_TINTA := Color(0.227, 0.133, 0.094)
const COR_TINTA_FRACA := Color(0.227, 0.133, 0.094, 0.55)
const COR_OK := Color(0.15, 0.42, 0.1)
const COR_FALTA := Color(0.62, 0.12, 0.1)
const COR_DICA := Color(0.93, 0.88, 0.76, 0.8)

## Fitas da lateral: filtro, nome, ícone e cor.
const ABAS := [
	{"id": "todas", "nome": "Todas", "icone": "icons/scroll.png", "cor": Color(0.86, 0.72, 0.48)},
	{"id": "arma", "nome": "Armas", "icone": "icons/sword.png", "cor": Color(0.82, 0.27, 0.22)},
	{"id": "curativo", "nome": "Cura", "icone": "icons/potion_red.png", "cor": Color(0.33, 0.66, 0.3)},
	{"id": "melhoria", "nome": "Melhorias", "icone": "icons/gem.png", "cor": Color(0.38, 0.48, 0.88)},
]
const SLOT_POR_TIPO := {"arma": "RareSlot", "curativo": "UncommonSlot", "melhoria": "EpicSlot"}
const NOME_TIPO := {"arma": "Arma", "curativo": "Item de cura", "melhoria": "Melhoria"}

var _modo := "receitas"  # o Jogo ainda chama abrir/alternar com o modo
var _aba := "todas"
var _sel := ""  # id da receita aberta na página direita
var _visiveis: Array[String] = []

var _lista: VBoxContainer
var _contagem: Label
var _detalhe: VBoxContainer
var _abas_bt := {}
var _escuro: ColorRect
var _estilo_sel: StyleBoxTexture
var _estilo_hover: StyleBoxFlat
var _estilo_vazio: StyleBoxEmpty


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_criar_estilos()

	var raiz := Control.new()
	raiz.size = TELA
	raiz.theme = load(UI + "themes/parchment.tres")
	add_child(raiz)

	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0, 0.6)
	raiz.add_child(_escuro)

	# fitas antes da capa, para a capa cobrir a base delas
	for i in ABAS.size():
		var a: Dictionary = ABAS[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.icon = load(UI + a.icone)
		b.tooltip_text = a.nome
		b.expand_icon = false
		b.size = Vector2(30, 22)
		b.pressed.connect(_escolher_aba.bind(a.id))
		raiz.add_child(b)
		_abas_bt[a.id] = b

	var capa := _nine(UI + "themes/parchment/portrait.png", 9, CAPA)
	raiz.add_child(capa)

	var esq := Rect2(CAPA.position + Vector2(10, 10), Vector2(LARGURA_PAGINA, CAPA.size.y - 20))
	var dir := Rect2(CAPA.position + Vector2(CAPA.size.x - 10 - LARGURA_PAGINA, 10), esq.size)
	raiz.add_child(_nine(UI + "themes/parchment/panel.png", 6, esq))
	raiz.add_child(_nine(UI + "themes/parchment/panel.png", 6, dir))
	# lombada
	var lombada := ColorRect.new()
	lombada.color = Color(0.16, 0.09, 0.06)
	lombada.position = Vector2(CAPA.get_center().x - 1, CAPA.position.y + 6)
	lombada.size = Vector2(2, CAPA.size.y - 12)
	raiz.add_child(lombada)

	# página esquerda: título, contagem e a lista
	var m_esq := _margem(esq, 10, 8)
	raiz.add_child(m_esq)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	m_esq.add_child(col)
	var topo := HBoxContainer.new()
	col.add_child(topo)
	var titulo := _texto("Receitas", COR_TINTA)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	_contagem = _texto("", COR_TINTA_FRACA)
	topo.add_child(_contagem)
	col.add_child(HSeparator.new())
	var rolar := ScrollContainer.new()
	rolar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(rolar)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 1)
	rolar.add_child(_lista)

	# página direita: detalhe da receita
	var m_dir := _margem(dir, 10, 8)
	raiz.add_child(m_dir)
	_detalhe = VBoxContainer.new()
	_detalhe.add_theme_constant_override("separation", 2)
	m_dir.add_child(_detalhe)

	# faixa com o nome do livro, por cima da capa
	var faixa := CenterContainer.new()
	faixa.position = Vector2(0, CAPA.position.y - 9)
	faixa.size = Vector2(TELA.x, 18)
	raiz.add_child(faixa)
	var nome_livro := Label.new()
	nome_livro.theme_type_variation = &"Ribbon"
	nome_livro.text = "Livro de Receitas"
	faixa.add_child(nome_livro)

	var dica := _texto("R/Esc: fechar    Setas: escolher    Enter: criar", COR_DICA)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.position = Vector2(0, CAPA.end.y + 2)
	dica.size = Vector2(TELA.x, 13)
	raiz.add_child(dica)

	Jogo.inventario_mudou.connect(_atualizar)
	Jogo.armas_mudou.connect(_atualizar)


func abrir(modo: String) -> void:
	_modo = modo
	_ajustar_escala()
	visible = true
	get_tree().paused = true
	Jogo.esconder_dica()
	_montar()


func fechar() -> void:
	visible = false
	get_tree().paused = false


## R de novo fecha o livro.
func alternar(_modo_pedido: String) -> void:
	fechar()


func _atualizar() -> void:
	if visible:
		_montar.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_up"):
		_mover(-1)
	elif event.is_action("ui_down"):
		_mover(1)
	elif event.is_action("ui_left"):
		_mover_aba(-1)
	elif event.is_action("ui_right"):
		_mover_aba(1)
	elif event.is_action("ui_accept"):
		if _sel != "":
			Jogo.criar(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


## Maior escala inteira que cabe na janela; centraliza e estica o fundo escuro.
func _ajustar_escala() -> void:
	var tela := get_viewport().get_visible_rect().size
	var e := maxf(1.0, floorf(minf(tela.x / TELA.x, tela.y / TELA.y)))
	scale = Vector2(e, e)
	offset = ((tela - TELA * e) / 2.0).floor()
	_escuro.position = -offset / e - Vector2.ONE
	_escuro.size = tela / e + Vector2(2, 2)


# --- montagem -----------------------------------------------------------------------------

func _montar() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_visiveis.clear()
	var da_aba := []
	for r in Itens.RECEITAS:
		if _aba == "todas" or r.tipo == _aba:
			da_aba.append(r)
			if Jogo.receitas_conhecidas.has(r.id):
				_visiveis.append(r.id)
	if not _visiveis.has(_sel):
		_sel = _visiveis[0] if not _visiveis.is_empty() else ""
	for r in da_aba:
		_lista.add_child(_linha(r, Jogo.receitas_conhecidas.has(r.id)))
	_contagem.text = "%d/%d" % [_visiveis.size(), da_aba.size()]
	_montar_abas()
	_montar_detalhe()


func _montar_abas() -> void:
	for i in ABAS.size():
		var a: Dictionary = ABAS[i]
		var b: Button = _abas_bt[a.id]
		var sel: bool = a.id == _aba
		# a escolhida sai mais da capa e fica mais clara
		b.position = Vector2(CAPA.end.x - (6.0 if sel else 10.0), CAPA.position.y + 22 + i * 26)
		var cor: Color = a.cor if sel else a.cor.darkened(0.3)
		for estado in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(estado, _estilo_fita(cor.lightened(0.15) if estado.begins_with("hover") else cor))


## Uma linha da lista: ícone, nome e, à direita, ✓ (já criado) ou ! (dá para criar).
func _linha(r: Dictionary, conhece: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 18)
	b.expand_icon = true  # ícones altos cabem na altura da linha
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 4)
	var sel: bool = conhece and r.id == _sel
	b.add_theme_stylebox_override("normal", _estilo_sel if sel else _estilo_vazio)
	b.add_theme_stylebox_override("hover", _estilo_sel if sel else _estilo_hover)
	b.add_theme_stylebox_override("pressed", _estilo_sel)
	b.add_theme_stylebox_override("hover_pressed", _estilo_sel)
	b.add_theme_stylebox_override("disabled", _estilo_vazio)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, COR_TINTA)
	b.add_theme_color_override("font_disabled_color", COR_TINTA_FRACA)
	if not conhece:
		b.text = "???"
		b.icon = load(UI + "icons/lock.png")
		b.disabled = true
		return b
	b.text = Itens.nome_receita(r)
	b.icon = _icone(r)
	var cor := _cor_icone(r)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, cor)
	b.pressed.connect(_escolher.bind(r.id))
	var marca := ""
	if Jogo.ja_criou(r):
		marca = "icons/check.png"
	elif Jogo.pode_criar(r):
		marca = "icons/quest.png"
	if marca != "":
		var t := TextureRect.new()
		t.texture = load(UI + marca)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.anchor_left = 1.0
		t.anchor_right = 1.0
		t.anchor_top = 0.5
		t.anchor_bottom = 0.5
		t.offset_left = -18
		t.offset_right = -2
		t.offset_top = -8
		t.offset_bottom = 8
		b.add_child(t)
	return b


func _montar_detalhe() -> void:
	for c in _detalhe.get_children():
		c.queue_free()
	if _sel == "":
		_detalhe.add_child(_texto("Nenhuma receita descoberta aqui ainda.", COR_TINTA, true))
		_detalhe.add_child(_texto("Procure páginas pelos andares e derrote monstros novos.", COR_TINTA_FRACA, true))
		return
	var r := Itens.receita(_sel)

	# ícone grande no slot da cor do tipo + nome e tipo
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 6)
	var slot := PanelContainer.new()
	slot.theme_type_variation = SLOT_POR_TIPO.get(r.tipo, &"InsetPanel")
	var ic := TextureRect.new()
	ic.texture = _icone(r)
	ic.modulate = _cor_icone(r)
	ic.custom_minimum_size = Vector2(32, 32)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(ic)
	topo.add_child(slot)
	var nomes := VBoxContainer.new()
	nomes.alignment = BoxContainer.ALIGNMENT_CENTER
	nomes.add_theme_constant_override("separation", 0)
	nomes.add_child(_texto(Itens.nome_receita(r), COR_TINTA))
	nomes.add_child(_texto(NOME_TIPO.get(r.tipo, ""), COR_TINTA_FRACA))
	topo.add_child(nomes)
	_detalhe.add_child(topo)

	_detalhe.add_child(HSeparator.new())
	_detalhe.add_child(_texto(r.efeito, COR_TINTA, true))
	if r.tipo == "arma":
		var a: Dictionary = Itens.ARMAS[r.id]
		_detalhe.add_child(_texto("Dano %d   Alcance %d   %.2fs" % [a.dano, a.alcance, a.recarga], COR_TINTA_FRACA))
	elif r.tipo == "curativo":
		_detalhe.add_child(_texto("Você tem: %d" % Jogo.curativos, COR_TINTA_FRACA))

	# materiais (tem/precisa)
	_detalhe.add_child(HSeparator.new())
	for m in r.custo:
		var tem := Jogo.quantidade(m)
		var precisa: int = r.custo[m]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var mi := TextureRect.new()
		mi.texture = Itens.icone(m)
		mi.modulate = Itens.cor_icone(m)
		mi.custom_minimum_size = Vector2(14, 12)
		mi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(mi)
		var nome := _texto(Itens.nome_material(m), COR_TINTA)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nome)
		h.add_child(_texto("%d/%d" % [tem, precisa], COR_OK if tem >= precisa else COR_FALTA))
		_detalhe.add_child(h)

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detalhe.add_child(espaco)

	var base := HBoxContainer.new()
	base.alignment = BoxContainer.ALIGNMENT_CENTER
	base.add_theme_constant_override("separation", 4)
	if Jogo.ja_criou(r):
		var ok := TextureRect.new()
		ok.texture = load(UI + "icons/check.png")
		base.add_child(ok)
		base.add_child(_texto("Já criado", COR_OK))
	else:
		var criar := Button.new()
		criar.text = "Criar"
		criar.focus_mode = Control.FOCUS_NONE
		criar.custom_minimum_size = Vector2(64, 0)
		criar.disabled = not Jogo.pode_criar(r)
		criar.pressed.connect(func(): Jogo.criar(r.id))
		base.add_child(criar)
	_detalhe.add_child(base)


# --- navegação ---------------------------------------------------------------------------

func _escolher(id: String) -> void:
	_sel = id
	_montar()


func _escolher_aba(id: String) -> void:
	_aba = id
	_montar()


func _mover(passo: int) -> void:
	if _visiveis.is_empty():
		return
	var i := _visiveis.find(_sel)
	_escolher(_visiveis[clampi(i + passo, 0, _visiveis.size() - 1)])


func _mover_aba(passo: int) -> void:
	var i := 0
	for k in ABAS.size():
		if ABAS[k].id == _aba:
			i = k
	_escolher_aba(ABAS[wrapi(i + passo, 0, ABAS.size())].id)


# --- peças ---------------------------------------------------------------------------------

func _icone(r: Dictionary) -> Texture2D:
	match r.tipo:
		"arma":
			return Itens.sprite_arma(r.id)
		"curativo":
			return Itens.icone("curativo")
		"melhoria":
			if r.id == "tocha":  # Luz reforçada
				return load(UI + "icons/xp.png")
	return load(UI + "icons/gem.png")


func _cor_icone(r: Dictionary) -> Color:
	if r.tipo == "arma":
		return Itens.ARMAS[r.id].get("sprite_cor", Color.WHITE)
	if r.tipo == "curativo":
		return Itens.cor_icone("curativo")
	return Color.WHITE


func _criar_estilos() -> void:
	_estilo_vazio = StyleBoxEmpty.new()
	_estilo_vazio.set_content_margin_all(2)
	_estilo_hover = StyleBoxFlat.new()
	_estilo_hover.bg_color = Color(COR_TINTA, 0.12)
	_estilo_hover.set_content_margin_all(2)
	_estilo_sel = StyleBoxTexture.new()
	_estilo_sel.texture = load(UI + "themes/parchment/button_pressed.png")
	_estilo_sel.set_texture_margin_all(5)
	_estilo_sel.set_content_margin_all(2)


func _estilo_fita(cor: Color) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(UI + "themes/parchment/button_normal.png")
	s.set_texture_margin_all(5)
	s.modulate_color = cor
	# o ícone fica na parte que sai da capa
	s.content_margin_left = 12
	s.content_margin_right = 2
	return s


func _nine(caminho: String, margem: int, r: Rect2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(caminho)
	n.patch_margin_left = margem
	n.patch_margin_top = margem
	n.patch_margin_right = margem
	n.patch_margin_bottom = margem
	n.position = r.position
	n.size = r.size
	return n


func _margem(r: Rect2, lado: int, cima: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.position = r.position
	m.size = r.size
	m.add_theme_constant_override("margin_left", lado)
	m.add_theme_constant_override("margin_right", lado)
	m.add_theme_constant_override("margin_top", cima)
	m.add_theme_constant_override("margin_bottom", cima)
	return m


func _texto(texto: String, cor: Color, quebra := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", cor)
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = LARGURA_TEXTO
	return l
