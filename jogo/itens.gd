class_name Itens
extends RefCounted
## Tabelas do jogo (GDD seções 4 e 6): materiais, armas, receitas e monstros.
## Os números são uma primeira proposta, para ajustar nos testes de balanceamento.

const VIDA_PAI := 10
## Quanto um curativo recupera.
const CURA := 4
## Segundos que o monstro fica atordoado com a melhoria "Arma eletrificada".
const TEMPO_CHOQUE := 0.6

const _MED := "res://assets/Medieval Free Pack/Medieval Free Pack ( Dev Essentials ).png"
const _OBJ := "res://assets/tile/Tiled_files/Objects.png"
const _DP := "res://assets/Dungeons and Pixels #U2014 Free Demo/"
## Folhas de ícones 16x16 (4 colunas x 8 linhas) usadas para a arma na mão do Pai.
const _GUERREIRO := "res://assets/itens-armas/warrior-items__asset.png"
const _MAGO := "res://assets/itens-armas/xevin-wizard-items__asset.png"
const TAM_ICONE := 16
## Cajados (32x32, um por arquivo, na diagonal como os ícones das armas).
const _STAFFS := "res://assets/staffs/"
## Arma usada quando os três atalhos estão vazios: o Pai luta com as mãos.
const SEM_ARMA := "socos"

## Materiais (GDD 4.1). "cor" tinge o ícone.
const MATERIAIS := {
	"osso": {"nome": "Osso", "tex": _DP + "Props/Static/bones1.png", "regiao": Rect2(2, 4, 15, 11)},
	"teia": {"nome": "Teia resistente", "tex": "res://jogo/icones/teia.png", "regiao": Rect2(0, 0, 23, 23)},
	"presa": {"nome": "Presa venenosa", "tex": _MED, "regiao": Rect2(515, 48, 9, 16), "cor": Color(0.6, 1.0, 0.5)},
	"ectoplasma": {"nome": "Ectoplasma", "tex": _DP + "Items/mana_potion.png", "regiao": Rect2(6, 5, 19, 23), "cor": Color(0.6, 1.0, 0.7)},
	"po_magico": {"nome": "Pó mágico", "tex": _DP + "Items/mana_potion.png", "regiao": Rect2(6, 5, 19, 23)},
	"fragmento": {"nome": "Fragmento sombrio", "tex": _MED, "regiao": Rect2(530, 69, 10, 9), "cor": Color(0.55, 0.35, 0.85)},
	"madeira": {"nome": "Madeira", "tex": _OBJ, "regiao": Rect2(81, 82, 15, 20)},
	"sucata": {"nome": "Sucata", "tex": _MED, "regiao": Rect2(530, 69, 10, 9)},
	"curativo": {"nome": "Curativo", "tex": _DP + "Items/health_potion.png", "regiao": Rect2(6, 5, 19, 23)},
	# cura na hora, ao passar por cima (ver CURAS)
	"maca": {"nome": "Maçã", "tex": _GUERREIRO, "regiao": Rect2(0, 48, 16, 16)},
	"pocao_vida": {"nome": "Poção de vida", "tex": _GUERREIRO, "regiao": Rect2(16, 64, 16, 16)},
}

## Itens que curam o Pai na hora em que ele pega (não vão para o inventário): vida por unidade.
const CURAS := {"maca": 1, "pocao_vida": 3}

