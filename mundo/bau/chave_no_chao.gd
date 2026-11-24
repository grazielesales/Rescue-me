extends Sprite2D
## Chave caída no chão: o Pai pega só de passar por cima. Marca a flag no
## Jogo, mostra a mensagem, salva na hora e some subindo.
## Com a flag já no save, a chave não aparece mais.
## Ex.: a chave do fosso de espinhos (bolsão oeste) abre as portas da Sala Sul.

## Flag que a chave dá (as portas com essa `flag_necessaria` destrancam).
@export var flag := "chave_tumba"
@export var mensagem := "Você pegou uma chave de ferro. Ela deve abrir a tumba."
@export var raio := 8.0

var _pega := false


func _ready() -> void:
	if Jogo.get_flag(flag, false):
		queue_free()
		return
	var area := Area2D.new()
	area.collision_layer = 0
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = raio
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_entrou)


func _on_entrou(body: Node) -> void:
	if _pega or not body.is_in_group("player"):
		return
	_pega = true
	Som.tocar("mundo/chave", 0.0, 1.0, 0.0)
	Jogo.set_flag(flag, true)
	Jogo.salvar_progresso()
	if mensagem != "":
		Jogo.mostrar_mensagem(mensagem, 3.0)
	z_index = 5
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 14.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tw.tween_callback(queue_free)
