extends CanvasLayer
## Tela do inventário (Tab) — só a camada visual.
## Lê o que já existe no autoload Jogo (inventario, armas, slots, curativos)
## e usa as ações que ele já oferece (colocar_no_slot, equipar_slot,
## usar_curativo). Não guarda nem altera dados por conta própria.
##
## Visual: survival horror clássico em pixel art. Ícones das folhas
## warrior-items__asset.png e xevin-wizard-items__asset.png (16x16).

const GUERREIRO := "res://warrior-items__asset.png"
const MAGO := "res://xevin-wizard-items__asset.png"
const ICONE := 16

## id do item -> [folha, coluna, linha, tinta opcional]
const ICONES := {
	# armas
	"cano": [GUERREIRO, 3, 0],
	"clava": [MAGO, 0, 1],
	"lanca": [MAGO, 1, 1],
	"adaga": [GUERREIRO, 0, 0],
	"espada": [GUERREIRO, 1, 0, Color(0.7, 0.95, 1.0)],
	"machado": [GUERREIRO, 2, 0, Color(0.8, 0.6, 1.0)],
	"lamina": [GUERREIRO, 1, 0, Color(1.0, 0.95, 0.55)],
	# materiais e itens
	"presa": [GUERREIRO, 1, 7],
	"po_magico": [MAGO, 1, 6],
	"ectoplasma": [MAGO, 1, 7, Color(0.65, 1.0, 0.75)],
	"fragmento": [GUERREIRO, 3, 7],
	"curativo": [GUERREIRO, 1, 4],
}

const DESCRICOES := {
	"cano": "Um cano velho e pesado, arrancado da sala de comando. Melhor que nada.",
	"osso": "Osso seco e resistente. Base de armas e escudos.",
	"teia": "Fios grossos e pegajosos. Servem de corda e de reforço.",
	"presa": "Presa de aranha grande. Ainda pinga veneno.",
	"ectoplasma": "Resto gelado de um fantasma. Brilha fraco no escuro.",
	"po_magico": "Pó cintilante que as criaturas mágicas deixam para trás.",
	"fragmento": "Pedaço de sombra endurecida. Frio ao toque.",
	"madeira": "Tábuas de caixas e móveis quebrados.",
	"sucata": "Metal retorcido. Entra em quase toda receita.",
	"curativo": "Atadura com ervas amassadas. Fecha as feridas por um tempo.",
}

const COLUNAS := 6
const LINHAS := 4
const LADO_SLOT := 56
const ESCALA_ICONE := 3

const COR_FUNDO := Color(0.055, 0.05, 0.06, 0.97)
const COR_MOLDURA := Color(0.32, 0.33, 0.38)
const COR_MOLDURA_CLARA := Color(0.55, 0.58, 0.64)
const COR_SANGUE := Color(0.55, 0.07, 0.07)
const COR_TEXTO := Color(0.86, 0.84, 0.78)
const COR_TEXTO_FRACO := Color(0.55, 0.53, 0.5)
const COR_DESTAQUE := Color(0.95, 0.75, 0.3)

var _slots_grade: Array[Slot] = []
var _slots_equip: Array[Slot] = []
var _selecionado: Slot
var _info_icone: TextureRect
var _info_nome: Label
var _info_tipo: Label
var _info_desc: Label
var _info_status: GridContainer
var _info_acoes: Label
var _rodape_qtd: Label
var _cache := {}


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar()
	Jogo.inventario_mudou.connect(_atualizar)
	Jogo.armas_mudou.connect(_atualizar)


func abrir() -> void:
	visible = true
	get_tree().paused = true
	Jogo.esconder_dica()
	_atualizar()
	if _selecionado == null or not _selecionado.is_visible_in_tree():
		_selecionar(_slots_grade[0])


func fechar() -> void:
	visible = false
	get_tree().paused = false


func _atualizar() -> void:
	if not visible:
		return
	_preencher()
	_mostrar_info()


