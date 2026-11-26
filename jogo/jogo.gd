extends CanvasLayer
## Autoload "Jogo": estado que precisa sobreviver à troca de andar e à morte
## (salas visitadas e concluídas, inventário, armas, receitas, ponto de
## salvamento) + fade, mensagens na tela, HUD e livro de receitas.
##
## Save em disco (user://save.json): grava sozinho quando o checkpoint muda
## (definir_checkpoint) e ao fechar a janela. O jogo abre no menu inicial
## (jogo/telas/menu_inicial.tscn): "Continuar" volta ao checkpoint do save e
## "Novo jogo" apaga o save. Ctrl+Shift+N (só em build de desenvolvimento)
## apaga o save e recomeça. Esc abre a pausa (jogo/telas/pausa.gd); o abraço
## no filho termina o jogo com os créditos (jogo/telas/creditos.gd).

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
## Armas que o Pai já tem (ids de Itens.ARMAS). Começa sem nenhuma: com os
## atalhos vazios ele luta com socos (Itens.SEM_ARMA).
var armas: Array[String] = []
## Atalhos 1, 2 e 3 (GDD 3.2). "" = vazio.
var slots: Array[String] = ["", "", ""]
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
## Materiais caídos que o Pai ainda não pegou, por cena:
## cena -> {id: {"item", "qtd", "pos"}}. Continuam no chão ao morrer,
## ao recomeçar e ao trocar de andar, até o Pai voltar e pegar.
var drops := {}
var _proximo_drop := 0
## Marcas livres do jogo (chaves pegas, alavancas puxadas...). Valores simples:
## bool, número ou texto. Vão no save. Use set_flag / get_flag.
var flags := {}

# --- luz do filho -------------------------------------------------------------------
## A luz do filho (preso com o chefe) só se apaga quando o Pai se machuca:
## cada ponto de vida perdido apaga PERDA_LUZ_POR_DANO da luz. Se chegar a zero
## antes de ele ser libertado, o filho não pôde ser salvo e o jogo recomeça do
## zero (tela de fim_filho.gd + música triste).
## Luz cheia (a escala ficou em "segundos" por causa do save antigo).
const TEMPO_LUZ_FILHO := 600.0
## Fração da luz que cada ponto de dano no Pai apaga (0.04 = 25 pontos de dano até apagar).
const PERDA_LUZ_POR_DANO := 0.04
## Marca de quando a bolha estoura (o chefe caiu): a luz para de cair.
const FLAG_FILHO_LIVRE := "filho_libertado"
## Avisos quando a luz passa dessas frações.
const AVISOS_LUZ_FILHO := [
	[0.5, "A luz do seu filho está enfraquecendo..."],
	[0.25, "A luz do seu filho treme. Cada ferida sua apaga um pouco mais."],
	[0.1, "A luz do seu filho é só uma faísca. Não se machuque!"],
]
## Segundos de luz que ainda restam.
var luz_filho := TEMPO_LUZ_FILHO
var _fim_filho := false
var _tela_fim: CanvasLayer

# --- save -------------------------------------------------------------------------
## Sobe quando o formato do save mudar (e trate a diferença em _migrar_save).
const VERSAO_SAVE := 1
## Onde o save fica. Os testes trocam por outro arquivo.
var caminho_save := "user://save.json"

## Primeira tela (cena principal do projeto) e onde começa um jogo novo.
const CENA_MENU := "res://jogo/telas/menu_inicial.tscn"
const CENA_PRIMEIRO_ANDAR := "res://andares/andar1.tscn"

var _hud: CanvasLayer
var _livro: CanvasLayer
var _inv: CanvasLayer
var _morrendo := false
var _pausa: CanvasLayer
var _creditos: CanvasLayer
## true do abraço no filho até os créditos acabarem.
var _fim_jogo := false

var _fade: ColorRect
var _titulo: Label
var _msg: Label
var _msg_tween: Tween
## Quando a mensagem atual sai da tela (Time.get_ticks_msec).
var _msg_ate := 0
var _dica: Label
var _painel: PanelContainer
var _texto: Label
var _imagem: TextureRect
var _trocando := false

