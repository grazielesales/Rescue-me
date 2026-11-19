@tool
extends StaticBody2D
## Grade de ferro no alto de uma escada (ex.: a escada do fosso da Sala Sudeste).
## Funciona como uma porta para a sala.gd: ponha o caminho dela em `portas`.
## - Arena: começa aberta; `bloquear()` desce a grade (o Pai fica preso no
##   fosso) e `liberar()` sobe de novo quando a arena é vencida.
## - Com `flag_necessaria`: fica fechada até o Jogo ter a flag e abre quando
##   o Pai chega perto (ex.: precisa de uma chave).
## A posição do nó é o meio da base da grade. `largura` = largura da escada.

@export var flag_necessaria := ""
@export var largura := 16:
	set(v):
		largura = v
		queue_redraw()
@export var altura := 10:
	set(v):
		altura = v
		queue_redraw()
@export var mensagem_trancada := "Uma grade tranca a escada. Precisa de uma chave."

const COR_BARRA := Color(0.32, 0.31, 0.36)
const COR_BRILHO := Color(0.55, 0.54, 0.6)
const COR_SOMBRA := Color(0.12, 0.11, 0.14)

## Lido pela sala.gd (como no porta.gd): trancada por falta da flag.
var trancado: bool:
	get:
		return flag_necessaria != "" and not Jogo.get_flag(flag_necessaria, false)
var _forma: CollisionShape2D
var _fechada := false
var _bloqueada := false
var _desce := 0.0  # 0 = grade em cima (aberta), 1 = no chão (fechada)


func _ready() -> void:
	if Engine.is_editor_hint():
		_desce = 1.0
		return
	_forma = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(largura, 6)
	_forma.shape = r
	_forma.position = Vector2(0, -3)
	add_child(_forma)
	var area := Area2D.new()
	area.name = "Area2D"
	area.collision_layer = 0
	area.monitorable = false
	var ca := CollisionShape2D.new()
	var c := RectangleShape2D.new()
	c.size = Vector2(largura + 8, 24)
	ca.shape = c
	ca.position = Vector2(0, 2)
	area.add_child(ca)
	add_child(area)
	area.body_entered.connect(_on_entrou)
	_mudar(trancado, true)


func _on_entrou(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if trancado:
		Jogo.mostrar_mensagem(mensagem_trancada, 2.5)
	elif _fechada and not _bloqueada:
		_mudar(false)


## Arena: fecha a grade.
func bloquear() -> void:
	_bloqueada = true
	_mudar(true)


## Arena vencida: abre a grade.
func liberar() -> void:
	_bloqueada = false
	if not trancado:
		_mudar(false)


func _mudar(fechar: bool, imediato := false) -> void:
	_fechada = fechar
	_forma.set_deferred("disabled", not fechar)
	var alvo := 1.0 if fechar else 0.0
	if imediato:
		_desce = alvo
		queue_redraw()
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_desce = v
		queue_redraw(), _desce, alvo, 0.35)


func _draw() -> void:
	if _desce <= 0.01:
		return
	var h := roundi(altura * _desce)
	var x0 := -largura / 2
	draw_rect(Rect2(x0, -h, largura, 2), COR_SOMBRA)
	draw_rect(Rect2(x0, -h, largura, 1), COR_BARRA)
	draw_rect(Rect2(x0, -2, largura, 2), COR_SOMBRA)
	draw_rect(Rect2(x0, -2, largura, 1), COR_BARRA)
	var x := x0 + 1
	while x < x0 + largura:
		draw_rect(Rect2(x, -h, 2, h), COR_SOMBRA)
		draw_rect(Rect2(x, -h, 1, h), COR_BARRA)
		draw_rect(Rect2(x, -h + 1, 1, mini(2, h)), COR_BRILHO)
		x += 4
