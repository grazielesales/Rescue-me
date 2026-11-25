extends SceneTree
## Gera todos os efeitos sonoros do jogo (res://sons/**/*.wav) por síntese:
## ruído filtrado, osciladores, envelopes e eco. Nada é baixado da internet.
##
## Para gerar de novo (ex.: depois de mexer num som aqui), no terminal:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <pasta do projeto> --script res://sons/gerador/gerar_sons.gd
## e depois abra o editor (ou rode com --headless --import) para importar os .wav.
##
## O resultado é sempre o mesmo (cada som tem a própria semente).
## Para trocar um som por um gravado/baixado, substitua o .wav (mesmo nome)
## e apague a linha dele aqui, senão a próxima geração sobrescreve.
##
## Variações: arquivos nome_1.wav, nome_2.wav... são sorteados pelo Som
## (jogo/som.gd) a cada vez que "nome" toca.
##
## Músicas (sons/musica): uma ambiente e uma tensa por andar, em laço, do
## mesmo tamanho, tocadas juntas pelo autoload Musica (jogo/musica.gd).
## Só elas: acrescente "-- musica" no fim do comando. Só os efeitos: "-- efeitos".

## Taxa de amostragem atual (os efeitos usam 44,1 kHz; as músicas, 22,05 kHz,
## para os arquivos longos ficarem menores).
var SR := 44100

