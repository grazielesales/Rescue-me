class_name TelaPixel
extends CanvasLayer
## Base das telas de interface (menu inicial, pausa e créditos), com a arte do
## Pixel UI Fantasy (tema parchment), como o livro de receitas: tudo é montado
## num espaço de TELA pixels (`raiz`) e ampliado pela maior escala INTEIRA que
## cabe na janela, centralizado (pixels nítidos). O `fundo` fica fora da escala
## e cobre a janela inteira.
## Arte: Pixel UI Fantasy Free by heyheythere - CC BY 4.0

const UI := "res://addons/pixel_ui_fantasy/"
const TELA := Vector2(428, 242)
const COR_TINTA := Color(0.227, 0.133, 0.094)
const COR_TINTA_FRACA := Color(0.227, 0.133, 0.094, 0.6)
const COR_CLARA := Color(0.93, 0.88, 0.76)
const COR_CLARA_FRACA := Color(0.93, 0.88, 0.76, 0.55)

var fundo: ColorRect
var raiz: Control


func _montar_base(cor_fundo: Color) -> void:
	fundo = ColorRect.new()
	fundo.color = cor_fundo
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP  # nada passa para o jogo por baixo
	add_child(fundo)
	raiz = Control.new()
	raiz.size = TELA
	raiz.theme = load(UI + "themes/parchment.tres")
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	get_viewport().size_changed.connect(_ajustar_escala)
	_ajustar_escala()


## Maior escala inteira que cabe na janela, centralizada.
func _ajustar_escala() -> void:
	var tela := get_viewport().get_visible_rect().size
	var e := maxf(1.0, floorf(minf(tela.x / TELA.x, tela.y / TELA.y)))
	raiz.scale = Vector2(e, e)
	raiz.position = ((tela - TELA * e) / 2.0).floor()


func _rotulo(texto: String, cor: Color, tamanho := 10) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", cor)
	if tamanho != 10:
		l.add_theme_font_size_override("font_size", tamanho)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _botao(texto: String, ao_apertar: Callable, largura := 112) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(largura, 0)
	b.pressed.connect(func():
		Som.tocar("interface/equipar", 0.0, 1.0, 0.0)
		ao_apertar.call())
	return b


## Painel de pergaminho (o mesmo do livro) com margem interna.
func _painel(margem := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxTexture.new()
	s.texture = load(UI + "themes/parchment/panel.png")
	s.set_texture_margin_all(6)
	s.set_content_margin_all(margem)
	p.add_theme_stylebox_override("panel", s)
	return p


## Faixa vermelha com um título (a mesma do nome do livro).
func _faixa(texto: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Ribbon"
	l.text = texto
	return l
