extends Node2D
## Script da raiz de cada andar. Mostra o nome do andar ao entrar e,
## se o Pai veio por uma escada, coloca ele saindo dessa escada.

@export var nome := "1º andar"


func _ready() -> void:
	Jogo.mostrar_titulo(nome)
	if Jogo.escada_de_chegada == "":
		return
	var pai := get_tree().get_first_node_in_group("player")
	for escada in get_tree().get_nodes_in_group("escadas"):
		if escada.id == Jogo.escada_de_chegada and pai:
			escada.chegar(pai)
			break
	Jogo.escada_de_chegada = ""
