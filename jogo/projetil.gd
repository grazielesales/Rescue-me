class_name Projetil
extends Area2D
## Projétil mágico dos monstros que atacam de longe (GDD 6.1: criatura mágica,
## 6.2: feiticeiro espectral). Some ao bater numa parede ou no Pai.

var direcao := Vector2.RIGHT
var velocidade := 110.0
var dano := 1
var cor := Color(0.75, 0.45, 1.0)
var _vida := 2.5

static var _luz_tex: Texture2D


## Brilho redondo pequeno em volta do projétil.
static func _textura_luz() -> Texture2D:
	if _luz_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 40
		t.height = 40
		_luz_tex = t
	return _luz_tex


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	z_index = 5
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	cs.shape = shape
	add_child(cs)
	var luz := PointLight2D.new()
	luz.texture = _textura_luz()
	luz.color = cor
	luz.energy = 0.9
	add_child(luz)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direcao * velocidade * delta
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var pulso := 1.0 + sin(_vida * 20.0) * 0.2
	draw_circle(Vector2.ZERO, 4.0 * pulso, Color(cor, 0.35))
	draw_circle(Vector2.ZERO, 2.2, cor.lightened(0.5))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("inimigos"):
		return
	if body.is_in_group("player"):
		body.levar_dano(dano, global_position - direcao * 8.0)
	queue_free()
