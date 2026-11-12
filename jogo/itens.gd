class_name Itens
extends RefCounted
## Tabelas do jogo (GDD seções 4 e 6): materiais, armas, receitas e monstros.
## Os números são uma primeira proposta, para ajustar nos testes de balanceamento.

const VIDA_PAI := 10
## Quanto um curativo recupera.
const CURA := 4

const _MED := "res://Medieval Free Pack ( Dev Essentials ).png"
const _OBJ := "res://tile/Tiled_files/Objects.png"
const _DP := "res://Dungeons and Pixels #U2014 Free Demo/"
## Folhas de ícones 16x16 (4 colunas x 8 linhas) usadas para a arma na mão do Pai.
const _GUERREIRO := "res://warrior-items__asset.png"
const _MAGO := "res://xevin-wizard-items__asset.png"
const TAM_ICONE := 16

## Materiais (GDD 4.1). "cor" tinge o ícone.
const MATERIAIS := {
	"osso": {"nome": "Osso", "tex": _DP + "Props/Static/bones1.png", "regiao": Rect2(2, 4, 15, 11)},
	"teia": {"nome": "Teia resistente", "tex": _MED, "regiao": Rect2(84, 64, 30, 27)},
	"presa": {"nome": "Presa venenosa", "tex": _MED, "regiao": Rect2(515, 48, 9, 16), "cor": Color(0.6, 1.0, 0.5)},
	"ectoplasma": {"nome": "Ectoplasma", "tex": _DP + "Items/mana_potion.png", "regiao": Rect2(6, 5, 19, 23), "cor": Color(0.6, 1.0, 0.7)},
	"po_magico": {"nome": "Pó mágico", "tex": _DP + "Items/mana_potion.png", "regiao": Rect2(6, 5, 19, 23)},
	"fragmento": {"nome": "Fragmento sombrio", "tex": _MED, "regiao": Rect2(530, 69, 10, 9), "cor": Color(0.55, 0.35, 0.85)},
	"madeira": {"nome": "Madeira", "tex": _OBJ, "regiao": Rect2(81, 82, 15, 20)},
	"sucata": {"nome": "Sucata", "tex": _MED, "regiao": Rect2(530, 69, 10, 9)},
	"curativo": {"nome": "Curativo", "tex": _DP + "Items/health_potion.png", "regiao": Rect2(6, 5, 19, 23)},
}

## Armas (GDD 4.3). alcance em px; angulo = metade da abertura do golpe, em graus.
## sprite = [folha, coluna, linha] do ícone que o Pai segura; sprite_cor tinge o ícone.
## Os ícones são desenhados na diagonal: cabo embaixo à esquerda, ponta em cima à direita.
const ARMAS := {
	"cano": {"nome": "Cano de ferro", "curto": "Cano", "dano": 2, "alcance": 20.0, "recarga": 0.38, "angulo": 70.0, "cor": Color(0.78, 0.8, 0.88), "sprite": [_MAGO, 1, 0], "sprite_cor": Color(0.85, 0.85, 0.9)},
	"clava": {"nome": "Clava de osso", "curto": "Clava", "dano": 4, "alcance": 20.0, "recarga": 0.75, "angulo": 80.0, "cor": Color(0.95, 0.9, 0.75), "sprite": [_GUERREIRO, 3, 0], "sprite_cor": Color(1.0, 0.95, 0.8)},
	"lanca": {"nome": "Lança de teia", "curto": "Lança", "dano": 3, "alcance": 34.0, "recarga": 0.5, "angulo": 28.0, "cor": Color(0.88, 0.88, 1.0), "sprite": [_MAGO, 1, 1]},
	"adaga": {"nome": "Adaga venenosa", "curto": "Adaga", "dano": 2, "alcance": 16.0, "recarga": 0.25, "angulo": 60.0, "veneno": 3.0, "cor": Color(0.5, 1.0, 0.4), "sprite": [_GUERREIRO, 0, 0], "sprite_cor": Color(0.75, 1.0, 0.65)},
	"espada": {"nome": "Espada espectral", "curto": "Espada", "dano": 4, "alcance": 24.0, "recarga": 0.4, "angulo": 75.0, "bonus": {"Fantasma": 3, "Feiticeiro espectral": 3}, "cor": Color(0.6, 0.9, 1.0), "sprite": [_GUERREIRO, 1, 0], "sprite_cor": Color(0.7, 0.95, 1.0)},
	"machado": {"nome": "Machado sombrio", "curto": "Machado", "dano": 6, "alcance": 24.0, "recarga": 0.8, "angulo": 160.0, "cor": Color(0.65, 0.4, 0.95), "sprite": [_GUERREIRO, 2, 0], "sprite_cor": Color(0.8, 0.65, 1.0)},
	"lamina": {"nome": "Lâmina de luz", "curto": "Lâmina", "dano": 6, "alcance": 28.0, "recarga": 0.35, "angulo": 80.0, "bonus": {"Boss": 4}, "cor": Color(1.0, 0.95, 0.6), "sprite": [_MAGO, 2, 1]},
}

