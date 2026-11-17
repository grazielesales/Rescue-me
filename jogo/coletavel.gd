class_name Coletavel
extends Area2D
## Material caído no chão (drop de monstro ou caixa quebrada).
## O Pai pega só de passar por cima (GDD 4.1).
## Fica guardado no Jogo (Jogo.drops) até ser pego: se o Pai morrer ou trocar
## de andar, o andar.gd recria o material no mesmo lugar.

var item := ""
var qtd := 1
## id do drop em Jogo.drops.
var id := ""
## Recriado ao voltar para o andar: aparece já no chão, sem o pulinho.
var no_chao := false

var _t := randf() * TAU
var _sprite: Sprite2D
var _pode_pegar := false


## Cria um coletável em `pos` (global), dentro de `pai_no`.
static func soltar(pai_no: Node, pos: Vector2, mat: String, quantos: int) -> void:
	if quantos <= 0 or pai_no == null:
		return
	var c := Coletavel.new()
	c.item = mat
	c.qtd = quantos
	pai_no.add_child(c)
	c.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-3, 5))
	c.id = Jogo.registrar_drop(mat, quantos, c.global_position)


## Recria um drop guardado em Jogo.drops (ao voltar para o andar).
static func recriar(pai_no: Node, id_drop: String, dados: Dictionary) -> void:
	var c := Coletavel.new()
	c.item = dados.item
	c.qtd = dados.qtd
	c.id = id_drop
	c.no_chao = true
	pai_no.add_child(c)
	c.global_position = dados.pos


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	cs.shape = shape
	cs.position = Vector2(0, -4)
	add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = Itens.icone(item)
	_sprite.modulate = Itens.cor_icone(item)
	if _sprite.texture:
		var lado := maxf(_sprite.texture.get_width(), _sprite.texture.get_height())
		_sprite.scale = Vector2.ONE * minf(1.0, 12.0 / lado)
	_sprite.offset = Vector2(0, -8 / maxf(_sprite.scale.y, 0.01))
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	if no_chao:
		_pode_pegar = true
		_checar.call_deferred()
		return
	# pulinho ao cair
	_sprite.position.y = -10
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _pode_pegar = true; _checar())


func _process(delta: float) -> void:
	if not _pode_pegar:
		return
	_t += delta * 3.0
	_sprite.position.y = sin(_t) * 1.5


func _checar() -> void:
	for b in get_overlapping_bodies():
		_on_body_entered(b)


func _on_body_entered(body: Node) -> void:
	if not _pode_pegar or not body.is_in_group("player") or body.get("morto"):
		return
	_pode_pegar = false
	Jogo.remover_drop(id)
	Jogo.adicionar(item, qtd)
	Jogo.mostrar_mensagem("+%d %s" % [qtd, Itens.nome_material(item)], 1.2)
	queue_free()
