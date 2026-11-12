extends Node2D
## Deixa o Sprite2D pai (caixa, barril) quebrável pelos ataques do Pai.
## Ao quebrar, solta madeira e sucata (GDD 4.1) e não volta mais.
## O andar.gd coloca este nó sozinho nos props cujo nome começa com "caixa"/"barril".

var chave := ""
var tipo := "Caixa"
var vida := 2


func _ready() -> void:
	if Jogo.esta_morto(chave):
		get_parent().queue_free()
		return
	add_to_group("atingiveis")


## Chamado pelo ataque do Pai.
func levar_dano(qtd: int, direcao: Vector2, _arma := {}) -> void:
	vida -= qtd
	var alvo := get_parent() as Node2D
	var base := alvo.position
	var tw := alvo.create_tween()
	tw.tween_property(alvo, "position", base + direcao * 2.0, 0.04)
	tw.tween_property(alvo, "position", base, 0.06)
	if vida > 0:
		return
	remove_from_group("atingiveis")
	Jogo.registrar_morte(chave, "")
	for d in Itens.CAIXA_DROPS:
		if randf() <= d[3]:
			Coletavel.soltar(alvo.get_parent(), alvo.global_position, d[0], randi_range(d[1], d[2]))
	alvo.queue_free()
