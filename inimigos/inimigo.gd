extends CharacterBody2D
## Ponto de encaixe para o combate (ainda não existe no projeto).
## Colocado na raiz de cada monstro posicionado nos andares:
## - entra no grupo "inimigos" (as salas-arena contam quem está dentro delas);
## - toca uma animação parada para o monstro não ficar congelado;
## - guarda dados do GDD (tipo, reação à tocha) para quem fizer a IA/combate.
## Quem implementar o combate chama morrer() quando a vida chegar a zero.

signal morreu(inimigo: Node)

enum ReacaoTocha { NENHUMA, FOGE, ATRAIDO, AGRESSIVO, REVELADO }

## Nome do monstro no GDD (seção 6), ex.: "Aranha grande", "Fantasma".
@export var tipo := ""
@export var reacao_a_tocha := ReacaoTocha.NENHUMA
## Animação que fica tocando. Vazio = "idle" (ou a primeira que existir).
@export var animacao := ""
## Flutua para cima e para baixo (fantasmas e o feiticeiro).
@export var flutuar := false
## Distância (px, antes da escala do nó) do centro do sprite até os pés.
## Usada para pôr a origem nos pés (ordem de desenho) e posicionar a colisão.
@export var altura_pes := 0.0
## Largura da colisão no chão (px). 0 = sem colisão (fantasmas atravessam).
@export var largura_corpo := 0.0

var _t := randf() * TAU
var _base_y := 0.0
@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	add_to_group("inimigos")
	if _sprite == null:
		return
	# origem nos pés: o sprite sobe e o nó desce a mesma distância
	_sprite.position.y -= altura_pes
	position.y += altura_pes * scale.y
	_base_y = _sprite.position.y
	if largura_corpo > 0.0 and collision_layer != 0:
		var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
		if cs and cs.shape == null:
			var r := RectangleShape2D.new()
			r.size = Vector2(largura_corpo, 6)
			cs.shape = r
			cs.position = Vector2(0, -3)
	if _sprite.sprite_frames == null:
		return
	var nomes := _sprite.sprite_frames.get_animation_names()
	var anim := animacao
	if anim == "" or not _sprite.sprite_frames.has_animation(anim):
		anim = "idle" if _sprite.sprite_frames.has_animation("idle") else (nomes[0] if nomes.size() > 0 else "")
	if anim != "":
		_sprite.sprite_frames.set_animation_loop(anim, true)
		_sprite.play(anim)
		_sprite.frame = randi() % max(1, _sprite.sprite_frames.get_frame_count(anim))


func _process(delta: float) -> void:
	if flutuar and _sprite:
		_t += delta * 2.2
		_sprite.position.y = _base_y + sin(_t) * 2.0


func morrer() -> void:
	morreu.emit(self)
	queue_free()
