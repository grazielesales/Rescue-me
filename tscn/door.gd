extends StaticBody2D
## Porta comum: abre quando o Pai chega perto e fecha quando ele sai.
## Uma sala bloqueada (sala.gd) pode trancar a porta com bloquear()
## até todos os monstros dela morrerem (liberar()).

@onready var sprite := $AnimatedSprite2D
@onready var collision := $CollisionShape2D
@onready var area := $Area2D

## Trancada por uma sala bloqueada (GDD 3.5).
var bloqueada := false
var _aberta := false


func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if not body.is_in_group("player"):
		return
	if bloqueada:
		Jogo.mostrar_mensagem("Trancada! Derrote todos os monstros da sala.", 1.5)
		return
	_abrir()


func _on_body_exited(body):
	if body.is_in_group("player") and not bloqueada:
		_fechar()


func bloquear() -> void:
	bloqueada = true
	_fechar()


func liberar() -> void:
	bloqueada = false
	if Jogo._pai_ativo() and area.overlaps_body(Jogo.pai):
		_abrir()


func _abrir() -> void:
	_aberta = true
	sprite.play("opening")
	collision.set_deferred("disabled", true)


func _fechar() -> void:
	if _aberta:
		sprite.play("closing")
	_aberta = false
	collision.set_deferred("disabled", false)
