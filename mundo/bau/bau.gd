extends Sprite2D
## Baú que abre com E (mesmo padrão do alavanca.gd). Perto dele aparece
## "E: abrir baú"; apertar E troca o desenho para o baú aberto, mostra o item
## subindo, marca as flags no Jogo e salva na hora.
## Usa uma região da textura (region_enabled) para cada estado.
## Ex.: o baú da tumba (SalaSul) dá a chave do Nordeste e acorda os esqueletos.

## Região da textura com o baú fechado e com o baú aberto.
@export var regiao_fechado := Rect2(151, 20, 19, 18)
@export var regiao_aberto := Rect2(179, 52, 29, 20)
@export var raio := 20.0
## Flag marcada ao abrir; com ela no save, o baú já aparece aberto.
@export var flag_aberto := "tumba_aberta"
## Flag do item que o baú dá (ex.: "chave_nordeste"). Vazio = nenhum.
@export var flag_recompensa := "chave_nordeste"
@export var mensagem := "Você encontrou uma chave enferrujada."
## Desenho do item que sobe do baú ao abrir (opcional).
@export var textura_recompensa: Texture2D
@export var regiao_recompensa := Rect2(274, 64, 12, 8)

var _perto := false
var _aberto := false


func _ready() -> void:
	region_enabled = true
	var area := Area2D.new()
	area.collision_layer = 0
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = raio
	cs.shape = shape
	cs.position = Vector2(0, -6)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_entrou)
	area.body_exited.connect(_on_saiu)
	_mostrar(flag_aberto != "" and Jogo.get_flag(flag_aberto, false))


## Troca o desenho mantendo a base do baú no mesmo lugar (origem nos pés).
func _mostrar(aberto: bool) -> void:
	_aberto = aberto
	region_rect = regiao_aberto if aberto else regiao_fechado
	offset = Vector2(0, -region_rect.size.y / 2.0 + 1.0)


func _on_entrou(body: Node) -> void:
	if body.is_in_group("player") and not _aberto:
		_perto = true
		Jogo.mostrar_dica("E: abrir baú")


func _on_saiu(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = false
		Jogo.esconder_dica()


func _process(_delta: float) -> void:
	if _perto and not _aberto and Input.is_action_just_pressed("interagir"):
		abrir()


func abrir() -> void:
	if _aberto:
		return
	_perto = false
	Jogo.esconder_dica()
	_mostrar(true)
	if flag_aberto != "":
		Jogo.set_flag(flag_aberto, true)
	if flag_recompensa != "":
		Jogo.set_flag(flag_recompensa, true)
	Jogo.salvar_progresso()
	if mensagem != "":
		Jogo.mostrar_mensagem(mensagem, 3.0)
	_item_subindo()


## O item sobe de dentro do baú e some.
func _item_subindo() -> void:
	if textura_recompensa == null:
		return
	var s := Sprite2D.new()
	s.texture = textura_recompensa
	s.region_enabled = true
	s.region_rect = regiao_recompensa
	s.position = Vector2(0, -region_rect.size.y * 0.6)
	s.z_index = 5
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y - 14.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.tween_callback(s.queue_free)