## Armas (GDD 4.3). alcance em px; angulo = metade da abertura do golpe, em graus.
## sprite = [folha, coluna, linha] do ícone 16x16 que o Pai segura, ou o caminho
## de um PNG inteiro (ex.: 32x32); sprite_cor tinge o ícone; sprite_cabo = ponto
## do cabo no PNG inteiro (padrão: o equivalente a (3, 13) num ícone 16x16).
## Os ícones são desenhados na diagonal: cabo embaixo à esquerda, ponta em cima à direita.
## "socos" não tem sprite: é o que o Pai usa sem arma (quebra caixas e barris).
const ARMAS := {
	"socos": {"nome": "Socos", "curto": "Socos", "dano": 1, "alcance": 12.0, "recarga": 0.32, "angulo": 50.0, "cor": Color(1.0, 0.9, 0.8)},
	"porrete": {"nome": "Porrete de madeira", "curto": "Porrete", "dano": 3, "alcance": 20.0, "recarga": 0.5, "angulo": 70.0, "bonus": {"Aranha pequena": 2}, "cor": Color(0.85, 0.7, 0.5), "sprite": _STAFFS + "7.png", "sprite_cabo": Vector2(6, 26)},
	"cajado_fogo": {"nome": "Cajado de fogo", "curto": "Cajado", "dano": 3, "alcance": 22.0, "recarga": 0.5, "angulo": 70.0, "bonus": {"Frankie": 4}, "cor": Color(1.0, 0.6, 0.3), "sprite": _STAFFS + "6.png", "sprite_cabo": Vector2(6, 26)},
	"clava": {"nome": "Clava de osso", "curto": "Clava", "dano": 4, "alcance": 20.0, "recarga": 0.75, "angulo": 80.0, "bonus": {"Esqueleto": 3}, "cor": Color(0.95, 0.9, 0.75), "sprite": [_GUERREIRO, 3, 0], "sprite_cor": Color(1.0, 0.95, 0.8)},
	"lanca": {"nome": "Lança de teia", "curto": "Lança", "dano": 3, "alcance": 34.0, "recarga": 0.5, "angulo": 28.0, "bonus": {"Bruxa": 3}, "cor": Color(0.88, 0.88, 1.0), "sprite": [_MAGO, 1, 1]},
	"adaga": {"nome": "Adaga venenosa", "curto": "Adaga", "dano": 2, "alcance": 16.0, "recarga": 0.25, "angulo": 60.0, "veneno": 3.0, "cor": Color(0.5, 1.0, 0.4), "sprite": [_GUERREIRO, 0, 0], "sprite_cor": Color(0.75, 1.0, 0.65)},
	"espada": {"nome": "Espada espectral", "curto": "Espada", "dano": 4, "alcance": 24.0, "recarga": 0.4, "angulo": 75.0, "bonus": {"Fantasma": 3, "Feiticeiro espectral": 3}, "cor": Color(0.6, 0.9, 1.0), "sprite": [_GUERREIRO, 1, 0], "sprite_cor": Color(0.7, 0.95, 1.0)},
	"machado": {"nome": "Machado sombrio", "curto": "Machado", "dano": 6, "alcance": 24.0, "recarga": 0.8, "angulo": 160.0, "cor": Color(0.65, 0.4, 0.95), "sprite": [_GUERREIRO, 2, 0], "sprite_cor": Color(0.8, 0.65, 1.0)},
	"lamina": {"nome": "Lâmina de luz", "curto": "Lâmina", "dano": 6, "alcance": 28.0, "recarga": 0.35, "angulo": 80.0, "bonus": {"Boss": 4}, "cor": Color(1.0, 0.95, 0.6), "sprite": [_MAGO, 2, 1]},
}

## Receitas (GDD 4.3). "inicial" = já vem no livro; as outras aparecem ao achar
## a página (bilhete com `receita`, ex.: o curativo, no bilhete da Sala1) ou ao derrotar certo monstro pela 1ª vez.
const RECEITAS := [
	{"id": "porrete", "tipo": "arma", "custo": {"madeira": 3}, "inicial": true, "efeito": "Primeira arma de verdade. Forte contra aranhas."},
	{"id": "clava", "tipo": "arma", "custo": {"osso": 3, "madeira": 2}, "inicial": true, "efeito": "Ataque lento que esmaga ossos: forte contra esqueletos."},
	{"id": "cajado_fogo", "tipo": "arma", "custo": {"po_magico": 2, "madeira": 2}, "efeito": "Queima: forte contra o Frankie."},
	{"id": "lanca", "tipo": "arma", "custo": {"teia": 3, "madeira": 2, "sucata": 1}, "inicial": true, "efeito": "Alcance longo. Forte contra a Bruxa."},
	{"id": "curativo", "tipo": "curativo", "nome": "Curativo", "custo": {"teia": 2, "madeira": 1}, "efeito": "Recupera %d de vida (tecla Q)." % CURA},
	{"id": "adaga", "tipo": "arma", "custo": {"presa": 2, "osso": 1}, "efeito": "Causa veneno por alguns segundos."},
	{"id": "tocha", "tipo": "melhoria", "nome": "Luz reforçada", "custo": {"po_magico": 1, "madeira": 2}, "efeito": "Aumenta o raio da luz que acompanha o Pai."},
	{"id": "choque", "tipo": "melhoria", "nome": "Arma eletrificada", "custo": {"sucata": 3}, "efeito": "Qualquer arma dá choque: o monstro atingido fica atordoado por um instante."},
	{"id": "espada", "tipo": "arma", "custo": {"ectoplasma": 4, "osso": 2, "sucata": 2}, "efeito": "Dano extra contra fantasmas."},
	{"id": "machado", "tipo": "arma", "custo": {"fragmento": 3, "osso": 2, "sucata": 2}, "efeito": "Dano alto, ataque em área."},
	{"id": "lamina", "tipo": "arma", "custo": {"po_magico": 3, "fragmento": 2, "ectoplasma": 1}, "efeito": "Melhor arma do jogo, eficaz contra o boss."},
]