## Escala (inteira, pixels nítidos) da imagem mostrada junto com um texto.
const ESCALA_IMAGEM_TEXTO := 4
## Painel dos bilhetes: largura e margem interna (px da tela).
const LARGURA_PAINEL := 420
const MARGEM_PAINEL := 14


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
	estilo.set_content_margin_all(MARGEM_PAINEL)
	_painel.add_theme_stylebox_override("panel", estilo)
	_painel.set_anchors_preset(Control.PRESET_CENTER)
	_painel.custom_minimum_size = Vector2(LARGURA_PAINEL, 0)
	_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_painel.visible = false
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(coluna)
	# imagem opcional em cima do texto (ex.: o desenho do filho visto de perto)
	_imagem = TextureRect.new()
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagem.visible = false
	coluna.add_child(_imagem)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 15)
	_texto.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	# largura fixa: um Label com quebra de linha mede a altura pela largura
	# atual; sem isso, na primeira vez ele mede com largura ~0 (uma letra por
	# linha) e o painel fica imenso, empurrando a imagem para fora da tela
	_texto.custom_minimum_size = Vector2(LARGURA_PAINEL - 2 * MARGEM_PAINEL, 0)
	coluna.add_child(_texto)
	add_child(_painel)

	_estado_inicial()
	_hud = preload("res://jogo/hud.gd").new()
	add_child(_hud)
	_livro = preload("res://jogo/livro.gd").new()
	add_child(_livro)
	_inv = preload("res://jogo/inventario_ui.gd").new()
	add_child(_inv)
	_tela_fim = preload("res://jogo/fim_filho.gd").new()
	add_child(_tela_fim)
	_pausa = preload("res://jogo/telas/pausa.gd").new()  # aplica o volume salvo
	_pausa.name = "Pausa"
	add_child(_pausa)
	_creditos = preload("res://jogo/telas/creditos.gd").new()
	_creditos.name = "Creditos"
	add_child(_creditos)

	# Fechar a janela passa por _notification (salva antes de sair).
	get_tree().set_auto_accept_quit(false)
	# Carrega o save já na abertura: o menu usa para o "Continuar", e rodar um
	# andar solto no editor (F6) começa com o estado salvo.
	carregar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not checkpoint.is_empty():
			salvar()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _fim_filho or _fim_jogo \
			or _pausa.visible or _creditos.visible:
		return
	if OS.is_debug_build() and event is InputEventKey and event.keycode == KEY_N \
			and event.ctrl_pressed and event.shift_pressed:
		get_viewport().set_input_as_handled()
		novo_jogo()
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
	elif event.is_action("ui_cancel"):
		_pausa.abrir()
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


## `aviso` = mostra "Sala vencida!" (só faz sentido se as portas trancaram).
func concluir_sala(chave: String, pos: Vector2, aviso := true) -> void:
	salas_concluidas[chave] = true
	definir_checkpoint({"cena": cena_atual(), "pos": pos})
	if aviso:
		mostrar_mensagem("Sala vencida! As portas se destrancaram.")


## Muda o ponto de salvamento e grava o save em disco.
## dados = {"cena", "pos"} ou {"cena", "escada"}.
func definir_checkpoint(dados: Dictionary) -> void:
	checkpoint = dados
	salvar()


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


# --- flags -------------------------------------------------------------------------

## Guarda uma marca (ex.: set_flag("chave_porao", true)). Entra no próximo save.
func set_flag(nome: String, valor: Variant) -> void:
	flags[nome] = valor


func get_flag(nome: String, padrao: Variant = null) -> Variant:
	return flags.get(nome, padrao)


## Grava agora, sem mudar o checkpoint (eventos de progresso: alavanca, baú,
## arena vencida). Antes do primeiro checkpoint não há o que gravar.
func salvar_progresso() -> void:
	if not checkpoint.is_empty():
		salvar()


