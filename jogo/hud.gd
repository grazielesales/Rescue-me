extends CanvasLayer
## HUD mínimo (GDD 7.4), com os ícones da pasta "HUD Containers":
## - canto superior esquerdo: vida em corações (cada coração = 2 de vida,
##   meio coração = 1). Pisca ao perder, "nasce" ao curar, brilha de vez em
##   quando e ganha um contorno piscando quando a vida está baixa;
## - canto superior direito: andar atual;
## - canto inferior esquerdo: plaquinha com a arma equipada e os slots dos
##   atalhos 1, 2 e 3, com a arte do Pixel UI Fantasy (a mesma do livro).
##   Esse canto é ampliado pela maior escala inteira que cabe na janela.
## As mensagens do centro continuam no autoload Jogo.

const PASTA := "res://HUD Containers/"
const UI := "res://addons/pixel_ui_fantasy/"
## Mesmo espaço de desenho do livro: a escala do canto das armas é a do livro.
const TELA_UI := Vector2(428, 242)
## Os ícones têm 16x16 px; o desenho ocupa só o meio, então eles se sobrepõem.
const ESCALA := 4.0
const PASSO_CORACAO := 36.0
const VIDA_BAIXA := 3

const COR_BORDA := Color(0.75, 0.66, 0.48)
const COR_FUNDO := Color(0.08, 0.06, 0.05, 0.85)
const COR_TEXTO := Color(0.93, 0.88, 0.76)

var _raiz: Control
var _coracoes: Array[Icone] = []
var _contorno: Icone
var _andar: Label
var _arma: Label
var _slots: Array[PanelContainer] = []
var _slot_icone: Array[TextureRect] = []
var _slot_num: Array[Label] = []
var _dica: Label
var _pai: Node
var _canto_esq: Control
var _vida := -1
var _brilho_t := 2.0


func _ready() -> void:
	layer = 50
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_dica = _label("Clique: atacar   R: receitas   Tab: inventário", 11, Color(COR_TEXTO, 0.55))
	_raiz.add_child(_dica)

	# andar (superior direito)
	_andar = _label("", 16, COR_TEXTO)
	_andar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_raiz.add_child(_andar)

	# armas (inferior esquerdo): plaquinha com o nome + 3 slots
	var armas := VBoxContainer.new()
	_canto_esq = armas
	armas.theme = load(UI + "themes/parchment.tres")
	armas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	armas.add_theme_constant_override("separation", 2)
	_raiz.add_child(armas)
	_arma = Label.new()
	_arma.theme_type_variation = &"Nameplate"
	_arma.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	armas.add_child(_arma)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 2)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	armas.add_child(fila)
	for i in 3:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(16, 16)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.add_child(ic)
		# número do atalho embaixo do slot, para não cobrir o ícone
		var coluna := VBoxContainer.new()
		coluna.add_theme_constant_override("separation", 0)
		coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_child(p)
		var n := Label.new()
		n.text = str(i + 1)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_color", COR_TEXTO)
		n.add_theme_color_override("font_shadow_color", Color.BLACK)
		n.add_theme_constant_override("shadow_offset_x", 1)
		n.add_theme_constant_override("shadow_offset_y", 1)
		coluna.add_child(n)
		fila.add_child(coluna)
		_slots.append(p)
		_slot_icone.append(ic)
		_slot_num.append(n)

	Jogo.pai_registrado.connect(_on_pai)
	Jogo.armas_mudou.connect(_atualizar_armas)
	Jogo.andar_mudou.connect(func(n): _andar.text = n)
	_atualizar_armas()
	visible = false


func _process(delta: float) -> void:
	visible = is_instance_valid(_pai)
	if not visible:
		return
	var tela := get_viewport().get_visible_rect().size
	_andar.size = _andar.get_minimum_size()
	_andar.position = Vector2(tela.x - _andar.size.x - 16, 14)
	# maior escala inteira que cabe (igual ao livro): pixels nítidos
	var e := maxf(1.0, floorf(minf(tela.x / TELA_UI.x, tela.y / TELA_UI.y)))
	_canto_esq.scale = Vector2(e, e)
	_canto_esq.size = _canto_esq.get_combined_minimum_size()
	_canto_esq.position = Vector2(14, tela.y - _canto_esq.size.y * e - 14)

	if _contorno and _contorno.visible:
		_contorno.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 110.0)

	# de tempos em tempos o último coração cheio brilha (mais rápido com vida baixa)
	_brilho_t -= delta
	if _brilho_t <= 0.0:
		var baixa := _vida <= VIDA_BAIXA
		_brilho_t = 1.2 if baixa else 3.5
		for i in range(_coracoes.size() - 1, -1, -1):
			if _coracoes[i].estado != "empty":
				_coracoes[i].brilhar()
				break


func _on_pai(pai: Node) -> void:
	_pai = pai
	pai.vida_mudou.connect(_atualizar_vida)
	_montar_coracoes(pai.vida_maxima)
	_vida = -1
	_atualizar_vida(pai.vida, pai.vida_maxima)
	_andar.text = Jogo.nome_andar


func _montar_coracoes(maxima: int) -> void:
	for c in _coracoes:
		c.queue_free()
	_coracoes.clear()
	if _contorno:
		_contorno.queue_free()
	var n := ceili(maxima / 2.0)
	for i in n:
		var c := Icone.new(PASTA + "Heart Red/", ESCALA)
		c.position = Vector2(4 + i * PASSO_CORACAO, -6)
		_raiz.add_child(c)
		_coracoes.append(c)
	_contorno = Icone.new(PASTA + "Heart Highlight/", ESCALA)
	_contorno.visible = false
	_raiz.add_child(_contorno)
	_dica.position = Vector2(16, 50)