## Monstros (GDD 6). drops = [material, mín, máx, chance].
## distancia/projetil: monstros que atacam de longe (criatura mágica, feiticeiro).
## receita: aparece no livro ao derrotar esse monstro pela primeira vez.
## Campos opcionais (inimigo.gd):
## - velocidade_projetil (px/s, padrão 110) e cor_projetil;
## - escala: tamanho do monstro (1 = normal);
## - fixo: não vaga, não persegue nem é empurrado (ex.: olho preso na parede);
## - distancia_fechar, tempo_fechado, tempo_aberto: fixo que fecha quando o Pai
##   chega a distancia_fechar px. Fechado fica invulnerável e não atira por
##   tempo_fechado s; depois fica aberto (vulnerável) pelo menos tempo_aberto s;
## - apagar_luz: segundos que o projétil apaga a luz do Pai ao acertar;
## - energia: flags (alavancas) que precisam estar marcadas para o monstro levar
##   dano; antes disso ele fica carregado (golpe só faz "tink" azul);
## - furia_vida (fração da vida), furia_velocidade, furia_recarga (multiplicadores):
##   abaixo de furia_vida o monstro fica mais rápido e deixa rastro de fogo;
## - rastro_intervalo (s entre chamas), rastro_duracao (s), rastro_dano.
const INIMIGOS := {
	"Aranha pequena": {"vida": 9, "dano": 1, "velocidade": 55.0, "alcance": 14.0, "recarga": 0.9, "drops": [["teia", 1, 1, 1.0], ["maca", 1, 1, 0.3]]},
	"Aranha grande": {"vida": 8, "dano": 2, "velocidade": 40.0, "alcance": 20.0, "recarga": 1.2, "drops": [["teia", 1, 2, 1.0], ["presa", 1, 1, 0.75]]},
	"Aranha-mãe": {"vida": 16, "dano": 2, "velocidade": 38.0, "alcance": 22.0, "recarga": 1.1, "drops": [["presa", 2, 2, 1.0], ["teia", 2, 3, 1.0]], "receita": "adaga"},
	"Esqueleto": {"vida": 12, "dano": 2, "velocidade": 44.0, "alcance": 16.0, "recarga": 1.3, "drops": [["osso", 1, 2, 1.0], ["pocao_vida", 1, 1, 0.34]]},
	"Zumbi": {"vida": 8, "dano": 2, "velocidade": 22.0, "alcance": 16.0, "recarga": 1.4, "drops": [["osso", 1, 1, 0.8], ["sucata", 1, 1, 0.5]]},
	# 1º andar
	"Olho maligno vermelho": {"vida": 3, "dano": 1, "velocidade": 0.0, "alcance": 110.0, "recarga": 2.2, "projetil": true, "velocidade_projetil": 45.0, "cor_projetil": Color(1.0, 0.35, 0.3), "fixo": true, "distancia_fechar": 28.0, "tempo_fechado": 2.5, "tempo_aberto": 1.5, "drops": [["po_magico", 1, 1, 1.0]]},
	"Olho maligno azul": {"vida": 4, "dano": 1, "velocidade": 38.0, "alcance": 16.0, "recarga": 1.0, "drops": [["teia", 1, 1, 0.7]]},
	# Sala Nordeste: a bruxa no lugar dos 3 olhos (solta o mesmo pó mágico que eles somados)
	"Bruxa": {"vida": 12, "dano": 1, "velocidade": 30.0, "alcance": 120.0, "distancia": 64.0, "recarga": 1.6, "projetil": true, "velocidade_projetil": 75.0, "cor_projetil": Color(0.55, 1.0, 0.35), "drops": [["po_magico", 3, 3, 1.0], ["pocao_vida", 1, 1, 1.0]], "receita": "cajado_fogo"},
	# mini-chefe da arena Sudeste
	"Chama sombria": {"vida": 18, "dano": 2, "velocidade": 28.0, "alcance": 110.0, "distancia": 60.0, "recarga": 1.8, "projetil": true, "velocidade_projetil": 90.0, "escala": 1.5, "apagar_luz": 3.0, "furia_vida": 0.5, "furia_velocidade": 1.6, "furia_recarga": 0.75, "rastro_intervalo": 0.3, "rastro_duracao": 3.0, "rastro_dano": 1, "drops": [["fragmento", 1, 1, 1.0]]},
	# mini-chefe do laboratório da Sala Sudeste (substituiu a Chama sombria): bate de perto; abaixo da metade fica furioso (sem rastro de fogo)
	"Frankie": {"vida": 22, "dano": 2, "velocidade": 26.0, "alcance": 18.0, "recarga": 1.3, "furia_vida": 0.5, "furia_velocidade": 1.7, "furia_recarga": 0.7, "drops": [["fragmento", 1, 1, 1.0], ["sucata", 2, 2, 1.0], ["pocao_vida", 1, 1, 1.0]], "receita": "choque", "energia": ["energia_lab_1", "energia_lab_2"]},
	"Fantasma": {"vida": 4, "dano": 1, "velocidade": 35.0, "alcance": 14.0, "recarga": 1.0, "drops": [["ectoplasma", 1, 1, 1.0]]},
	"Criatura mágica": {"vida": 5, "dano": 1, "velocidade": 35.0, "alcance": 110.0, "distancia": 70.0, "recarga": 1.8, "projetil": true, "drops": [["po_magico", 1, 1, 1.0]], "receita": "tocha"},
	"Demônio": {"vida": 10, "dano": 2, "velocidade": 45.0, "alcance": 18.0, "recarga": 1.1, "drops": [["fragmento", 1, 1, 0.7], ["osso", 1, 1, 0.4]]},
	"Feiticeiro espectral": {"vida": 20, "dano": 2, "velocidade": 30.0, "alcance": 130.0, "distancia": 80.0, "recarga": 1.3, "projetil": true, "drops": [["po_magico", 2, 2, 1.0], ["ectoplasma", 2, 2, 1.0]], "receita": "espada"},
}
const INIMIGO_PADRAO := {"vida": 4, "dano": 1, "velocidade": 30.0, "alcance": 16.0, "recarga": 1.2, "drops": []}

## Caixas, barris e móveis quebrados (GDD 4.1).
const CAIXA_DROPS := [["madeira", 1, 2, 1.0], ["sucata", 1, 1, 0.4], ["maca", 1, 1, 0.2]]

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
	var s: Variant = ARMAS.get(id, {}).get("sprite", [])
	if s is String:
		_sprites_armas[id] = load(s)
		return _sprites_armas[id]
	if s.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = load(s[0])
	at.region = Rect2(s[1] * TAM_ICONE, s[2] * TAM_ICONE, TAM_ICONE, TAM_ICONE)
	_sprites_armas[id] = at
	return at


## Quanto o ícone da arma encolhe para ficar do tamanho de um ícone 16x16.
static func escala_icone_arma(id: String) -> float:
	var tex := sprite_arma(id)
	return 1.0 if tex == null else TAM_ICONE / maxf(tex.get_width(), 1.0)


## Ponto do cabo da arma, em pixels do ícone.
static func cabo_arma(id: String) -> Vector2:
	return ARMAS.get(id, {}).get("sprite_cabo", Vector2(3, 13) / escala_icone_arma(id))


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
