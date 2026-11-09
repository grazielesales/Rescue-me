extends StaticBody2D
## Portão de grade. Destrancado, funciona como as portas (abre quando o Pai
## chega perto). Trancado, só abre pela alavanca ligada a ele (alavanca.gd),
## e aí fica levantado de vez.

## Começa trancado (precisa de alavanca).
@export var trancado := false
@export var mensagem_trancado := "O portão não abre. Deve haver uma alavanca por perto."

var _levantado := false

@onready var sprite := $AnimatedSprite2D
@onready var collision := $CollisionShape2D
@onready var area := $Area2D


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _levantado:
		return
	if trancado:
		Jogo.mostrar_mensagem(mensagem_trancado)
		return
	sprite.play("opening")
	collision.set_deferred("disabled", true)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player") or _levantado or trancado:
		return
	sprite.play("closing")
	collision.set_deferred("disabled", false)


## Chamado pela alavanca: levanta o portão e ele não fecha mais.
func destrancar() -> void:
	trancado = false
	_levantado = true
	sprite.play("opening")
	collision.set_deferred("disabled", true)
