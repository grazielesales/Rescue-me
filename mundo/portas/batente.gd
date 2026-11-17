extends Sprite2D
## Arco de pedra da porta + a parede logo acima dele.
##
## O nó fica na linha de y-sort perto da base da parede (position.y = 20).
## Com os pés acima dessa linha (atravessando o vão ou na sala de cima),
## o Pai é desenhado atrás do arco e da parede que fica em cima da porta.
##
## A parede é copiada, ao abrir a cena, das camadas de parede do andar
## (`camadas_de_parede`) para uma camada filha deste nó.

## Camadas de parede do andar, relativas ao nó raiz do andar.
@export var camadas_de_parede: Array[String] = ["Map/wall", "wall2"]
## Quantas linhas de tile acima do arco são copiadas.
@export var linhas_acima := 3
## Colunas extras copiadas de cada lado do vão de 2 tiles.
@export var colunas_extras := 1


func _ready() -> void:
	_copiar_parede.call_deferred()


func _copiar_parede() -> void:
	var andar := _achar_andar()
	if andar == null:
		return
	# Centro do sprite da porta (32x48), em coordenadas globais.
	var centro := to_global(offset)
	for caminho in camadas_de_parede:
		var origem := andar.get_node_or_null(caminho) as TileMapLayer
		if origem == null or not origem.visible or origem.tile_set == null:
			continue
		# Centro da porta = (X*16+16, L*16+19) -> célula (X+1, L+1).
		var c := origem.local_to_map(origem.to_local(centro))
		var linha_arco := c.y - 1
		var copia := TileMapLayer.new()
		copia.name = "Parede " + origem.name
		copia.tile_set = origem.tile_set
		copia.collision_enabled = false
		copia.navigation_enabled = false
		copia.show_behind_parent = true  # o arco fica por cima da parede
		var algum := false
		for y in range(linha_arco - linhas_acima, linha_arco + 1):
			for x in range(c.x - 1 - colunas_extras, c.x + colunas_extras + 1):
				var p := Vector2i(x, y)
				var fonte := origem.get_cell_source_id(p)
				if fonte == -1:
					continue
				copia.set_cell(p, fonte, origem.get_cell_atlas_coords(p), origem.get_cell_alternative_tile(p))
				algum = true
		if not algum:
			copia.free()
			continue
		add_child(copia)
		copia.global_transform = origem.global_transform


func _achar_andar() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_node("Map"):
			return n
		n = n.get_parent()
	return null