# --- save em disco -----------------------------------------------------------------

## Estado de um jogo novo.
func _estado_inicial() -> void:
	salas_visitadas = {}
	escada_de_chegada = ""
	inventario = {}
	armas.assign([])
	slots.assign(["", "", ""])
	slot_atual = 0
	curativos = 0
	receitas_conhecidas = {}
	for r in Itens.RECEITAS:
		if r.get("inicial", false):
			receitas_conhecidas[r.id] = true
	melhorias = {}
	mortos = {}
	salas_concluidas = {}
	tipos_derrotados = {}
	checkpoint = {}
	drops = {}
	_proximo_drop = 0
	flags = {}
	luz_filho = TEMPO_LUZ_FILHO


func tem_save() -> bool:
	return FileAccess.file_exists(caminho_save)


func apagar_save() -> void:
	if tem_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))


## Grava todo o estado em `caminho_save`. Escreve num .tmp e depois troca,
## para um fechamento no meio da gravação não estragar o save anterior.
func salvar() -> bool:
	var cp := checkpoint.duplicate()
	if cp.has("pos"):
		cp.pos = _vec_para_json(cp.pos)
	var drops_json := {}
	for cena in drops:
		var da_cena := {}
		for id in drops[cena]:
			var d: Dictionary = drops[cena][id]
			da_cena[id] = {"item": d.item, "qtd": d.qtd, "pos": _vec_para_json(d.pos)}
		drops_json[cena] = da_cena
	var dados := {
		"versao": VERSAO_SAVE,
		"inventario": inventario,
		"armas": armas,
		"slots": slots,
		"slot_atual": slot_atual,
		"curativos": curativos,
		"receitas_conhecidas": receitas_conhecidas.keys(),
		"melhorias": melhorias.keys(),
		"mortos": mortos.keys(),
		"salas_visitadas": salas_visitadas.keys(),
		"salas_concluidas": salas_concluidas.keys(),
		"tipos_derrotados": tipos_derrotados.keys(),
		"checkpoint": cp,
		"drops": drops_json,
		"proximo_drop": _proximo_drop,
		"flags": flags,
		"luz_filho": luz_filho,
	}
	var tmp := caminho_save + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: não deu para gravar %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(dados, "\t"))
	f.close()
	var final := ProjectSettings.globalize_path(caminho_save)
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(final)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), final)
	if err != OK:
		push_warning("Save: não deu para trocar o arquivo (%s)" % error_string(err))
		return false
	return true


## Lê o save, se houver. Devolve true se carregou. Arquivo estragado ou de uma
## versão mais nova do jogo: avisa, não apaga e começa do zero.
func carregar() -> bool:
	if not tem_save():
		return false
	var texto := FileAccess.get_file_as_string(caminho_save)
	var dados: Variant = JSON.parse_string(texto)
	if not dados is Dictionary or not dados.has("versao"):
		push_warning("Save: %s está ilegível; começando do zero." % caminho_save)
		return false
	var versao := int(dados.versao)
	if versao > VERSAO_SAVE:
		push_warning("Save: versão %d é mais nova que a do jogo (%d); começando do zero." % [versao, VERSAO_SAVE])
		return false
	dados = _migrar_save(dados, versao)

	_estado_inicial()
	for m in dados.get("inventario", {}):
		inventario[m] = int(dados.inventario[m])
	# ids que não existem mais (ex.: o antigo "cano") são descartados
	armas.assign(dados.get("armas", []).filter(func(a): return Itens.ARMAS.has(a) and a != Itens.SEM_ARMA))
	slots.assign(["", "", ""])
	var lidos: Array = dados.get("slots", [])
	for i in mini(lidos.size(), 3):
		if lidos[i] in armas:
			slots[i] = lidos[i]
	slot_atual = clampi(int(dados.get("slot_atual", 0)), 0, slots.size() - 1)
	curativos = int(dados.get("curativos", 0))
	for id in dados.get("receitas_conhecidas", []):
		receitas_conhecidas[id] = true
	melhorias = _conjunto(dados.get("melhorias", []))
	mortos = _conjunto(dados.get("mortos", []))
	salas_visitadas = _conjunto(dados.get("salas_visitadas", []))
	salas_concluidas = _conjunto(dados.get("salas_concluidas", []))
	tipos_derrotados = _conjunto(dados.get("tipos_derrotados", []))
	checkpoint = dados.get("checkpoint", {})
	if checkpoint.has("pos"):
		checkpoint.pos = _vec_de_json(checkpoint.pos)
	for cena in dados.get("drops", {}):
		var da_cena := {}
		for id in dados.drops[cena]:
			var d: Dictionary = dados.drops[cena][id]
			da_cena[id] = {"item": d.item, "qtd": int(d.qtd), "pos": _vec_de_json(d.pos)}
		drops[cena] = da_cena
	_proximo_drop = int(dados.get("proximo_drop", 0))
	for nome in dados.get("flags", {}):
		var v: Variant = dados.flags[nome]
		# o JSON lê todo número como float; inteiros voltam a ser int
		flags[nome] = int(v) if v is float and v == floorf(v) else v
	luz_filho = clampf(float(dados.get("luz_filho", TEMPO_LUZ_FILHO)), 0.0, TEMPO_LUZ_FILHO)
	inventario_mudou.emit()
	armas_mudou.emit()
	return true


