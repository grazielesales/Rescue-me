extends Node2D
## Script da raiz de cada andar. Mostra o nome do andar ao entrar e,
## se o Pai veio por uma escada, coloca ele saindo dessa escada.
## Também cuida do ponto de salvamento (GDD 3.4) e deixa caixas e barris
## quebráveis (soltam madeira e sucata, GDD 4.1).

@export var nome := "1º andar"
## Sprites em Props cujo nome começa com uma destas palavras viram quebráveis.
@export var prefixos_quebraveis: PackedStringArray = ["caixa", "barril"]
## Música do andar em res://sons/musica (<musica>_ambiente.wav e
## <musica>_tensao.wav). Vazio = o nome do arquivo da cena (ex.: "andar1").
@export var musica := ""


func _ready() -> void:
	# A escuridão (CanvasModulate) fica desligada na cena para o editor mostrar
	# o mapa claro; no jogo ela é ligada aqui.
	for n in find_children("*", "CanvasModulate", false, false):
		n.visible = true
	Jogo.definir_andar(nome)
	Musica.tocar_andar(musica if musica != "" else scene_file_path.get_file().get_basename())
	_preparar_quebraveis()
	_recriar_drops()
	_criar_navegacao()
	var pai := get_tree().get_first_node_in_group("player")
	var cena := scene_file_path
	if Jogo.escada_de_chegada != "":
		var id := Jogo.escada_de_chegada
		Jogo.escada_de_chegada = ""
		Jogo.definir_checkpoint({"cena": cena, "escada": id})
		_chegar_pela_escada(pai, id)
	elif Jogo.checkpoint.get("cena", "") == cena and pai:
		# voltou depois de morrer
		if Jogo.checkpoint.has("pos"):
			pai.global_position = Jogo.checkpoint.pos
		else:
			_chegar_pela_escada(pai, Jogo.checkpoint.escada)
	elif pai:
		Jogo.definir_checkpoint({"cena": cena, "pos": pai.global_position})


## Malha de navegação dos monstros: todo o chão do andar, menos as paredes
## (tiles com colisão) e tudo que for StaticBody2D (móveis, piscina, poço,
## muretas). Portas e portões ficam de fora: o caminho passa por eles, e
## fechados eles barram o monstro pela colisão normal.
func _criar_navegacao() -> void:
	const GRUPO := &"nav_obstaculo"
	for n in find_children("*", "TileMapLayer", true, false):
		var t := n as TileMapLayer
		if t.collision_enabled and t.tile_set and t.tile_set.get_physics_layers_count() > 0:
			t.add_to_group(GRUPO)
	for n in find_children("*", "StaticBody2D", true, false):
		if not n.has_method("bloquear"):
			n.add_to_group(GRUPO)

	var limites := Rect2()
	for n in find_children("floor", "TileMapLayer", true, false):
		var t := n as TileMapLayer
		var usado := t.get_used_rect()
		if usado.size == Vector2i.ZERO:
			continue
		var meio := Vector2(t.tile_set.tile_size) / 2.0
		var a := to_local(t.to_global(t.map_to_local(usado.position) - meio))
		var b := to_local(t.to_global(t.map_to_local(usado.end - Vector2i.ONE) + meio))
		var r := Rect2(a, b - a).abs()
		limites = r if limites.size == Vector2.ZERO else limites.merge(r)
	if limites.size == Vector2.ZERO:
		return

	var np := NavigationPolygon.new()
	# metade da colisão dos monstros (inimigo.gd: no máximo 8 px) + 1 px de folga
	np.agent_radius = 5.0
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 1
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	np.source_geometry_group_name = GRUPO
	var fonte := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(np, fonte, self)
	fonte.add_traversable_outline(PackedVector2Array([
		limites.position, Vector2(limites.end.x, limites.position.y),
		limites.end, Vector2(limites.position.x, limites.end.y)]))
	NavigationServer2D.bake_from_source_geometry_data(np, fonte)
	var regiao := NavigationRegion2D.new()
	regiao.name = "Navegacao"
	regiao.navigation_polygon = np
	add_child(regiao)


## Materiais que caíram e o Pai ainda não pegou voltam para o mesmo lugar.
func _recriar_drops() -> void:
	var alvo: Node = get_node_or_null("Entities")
	if alvo == null:
		alvo = self
	var da_cena := Jogo.drops_da_cena(scene_file_path)
	for id in da_cena:
		Coletavel.recriar(alvo, id, da_cena[id])


func _chegar_pela_escada(pai: Node, id: String) -> void:
	for escada in get_tree().get_nodes_in_group("escadas"):
		if escada.id == id and pai:
			escada.chegar(pai)
			break


func _preparar_quebraveis() -> void:
	var props := get_node_or_null("Props")
	if props == null:
		return
	for n in props.get_children():
		if not n is Sprite2D:
			continue
		var nome_min := String(n.name).to_lower()
		for p in prefixos_quebraveis:
			if nome_min.begins_with(p):
				var q := preload("res://jogo/quebravel.gd").new()
				q.chave = "%s:Props/%s" % [scene_file_path, n.name]
				n.add_child(q)
				break
