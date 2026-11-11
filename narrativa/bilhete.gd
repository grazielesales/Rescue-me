extends Sprite2D
## Bilhete, desenho ou marca na parede (GDD 2.4, narrativa ambiental).
## Perto dele aparece "E: ler"; apertar E mostra o texto. Afastar fecha.

@export_multiline var texto := ""
@export var raio := 22.0

var _perto := false
var _lendo := false


func _ready() -> void:
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
	area.body_exited.connect(_on_saiu)


func _on_entrou(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = true
		Jogo.mostrar_dica("E: ler")


func _on_saiu(body: Node) -> void:
	if body.is_in_group("player"):
		_perto = false
		_lendo = false
		Jogo.esconder_dica()
		Jogo.esconder_texto()


func _process(_delta: float) -> void:
	if _perto and Input.is_action_just_pressed("interagir"):
		_lendo = not _lendo
		if _lendo:
			Jogo.esconder_dica()
			Jogo.mostrar_texto(texto)
		else:
			Jogo.esconder_texto()
			Jogo.mostrar_dica("E: ler")
