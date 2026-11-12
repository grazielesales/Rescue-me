extends CanvasLayer
## Autoload "Jogo": estado que precisa sobreviver à troca de andar e à morte
## (salas visitadas e concluídas, inventário, armas, receitas, ponto de
## salvamento) + fade, mensagens na tela, HUD e livro de receitas.

signal inventario_mudou
signal armas_mudou
signal andar_mudou(nome: String)
signal pai_registrado(pai: Node)

## Chave "cena:sala" de cada sala que o Pai já visitou.
var salas_visitadas := {}
## id da escada onde o Pai deve aparecer no próximo andar ("" = posição da cena).
var escada_de_chegada := ""

# --- combate e crafting ----------------------------------------------------------
## O Pai do andar atual (registra-se sozinho no _ready dele).
var pai: Node = null
var nome_andar := ""
## material -> quantidade (GDD 4.1). Não se perde ao morrer (GDD 8.3).
var inventario := {}
## Armas que o Pai já tem (ids de Itens.ARMAS).
var armas: Array[String] = ["cano"]
## Atalhos 1, 2 e 3 (GDD 3.2). "" = vazio.
var slots: Array[String] = ["cano", "", ""]
var slot_atual := 0
var curativos := 0
var receitas_conhecidas := {}
## Melhorias criadas (ex.: "tocha" = Luz reforçada; o id ficou o mesmo).
var melhorias := {}
## Inimigos e caixas já destruídos ("cena:caminho"). Não voltam ao recomeçar.
var mortos := {}
## Salas bloqueadas já vencidas ("cena:sala").
var salas_concluidas := {}
var tipos_derrotados := {}
## Ponto de salvamento (GDD 3.4): {"cena", "pos"} ou {"cena", "escada"}.
var checkpoint := {}

var _hud: CanvasLayer
var _livro: CanvasLayer
var _inv: CanvasLayer
var _morrendo := false

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

	for r in Itens.RECEITAS:
		if r.get("inicial", false):
			receitas_conhecidas[r.id] = true
	_hud = preload("res://jogo/hud.gd").new()
	add_child(_hud)
	_livro = preload("res://jogo/livro.gd").new()
	add_child(_livro)
	_inv = preload("res://jogo/inventario_ui.gd").new()
	add_child(_inv)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _inv.visible:
		return  # a tela do inventário cuida das próprias teclas
	if _livro.visible:
		if event.is_action("ui_cancel"):
			_livro.fechar()
		elif event.is_action("livro"):
			_livro.alternar("receitas")
		elif event.is_action("inventario"):
			abrir_inventario()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not _pai_ativo() or _morrendo or _trocando:
		return
	if event.is_action("livro"):
		_livro.abrir("receitas")
	elif event.is_action("inventario"):
		abrir_inventario()
	elif event.is_action("arma_1"):
		equipar_slot(0)
	elif event.is_action("arma_2"):
		equipar_slot(1)
	elif event.is_action("arma_3"):
		equipar_slot(2)
	elif event.is_action("curar"):
		usar_curativo()
	else:
		return
	get_viewport().set_input_as_handled()


## Abre a tela do inventário (Tab), fechando o livro se estiver aberto.
func abrir_inventario() -> void:
	if _livro.visible:
		_livro.fechar()
	_inv.abrir()


func _pai_ativo() -> bool:
	return is_instance_valid(pai) and not pai.morto


# --- Pai, andar e ponto de salvamento ------------------------------------------------

func registrar_pai(p: Node) -> void:
	pai = p
	pai_registrado.emit(p)


func definir_andar(nome: String) -> void:
	nome_andar = nome
	andar_mudou.emit(nome)
	mostrar_titulo(nome)


func cena_atual() -> String:
	var c := get_tree().current_scene
	return c.scene_file_path if c else ""