var rng := RandomNumberGenerator.new()
var _nome := ""
var _feitos := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if not "musica" in args:
		_pai()
		_armas()
		_inimigos()
		_mundo()
		_interface()
	if not "efeitos" in args:
		_musicas()
		_lamento()
	print("%d sons gerados em %.1f s" % [_feitos, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()


# --- Pai -------------------------------------------------------------------------------

func _pai() -> void:
	for i in range(1, 5):
		_s("pai/passo_%d" % i)
		# passo abafado: quase só a batida grave, com um raspar bem leve
		var batida := env(osc(0.05, rng.randf_range(90, 115), 55), 0.002, 0.012)
		var raspa := env(pb(banda(ruido(0.05), rng.randf_range(500, 800), -1, 0.9), 1400), 0.002, 0.01)
		salvar(somar(batida, raspa, 0.35), 0.16)

	# dano: um "hit" curto e seco, tipo "uf!" (tom redondo, sem distorção)
	for i in range(1, 3):
		_s("pai/dano_%d" % i)
		var soco := env(osc(0.07, 150, 70), 0.001, 0.02)
		var uf := env(voz(0.16, 250 - i * 15, 160, [520, 900], 0.0, 0.0, 0.06, "tri"), 0.004, 0.045)
		salvar(somar(soco, uf, 1.0, 0.005), 0.6)

	_s("pai/morte")
	var lamento := sino(voz(0.95, 220, 70, [600, 1050], 5.0, 0.03, 0.2), 0.08, 0.8)
	var queda := baque(0.4, 95, 38, 900)
	salvar(somar(somar(baque(0.12, 180, 60, 1600), lamento, 0.9, 0.02), queda, 1.3, 0.75), 0.85)

	_s("pai/cura")
	var subida := notas([523.25, 659.25, 783.99, 1046.5], 0.07, 0.3, "tri", 0.09)
	salvar(somar(subida, brilhos(0.45, 7, 2000, 4200), 0.35, 0.05), 0.5)


# --- armas -------------------------------------------------------------------------------

func _armas() -> void:
	# golpes no ar (um por arma; o nome é o id em Itens.ARMAS)
	_s("armas/socos")
	salvar(zunido(0.11, 500, 1100, 0.9), 0.38)

	_s("armas/porrete")
	salvar(somar(zunido(0.2, 340, 900, 0.8), sino(pb(ruido(0.2), 400), 0.4), 0.4), 0.5)

	_s("armas/clava")
	var grave := ganho(sino(osc(0.28, 72, 50), 0.4, 1.0), 0.35)
	salvar(somar(zunido(0.28, 240, 650, 0.7), grave), 0.55)

	_s("armas/cajado_fogo")
	var chamas := somar(ganho(sino(pb(ruido(0.4), 700), 0.35), 0.7), estalos(0.4, 16, 1800, 5500), 0.5)
	salvar(somar(zunido(0.24, 420, 1050, 0.8), chamas, 0.9, 0.03), 0.55)

	_s("armas/lanca")
	salvar(zunido(0.15, 1100, 2700, 0.35), 0.45)

	_s("armas/adaga")
	salvar(somar(zunido(0.09, 1800, 3800, 0.5), metal(0.12, 3200, [1.0, 1.5], 0.03), 0.12), 0.42)

	_s("armas/espada")
	var espectro := env(osc(0.38, 880, 1320, "sen", 7.0, 0.02), 0.02, 0.12)
	salvar(somar(somar(zunido(0.18, 800, 1900, 0.6), espectro, 0.3), metal(0.38, 1400, [1.0, 2.76, 5.4], 0.1), 0.18), 0.5)

	_s("armas/machado")
	var peso := somar(sino(osc(0.36, 62, 44), 0.4), sino(pb(osc(0.36, 110, 88, "serra"), 420), 0.4), 0.4)
	salvar(somar(zunido(0.36, 190, 560, 0.6), peso, 0.5), 0.6)

	_s("armas/lamina")
	var luz := silencio(0.4)
	for f in [1318.5, 1975.5, 2637.0]:
		luz = somar(luz, env(osc(0.4, f, f * 1.01), 0.01, 0.13), 0.5)
	salvar(somar(zunido(0.18, 900, 2300, 0.6), luz, 0.45, 0.02), 0.5)

	# acerto num monstro
	for i in range(1, 3):
		_s("armas/impacto_%d" % i)
		var corpo := baque(0.11, 175 - i * 15, 52, 2200)
		salvar(saturar(somar(corpo, clique(1400, 0.01), 0.6), 2.0), 0.65)

	# "tink": monstro fechado (olho) ou carregado de energia (Frankie)
	_s("armas/bloqueado")
	salvar(somar(metal(0.28, 1900, [1.0, 2.41, 3.9, 5.3], 0.06), clique(5000, 0.006), 0.5), 0.5)

	# melhoria "Arma eletrificada"
	_s("armas/choque")
	salvar(zap(0.32), 0.45)

	# veneno da adaga fazendo efeito
	_s("armas/veneno")
	var bolhas := silencio(0.2)
	for k in 3:
		bolhas = somar(bolhas, env(osc(0.05, 380 + k * 120, 900 + k * 150), 0.002, 0.012), 1.0, k * 0.05)
	salvar(somar(bolhas, env(pa(ruido(0.18), 4000), 0.003, 0.05), 0.25), 0.32)


# --- monstros ---------------------------------------------------------------------------
## Cada família (campo "som" de Itens.INIMIGOS) tem _ataque, _dano e _morte.

func _inimigos() -> void:
	# aranhas: chiado e patinhas
	_s("inimigos/aranha_ataque")
	salvar(somar(ganho(sino(pa(ruido(0.3), 3500), 0.15), 0.6), estalos(0.3, 12, 2500, 4500)), 0.5)
	_s("inimigos/aranha_dano")
	salvar(somar(env(osc(0.09, 2200, 1400, "tri"), 0.003, 0.035), estalos(0.1, 4, 2500, 4500), 0.6), 0.42)
	_s("inimigos/aranha_morte")
	var guincho := voz(0.45, 1700, 650, [2200, 3200], 18.0, 0.04, 0.3)
	var esmagar := env(banda(ruido(0.3), 900, 250, 0.8), 0.002, 0.08)
	salvar(somar(esmagar, guincho, 0.8), 0.6)

	# esqueletos: ossos batendo
	_s("inimigos/esqueleto_ataque")
	salvar(somar(estalos(0.28, 9, 1100, 2400, "toc"), zunido(0.22, 380, 900), 0.6, 0.06), 0.5)
	_s("inimigos/esqueleto_dano")
	salvar(somar(toc(1150), toc(1550), 0.9, 0.06), 0.5)
	_s("inimigos/esqueleto_morte")
	var desmonta := estalos(0.95, 24, 700, 2600, "toc", 1.7)
	salvar(somar(desmonta, baque(0.22, 120, 60, 1200), 0.5, 0.55), 0.6)

	# zumbis: gemidos roucos
	_s("inimigos/zumbi_ataque")
	salvar(saturar(sino(voz(0.55, 115, 85, [450, 950, 2400], 4.0, 0.04, 0.35), 0.3, 0.7), 2.0), 0.6)
	_s("inimigos/zumbi_dano")
	salvar(env(voz(0.22, 140, 100, [500, 1000], 0.0, 0.0, 0.3), 0.01, 0.08), 0.55)
	_s("inimigos/zumbi_morte")
	var gemido_longo := sino(voz(1.1, 125, 55, [450, 900], 3.0, 0.05, 0.35), 0.15, 0.6)
	salvar(somar(gemido_longo, baque(0.3, 80, 40, 700), 1.0, 0.9), 0.7)

	# olhos malignos: disparo molhado e "plop"
	_s("inimigos/olho_ataque")
	var pew := pb(env(osc(0.16, 950, 280, "quad"), 0.002, 0.05), 3000)
	salvar(somar(pew, env(banda(ruido(0.12), 1200, 500, 0.6), 0.002, 0.04), 0.5), 0.36)
	_s("inimigos/olho_dano")
	salvar(somar(env(banda(ruido(0.14), 900, 300, 0.5), 0.003, 0.05), env(osc(0.06, 700, 500), 0.002, 0.02), 0.5), 0.45)
	_s("inimigos/olho_morte")
	salvar(somar(env(osc(0.1, 700, 90), 0.001, 0.03), env(pb(ruido(0.3), 1800, 300), 0.002, 0.08), 0.8), 0.6)

	# bruxa: feitiço brilhante, grito agudo
	_s("inimigos/bruxa_ataque")
	var feitico := sino(banda(osc(0.45, 300, 1100, "serra", 6.0, 0.03), 900, 2400, 0.4), 0.6)
	salvar(eco(somar(feitico, brilhos(0.45, 8, 2000, 5000), 0.6), 0.09, 0.35, 3), 0.5)
	_s("inimigos/bruxa_dano")
	salvar(env(voz(0.2, 850, 1050, [1300, 2700], 10.0, 0.03, 0.15), 0.005, 0.07), 0.48)
	_s("inimigos/bruxa_morte")
	var grito := sino(voz(1.0, 1150, 260, [1200, 2600], 7.0, 0.05, 0.15), 0.1, 0.6)
	salvar(eco(somar(grito, brilhos(1.2, 14, 1800, 4800), 0.35), 0.12, 0.3, 3), 0.62)

	# chama sombria: fogo
	_s("inimigos/chama_ataque")
	salvar(somar(sino(banda(ruido(0.42), 500, 1800, 1.2), 0.35), estalos(0.42, 14, 2000, 6000), 0.5), 0.55)
	_s("inimigos/chama_dano")
	salvar(somar(env(pa(ruido(0.22), 3000), 0.002, 0.07), estalos(0.22, 6, 2000, 6000), 0.6), 0.42)
	_s("inimigos/chama_morte")
	var apaga := sino(pb(ruido(0.9), 3500, 250), 0.05, 0.8)
	salvar(somar(somar(apaga, env(pa(ruido(0.9), 5000), 0.01, 0.3), 0.4), estalos(0.6, 10, 2000, 6000), 0.4), 0.6)

	# Frankie: grunhidos graves e eletricidade
	_s("inimigos/frankie_ataque")
	var urro := saturar(sino(voz(0.4, 88, 72, [380, 850, 2200], 0.0, 0.0, 0.3), 0.25, 0.6), 2.5)
	salvar(somar(urro, zunido(0.3, 200, 500), 0.7, 0.12), 0.65)
	_s("inimigos/frankie_dano")
	salvar(somar(env(voz(0.24, 100, 80, [400, 900]), 0.008, 0.09), zap(0.14), 0.35), 0.6)
	_s("inimigos/frankie_morte")
	var fim := sino(voz(1.3, 95, 40, [380, 800], 3.0, 0.04, 0.3), 0.15, 0.6)
	salvar(somar(somar(fim, zap(0.55), 0.6, 0.3), baque(0.5, 70, 30, 800), 1.3, 1.0), 0.75)

	# fantasma: sopro e lamento (está na tabela, ainda sem cena)
	_s("inimigos/fantasma_ataque")
	var sopro := sino(banda(ruido(0.5), 500, 1400, 0.5), 0.5, 1.2)
	salvar(eco(somar(sopro, sino(osc(0.5, 520, 700, "sen", 5.0, 0.04), 0.5), 0.5), 0.1, 0.35, 3), 0.5)
	_s("inimigos/fantasma_dano")
	salvar(env(osc(0.25, 760, 520, "tri", 9.0, 0.05), 0.01, 0.08), 0.42)
	_s("inimigos/fantasma_morte")
	var lamento := sino(osc(1.1, 900, 200, "sen", 6.0, 0.06), 0.15, 0.6)
	salvar(eco(somar(lamento, sino(banda(ruido(1.1), 1200, 300, 0.6), 0.3), 0.5), 0.15, 0.4, 4), 0.6)

	# criatura mágica: bipes e zaps
	_s("inimigos/magico_ataque")
	salvar(eco(pb(env(osc(0.18, 900, 2600, "quad"), 0.002, 0.06), 5000), 0.06, 0.4, 3), 0.32)
	_s("inimigos/magico_dano")
	salvar(env(osc(0.1, 1600, 900, "tri"), 0.002, 0.04), 0.34)
	_s("inimigos/magico_morte")
	var desce := pb(notas([1568.0, 1175.0, 880.0, 659.0], 0.06, 0.08, "quad", 0.03), 4000)
	salvar(eco(somar(desce, env(osc(0.1, 700, 90), 0.001, 0.03), 1.0, 0.26), 0.07, 0.35, 2), 0.36)

	# demônio: rosnados
	_s("inimigos/demonio_ataque")
	salvar(saturar(sino(voz(0.5, 65, 85, [300, 700, 1800], 22.0, 0.08, 0.4), 0.3, 0.6), 3.0), 0.65)
	_s("inimigos/demonio_dano")
	salvar(saturar(env(voz(0.22, 120, 95, [400, 900], 18.0, 0.06, 0.35), 0.006, 0.08), 2.0), 0.55)
	_s("inimigos/demonio_morte")
	var rugido := saturar(sino(voz(1.3, 110, 40, [350, 800, 1900], 15.0, 0.07, 0.4), 0.12, 0.6), 3.0)
	salvar(somar(rugido, sino(pb(ruido(1.3), 200), 0.3), 0.6), 0.75)

	# feiticeiro espectral (chefe): magia escura com eco
	_s("inimigos/feiticeiro_ataque")
	var escuro := sino(banda(osc(0.6, 110, 55, "serra"), 300, 800, 0.5), 0.5)
	var arrepio := sino(osc(0.6, 1200, 2400, "sen", 9.0, 0.02), 0.9, 1.5)
	salvar(eco(somar(somar(escuro, arrepio, 0.3), brilhos(0.6, 6, 1500, 3500), 0.3), 0.13, 0.4, 4), 0.55)
	_s("inimigos/feiticeiro_dano")
	salvar(eco(env(voz(0.28, 190, 150, [600, 1300], 5.0, 0.03, 0.2), 0.008, 0.1), 0.08, 0.3, 2), 0.55)
	_s("inimigos/feiticeiro_morte")
	var acorde := silencio(1.8)
	for f in [220.0, 277.18, 329.63]:
		acorde = somar(acorde, pb(osc(1.8, f, f * 0.35, "serra"), 1200, 300), 0.5)
	acorde = sino(acorde, 0.1, 0.7)
	var onda := sino(pb(ruido(1.8), 2000, 200), 0.3)
	salvar(eco(somar(somar(acorde, onda, 0.5), brilhos(1.4, 16, 1500, 4500), 0.3), 0.18, 0.45, 4), 0.75)

	# genérico: monstro sem família ou família sem algum dos sons
	_s("inimigos/generico_ataque")
	salvar(somar(zunido(0.22, 300, 800), env(voz(0.25, 150, 120, [500, 1000]), 0.01, 0.08), 0.5), 0.5)
	_s("inimigos/generico_dano")
	salvar(env(voz(0.18, 160, 120, [500, 1000]), 0.005, 0.06), 0.5)
	_s("inimigos/generico_morte")
	salvar(somar(sino(voz(0.6, 150, 60, [500, 900]), 0.15, 0.6), baque(0.25, 100, 45, 900), 1.0, 0.45), 0.6)

	# monstro entrando em fúria (abaixo de metade da vida)
	_s("inimigos/furia")
	var ronco := sino(pb(ruido(0.9), 300), 0.6)
	var sobe := sino(pb(osc(0.9, 80, 220, "serra"), 900), 0.7)
	salvar(saturar(somar(ronco, sobe, 0.8), 2.0), 0.5)

	# projétil batendo numa parede ou no Pai
	_s("inimigos/projetil_impacto")
	salvar(somar(env(osc(0.08, 900, 200), 0.001, 0.02), env(pa(ruido(0.1), 2500), 0.001, 0.03), 0.5), 0.35)


# --- mundo ------------------------------------------------------------------------------

func _mundo() -> void:
	_s("mundo/porta_abrir")
	salvar(somar(clique(1800, 0.01), rangido(0.5, 45, 85, 950), 1.0, 0.02), 0.45)
	_s("mundo/porta_fechar")
	salvar(somar(baque(0.25, 105, 50, 1200), toc(700), 0.5, 0.01), 0.55)
	_s("mundo/porta_trancada")
	var trinco := silencio(0.25)
	for t in [0.0, 0.07, 0.15]:
		trinco = somar(trinco, somar(metal(0.06, rng.randf_range(1100, 1400), [1.0, 2.3], 0.012), clique(3000, 0.006)), 1.0, t)
	salvar(trinco, 0.42)

	_s("mundo/portao_abrir")
	var corrente := sino(tremolo(banda(ruido(0.8), 1500, 1100, 0.5), 28.0, 0.8), 0.2, 0.6)
	salvar(somar(somar(corrente, rangido(0.8, 70, 110, 2500), 0.4), metal(0.3, 300, [1.0, 2.76, 5.4], 0.06), 0.6, 0.62), 0.55)
	_s("mundo/portao_fechar")
	salvar(somar(metal(0.6, 220, [1.0, 2.76, 5.4, 8.93, 13.3], 0.18), baque(0.3, 90, 45, 1500)), 0.62)

	_s("mundo/alavanca")
	var clunk := somar(metal(0.3, 600, [1.0, 2.5, 4.1], 0.05), baque(0.15, 140, 70, 1200), 1.2, 0.04)
	salvar(somar(clique(2500, 0.01), clunk, 0.7), 0.55)

	_s("mundo/bau_abrir")
	salvar(somar(rangido(0.35, 55, 95, 750), baque(0.15, 120, 60, 1000), 0.9, 0.32), 0.5)
	# recompensa: algo bom apareceu (baú, alavanca escondida, reencontro)
	_s("mundo/achado")
	salvar(eco(notas([783.99, 987.77, 1174.66, 1567.98], 0.06, 0.25, "tri", 0.08), 0.1, 0.3, 2), 0.42)
	_s("mundo/chave")
	var tilintar := silencio(0.35)
	for k in 5:
		tilintar = somar(tilintar, metal(0.12, rng.randf_range(2500, 4200), [1.0, 1.7, 2.9], 0.04), rng.randf_range(0.5, 1.0), rng.randf() * 0.25)
	salvar(tilintar, 0.42)
	# material pego do chão
	_s("mundo/item")
	salvar(pb(somar(env(osc(0.06, 660, 990, "quad"), 0.002, 0.02), env(osc(0.08, 990, 1320, "quad"), 0.002, 0.03), 1.0, 0.05), 4000), 0.24)

	_s("mundo/caixa_bater")
	salvar(somar(env(osc(0.07, 380, 300, "tri"), 0.001, 0.02), env(banda(ruido(0.06), 1200, -1, 0.8), 0.001, 0.015), 0.8), 0.5)
	_s("mundo/caixa_quebrar")
	var lascas := silencio(0.4)
	for k in 7:
		lascas = somar(lascas, env(banda(ruido(0.05), rng.randf_range(800, 2600), -1, 0.7), 0.001, 0.015), rng.randf_range(0.5, 1.0), rng.randf() * 0.25)
	lascas = somar(lascas, estalos(0.3, 5, 300, 600, "toc"), 0.6)
	salvar(saturar(somar(baque(0.2, 120, 60, 1500), lascas, 0.9), 1.5), 0.62)

	_s("mundo/espinhos")
	var shing := somar(env(pa(ruido(0.12), 4000), 0.001, 0.03), metal(0.15, 2400, [1.0, 1.9, 3.1], 0.025), 0.5)
	salvar(somar(shing, clique(2000, 0.008), 0.6), 0.38)

	# arena: portas fechando de uma vez e sala vencida
	_s("mundo/sala_trancar")
	var boom := somar(baque(0.9, 70, 35, 600), metal(0.9, 110, [1.0, 2.76, 5.4], 0.25), 0.35)
	salvar(somar(boom, env(pb(ruido(1.0), 300), 0.005, 0.3), 0.5), 0.75)
	_s("mundo/sala_vencida")
	var destrava := somar(metal(0.3, 700, [1.0, 2.5], 0.05), baque(0.12, 160, 80, 1500), 0.8)
	var claro := eco(notas([1046.5, 1567.98], 0.09, 0.45, "tri", 0.15), 0.1, 0.3, 2)
	salvar(somar(somar(destrava, claro, 0.8, 0.12), brilhos(0.6, 8, 2500, 5000), 0.25, 0.15), 0.5)

	_s("mundo/bilhete")
	salvar(papel(0.35), 0.35)
	# bolha de magia que prendia o filho estourando
	_s("mundo/bolha_estoura")
	var plop := env(osc(0.08, 300, 1400), 0.001, 0.02)
	salvar(eco(somar(plop, brilhos(0.7, 12, 1500, 4500), 0.5, 0.03), 0.1, 0.3, 2), 0.5)
	_s("mundo/receita_nova")
	salvar(somar(notas([1046.5, 1318.5, 1568.0, 2093.0], 0.06, 0.3, "sen", 0.1), brilhos(0.5, 6, 2500, 5000), 0.3), 0.4)


# --- interface ------------------------------------------------------------------------

func _interface() -> void:
	_s("interface/livro_abrir")
	salvar(somar(papel(0.3), baque(0.12, 140, 80, 800), 0.5), 0.4)
	_s("interface/livro_fechar")
	salvar(somar(baque(0.14, 120, 70, 900), papel(0.12), 0.4, 0.01), 0.4)
	_s("interface/inventario")
	salvar(somar(pb(papel(0.25), 2200), baque(0.1, 160, 90, 700), 0.5, 0.02), 0.35)
	_s("interface/mover")
	salvar(env(osc(0.035, 1800, 1700, "tri"), 0.001, 0.012), 0.2)
	_s("interface/criar")
	var marteladas := somar(metal(0.25, 900, [1.0, 2.76, 5.4], 0.06), metal(0.25, 950, [1.0, 2.76, 5.4], 0.06), 0.9, 0.14)
	salvar(somar(marteladas, notas([1046.5, 1568.0], 0.08, 0.3, "tri", 0.1), 0.5, 0.3), 0.5)
	_s("interface/erro")
	salvar(pb(somar(osc(0.09, 220, 220, "quad"), osc(0.12, 165, 160, "quad"), 1.0, 0.1), 1500), 0.18)
	_s("interface/equipar")
	salvar(somar(somar(metal(0.2, 2200, [1.0, 1.6, 2.9], 0.04), zunido(0.12, 1500, 3000), 1.2), clique(3000, 0.008), 0.5), 0.4)


# --- músicas ------------------------------------------------------------------------
## Cada andar: <andar>_ambiente.wav e <andar>_tensao.wav, com LACO segundos
## (16 compassos a 120 bpm), mesmo tom e mesmos acordes, para a troca entre
## elas ser só de volume. As duas emendam o fim no começo (laço sem estalo).

const SR_MUSICA := 22050
const LACO := 32.0

## acordes = semitons a partir da `raiz` (um acorde a cada LACO / 4 s);
## baixos = semitom da nota grave de cada acorde; dissonancia = intervalo das
## cordas tensas (1 = segunda menor, 6 = trítono).
const ANDARES := {
	# 1º andar: ré menor, caixinha de música triste no escuro
	"andar1": {
		"raiz": 146.83, "drone": 73.42,
		"acordes": [[0, 3, 7], [-4, 0, 3], [-7, -4, 0], [-5, -1, 2]],
		"baixos": [0, -4, -7, -5],
		"densidade": 0.22, "vibrato": 0.0, "oitava": 12, "vento": 500.0,
		"dissonancia": 1, "sincopa": false,
	},
	# 2º andar: lá frígio, mais estranho (sino desafinado, luzes piscando)
	"andar2": {
		"raiz": 220.0, "drone": 55.0,
		"acordes": [[0, 3, 7], [1, 5, 8], [0, 3, 7], [-1, 2, 5]],
		"baixos": [0, 1, 0, -1],
		"densidade": 0.18, "vibrato": 0.012, "oitava": 12, "vento": 750.0,
		"dissonancia": 6, "sincopa": true,
	},
}


func _musicas() -> void:
	SR = SR_MUSICA
	for andar in ANDARES:
		var c: Dictionary = ANDARES[andar]
		_s("musica/%s_base" % andar)
		var pad := _norm(_pad(c))
		var vento := _norm(_vento(c))
		var melodia := _norm(_melodia(c))
		var calmo := _norm(_drone(c, 260.0))

		_s("musica/%s_ambiente" % andar)
		var amb := somar(calmo, pad, 0.9)
		amb = somar(amb, vento, 0.35)
		amb = somar(amb, melodia, 0.55)
		salvar(amb, 0.5, true)

		_s("musica/%s_tensao" % andar)
		var ten := somar(_norm(_drone(c, 520.0)), pad, 0.75)
		ten = somar(ten, vento, 0.3)
		ten = somar(ten, melodia, 0.2)
		ten = somar(ten, _norm(_pulso(c)), 0.55)
		ten = somar(ten, _norm(_tambor(c)), 0.85)
		ten = somar(ten, _norm(_chimbal(c)), 0.22)
		ten = somar(ten, _norm(_cordas(c)), 0.3)
		salvar(saturar(ten, 1.3), 0.6, true)
	SR = 44100


## Lamento (musica/filho_perdido): toca uma vez quando a luz do filho apaga.
## Caixinha de música em ré menor que vai perdendo a corda: as últimas notas
## atrasam e desafinam para baixo, e o acorde final fica pendurado no escuro.
## seg = segundos por acorde; notas = [tempo (s), semitom (uma oitava acima
## da raiz), quanto a nota desafina até o fim (semitons)].
const LAMENTO := {
	"raiz": 146.83,
	"seg": 5.0,
	"acordes": [[0, 3, 7], [-4, 0, 3], [-7, -4, 0], [-5, -1, 2], [0, 3, 7]],
	"baixos": [0, -4, -7, -5, 0],
	"notas": [
		[0.5, 7, 0.0], [1.5, 5, 0.0], [2.5, 3, 0.0], [3.5, 2, 0.0], [4.25, 3, 0.0],
		[5.5, 5, 0.0], [6.5, 3, 0.0], [7.5, 2, 0.0], [8.5, 0, 0.0], [9.25, -2, 0.0],
		[10.5, -2, 0.0], [11.5, 0, 0.0], [12.5, 2, 0.0], [13.5, 3, 0.0], [14.25, 2, 0.0],
		[15.5, 1, 0.0], [16.6, 2, 0.0], [17.8, -1, 0.0], [19.2, -5, 0.0],
		[20.8, 3, 0.0], [22.5, 2, -0.3], [24.6, 0, -0.8],
	],
}


func _lamento() -> void:
	SR = SR_MUSICA
	_s("musica/filho_perdido")
	var c := LAMENTO
	var seg: float = c.seg
	var qtd: int = c.acordes.size()
	var o := silencio(seg * qtd + 5.0)
	# acordes longos e escuros (o último fica soando)
	for i in qtd:
		var dur: float = seg + (5.0 if i == qtd - 1 else 2.0)
		var acorde := silencio(dur)
		for s in c.acordes[i]:
			var f := _nota(c, s)
			acorde = somar(acorde, osc(dur, f * 0.997, -1, "tri"), 0.5)
			acorde = somar(acorde, osc(dur, f * 1.003, -1, "tri"), 0.5)
		o = somar(o, sino(pb(acorde, 900), 0.3, 0.8), 0.35, i * seg)
		# baixo grave, uma oitava abaixo
		var grave := sino(osc(dur, _nota(c, c.baixos[i], -1)), 0.25)
		o = somar(o, grave, 0.45, i * seg)
	# caixinha de música, com eco
	for n in c.notas:
		var f := _nota(c, n[1], 1)
		var f1: float = f * pow(2.0, n[2] / 12.0)
		var nota := somar(osc(2.0, f, f1), osc(2.0, f * 2.0, f1 * 2.0), 0.25)
		nota = pb(env(nota, 0.004, 0.5), 2600)
		for e in 3:
			o = somar(o, nota, 0.5 * pow(0.45, e), n[0] + e * 0.5)
	salvar(o, 0.5)
	SR = 44100


## Frequência ajustada para dar um número inteiro de ciclos no laço.
func _q(f: float) -> float:
	return maxf(1.0, roundf(f * LACO)) / LACO


func _norm(b: PackedFloat32Array) -> PackedFloat32Array:
	var maior := 0.0
	for v in b:
		maior = maxf(maior, absf(v))
	return ganho(b, 1.0 / maxf(maior, 0.000001))


## Soma `b` em `dest` a partir de `t` segundos, dando a volta no fim do laço.
func colocar(dest: PackedFloat32Array, b: PackedFloat32Array, t: float, g := 1.0) -> PackedFloat32Array:
	var o := dest.duplicate()
	var tam := o.size()
	var ini := int(t * SR)
	for i in b.size():
		o[posmod(ini + i, tam)] += b[i] * g
	return o


func _seg_acorde(c: Dictionary) -> float:
	return LACO / c.acordes.size()


func _nota(c: Dictionary, semitom: float, oitavas := 0) -> float:
	return c.raiz * pow(2.0, semitom / 12.0 + oitavas)


## Zumbido grave contínuo que "respira" devagar.
func _drone(c: Dictionary, brilho: float) -> PackedFloat32Array:
	# gera 1 s a mais e descarta o começo: o filtro já entra "aquecido" e o
	# trecho final emenda certinho no inicial (o sinal se repete a cada LACO)
	var f := _q(c.drone)
	var d := somar(osc(LACO + 1.0, f, f, "serra"), osc(LACO + 1.0, _q(f * 1.004), -1, "serra"), 0.8)
	d = somar(d, osc(LACO + 1.0, f), 0.8)
	d = pb(d, brilho).slice(SR, SR + _n(LACO))
	return tremolo(d, _q(0.125), 0.35)


## Acordes longos e macios (um por segmento, entrando devagar).
func _pad(c: Dictionary) -> PackedFloat32Array:
	var o := silencio(LACO)
	var seg := _seg_acorde(c)
	for i in c.acordes.size():
		var acorde := silencio(seg + 2.0)
		for s in c.acordes[i]:
			var f := _nota(c, s)
			acorde = somar(acorde, osc(seg + 2.0, f * 0.997, -1, "tri"), 0.5)
			acorde = somar(acorde, osc(seg + 2.0, f * 1.003, -1, "tri"), 0.5)
		o = colocar(o, sino(pb(acorde, 1100), 0.3, 0.7), i * seg - 1.0)
	return o


## Notas soltas de caixinha de música/sino, com eco, nas notas do acorde.
func _melodia(c: Dictionary) -> PackedFloat32Array:
	var o := silencio(LACO)
	var passo := 0.5  # um tempo a 120 bpm
	var seg := _seg_acorde(c)
	for b in int(LACO / passo):
		if rng.randf() > c.densidade:
			continue
		var t := b * passo
		var acorde: Array = c.acordes[mini(int(t / seg), c.acordes.size() - 1)]
		var s: float = acorde[rng.randi() % acorde.size()] + c.oitava * (1 + rng.randi() % 2)
		var f := _nota(c, s)
		var nota := somar(osc(1.4, f, -1, "sen", 5.0, c.vibrato), osc(1.4, f * 2.0), 0.25)
		nota = pb(env(nota, 0.004, 0.35), 3000)
		for e in 3:
			o = colocar(o, nota, t + e * 0.375, pow(0.45, e))
	return o


## Vento/ar do porão: ruído numa banda que sobe e desce de volume.
func _vento(c: Dictionary) -> PackedFloat32Array:
	var v := banda(ruido(LACO), c.vento, -1.0, 0.5)
	v = tremolo(v, _q(1.0 / 16.0), 0.85)
	return tremolo(v, _q(0.19), 0.4)


## Tensão: baixo pulsando em colcheias, seguindo o acorde.
func _pulso(c: Dictionary) -> PackedFloat32Array:
	var o := silencio(LACO)
	var seg := _seg_acorde(c)
	for k in int(LACO / 0.25):
		if c.sincopa and k % 8 in [3, 6]:
			continue
		var t := k * 0.25
		var f := _nota(c, c.baixos[mini(int(t / seg), c.baixos.size() - 1)], -1)
		var n := env(pb(osc(0.22, f, -1, "serra"), 650), 0.004, 0.07)
		o = colocar(o, n, t, 1.0 if k % 2 == 0 else 0.6)
	return o


## Tensão: tambor grave como batida de coração (tum-tum a cada compasso e meio).
func _tambor(c: Dictionary) -> PackedFloat32Array:
	var o := silencio(LACO)
	var bumbo := baque(0.6, 75, 42, 300)
	var passo := 0.5 if c.sincopa else 1.0
	for k in int(LACO / passo):
		o = colocar(o, bumbo, k * passo, 1.0 if k % 2 == 0 else 0.7)
		if not c.sincopa:
			o = colocar(o, bumbo, k * passo + 0.28, 0.5)
	return o


## Tensão: tique-taque agudo nas colcheias.
func _chimbal(_c: Dictionary) -> PackedFloat32Array:
	var o := silencio(LACO)
	for k in int(LACO / 0.25):
		var tic := env(pa(ruido(0.05), 6000), 0.001, 0.012 if k % 2 == 0 else 0.025)
		o = colocar(o, tic, k * 0.25, 0.6 if k % 2 == 0 else 1.0)
	return o


## Tensão: cordas agudas em trêmulo, dissonantes, crescendo em cada acorde.
func _cordas(c: Dictionary) -> PackedFloat32Array:
	var o := silencio(LACO)
	var seg := _seg_acorde(c)
	for i in c.baixos.size():
		var f := _nota(c, c.baixos[i], 1)
		var par := somar(osc(seg + 1.0, f, -1, "serra", 5.5, 0.004), osc(seg + 1.0, f * pow(2.0, c.dissonancia / 12.0), -1, "serra", 6.1, 0.004))
		par = tremolo(pb(par, 2200), 8.0, 0.6)
		o = colocar(o, sino(par, 0.75, 1.2), i * seg - 0.5)
	return o


# === síntese ==========================================================================
# Todo sinal é um PackedFloat32Array mono a 44,1 kHz, de -1 a 1 (mais ou menos).
# As funções devolvem um sinal novo, sem mexer no que receberam.

## Começa um som: guarda o nome e fixa a semente (mesmo resultado sempre).
func _s(nome: String) -> void:
	_nome = nome
	rng.seed = hash(nome)


func _n(dur: float) -> int:
	return maxi(1, int(dur * SR))


func silencio(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(_n(dur))
	b.fill(0.0)
	return b


func ruido(dur: float) -> PackedFloat32Array:
	var b := silencio(dur)
	for i in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## Oscilador com a frequência indo de f0 a f1 (curva exponencial).
## forma: "sen", "quad", "serra" ou "tri". vib_* = vibrato (Hz e fração).
func osc(dur: float, f0: float, f1 := -1.0, forma := "sen", vib_hz := 0.0, vib_prof := 0.0) -> PackedFloat32Array:
	if f1 <= 0.0:
		f1 = f0
	var b := silencio(dur)
	var tam := b.size()
	var razao := f1 / f0
	var tipo := ["sen", "quad", "serra", "tri"].find(forma)
	var fase := 0.0
	for i in tam:
		var f := f0 * pow(razao, float(i) / tam)
		if vib_hz > 0.0:
			f *= 1.0 + vib_prof * sin(TAU * vib_hz * i / SR)
		fase = fmod(fase + f / SR, 1.0)
		match tipo:
			0:
				b[i] = sin(TAU * fase)
			1:
				b[i] = 1.0 if fase < 0.5 else -1.0
			2:
				b[i] = 2.0 * fase - 1.0
			_:
				b[i] = 4.0 * absf(fase - 0.5) - 1.0
	return b


## Ataque linear e queda exponencial (`queda` = constante de tempo, em s).
func env(b: PackedFloat32Array, ataque: float, queda: float) -> PackedFloat32Array:
	var o := b.duplicate()
	ataque = maxf(ataque, 0.0001)
	for i in o.size():
		var t := float(i) / SR
		o[i] *= (t / ataque) if t < ataque else exp(-(t - ataque) / queda)
	return o


## Sobe até `pico` (fração da duração) e desce até zero no fim.
## `p` > 1 deixa a curva mais pontuda; < 1, mais cheia.
func sino(b: PackedFloat32Array, pico := 0.4, p := 1.0) -> PackedFloat32Array:
	var o := b.duplicate()
	var tam := o.size()
	pico = clampf(pico, 0.01, 0.99)
	for i in tam:
		var k := float(i) / tam
		var g := k / pico if k < pico else (1.0 - k) / (1.0 - pico)
		g = g * g * (3.0 - 2.0 * g)
		o[i] *= pow(g, p)
	return o


func _corte(fc0: float, fc1: float, k: float) -> float:
	return fc0 if fc1 <= 0.0 else fc0 * pow(fc1 / fc0, k)


## Passa-baixa de 1 polo; o corte vai de fc0 a fc1 (fc1 < 0 = fixo).
func pb(b: PackedFloat32Array, fc0: float, fc1 := -1.0) -> PackedFloat32Array:
	var o := b.duplicate()
	var tam := o.size()
	var y := 0.0
	for i in tam:
		var a := 1.0 - exp(-TAU * _corte(fc0, fc1, float(i) / tam) / SR)
		y += a * (o[i] - y)
		o[i] = y
	return o


## Passa-alta de 1 polo.
func pa(b: PackedFloat32Array, fc0: float, fc1 := -1.0) -> PackedFloat32Array:
	var baixa := pb(b, fc0, fc1)
	var o := b.duplicate()
	for i in o.size():
		o[i] -= baixa[i]
	return o


## Passa-banda (filtro de variável de estado). `amort` menor = banda mais estreita.
func banda(b: PackedFloat32Array, fc0: float, fc1 := -1.0, amort := 0.7) -> PackedFloat32Array:
	var o := b.duplicate()
	var tam := o.size()
	var baixa := 0.0
	var meio := 0.0
	for i in tam:
		var fc := minf(_corte(fc0, fc1, float(i) / tam), SR / 6.5)
		var f := 2.0 * sin(PI * fc / SR)
		baixa += f * meio
		var alta := o[i] - baixa - amort * meio
		meio += f * alta
		o[i] = meio
	return o


## a + b x ganho, com b começando `atraso` segundos depois.
func somar(a: PackedFloat32Array, b: PackedFloat32Array, g := 1.0, atraso := 0.0) -> PackedFloat32Array:
	var ini := int(atraso * SR)
	var o := a.duplicate()
	if o.size() < ini + b.size():
		var antes := o.size()
		o.resize(ini + b.size())
		for i in range(antes, o.size()):
			o[i] = 0.0
	for i in b.size():
		o[ini + i] += b[i] * g
	return o


func ganho(b: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var o := b.duplicate()
	for i in o.size():
		o[i] *= g
	return o


## Distorção suave (deixa grunhidos e golpes mais "sujos").
func saturar(b: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var o := b.duplicate()
	var maior := 0.0
	for v in o:
		maior = maxf(maior, absf(v))
	var escala := 1.0 / maxf(maior, 0.000001)
	for i in o.size():
		o[i] = tanh(k * o[i] * escala) / tanh(k)
	return o


## Volume subindo e descendo `hz` vezes por segundo.
func tremolo(b: PackedFloat32Array, hz: float, prof: float) -> PackedFloat32Array:
	var o := b.duplicate()
	for i in o.size():
		o[i] *= 1.0 - prof * (0.5 + 0.5 * sin(TAU * hz * i / SR))
	return o


## Repetições cada vez mais baixas (`fb` = quanto sobra a cada vez).
func eco(b: PackedFloat32Array, tempo: float, fb: float, vezes: int) -> PackedFloat32Array:
	var o := b.duplicate()
	for j in range(1, vezes + 1):
		o = somar(o, pb(b, 4000.0 / j), pow(fb, j), tempo * j)
	return o


# --- peças prontas ------------------------------------------------------------------

## Batida grave: seno que despenca + estalo de ruído (impactos, quedas).
func baque(dur: float, f0: float, f1: float, brilho: float) -> PackedFloat32Array:
	var corpo := env(osc(dur, f0, f1), 0.002, dur * 0.3)
	var batida := env(pb(ruido(minf(dur, 0.08)), brilho), 0.0008, 0.012)
	return somar(corpo, batida, 0.7)


func clique(fc := 3000.0, dur := 0.012) -> PackedFloat32Array:
	return env(banda(ruido(dur), fc, -1.0, 0.6), 0.0005, dur * 0.25)


## Golpe no ar ("whoosh"): ruído numa banda que varre de fc0 a fc1.
func zunido(dur: float, fc0: float, fc1: float, amort := 0.8) -> PackedFloat32Array:
	return sino(banda(ruido(dur), fc0, fc1, amort), 0.4, 1.3)


## Metal: parciais inarmônicas que somem mais rápido quanto mais agudas.
func metal(dur: float, f: float, parciais := [1.0, 2.76, 5.4, 8.93], queda := 0.15) -> PackedFloat32Array:
	var o := silencio(dur)
	for j in parciais.size():
		var fp: float = f * parciais[j]
		o = somar(o, env(osc(dur, fp, fp * 0.998), 0.001, queda / (1.0 + j * 0.6)), 1.0 / (1.0 + j * 0.7))
	return o


## Batidinha de madeira ou osso.
func toc(f: float) -> PackedFloat32Array:
	return somar(env(osc(0.05, f, f * 0.9), 0.0005, 0.01), clique(f * 2.2, 0.008), 0.6)


## `quantos` estalos espalhados em `dur`: "ruido" (fogo, patinhas) ou "toc"
## (ossos, madeira). `concentrar` > 1 junta mais estalos no começo.
func estalos(dur: float, quantos: int, f_min: float, f_max: float, tipo := "ruido", concentrar := 1.0) -> PackedFloat32Array:
	var o := silencio(dur)
	for j in quantos:
		var t := dur * pow(rng.randf(), concentrar) * 0.92
		var f := rng.randf_range(f_min, f_max)
		var e := clique(f, rng.randf_range(0.004, 0.012)) if tipo == "ruido" else toc(f)
		o = somar(o, e, rng.randf_range(0.4, 1.0), t)
	return o


## Faíscas mágicas: bipes agudos curtos em momentos aleatórios.
func brilhos(dur: float, quantos: int, f_min: float, f_max: float) -> PackedFloat32Array:
	var o := silencio(dur)
	for j in quantos:
		var f := rng.randf_range(f_min, f_max)
		o = somar(o, env(osc(0.12, f), 0.002, 0.03), rng.randf_range(0.3, 1.0), rng.randf() * dur * 0.85)
	return o


## Notas em sequência (arpejos curtos de efeito, não música).
func notas(freqs: Array, passo: float, dur_nota: float, forma := "tri", queda := 0.08) -> PackedFloat32Array:
	var o := silencio(0.01)
	for j in freqs.size():
		o = somar(o, env(osc(dur_nota, freqs[j], freqs[j], forma), 0.003, queda), 1.0, j * passo)
	return o


## "Voz" de criatura: serra (com vibrato) + sopro passando por formantes.
func voz(dur: float, f0: float, f1: float, formantes: Array, vib_hz := 0.0, vib_prof := 0.0, sopro := 0.2, forma := "serra") -> PackedFloat32Array:
	var fonte := somar(osc(dur, f0, f1, forma, vib_hz, vib_prof), ruido(dur), sopro)
	var o := silencio(dur)
	for j in formantes.size():
		o = somar(o, banda(fonte, formantes[j], -1.0, 0.3), 1.0 / (1.0 + j * 0.5))
	return sino(o, 0.15, 0.7)


## Rangido (dobradiça, baú): pulsos de atrito num ritmo que oscila, filtrados.
func rangido(dur: float, hz0: float, hz1: float, fc: float) -> PackedFloat32Array:
	var o := silencio(dur)
	var tam := o.size()
	var fase := 0.0
	var pulso := 0.0
	for i in tam:
		var t := float(i) / SR
		var hz := lerpf(hz0, hz1, float(i) / tam) * (1.0 + 0.3 * sin(TAU * 3.1 * t) + 0.15 * sin(TAU * 7.3 * t))
		fase += hz / SR
		if fase >= 1.0:
			fase -= 1.0
			pulso = rng.randf_range(0.6, 1.0)
		o[i] = pulso
		pulso *= 0.93
	var corpo := somar(banda(o, fc, -1.0, 0.25), banda(o, fc * 2.1, -1.0, 0.3), 0.5)
	return sino(corpo, 0.3, 0.7)


## Papel farfalhando: ruído agudo cortado em pedacinhos de volume aleatório.
func papel(dur: float) -> PackedFloat32Array:
	var o := banda(ruido(dur), 3200, -1.0, 0.9)
	var g := 0.0
	var resta := 0
	for i in o.size():
		if resta <= 0:
			g = pow(rng.randf(), 2.0)
			resta = int(rng.randf_range(0.004, 0.02) * SR)
		resta -= 1
		o[i] *= g
	return sino(o, 0.3, 0.6)


## Choque elétrico: zumbido + chiado que liga e desliga como faísca.
func zap(dur: float) -> PackedFloat32Array:
	var o := somar(osc(dur, 95, 90, "quad"), osc(dur, 190, 170, "serra"), 0.6)
	o = somar(o, pa(ruido(dur), 2500), 0.7)
	var g := 1.0
	var resta := 0
	for i in o.size():
		if resta <= 0:
			g = rng.randf_range(0.1, 1.0)
			resta = int(rng.randf_range(0.005, 0.02) * SR)
		resta -= 1
		o[i] *= g
	return env(pb(o, 6000), 0.003, dur * 0.4)


# --- gravação ---------------------------------------------------------------------------

## Tira o silêncio do fim, normaliza para `pico` (0–1, o volume relativo do
## som no jogo) e grava res://sons/<nome>.wav (16 bits, mono, na taxa SR).
## `laco` (músicas): não corta nem suaviza as pontas e grava o ponto de laço
## no arquivo (bloco "smpl"), que o importador do Godot usa para repetir.
func salvar(b: PackedFloat32Array, pico := 0.7, laco := false) -> void:
	var o := b if laco else pa(b, 25.0)  # tira o deslocamento DC
	var maior := 0.0
	for v in o:
		maior = maxf(maior, absf(v))
	if maior < 0.000001:
		push_error("Som vazio: " + _nome)
		return
	var g := pico / maior
	var tam := o.size()
	while not laco and tam > 1 and absf(o[tam - 1]) < maior * 0.002:
		tam -= 1
	var ini := 0 if laco else mini(int(0.001 * SR), tam)
	var fim := 0 if laco else mini(int(0.012 * SR), tam)
	var dados := PackedByteArray()
	dados.resize(tam * 2)
	for i in tam:
		var v := o[i] * g
		if i < ini:
			v *= float(i) / ini
		if i > tam - fim:
			v *= float(tam - i) / fim
		dados.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var caminho := "res://sons/%s.wav" % _nome
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		push_error("Não deu para gravar %s (%s)" % [caminho, error_string(FileAccess.get_open_error())])
		return
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + dados.size() + (68 if laco else 0))
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)       # tamanho do bloco fmt
	f.store_16(1)        # PCM
	f.store_16(1)        # mono
	f.store_32(SR)
	f.store_32(SR * 2)   # bytes por segundo
	f.store_16(2)        # bytes por amostra
	f.store_16(16)       # bits
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(dados.size())
	f.store_buffer(dados)
	if laco:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(60)
		for k in 7:          # fabricante, produto, período, nota, afinação, SMPTE (x2)
			f.store_32(1000000000 / SR if k == 2 else (60 if k == 3 else 0))
		f.store_32(1)        # um laço
		f.store_32(0)        # dados extras
		f.store_32(0)        # id do laço
		f.store_32(0)        # tipo: para a frente
		f.store_32(0)        # começo (amostra)
		f.store_32(tam - 1)  # fim (amostra)
		f.store_32(0)        # fração
		f.store_32(0)        # repetições (0 = sempre)
	f.close()
	_feitos += 1
	print("  %-32s %.2f s" % [_nome, float(tam) / SR])