# --- entrada (só navegação e atalhos que já existem no Jogo) ---------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("inventario") or event.is_action("ui_cancel"):
		fechar()
	elif event.is_action("ui_left"):
		_mover(Vector2.LEFT)
	elif event.is_action("ui_right"):
		_mover(Vector2.RIGHT)
	elif event.is_action("ui_up"):
		_mover(Vector2.UP)
	elif event.is_action("ui_down"):
		_mover(Vector2.DOWN)
	elif event.is_action("livro"):
		fechar()
		Jogo._livro.abrir("receitas")
	elif event.is_action("interagir") or event.is_action("ui_accept"):
		_usar()
	elif event.is_action("arma_1"):
		_atalho(0)
	elif event.is_action("arma_2"):
		_atalho(1)
	elif event.is_action("arma_3"):
		_atalho(2)
	else:
		return
	get_viewport().set_input_as_handled()


## Vai para o slot mais próximo naquela direção.
func _mover(dir: Vector2) -> void:
	if _selecionado == null:
		_selecionar(_slots_grade[0])
		return
	var origem := _selecionado.get_global_rect().get_center()
	var melhor: Slot = null
	var melhor_d := INF
	for s in _slots_equip + _slots_grade:
		if s == _selecionado:
			continue
		var v := s.get_global_rect().get_center() - origem
		if v.normalized().dot(dir) < 0.5:
			continue
		var d := v.length() + absf(v.cross(dir)) * 2.0
		if d < melhor_d:
			melhor_d = d
			melhor = s
	if melhor:
		_selecionar(melhor)


func _usar() -> void:
	if _selecionado == null or _selecionado.item == "":
		return
	if _selecionado.equip_indice >= 0:
		Jogo.equipar_slot(_selecionado.equip_indice)
	elif _selecionado.item == "curativo":
		Jogo.usar_curativo()


func _atalho(i: int) -> void:
	if _selecionado and _selecionado.tipo == "arma":
		Jogo.colocar_no_slot(_selecionado.item, i)


func _selecionar(s: Slot) -> void:
	if _selecionado:
		_selecionado.selecionado = false
	_selecionado = s
	s.selecionado = true
	_mostrar_info()


# --- conteúdo ---------------------------------------------------------------------------

func _preencher() -> void:
	# atalhos 1, 2, 3
	for i in 3:
		var id: String = Jogo.slots[i]
		_slots_equip[i].definir(id, "arma" if id != "" else "", _icone(id), 0)
		_slots_equip[i].ativo = id != "" and id == Jogo.id_arma_atual()
	# grade: armas, curativos e materiais
	var itens: Array = []
	for id in Jogo.armas:
		itens.append([id, "arma", 0])
	if Jogo.curativos > 0:
		itens.append(["curativo", "item", Jogo.curativos])
	for m in Itens.MATERIAIS:
		if m != "curativo" and Jogo.quantidade(m) > 0:
			itens.append([m, "material", Jogo.quantidade(m)])
	for i in _slots_grade.size():
		if i < itens.size():
			_slots_grade[i].definir(itens[i][0], itens[i][1], _icone(itens[i][0]), itens[i][2])
		else:
			_slots_grade[i].definir("", "", [], 0)
		_slots_grade[i].ativo = false
	_rodape_qtd.text = "%d / %d" % [mini(itens.size(), _slots_grade.size()), _slots_grade.size()]


func _mostrar_info() -> void:
	if _info_nome == null:
		return
	var s := _selecionado
	if s == null or s.item == "":
		_info_icone.texture = null
		_info_nome.text = "—"
		_info_tipo.text = ""
		_info_desc.text = "Espaço vazio." if s == null or s.equip_indice < 0 else "Atalho %d vazio. Escolha uma arma na grade e aperte %d." % [s.equip_indice + 1, s.equip_indice + 1]
		_status([])
		_info_acoes.text = ""
		return
	var id := s.item
	_info_icone.texture = s.textura
	_info_icone.modulate = s.tinta
	if s.tipo == "arma":
		var a: Dictionary = Itens.ARMAS[id]
		_info_nome.text = a.nome
		_info_tipo.text = "ARMA"
		_info_desc.text = DESCRICOES.get(id, Itens.receita(id).get("efeito", ""))
		var linhas := [["Dano", str(a.dano)], ["Alcance", str(int(a.alcance))], ["Velocidade", _velocidade(a.recarga)]]
		if a.has("veneno"):
			linhas.append(["Veneno", "%d s" % a.veneno])
		_status(linhas)
		var no_atalho := Jogo.slots.find(id)
		var dica := "[1] [2] [3] colocar no atalho"
		if s.equip_indice >= 0:
			dica = "[E] equipar agora"
		elif no_atalho != -1:
			dica = "No atalho %d.   %s" % [no_atalho + 1, dica]
		_info_acoes.text = dica
	else:
		_info_nome.text = Itens.nome_material(id)
		_info_tipo.text = "ITEM DE CURA" if id == "curativo" else "MATERIAL"
		_info_desc.text = DESCRICOES.get(id, "")
		var linhas := [["Quantidade", "x%d" % s.quantidade]]
		if id == "curativo":
			linhas.append(["Recupera", "%d de vida" % Itens.CURA])
			_info_acoes.text = "[E] usar"
		else:
			_info_acoes.text = "Use no livro de receitas [R]"
		_status(linhas)