## GDD 3.4: vida zerada volta ao último ponto de salvamento, sem perder materiais.
func pai_morreu() -> void:
	if _morrendo:
		return
	_morrendo = true
	mostrar_mensagem("O Pai caiu... voltando ao último ponto seguro.", 1.4)
	await get_tree().create_timer(1.6).timeout
	await fade(1.0, 0.5)
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 0.5)
	_morrendo = false


func concluir_sala(chave: String, pos: Vector2) -> void:
	salas_concluidas[chave] = true
	checkpoint = {"cena": cena_atual(), "pos": pos}
	mostrar_mensagem("Sala vencida! As portas se destrancaram.")


func sala_concluida(chave: String) -> bool:
	return salas_concluidas.has(chave)


func registrar_morte(chave: String, tipo: String) -> void:
	mortos[chave] = true
	if tipo == "" or tipos_derrotados.has(tipo):
		return
	tipos_derrotados[tipo] = true
	var r: String = Itens.dados_inimigo(tipo).get("receita", "")
	if r != "":
		aprender_receita(r)


func esta_morto(chave: String) -> bool:
	return mortos.has(chave)


# --- inventário e crafting ---------------------------------------------------------

func adicionar(material: String, qtd: int) -> void:
	inventario[material] = quantidade(material) + qtd
	inventario_mudou.emit()


func quantidade(material: String) -> int:
	return inventario.get(material, 0)


func aprender_receita(id: String) -> void:
	if receitas_conhecidas.has(id):
		return
	receitas_conhecidas[id] = true
	mostrar_mensagem("Nova receita no livro (R): %s" % Itens.nome_receita(Itens.receita(id)), 3.0)
	inventario_mudou.emit()


func ja_criou(r: Dictionary) -> bool:
	match r.tipo:
		"arma":
			return armas.has(r.id)
		"melhoria":
			return melhorias.has(r.id)
	return false


func pode_criar(r: Dictionary) -> bool:
	if ja_criou(r):
		return false
	for m in r.custo:
		if quantidade(m) < r.custo[m]:
			return false
	return true


func criar(id: String) -> bool:
	var r := Itens.receita(id)
	if r.is_empty() or not pode_criar(r):
		return false
	for m in r.custo:
		inventario[m] = quantidade(m) - r.custo[m]
	match r.tipo:
		"arma":
			armas.append(id)
			var livre := slots.find("")
			if livre != -1:
				slots[livre] = id
			armas_mudou.emit()
		"curativo":
			curativos += 1
		"melhoria":
			melhorias[id] = true
			if _pai_ativo():
				pai.aplicar_melhorias()
	inventario_mudou.emit()
	mostrar_mensagem("Criado: %s" % Itens.nome_receita(r))
	return true


func usar_curativo() -> void:
	if curativos <= 0:
		mostrar_mensagem("Sem curativos. Crie um no livro de receitas (R).")
		return
	if not _pai_ativo() or pai.vida >= pai.vida_maxima:
		mostrar_mensagem("A vida já está cheia.")
		return
	curativos -= 1
	pai.curar(Itens.CURA)
	inventario_mudou.emit()


# --- armas -----------------------------------------------------------------------

func id_arma_atual() -> String:
	if slots[slot_atual] != "":
		return slots[slot_atual]
	for s in slots:
		if s != "":
			return s
	return "cano"


func arma_atual() -> Dictionary:
	return Itens.ARMAS[id_arma_atual()]


func equipar_slot(i: int) -> void:
	if slots[i] == "":
		return
	slot_atual = i
	armas_mudou.emit()
	mostrar_mensagem(Itens.ARMAS[slots[i]].nome, 1.0)


## Põe a arma no atalho i (tira de outro atalho, se estiver lá).
func colocar_no_slot(id: String, i: int) -> void:
	var antes := slots.find(id)
	if antes != -1:
		slots[antes] = slots[i]
	slots[i] = id
	slot_atual = i
	armas_mudou.emit()


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
	if _livro.visible:
		_livro.fechar()
	if _inv.visible:
		_inv.fechar()
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