## Adapta saves de versões antigas ao formato atual. Hoje só existe a versão 1.
func _migrar_save(dados: Dictionary, _versao: int) -> Dictionary:
	return dados


## Apaga o save e recomeça do 1º andar (botão "Novo jogo" do menu inicial e
## Ctrl+Shift+N em desenvolvimento). `mensagem` vazia = não mostra nada ao
## recomeçar.
func novo_jogo(mensagem := "Novo jogo (save apagado).") -> void:
	if _trocando:
		return
	_trocando = true
	if _livro.visible:
		_livro.fechar()
	if _inv.visible:
		_inv.fechar()
	if _pausa.visible:
		_pausa.fechar()
	apagar_save()
	await fade(1.0, 0.35)
	_estado_inicial()
	inventario_mudou.emit()
	armas_mudou.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(CENA_PRIMEIRO_ANDAR)
	await get_tree().process_frame
	await get_tree().process_frame
	_morrendo = false
	_fim_filho = false
	_fim_jogo = false
	await fade(0.0, 0.45)
	_trocando = false
	if mensagem != "":
		mostrar_mensagem(mensagem)


## "Continuar" do menu: relê o save e vai para o andar do checkpoint (o
## andar.gd põe o Pai no ponto salvo). Save ilegível: começa do 1º andar.
func continuar_jogo() -> void:
	if _trocando:
		return
	if not carregar():
		_estado_inicial()
		inventario_mudou.emit()
		armas_mudou.emit()
	var alvo: String = checkpoint.get("cena", "")
	if alvo == "" or not ResourceLoader.exists(alvo):
		alvo = CENA_PRIMEIRO_ANDAR
	await _ir_para(alvo)


## "Menu inicial" da pausa (e o fim dos créditos do fim do jogo): salva como
## ao fechar a janela e volta para o menu.
func ir_para_menu() -> void:
	if _trocando:
		return
	if not checkpoint.is_empty():
		salvar()
	if _pausa.visible:
		_pausa.fechar()
	if _livro.visible:
		_livro.fechar()
	if _inv.visible:
		_inv.fechar()
	esconder_texto()
	esconder_dica()
	await _ir_para(CENA_MENU)


## "Sair do jogo" da pausa: salva como ao fechar a janela.
func sair_do_jogo() -> void:
	if not checkpoint.is_empty():
		salvar()
	get_tree().quit()