## Tabela de atributos: nome à esquerda, valor à direita.
func _status(linhas: Array) -> void:
	for c in _info_status.get_children():
		c.queue_free()
	for l in linhas:
		_info_status.add_child(_label(l[0], 12, COR_TEXTO_FRACO))
		_info_status.add_child(_label(l[1], 12, COR_TEXTO))


func _velocidade(recarga: float) -> String:
	if recarga <= 0.3:
		return "rápida"
	if recarga <= 0.5:
		return "média"
	return "lenta"


func _icone(id: String) -> Array:
	if id == "":
		return [null, Color.WHITE]
	if _cache.has(id):
		return _cache[id]
	var r := [null, Color.WHITE]
	if ICONES.has(id):
		var d: Array = ICONES[id]
		var at := AtlasTexture.new()
		at.atlas = load(d[0])
		at.region = Rect2(d[1] * ICONE, d[2] * ICONE, ICONE, ICONE)
		r = [at, d[3] if d.size() > 3 else Color.WHITE]
	else:
		r = [Itens.icone(id), Itens.cor_icone(id)]
	_cache[id] = r
	return r


# --- montagem da tela --------------------------------------------------------------------

func _montar() -> void:
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.78)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(escuro)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var painel := Moldura.new()
	painel.cor_fundo = COR_FUNDO
	painel.cor_borda = COR_MOLDURA
	painel.cor_borda_clara = COR_MOLDURA_CLARA
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 20)
	painel.add_child(margem)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margem.add_child(col)

	# cabeçalho
	var topo := HBoxContainer.new()
	col.add_child(topo)
	var titulo := _label("INVENTÁRIO", 22, COR_TEXTO)
	titulo.add_theme_constant_override("outline_size", 0)
	topo.add_child(titulo)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(esp)
	topo.add_child(_tecla("TAB"))
	topo.add_child(_label("  fechar", 13, COR_TEXTO_FRACO))
	col.add_child(Linha.new(COR_SANGUE))

	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 22)
	col.add_child(corpo)

	# atalhos (1 em cima, 2 e 3 embaixo)
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 8)
	corpo.add_child(esq)
	esq.add_child(_label("EQUIPADO", 12, COR_TEXTO_FRACO))
	var cacho := Control.new()
	cacho.custom_minimum_size = Vector2(LADO_SLOT * 2 + 4, LADO_SLOT * 2 + 4)
	esq.add_child(cacho)
	var posicoes := [Vector2(LADO_SLOT / 2.0 + 2, 0), Vector2(0, LADO_SLOT + 4), Vector2(LADO_SLOT + 4, LADO_SLOT + 4)]
	for i in 3:
		var s := Slot.new(LADO_SLOT, ESCALA_ICONE)
		s.equip_indice = i
		s.rotulo = str(i + 1)
		s.position = posicoes[i]
		s.clicado.connect(_on_slot_clicado)
		cacho.add_child(s)
		_slots_equip.append(s)
	esq.add_child(_label("Arma em uso\nfica marcada.", 11, COR_TEXTO_FRACO))

	# grade
	var meio := VBoxContainer.new()
	meio.add_theme_constant_override("separation", 8)
	corpo.add_child(meio)
	var cab := HBoxContainer.new()
	meio.add_child(cab)
	cab.add_child(_label("ITENS", 12, COR_TEXTO_FRACO))
	var esp2 := Control.new()
	esp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(esp2)
	_rodape_qtd = _label("", 12, COR_TEXTO_FRACO)
	cab.add_child(_rodape_qtd)
	var grade := GridContainer.new()
	grade.columns = COLUNAS
	grade.add_theme_constant_override("h_separation", 4)
	grade.add_theme_constant_override("v_separation", 4)
	meio.add_child(grade)
	for i in COLUNAS * LINHAS:
		var s := Slot.new(LADO_SLOT, ESCALA_ICONE)
		s.clicado.connect(_on_slot_clicado)
		grade.add_child(s)
		_slots_grade.append(s)

	# informações do item selecionado
	var info := Moldura.new()
	info.cor_fundo = Color(0.035, 0.03, 0.04)
	info.cor_borda = Color(0.22, 0.22, 0.26)
	info.cor_borda_clara = Color(0.3, 0.3, 0.35)
	info.custom_minimum_size = Vector2(250, 340)  # altura fixa: o painel não "pula" ao trocar de item
	corpo.add_child(info)
	var im := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		im.add_theme_constant_override("margin_" + lado, 12)
	info.add_child(im)
	var ic := VBoxContainer.new()
	ic.add_theme_constant_override("separation", 6)
	im.add_child(ic)
	var moldura_icone := Slot.new(88, 5)
	moldura_icone.decorativo = true
	moldura_icone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.add_child(moldura_icone)
	_info_icone = moldura_icone.icone
	_info_nome = _label("", 17, COR_DESTAQUE)
	_info_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_child(_info_nome)
	_info_tipo = _label("", 11, COR_SANGUE.lightened(0.35))
	_info_tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_child(_info_tipo)
	ic.add_child(Linha.new(Color(0.22, 0.22, 0.26)))
	_info_desc = _label("", 13, COR_TEXTO)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.custom_minimum_size = Vector2(226, 54)
	ic.add_child(_info_desc)
	_info_status = GridContainer.new()
	_info_status.columns = 2
	_info_status.add_theme_constant_override("h_separation", 14)
	_info_status.add_theme_constant_override("v_separation", 0)
	ic.add_child(_info_status)
	var esp3 := Control.new()
	esp3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ic.add_child(esp3)
	_info_acoes = _label("", 12, COR_DESTAQUE)
	_info_acoes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_acoes.custom_minimum_size = Vector2(226, 0)
	ic.add_child(_info_acoes)

	# rodapé
	col.add_child(Linha.new(Color(0.22, 0.22, 0.26)))
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 6)
	col.add_child(rodape)
	for par in [["WASD", "mover"], ["E", "usar"], ["1 2 3", "atalho"], ["R", "receitas"], ["ESC", "fechar"]]:
		rodape.add_child(_tecla(par[0]))
		rodape.add_child(_label(par[1] + "    ", 12, COR_TEXTO_FRACO))


