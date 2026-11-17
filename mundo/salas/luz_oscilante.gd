extends PointLight2D
## Luz que oscila de leve em volta da energia definida no editor
## (ex.: o brilho azulado dos monitores da Sala de Comando).

## Quanto a energia varia para cima e para baixo (0.1 = ±10%).
@export_range(0.0, 0.5) var variacao := 0.1
## Velocidade da oscilação.
@export var velocidade := 1.5

var _base := 0.0
var _t := randf() * 100.0
var _ruido := FastNoiseLite.new()


func _ready() -> void:
	_base = energy
	_ruido.frequency = 1.0


func _process(delta: float) -> void:
	_t += delta * velocidade
	# respiração lenta + um tremidinho de tela
	var onda := sin(_t) * 0.6 + _ruido.get_noise_1d(_t * 3.0) * 0.4
	energy = _base * (1.0 + variacao * onda)