func _atualizar_vida(vida: int, _maxima: int) -> void:
	var primeira := _vida < 0
	for i in _coracoes.size():
		var valor := clampi(vida - i * 2, 0, 2)
		var estado: String = ["empty", "half", "full"][valor]
		# ao entrar no andar os corações "nascem" um depois do outro
		_coracoes[i].definir(estado, not primeira, i * 0.08 if primeira else 0.0)
		if primeira and estado != "empty":
			_coracoes[i].nascer(i * 0.08)
	_vida = vida
	# contorno piscando no último coração com vida baixa
	var baixa := vida > 0 and vida <= VIDA_BAIXA
	_contorno.visible = baixa
	if baixa:
		var ultimo := clampi(ceili(vida / 2.0) - 1, 0, _coracoes.size() - 1)
		_contorno.position = _coracoes[ultimo].position


## Slot da arma equipada fica dourado; com arma, comum; vazio, afundado.
func _atualizar_armas() -> void:
	var atual := Jogo.id_arma_atual()
	_arma.text = Itens.ARMAS[atual].nome
	for i in 3:
		var id: String = Jogo.slots[i]
		var ic := _slot_icone[i]
		ic.texture = Itens.sprite_arma(id) if id != "" else null
		ic.modulate = Itens.ARMAS[id].get("sprite_cor", Color.WHITE) if id != "" else Color.WHITE
		if id == "":
			_slots[i].theme_type_variation = &"InsetPanel"
		elif id == atual:
			_slots[i].theme_type_variation = &"LegendarySlot"
		else:
			_slots[i].theme_type_variation = &"CommonSlot"
		_slot_num[i].modulate.a = 0.5 if id == "" else 1.0


func _label(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Um ícone da pasta "HUD Containers" (coração, gota, contorno).
## Estados: "full", "half", "empty". Animações em tiras de quadros 16x16:
## spawn_*, shiny_*, e blink_* (um quadro, alternado com o estado novo).
class Icone extends TextureRect:
	const LADO := 16
	static var _cache := {}

	var pasta := ""
	var estado := "full"
	var _quadros: Array[Texture2D] = []
	var _i := 0
	var _t := 0.0
	var _fps := 12.0
	var _repetir := false
	var _espera := 0.0
	var _pisca_t := 0.0
	var _pisca_tex: Texture2D

	func _init(p: String, escala: float) -> void:
		pasta = p
		custom_minimum_size = Vector2(LADO, LADO) * escala
		size = custom_minimum_size
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_parar()

	## Muda o estado. Perder = pisca; ganhar = animação de "nascer".
	func definir(novo: String, animar := true, espera := 0.0) -> void:
		var antigo := estado
		estado = novo
		if not animar or novo == antigo:
			if _quadros.is_empty() and _pisca_t <= 0.0:
				_parar()
			return
		if _valor(novo) < _valor(antigo):
			_pisca_tex = _tex("blink_" + antigo)
			_pisca_t = 0.5
			_quadros.clear()
		else:
			nascer(espera)

	func nascer(espera := 0.0) -> void:
		if estado != "empty":
			_espera = espera
			tocar("spawn_" + estado, 14.0)
			if espera > 0.0:
				texture = _tex("empty")

	func brilhar() -> void:
		if estado != "empty" and _quadros.is_empty() and _pisca_t <= 0.0:
			tocar("shiny_" + estado, 12.0)

	func tocar(nome: String, fps: float, repetir := false) -> void:
		_quadros = _tira(nome)
		_i = 0
		_t = 0.0
		_fps = fps
		_repetir = repetir
		if _quadros.is_empty():
			_parar()
		elif _espera <= 0.0:
			texture = _quadros[0]

	func _process(delta: float) -> void:
		if _espera > 0.0:
			_espera -= delta
			if _espera <= 0.0 and not _quadros.is_empty():
				texture = _quadros[0]
			return
		if _pisca_t > 0.0:
			_pisca_t -= delta
			texture = _pisca_tex if int(_pisca_t * 16.0) % 2 == 0 else _tex(estado)
			if _pisca_t <= 0.0:
				_parar()
			return
		if _quadros.is_empty():
			return
		_t += delta
		if _t < 1.0 / _fps:
			return
		_t = 0.0
		_i += 1
		if _i >= _quadros.size():
			if _repetir:
				_i = 0
			else:
				_quadros.clear()
				_parar()
				return
		texture = _quadros[_i]

	func _parar() -> void:
		texture = _tex(estado) if ResourceLoader.exists(pasta + estado + ".png") else _tex("highlight")

	func _valor(e: String) -> int:
		return {"empty": 0, "half": 1, "full": 2}.get(e, 0)

	func _tex(nome: String) -> Texture2D:
		var caminho := pasta + nome + ".png"
		if not _cache.has(caminho):
			_cache[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
		return _cache[caminho]

	## Divide uma tira horizontal em quadros de 16x16.
	func _tira(nome: String) -> Array[Texture2D]:
		var r: Array[Texture2D] = []
		var tex := _tex(nome)
		if tex == null:
			return r
		for k in tex.get_width() / LADO:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(k * LADO, 0, LADO, LADO)
			r.append(a)
		return r
