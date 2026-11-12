extends Node2D
## Script da raiz de cada andar. Mostra o nome do andar ao entrar e,
## se o Pai veio por uma escada, coloca ele saindo dessa escada.
## Também cuida do ponto de salvamento (GDD 3.4) e deixa caixas e barris
## quebráveis (soltam madeira e sucata, GDD 4.1).

@export var nome := "1º andar"
## Sprites em Props cujo nome começa com uma destas palavras viram quebráveis.
@export var prefixos_quebraveis: PackedStringArray = ["caixa", "barril"]


func _ready() -> void:
	Jogo.definir_andar(nome)
	_preparar_quebraveis()
	var pai := get_tree().get_first_node_in_group("player")
	var cena := scene_file_path
	if Jogo.escada_de_chegada != "":
		var id := Jogo.escada_de_chegada
		Jogo.escada_de_chegada = ""
		Jogo.checkpoint = {"cena": cena, "escada": id}
		_chegar_pela_escada(pai, id)
	elif Jogo.checkpoint.get("cena", "") == cena and pai:
		# voltou depois de morrer
		if Jogo.checkpoint.has("pos"):
			pai.global_position = Jogo.checkpoint.pos
		else:
			_chegar_pela_escada(pai, Jogo.checkpoint.escada)
	elif pai:
		Jogo.checkpoint = {"cena": cena, "pos": pai.global_position}


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
