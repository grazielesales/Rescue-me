extends StaticBody2D

@onready var sprite := $AnimatedSprite2D
@onready var collision := $CollisionShape2D
@onready var area := $Area2D

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("Entrou: linda grazi ", body.name)
	if body.is_in_group("player"):
		sprite.play("opening")
		collision.set_deferred("disabled", true)

func _on_body_exited(body):
	if body.is_in_group("player"):
		sprite.play("closing")
		collision.set_deferred("disabled", false)
