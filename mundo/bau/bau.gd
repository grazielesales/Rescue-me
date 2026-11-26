extends Sprite2D
## Baú que abre com E (mesmo padrão do alavanca.gd). Perto dele aparece
## "E: abrir baú"; apertar E troca o desenho para o baú aberto, mostra o item
## subindo, marca as flags no Jogo e salva na hora.
## Usa uma região da textura (region_enabled) para cada estado.
## Ex.: o baú da tumba (SalaSul) dá a chave do Nordeste e acorda os esqueletos.
## Com `itens`, o baú solta esses materiais (ou curas) no chão à frente dele,
## sempre os mesmos. Eles ficam em Jogo.drops como qualquer drop: se o Pai não
## pegar, continuam lá ao voltar para o andar.

## Região da textura com o baú fechado e com o baú aberto.
@export var regiao_fechado := Rect2(151, 20, 19, 18)
@export var regiao_aberto := Rect2(179, 52, 29, 20)
@export var raio := 20.0
## Flag marcada ao abrir; com ela no save, o baú já aparece aberto.
@export var flag_aberto := "tumba_aberta"
## Flag do item que o baú dá (ex.: "chave_nordeste"). Vazio = nenhum.
@export var flag_recompensa := "chave_nordeste"
## Mensagem ao abrir. Vazia com `itens` = lista o que saiu ("No baú: 2 Teia resistente...").
@export var mensagem := "Você encontrou uma chave enferrujada."
## O que o baú solta ao abrir: id do material em Itens.MATERIAIS -> quantidade.
@export var itens: Dictionary[String, int] = {}
## Desenho do item que sobe do baú ao abrir (opcional).
@export var textura_recompensa: Texture2D
@export var regiao_recompensa := Rect2(274, 64, 12, 8)

var _perto := false
var _aberto := false


func _ready() -> void:
	region_enabled = true
	var area := Area2D.new()
	area.collision_layer = 0
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = raio
	cs.shape = shape
	cs.position = Vector2(0, -6)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_entrou)
	area.body_exited.connect(_on_saiu)
	_mostrar(flag_aberto != "" and Jogo.get_flag(flag_aberto, false))


## Troca o desenho mantendo a base do baú no mesmo lugar (origem nos pés).
func _mostrar(aberto: bool) -> void:
	_aberto = aberto
	region_rect = regiao_aberto if aberto else regiao_fechado
	offset = Vector2(0, -region_rect.size.y / 2.0 + 1.0)


func _on_entrou(body: Node) -> void:
	if body.is_in_group("player") and not _aberto:
		_perto = true
		Jogo.mostrar_dica("E: abrir baú")


func _on_saiu(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = false
		Jogo.esconder_dica()


func _process(_delta: float) -> void:
	if _perto and not _aberto and Input.is_action_just_pressed("interagir"):
		abrir()


func abrir() -> void:
	if _aberto:
		return
	_perto = false
	Jogo.esconder_dica()
	_mostrar(true)
	Som.tocar_em("mundo/bau_abrir", global_position)
	if flag_recompensa != "" or not itens.is_empty():
		get_tree().create_timer(0.35).timeout.connect(Som.tocar.bind("mundo/achado", 0.0, 1.0, 0.0))
	if flag_aberto != "":
		Jogo.set_flag(flag_aberto, true)
	if flag_recompensa != "":
		Jogo.set_flag(flag_recompensa, true)
	_soltar_itens()
	Jogo.salvar_progresso()
	var texto := mensagem if mensagem != "" or itens.is_empty() else _lista_itens()
	if texto != "":
		Jogo.mostrar_mensagem(texto, 3.0)
	_item_subindo()


## O item sobe de dentro do baú e some.
func _item_subindo() -> void:
	if textura_recompensa == null:
		return
	var s := Sprite2D.new()
	s.texture = textura_recompensa
	s.region_enabled = true
	s.region_rect = regiao_recompensa
	s.position = Vector2(0, -region_rect.size.y * 0.6)
	s.z_index = 5
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y - 14.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.tween_callback(s.queue_free)


## Os itens caem um pouco à frente do baú, separados, com o pulinho dos drops.
func _soltar_itens() -> void:
	var frente := global_position + Vector2(0, 12)
	for id in itens:
		if not Itens.MATERIAIS.has(id):
			push_warning("Baú %s: item desconhecido \"%s\"" % [name, id])
			continue
		Coletavel.soltar(get_parent(), frente, id, itens[id])


func _lista_itens() -> String:
	var partes: Array[String] = []
	for id in itens:
		partes.append("%d %s" % [itens[id], Itens.nome_material(id)])
	return "No baú: " + ", ".join(partes) + "."