## Receitas (GDD 4.3). "inicial" = já vem no livro; as outras aparecem ao achar
## a página (bilhete com `receita`) ou ao derrotar certo monstro pela 1ª vez.
const RECEITAS := [
	{"id": "clava", "tipo": "arma", "custo": {"osso": 3, "madeira": 2}, "inicial": true, "efeito": "Dano médio, ataque lento."},
	{"id": "lanca", "tipo": "arma", "custo": {"teia": 4, "madeira": 2, "sucata": 1}, "inicial": true, "efeito": "Alcance longo."},
	{"id": "curativo", "tipo": "curativo", "nome": "Curativo", "custo": {"teia": 2, "madeira": 1}, "inicial": true, "efeito": "Recupera %d de vida (tecla Q)." % CURA},
	{"id": "adaga", "tipo": "arma", "custo": {"presa": 2, "osso": 1}, "efeito": "Causa veneno por alguns segundos."},
	{"id": "tocha", "tipo": "melhoria", "nome": "Luz reforçada", "custo": {"po_magico": 1, "madeira": 2}, "efeito": "Aumenta o raio da luz que acompanha o Pai."},
	{"id": "espada", "tipo": "arma", "custo": {"ectoplasma": 4, "osso": 2, "sucata": 2}, "efeito": "Dano extra contra fantasmas."},
	{"id": "machado", "tipo": "arma", "custo": {"fragmento": 3, "osso": 2, "sucata": 2}, "efeito": "Dano alto, ataque em área."},
	{"id": "lamina", "tipo": "arma", "custo": {"po_magico": 3, "fragmento": 2, "ectoplasma": 1}, "efeito": "Melhor arma do jogo, eficaz contra o boss."},
]

## Monstros (GDD 6). drops = [material, mín, máx, chance].
## distancia/projetil: monstros que atacam de longe (criatura mágica, feiticeiro).
## receita: aparece no livro ao derrotar esse monstro pela primeira vez.
const INIMIGOS := {
	"Aranha pequena": {"vida": 2, "dano": 1, "velocidade": 55.0, "alcance": 14.0, "recarga": 0.9, "drops": [["teia", 1, 1, 1.0]]},
	"Aranha grande": {"vida": 8, "dano": 2, "velocidade": 40.0, "alcance": 20.0, "recarga": 1.2, "drops": [["teia", 1, 2, 1.0], ["presa", 1, 1, 0.75]]},
	"Aranha-mãe": {"vida": 16, "dano": 2, "velocidade": 38.0, "alcance": 22.0, "recarga": 1.1, "drops": [["presa", 2, 2, 1.0], ["teia", 2, 3, 1.0]], "receita": "adaga"},
	"Esqueleto": {"vida": 6, "dano": 2, "velocidade": 28.0, "alcance": 16.0, "recarga": 1.3, "drops": [["osso", 1, 2, 1.0]]},
	"Zumbi": {"vida": 8, "dano": 2, "velocidade": 22.0, "alcance": 16.0, "recarga": 1.4, "drops": [["osso", 1, 1, 0.8], ["sucata", 1, 1, 0.5]]},
	"Fantasma": {"vida": 4, "dano": 1, "velocidade": 35.0, "alcance": 14.0, "recarga": 1.0, "drops": [["ectoplasma", 1, 1, 1.0]]},
	"Criatura mágica": {"vida": 5, "dano": 1, "velocidade": 35.0, "alcance": 110.0, "distancia": 70.0, "recarga": 1.8, "projetil": true, "drops": [["po_magico", 1, 1, 1.0]], "receita": "tocha"},
	"Demônio": {"vida": 10, "dano": 2, "velocidade": 45.0, "alcance": 18.0, "recarga": 1.1, "drops": [["fragmento", 1, 1, 0.7], ["osso", 1, 1, 0.4]]},
	"Feiticeiro espectral": {"vida": 20, "dano": 2, "velocidade": 30.0, "alcance": 130.0, "distancia": 80.0, "recarga": 1.3, "projetil": true, "drops": [["po_magico", 2, 2, 1.0], ["ectoplasma", 2, 2, 1.0]], "receita": "espada"},
}
const INIMIGO_PADRAO := {"vida": 4, "dano": 1, "velocidade": 30.0, "alcance": 16.0, "recarga": 1.2, "drops": []}

## Caixas, barris e móveis quebrados (GDD 4.1).
const CAIXA_DROPS := [["madeira", 1, 2, 1.0], ["sucata", 1, 1, 0.4]]

static var _icones := {}


static func icone(id: String) -> Texture2D:
	if _icones.has(id):
		return _icones[id]
	var d: Dictionary = MATERIAIS.get(id, {})
	if d.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = load(d.tex)
	at.region = d.regiao
	_icones[id] = at
	return at


static var _sprites_armas := {}


## Textura da arma na mão do Pai (recorte 16x16 da folha de ícones).
static func sprite_arma(id: String) -> Texture2D:
	if _sprites_armas.has(id):
		return _sprites_armas[id]
	var s: Array = ARMAS.get(id, {}).get("sprite", [])
	if s.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = load(s[0])
	at.region = Rect2(s[1] * TAM_ICONE, s[2] * TAM_ICONE, TAM_ICONE, TAM_ICONE)
	_sprites_armas[id] = at
	return at


static func cor_icone(id: String) -> Color:
	return MATERIAIS.get(id, {}).get("cor", Color.WHITE)


static func nome_material(id: String) -> String:
	return MATERIAIS.get(id, {}).get("nome", id)


static func dados_inimigo(tipo: String) -> Dictionary:
	return INIMIGOS.get(tipo, INIMIGO_PADRAO)


static func receita(id: String) -> Dictionary:
	for r in RECEITAS:
		if r.id == id:
			return r
	return {}


static func nome_receita(r: Dictionary) -> String:
	if r.has("nome"):
		return r.nome
	return ARMAS.get(r.id, {}).get("nome", r.id)