## Escurece, troca de cena e clareia (sem escada de chegada).
func _ir_para(cena: String) -> void:
	_trocando = true
	await fade(1.0, 0.45)
	get_tree().paused = false
	get_tree().change_scene_to_file(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	_morrendo = false
	await fade(0.0, 0.45)
	_trocando = false


## Créditos subindo. `fim_de_jogo` = vieram do abraço no filho: o jogo fica
## pausado por baixo e, quando acabam, volta ao menu inicial.
func mostrar_creditos(fim_de_jogo := false) -> void:
	if _creditos.visible:
		return
	if fim_de_jogo:
		get_tree().paused = true
	await _creditos.mostrar()
	if fim_de_jogo:
		_fade.color.a = 1.0
		await _ir_para(CENA_MENU)
		_fim_jogo = false


## Fim do jogo (filho.gd, depois do abraço): um instante, a tela escurece e
## sobem os créditos; depois, o menu inicial.
func terminar_jogo() -> void:
	if _fim_jogo:
		return
	_fim_jogo = true
	await get_tree().create_timer(1.5).timeout
	esconder_dica()
	await fade(1.0, 1.2)
	await mostrar_creditos(true)


func _conjunto(lista: Array) -> Dictionary:
	var d := {}
	for k in lista:
		d[k] = true
	return d


func _vec_para_json(v: Vector2) -> Array:
	return [v.x, v.y]


func _vec_de_json(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else Vector2.ZERO


# --- materiais no chão -------------------------------------------------------------

## Guarda um material que caiu no chão da cena atual. Devolve o id do drop.
func registrar_drop(item: String, qtd: int, pos: Vector2) -> String:
	var id := str(_proximo_drop)
	_proximo_drop += 1
	var da_cena: Dictionary = drops.get_or_add(cena_atual(), {})
	da_cena[id] = {"item": item, "qtd": qtd, "pos": pos}
	return id


func remover_drop(id: String) -> void:
	var da_cena: Dictionary = drops.get(cena_atual(), {})
	da_cena.erase(id)


## Drops ainda no chão de uma cena (id -> dados).
func drops_da_cena(cena: String) -> Dictionary:
	return drops.get(cena, {})


# --- linha de visão ----------------------------------------------------------------

## true se nenhuma parede ou porta fechada fica entre `de` e `ate` (globais).
## Móveis, monstros, a piscina e outras coisas baixas não bloqueiam.
## Chame durante _physics_process.
func linha_livre(de: Vector2, ate: Vector2) -> bool:
	var espaco := get_tree().root.world_2d.direct_space_state
	var q := PhysicsRayQueryParameters2D.create(de, ate, 1)
	var ignorar: Array[RID] = []
	for i in 12:
		q.exclude = ignorar
		var hit := espaco.intersect_ray(q)
		if hit.is_empty():
			return true
		var c: Object = hit.collider
		if c is TileMapLayer or (c is Node and c.has_method("bloquear")):
			return false  # parede ou porta fechada
		ignorar.append(hit.rid)
	return true


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
	Som.tocar("mundo/receita_nova", 0.0, 1.0, 0.0)
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
	if ja_criou(r) or not receitas_conhecidas.has(r.id):
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
	Som.tocar("interface/criar", 0.0, 1.0, 0.0)
	mostrar_mensagem("Criado: %s" % Itens.nome_receita(r))
	return true


func usar_curativo() -> void:
	if curativos <= 0:
		Som.tocar("interface/erro", 0.0, 1.0, 0.0)
		mostrar_mensagem("Sem curativos. Crie um no livro de receitas (R).")
		return
	if not _pai_ativo() or pai.vida >= pai.vida_maxima:
		Som.tocar("interface/erro", 0.0, 1.0, 0.0)
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
	return Itens.SEM_ARMA


func arma_atual() -> Dictionary:
	return Itens.ARMAS[id_arma_atual()]


func equipar_slot(i: int) -> void:
	if slots[i] == "":
		return
	if i != slot_atual:
		Som.tocar("interface/equipar")
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
	Som.tocar("interface/equipar")
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


# --- luz do filho ------------------------------------------------------------------

## Chamado pelo pai.gd quando ele perde vida: apaga um pedaço da luz.
func pai_levou_dano(qtd: int) -> void:
	_gastar_luz_filho(TEMPO_LUZ_FILHO * PERDA_LUZ_POR_DANO * qtd)


## 1 = luz cheia, 0 = apagada.
func fracao_luz_filho() -> float:
	return luz_filho / TEMPO_LUZ_FILHO


## O jogo já foi zerado (o Pai abraçou o filho)? O menu esconde o Continuar.
func jogo_zerado() -> bool:
	return get_flag("filho_resgatado", false)


## O filho já saiu da bolha (o chefe caiu)? Daí a luz não cai mais.
func filho_livre() -> bool:
	return get_flag(FLAG_FILHO_LIVRE, false) or get_flag("filho_resgatado", false)


## Chamado pelo filho.gd quando a bolha estoura (ou já estava estourada).
func libertar_filho() -> void:
	if get_flag(FLAG_FILHO_LIVRE, false):
		return
	set_flag(FLAG_FILHO_LIVRE, true)
	salvar_progresso()


func _gastar_luz_filho(quanto: float) -> void:
	if _fim_filho or filho_livre() or quanto <= 0.0:
		return
	var antes := fracao_luz_filho()
	luz_filho = maxf(0.0, luz_filho - quanto)
	var agora := fracao_luz_filho()
	for aviso in AVISOS_LUZ_FILHO:
		if antes > aviso[0] and agora <= aviso[0]:
			mostrar_mensagem(aviso[1], 3.5, true)
	salvar_progresso()
	if luz_filho <= 0.0:
		_luz_filho_apagou()


## A luz acabou: tela do fim com a música triste e o jogo recomeça do zero.
func _luz_filho_apagou() -> void:
	_fim_filho = true
	if _livro.visible:
		_livro.fechar()
	if _inv.visible:
		_inv.fechar()
	esconder_texto()
	esconder_dica()
	if _msg_tween:
		_msg_tween.kill()
	_msg.modulate.a = 0.0
	get_tree().paused = true  # monstros e Pai param onde estão
	Musica.tocar_lamento()
	await _tela_fim.mostrar()
	_fade.color.a = 1.0  # preto por baixo da tela do fim
	await _tela_fim.esconder()
	await novo_jogo("")


# --- textos ----------------------------------------------------------------------

func mostrar_titulo(texto: String) -> void:
	_titulo.text = texto
	var t := create_tween()
	t.tween_property(_titulo, "modulate:a", 1.0, 0.6)
	t.tween_interval(1.8)
	t.tween_property(_titulo, "modulate:a", 0.0, 0.8)


## Mensagem curta no centro-baixo da tela (GDD 7.4).
## `depois_da_atual` = espera a mensagem que está na tela terminar, em vez de
## cobrir (ex.: a arena trancando logo depois do baú dar a chave).
func mostrar_mensagem(texto: String, duracao := 2.5, depois_da_atual := false) -> void:
	var agora := Time.get_ticks_msec()
	if depois_da_atual and agora < _msg_ate:
		_msg_ate += int((duracao + 0.6) * 1000.0)
		await get_tree().create_timer((_msg_ate - agora) / 1000.0 - duracao - 0.6).timeout
	_msg_ate = maxi(_msg_ate, Time.get_ticks_msec() + int((duracao + 0.6) * 1000.0))
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
## `imagem` (opcional) aparece em cima do texto, ampliada em pixels inteiros.
func mostrar_texto(texto: String, imagem: Texture2D = null) -> void:
	_texto.text = texto
	_imagem.texture = imagem
	_imagem.visible = imagem != null
	if imagem:
		_imagem.custom_minimum_size = imagem.get_size() * ESCALA_IMAGEM_TEXTO
	_painel.visible = true
	# encolhe para o tamanho do conteúdo (o próximo texto pode não ter imagem);
	# de novo no fim do quadro, depois que os containers se arrumarem
	_painel.reset_size()
	_painel.call_deferred("reset_size")


func esconder_texto() -> void:
	_painel.visible = false
