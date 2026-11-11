extends CharacterBody2D
## O Pai: movimento e animação (como antes) + tocha na tecla T.
## Sem tocha a visão é um círculo pequeno; segurando T o Pai ergue a tocha
## e o raio cresce torch_vision_multiplier vezes (1.6 = +60%).

signal torch_changed(raised: bool)

@export var speed := 80.0

@export_group("Tocha e visão")
## Raio da visão sem tocha, em pixels do mundo. Diminua por andar (GDD 5.2).
@export var base_vision_radius: float = 64.0
## Multiplicador do RAIO com a tocha. 1.6 = +60% de raio (a área cresce 2,56x).
## Para +60% de ÁREA use 1.265.
@export var torch_vision_multiplier: float = 1.8
## true: segura T para erguer (GDD 3.3). false: cada toque em T liga/desliga.
@export var hold_to_raise: bool = false
## GDD 3.3: com a tocha erguida o Pai anda mais devagar.
@export_range(0.1, 1.0) var torch_speed_multiplier: float = 0.75
@export var transition_time: float = 0.18
@export var vision_color: Color = Color(1.0, 0.7, 0.4)
@export var vision_energy: float = 1.25
@export var torch_color: Color = Color(1.0, 0.7, 0.4)
@export var torch_energy: float = 1.25
## Oscilação da chama (energia ±; o raio oscila 1/3 disso).
@export_range(0.0, 0.3) var flicker_strength: float = 0.08
## Textura da luz com a tocha acesa (mais camadas que a de sem tocha).
## Precisa ter 256x256 e preenchimento radial, como a do nó Visao.
## Vazio = usa a mesma textura com e sem tocha.
@export var torch_light_texture: Texture2D

const LIGHT_TEXTURE_RADIUS := 128.0  # a textura da luz tem 256 px de largura
const FLAME_FPS := 10.0
const FLAME_FRAMES := 4
## Onde fica a mão que segura a tocha, para cada direção (pixels do mundo).
## A origem do Pai fica nos PÉS (ordem de desenho correta com móveis e monstros).
const GRIP := {
	"down": Vector2(-6, -9),
	"up": Vector2(6, -9),
	"left": Vector2(-6, -9),
	"right": Vector2(6, -9),
}

var facing := "down"
var torch_raised := false
var vision_radius: float  ## raio atual (sem a oscilação da chama)

## true enquanto outro nó (ex.: a escada) controla o Pai; o jogador não move.
var controle_externo := false

var _blend := 0.0  # 0 = sem tocha, 1 = tocha erguida
var _base_light_texture: Texture2D
var _tween: Tween
var _time := 0.0
var _noise := FastNoiseLite.new()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var torch: Node2D = $Tocha
@onready var torch_sprite: Sprite2D = $Tocha/Sprite2D
@onready var vision: PointLight2D = $Visao


func _ready() -> void:
	add_to_group("player")  # as portas (door.gd) procuram esse grupo
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	torch.visible = false
	_base_light_texture = vision.texture
	_set_blend(0.0)


func _physics_process(_delta: float) -> void:
	_read_torch_input()
	if controle_externo:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed * (torch_speed_multiplier if torch_raised else 1.0)
	move_and_slide()
	_update_animation(dir)


func _process(delta: float) -> void:
	_time += delta
	var n := _noise.get_noise_1d(_time * 9.0) * _blend * flicker_strength
	vision.energy = lerpf(vision_energy, torch_energy, _blend) * (1.0 + n)
	vision.texture_scale = vision_radius * (1.0 + n / 3.0) / LIGHT_TEXTURE_RADIUS
	if torch.visible:
		torch_sprite.frame = int(_time * FLAME_FPS) % FLAME_FRAMES


func _update_animation(dir: Vector2) -> void:
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
	_place_torch()


# --- API pública (inimigos, HUD, armas) --------------------------------------

func set_torch_raised(value: bool) -> void:
	if value == torch_raised:
		return
	torch_raised = value
	torch.visible = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_blend, _blend, 1.0 if value else 0.0, transition_time)
	torch_changed.emit(value)


func is_torch_raised() -> bool:
	return torch_raised


## Raio de visão atual em pixels do mundo.
func get_vision_radius() -> float:
	return vision_radius


## O ponto está dentro do círculo de visão? Para monstros que "só aparecem
## quando se aproximam" ou que reagem à luz (GDD 3.3 e 6.1).
func is_point_visible(world_point: Vector2) -> bool:
	return vision.global_position.distance_to(world_point) <= vision_radius


## GDD 3.3: com a tocha erguida não dá para usar armas de duas mãos.
func can_use_two_handed() -> bool:
	return not torch_raised


## Usado pela escada: toca a animação de andar/parado numa direção
## ("down", "up", "side") sem mover o corpo.
func animar(direcao: String, andando: bool, virado_direita := false) -> void:
	facing = direcao
	if direcao == "side":
		sprite.flip_h = virado_direita
	sprite.play(("walk_" if andando else "idle_") + direcao)
	_place_torch()


## Liga/desliga a colisão do Pai (a escada desliga enquanto ele sobe).
func set_colisao(ativa: bool) -> void:
	$CollisionShape2D.set_deferred("disabled", not ativa)


# --- interno -------------------------------------------------------------------

func _read_torch_input() -> void:
	if hold_to_raise:
		set_torch_raised(Input.is_action_pressed("torch"))
	elif Input.is_action_just_pressed("torch"):
		set_torch_raised(not torch_raised)


func _set_blend(value: float) -> void:
	_blend = value
	vision_radius = lerpf(base_vision_radius, base_vision_radius * torch_vision_multiplier, value)
	vision.color = vision_color.lerp(torch_color, value)
	if torch_light_texture:
		vision.texture = torch_light_texture if value >= 0.5 else _base_light_texture


func _place_torch() -> void:
	var key := facing
	if facing == "side":
		key = "right" if sprite.flip_h else "left"
	torch.position = GRIP[key]