func _on_slot_clicado(s: Slot, duplo: bool) -> void:
	_selecionar(s)
	if duplo:
		_usar()


func _label(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Tecla desenhada como uma plaquinha: [TAB]
func _tecla(texto: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.14)
	sb.border_color = COR_MOLDURA
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_label(texto, 11, COR_TEXTO))
	return p


## Slot quadrado em pixel art: fundo escuro rebaixado, borda com luz em cima à
## esquerda e sombra embaixo à direita, ícone ampliado e quantidade no canto.
## Selecionado: cantoneiras âmbar pulsando. Ativo (arma em uso): borda vermelha.
class Slot extends Control:
	signal clicado(slot: Slot, duplo: bool)

	var item := ""
	var tipo := ""
	var quantidade := 0
	var textura: Texture2D
	var tinta := Color.WHITE
	var equip_indice := -1
	var rotulo := ""
	var decorativo := false
	var icone: TextureRect
	var selecionado := false:
		set(v):
			selecionado = v
			queue_redraw()
	var ativo := false:
		set(v):
			ativo = v
			queue_redraw()
	var _qtd: Label
	var _t := 0.0

	func _init(lado: int, escala: int) -> void:
		custom_minimum_size = Vector2(lado, lado)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		icone = TextureRect.new()
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_SCALE
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := 16 * escala
		icone.size = Vector2(t, t)
		icone.position = (Vector2(lado, lado) - icone.size) / 2.0
		add_child(icone)
		_qtd = Label.new()
		_qtd.add_theme_font_size_override("font_size", 13)
		_qtd.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
		_qtd.add_theme_color_override("font_outline_color", Color.BLACK)
		_qtd.add_theme_constant_override("outline_size", 4)
		_qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_qtd.size = Vector2(lado - 6, 16)
		_qtd.position = Vector2(2, lado - 19)
		_qtd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_qtd)

	func definir(id: String, t: String, ic: Array, qtd: int) -> void:
		item = id
		tipo = t
		quantidade = qtd
		textura = ic[0] if ic.size() > 0 else null
		tinta = ic[1] if ic.size() > 1 else Color.WHITE
		icone.texture = textura
		icone.modulate = tinta
		_qtd.text = ("x%d" % qtd) if qtd > 1 or (qtd == 1 and t != "arma") else ""
		queue_redraw()

	func _process(delta: float) -> void:
		if selecionado:
			_t += delta
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if decorativo:
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicado.emit(self, e.double_click)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# fundo rebaixado
		draw_rect(r, Color(0.09, 0.09, 0.11))
		draw_rect(r.grow(-3), Color(0.13, 0.135, 0.16))
		# chanfro: sombra em cima/esquerda por dentro, luz embaixo/direita
		draw_rect(Rect2(3, 3, size.x - 6, 2), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(3, 3, 2, size.y - 6), Color(0.05, 0.05, 0.06))
		# moldura metálica
		var claro := Color(0.5, 0.53, 0.6)
		var escuro := Color(0.24, 0.25, 0.3)
		draw_rect(Rect2(0, 0, size.x, 2), claro)
		draw_rect(Rect2(0, 0, 2, size.y), claro)
		draw_rect(Rect2(0, size.y - 2, size.x, 2), escuro)
		draw_rect(Rect2(size.x - 2, 0, 2, size.y), escuro)
		if rotulo != "":
			draw_string(get_theme_default_font(), Vector2(6, 15), rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.53, 0.5))
		if ativo:
			draw_rect(r.grow(-1), Color(0.7, 0.1, 0.1), false, 2.0)
		if selecionado:
			var a := 0.6 + 0.4 * sin(_t * 6.0)
			var c := Color(0.95, 0.75, 0.3, a)
			var k := 12.0
			var g := -2.0  # cantoneiras um pouco para fora do slot
			for canto in [Vector2(g, g), Vector2(size.x - g, g), Vector2(g, size.y - g), Vector2(size.x - g, size.y - g)]:
				var sx := 1.0 if canto.x < size.x / 2 else -1.0
				var sy := 1.0 if canto.y < size.y / 2 else -1.0
				draw_rect(Rect2(canto + Vector2(0 if sx > 0 else -k, 0 if sy > 0 else -2), Vector2(k, 2)), c)
				draw_rect(Rect2(canto + Vector2(0 if sx > 0 else -2, 0 if sy > 0 else -k), Vector2(2, k)), c)
			draw_rect(r.grow(-3), Color(0.95, 0.75, 0.3, 0.07))


## Painel com borda dupla (pixel art) e cantos com rebites.
class Moldura extends PanelContainer:
	var cor_fundo := Color.BLACK
	var cor_borda := Color.GRAY
	var cor_borda_clara := Color.WHITE

	func _ready() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, cor_fundo)
		draw_rect(r, Color.BLACK, false, 2.0)
		draw_rect(r.grow(-3), cor_borda, false, 2.0)
		draw_rect(Rect2(5, 5, size.x - 10, 1), cor_borda_clara.darkened(0.3))
		for p in [Vector2(8, 8), Vector2(size.x - 11, 8), Vector2(8, size.y - 11), Vector2(size.x - 11, size.y - 11)]:
			draw_rect(Rect2(p, Vector2(3, 3)), cor_borda_clara)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 2)), cor_borda.darkened(0.4))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Linha fina divisória.
class Linha extends ColorRect:
	func _init(cor: Color) -> void:
		color = cor
		custom_minimum_size = Vector2(0, 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
