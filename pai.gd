extends CharacterBody2D

@export var speed := 80.0
var facing := "down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta):
	print(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"))
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed
	move_and_slide()
	_update_animation(dir)

func _update_animation(dir: Vector2):
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			facing = "side"
			sprite.flip_h = dir.x > 0
		elif dir.y > 0:
			facing = "down"
		else:
			facing = "up"
		sprite.play("walk_" + facing)
	else:
		sprite.play("idle_" + facing)
