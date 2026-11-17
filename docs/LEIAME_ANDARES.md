# Andares, salas, portas e escadas

Testado no Godot 4.7.1. Comece pelo `andares/andar1.tscn` (1º andar). A escada da direita leva ao `andares/andar2.tscn`.

## Pastas do projeto

| Pasta | O que tem |
|---|---|
| `andares/` | As cenas dos andares (`andar1.tscn`, `andar2.tscn`) e o script da raiz de cada andar (`andar.gd`). |
| `mundo/` | Peças do cenário com comportamento: `alavanca/`, `escada/`, `narrativa/` (bilhetes), `portas/` e `salas/`. |
| `personagens/pai/` | O Pai: cena, script e câmera. |
| `inimigos/` | Cenas dos monstros (`aranha`, `zumbi`, `esqueleto`, `demonio`, `feiticeiro_espectral`, `frankie`) e o script `inimigo.gd`. |
| `jogo/` | Sistemas globais: autoload `Jogo`, HUD, livro, inventário, tabelas de itens, coletáveis, caixas quebráveis e projéteis. |
| `assets/` | Arte de terceiros. Cada pacote fica inteiro na sua pasta, como veio. |
| `addons/` | Pixel UI Fantasy (tema e ícones do HUD e do livro). |
| `docs/` | Este LEIAME, o `README.pdf` e o `modelo de sala.jpg`. |
| `_nao_usados/` | Arquivos que o jogo não usa (tocha antiga, cenas de teste, imagens soltas, wizard original). Dá para apagar quando quiser. |

Para mover arquivos depois, faça isso **pelo FileSystem do editor do Godot**: ele corrige os caminhos dentro das cenas. Movendo pelo Windows, as cenas podem perder as referências.

## Luz do Pai

- Não existe mais tocha: o Pai tem uma luz fixa que o acompanha (nó `Visao` do `personagens/pai/pai.tscn`, degradê suave).
- O raio é `base_vision_radius` (115 no 1º andar, 86 no 2º; o tamanho do antigo círculo da tocha erguida). A melhoria **Luz reforçada** multiplica o raio por `multiplicador_luz_reforcada` (1.3).
- Cor e brilho: `vision_color` e `vision_energy` no nó `pai`.
- O sprite do Pai fica na camada de luz 2 (`light_mask = 2`). Só a luz `Visao` ilumina essa camada (`range_item_cull_mask = 3`). Por isso a luz das salas não soma no Pai e ele tem o mesmo brilho dentro e fora delas.

## Alavanca do 1º andar (`mundo/alavanca/alavanca.gd`)

- É o nó `Props/AnimatedSprite2D3`, perto do portão da sala da aranha.
- Chegue perto e aperte **E**: a alavanca vira e levanta o portão, que fica aberto de vez.
- Até lá o portão fica trancado (`trancado = true` no `portao sala aranha`) e avisa que existe uma alavanca.
- Para ligar outra alavanca a outro portão, use o script `alavanca.gd` e aponte o campo `alvo` para um nó que tenha a função `destrancar()`.

## Salas que acendem (`mundo/salas/sala.gd`)

- Cada filho do nó **Salas** é uma sala. Ela começa coberta de preto e **acende quando o Pai pisa dentro dela**, depois de passar pela porta.
- A sala fica acesa para sempre, inclusive ao voltar de outro andar. O estado fica no autoload `Jogo`.
- Selecione uma sala no editor para ver os retângulos:
  - amarelo = `areas`, onde o Pai precisa pisar;
  - branco = `luz`;
  - azul = `nevoa`, o que fica preto antes.
- No Inspector: `cor_da_luz`, `energia`, `piscar` (luz tremendo, usada no 2º andar) e `acesa_no_inicio`.
- `arena` e `trancar_ao_entrar` são o encaixe da sala bloqueada do GDD 3.5. As arenas já sabem quais inimigos estão dentro (`inimigos()`). **Trancar ainda não faz nada**, porque o projeto não tem combate.

## Portas (`mundo/portas/`)

| Cena | Uso |
|---|---|
| `porta.tscn` | Porta de madeira com animação de 5 quadros. Usa o `mundo/portas/porta.gd` (o antigo `tscn/door.gd` de vocês). |
| `portao.tscn` | Portão de grade (`mundo/portas/portao.gd`). Destrancado, abre como as portas. Com `trancado`, só abre pela alavanca. |
| `porta_lateral.tscn` | Porta em parede vertical. O sprite é provisório, desenhado por mim. |

**Posição de uma porta comum:** para um vão de 2 tiles nas colunas X e X+1, com o arco na linha L, a posição é `(X*16+16, L*16+19)`.

**Batente (`mundo/portas/batente.gd`):** cada porta e portão tem um nó `Batente` com o arco de pedra (`mundo/portas/batente.png`). Ao abrir a cena, ele também copia os tiles de parede logo acima da porta (camadas `Map/wall` e `wall2`). O nó fica na linha de y-sort perto da base da parede, então o Pai passa por trás do arco e da parede de cima ao atravessar o vão.

**Portas novas no 1º andar:**
- sala nordeste;
- 2 portas da sala sul;
- porta lateral da sala sudeste;
- portão da sala da aranha.

O antigo `portao sala 2`, que era só um sprite em loop e não bloqueava nada, ficou **invisível**, não foi apagado.

## Escadas (`mundo/escada/escada.gd`)

- No pé da escada, aperte **cima**. O Pai passa a andar pelos degraus seguindo o `caminho`: cima sobe, baixo desce e volta ao chão.
- No topo ele some no escuro, a tela escurece e carrega o `destino`.
- No outro andar, a escada com id igual a `chegada_no_destino` faz o Pai aparecer no fim do caminho e voltar sozinho.
- `animacao_avancar`:
  - `"up"` para escada que sobe (o Pai fica de costas ao avançar);
  - `"down"` para escada que desce, como o poço do 2º andar.
- `cobertura`: nó desenhado por cima do Pai só enquanto ele está na escada. Serve para ele sumir atrás da borda de um poço.
- Selecione a escada no editor para ver o caminho (laranja) e a área do pé (verde).
- Se o `destino` estiver vazio, aparece a `mensagem_sem_destino`. É o caso da escadaria para o 3º andar.

## 2º andar (`andares/andar2.tscn`)

O contorno do prédio é o mesmo do 1º andar, mas o miolo foi redesenhado:

| Lugar | O que é |
|---|---|
| **Refúgio** (em cima da sala 1) | A única sala segura, com cama, baú e bilhete. |
| **Laboratório** (em cima da sala de comando) | Arena com 2 criaturas, o desenho do filho e um relatório. A porta fica em outra posição e não há patamar. |
| **Depósito** (sala nordeste) | Caminho opcional: aranha grande, baú e página de receita. |
| **Salão** | Aberto, sem colunas no meio. |
| **Ninho** (sudoeste) | Sala larga e baixa, com portão de grade e 5 aranhas pequenas. |
| **Porão** e **Arena central** (sul) | Atrás de um paredão comprido, cada um com porta própria e ligados por uma porta lateral. |
| **Sala do Feiticeiro espectral** (sudeste) | Entrada pela porta lateral da Arena. O chefão (wizard) e 2 demônios guardam a escadaria para o 3º andar. |

- **Poço da escada:** quem chega do 1º andar sai de um poço no chão, à direita do salão (`mundo/escada/poco.png`). Para voltar, ande até a beira e aperte **baixo**. O Pai desce os degraus, escurece e some atrás da borda; a borda é o nó `cobertura do poco`, que só aparece durante a descida.
- **Iluminação:** penumbra roxa e azul com luzes piscando. A visão base do Pai é 48.

## Decoração do 1º andar

- Objetos recortados do `assets/tile/Tiled_files/Objects.png` (o mesmo pacote das paredes), como `Sprite2D` em `Props` com `region_rect`. A origem fica na base do objeto, para o y-sort.
- Os grandes têm um filho `Colisao` (StaticBody2D) na base; montes de ouro, vasinhos e os escudos na parede não têm.
- **Nome começando com "caixa" ou "barril" = quebrável** (`jogo/quebravel.gd`, solta madeira e às vezes sucata). Os enfeites que não devem quebrar começam com "deco".
- Onde está: Sala de Comando (2 caixas e 1 barril quebráveis: a primeira madeira), Nordeste (depósito de caixas e barris), Sul (tumba com baú aberto, ouro, vasos e escudos), Sudeste (baú fechado, vasos, caixa e barril), Sala da Aranha (caixas e vasos).
- Cuidado ao mover objetos com colisão para muito perto de cantos de parede: a malha de navegação dos monstros é montada ao abrir o andar, e um obstáculo quase encostado num canto pode desligar uma sala da outra. Depois de mudar a decoração, confira se os monstros ainda chegam até o Pai.

## Monstros (`inimigos/`)

- Os monstros posicionados usam `inimigo.gd`:
  - ficam parados até o Pai entrar na sala deles. Fora de salas, até ele chegar a `raio_alerta` **sem parede no meio**; depois perseguem até ele passar de `raio_alerta × multiplicador_perseguicao`;
  - perseguem contornando paredes e móveis pela malha de navegação que o `andares/andar.gd` cria ao abrir o andar (nó `Navegacao`). Sem caminho (Pai atrás de porta fechada), esperam parados;
  - atacam corpo a corpo; criatura mágica e feiticeiro mantêm distância e atiram (`jogo/projetil.gd`). Ninguém ataca através de parede ou porta fechada, nem o Pai;
  - a colisão no chão tem no máximo 8 px de largura (`LARGURA_MAX_COLISAO`), para caberem nos mesmos vãos que o Pai. A malha usa `agent_radius = 5`: se aumentar um, aumente o outro;
  - **em grupo se revezam**: só `MAX_ATACANTES` (1) parte para cima do Pai por vez, durante 2,5 a 4 s depois de chegar perto; os outros rondam em volta dele a `raio_ronda` (48 px) esperando a vez. Ao perceber o Pai, cada um demora 0,2 a 0,9 s para reagir. Quem está rondando ainda se defende se o Pai chegar ao alcance dele. Monstros que atiram de longe ficam fora do revezamento;
  - não se amontoam: cada um empurra os vizinhos que chegam perto demais (`raio_separacao`; 0 = automático pelo tamanho do corpo);
  - **andam sozinhos** pela própria sala enquanto não percebem o Pai, com pausas (grupo **Vagar** no Inspector: `velocidade_vagar`, `pausa_vagar`; fora de salas, até `raio_vagar` de onde nasceram). Vem ligado em todos; desmarque `vagar` para um monstro ficar parado de guarda;
  - vida, dano, velocidade e drops vêm da tabela `Itens.INIMIGOS` pelo `tipo` (campos com 0 usam a tabela);
  - ao morrer soltam materiais e não voltam mais, nem depois que o Pai morre.
- **Materiais no chão** ficam guardados em `Jogo.drops` até o Pai pegar. Se ele morrer ou trocar de andar, eles reaparecem no mesmo lugar.
- **Obstáculos baixos** (grupo `obstaculo_baixo`: piscina, poço, muretas) bloqueiam a passagem, mas não a visão nem os projéteis.

## Câmera (`personagens/pai/camera_pixel.gd`)

- O zoom é ajustado para cada pixel do mundo ocupar um número inteiro de pixels da tela, em qualquer tamanho de janela. A área visível fica perto da de `zoom_base` (3).
- O movimento é suave, mas a posição sempre cai num pixel inteiro da tela. Junto com `snap_2d_transforms_to_pixel` no projeto, isso evita pixels de tamanhos diferentes e cenário tremendo.
- `feiticeiro_espectral.tscn` é o **chefão**: usa os sprites do wizard (`inimigos/wizard/`, cópias com o fundo cinza removido dos arquivos `wizard *.png` originais, hoje em `_nao_usados/wizard original/`; a folha de ataque original vinha ampliada 16x e foi reduzida para 80 px).
- `demonio.tscn` é o **Demônio** (Tiny RPG, `Demon_A`): corpo a corpo, solta fragmento sombrio. Dois guardam a Sala do Feiticeiro.

### Monstros do 1º andar

| Cena | Tipo | Vida / dano | Como luta | Solta |
|---|---|---|---|---|
| `olho_vermelho.tscn` | Olho maligno vermelho | 3 / 2 | voa e chicoteia com a cauda; rápido | osso |
| `olho_azul.tscn` | Olho maligno azul | 4 / 1 | igual, mais lento e resistente | teia |
| `chama_sombria.tscn` | Chama sombria | 5 / 1 | mantém distância e atira bolas de fogo | pó mágico, sucata |

| Sala | Monstros |
|---|---|
| Sala de Comando | nenhum: **o Pai começa aqui**, em frente ao console. Os monitores (`Props/centro-controle`, E: olhar) mostram o filho |
| Sala da Aranha (alavanca) | 3 mini aranhas (aranha pequena em escala 0,6) |
| Sala 1 | nenhum |
| Sala Sul | 3 esqueletos |
| Sala Nordeste | a definir |
| Sala Sudeste | a definir |

Olho vermelho, olho azul e chama sombria têm cena pronta, mas ainda não estão em nenhum andar.

Arte: **Evil Eye | Pixel Monsters Vol. 13** de elesrech (`assets/EvilEye_Pixel_Monsters_Vol_13_COLOR_OUTLINES/`, cores red e blue) e **32x32 Micro Pixel Art - Elemental Monsters Pack** (`assets/32x32_Pixel_Art_Monsters_Pack/`, `03_Shadow_Flame`). As duas licenças permitem uso comercial e pedem crédito opcional. O pacote do Evil Eye também tem as cores green e purple, prontas para virar variações.

## Combate, salas bloqueadas e crafting

| Tecla | Ação |
|---|---|
| WASD ou setas | Andar |
| Clique esquerdo | Atacar na direção do mouse |
| E | Ler / interagir |
| R | Livro de receitas |
| Tab | Inventário |
| 1, 2, 3 | Trocar de arma |
| Q | Usar curativo |

- **Tabelas** (`jogo/itens.gd`): materiais, armas, receitas e monstros. Os números são uma primeira proposta para balancear.
- **Pai** (`personagens/pai/pai.gd`): 10 de vida, ataque em arco com a arma equipada. Qualquer arma pode ser usada a qualquer momento.
- **Salas bloqueadas** (`mundo/salas/sala.gd`): toda sala com `arena = true` tranca as `portas` quando o Pai entra e destranca quando o último monstro dela morre. Vencer a sala vira ponto de salvamento.
- **Morte:** o Pai volta para o último ponto de salvamento (começo do andar ou última sala vencida), com vida cheia e sem perder materiais.
- **Drops:** monstros, caixas e barris soltam materiais; o Pai pega passando por cima. Todo sprite em `Props` cujo nome começa com "caixa" ou "barril" vira quebrável (`jogo/quebravel.gd`).
- **Receitas novas:** um bilhete com o campo `receita` preenchido é uma página do livro (no 2º andar, a página do Depósito libera a Adaga venenosa). Derrotar a criatura mágica libera a Luz reforçada, e o feiticeiro, a Espada espectral.
- **HUD** (`jogo/hud.gd`) e **livro/inventário** (`jogo/livro.gd`) são criados pelo autoload `Jogo`.

## Autoload `Jogo` (`jogo/jogo.gd`)

- Guarda as salas visitadas e a escada de chegada.
- Faz o fade entre andares.
- Mostra:
  - o título do andar;
  - mensagens curtas;
  - a dica "E: ler";
  - o painel de texto dos bilhetes.

## Colisão e ordem de desenho

- **A origem do Pai agora fica nos pés.** O sprite subiu 16 px dentro do `personagens/pai/pai.tscn`.
  - A colisão dele tem 10×5 px, nos pés (antes era 4×2 e ficava abaixo do sprite).
  - Para posicionar o Pai numa cena, use o ponto onde os pés tocam o chão.
- **Móveis sólidos** (mesas, estantes, baús, barris, caixas, cama, caldeirão, vaso, alavanca):
  - cada um ganhou um filho `Colisao` (StaticBody2D) só na base;
  - a origem de cada um foi para a base, sem mudar nada no desenho.
  - Para um móvel novo, faça igual: origem na base (`offset` negativo) e um StaticBody2D com um retângulo na parte de baixo.
- **Salas acendem pela porta:** cada sala tem a lista `portas`. Quando uma dessas portas abre para o Pai, a sala já acende, então ele não entra "embaixo" da escuridão.
- **Ordem de desenho:**
  - a raiz de cada andar tem `y_sort_enabled`, então Pai, monstros e móveis se ordenam pela altura dos pés: quem está mais abaixo aparece na frente;
  - `Map` fica em `z_index = -2`, sempre embaixo;
  - `wall2` (arcos, pilares e muretas) também fica em `z_index = -2`: nenhuma parede cobre o Pai;
  - as portas ficam em `z_index = -1`;
  - tapetes, bilhetes, crânios e poções ficam em `z_index = -1`, no chão.
- **Monstros** (`inimigo.gd`):
  - `altura_pes` põe a origem nos pés;
  - `largura_corpo` cria a colisão do corpo;
  - fantasmas e o feiticeiro não bloqueiam, porque atravessam paredes.
- **Muretas das escadinhas:** as laterais das duas escadinhas com mureta são bloqueadas pelo nó `Colisoes/muretas das escadas`.

## Livro de receitas (`jogo/livro.gd`)

- Arte do **Pixel UI Fantasy Free** (tema parchment), copiada para `addons/pixel_ui_fantasy/`.
  - Licença CC BY 4.0: os créditos do jogo precisam ter a linha
    `Pixel UI Fantasy Free by heyheythere - https://heyheythere.itch.io/pixel-ui-fantasy-free - CC BY 4.0`.
- Página esquerda: lista de receitas (✓ já criada, ! dá para criar, cadeado = não descoberta).
- Página direita: ícone, efeito, materiais (tem/precisa) e o botão Criar.
- Fitas na lateral filtram por categoria (todas, armas, cura, melhorias).
- Teclado: setas cima/baixo escolhem, esquerda/direita trocam a fita, Enter/Espaço criam, R/Esc fecham.
- O livro é desenhado em 428x242 pixels e ampliado pela maior escala inteira que cabe na janela.
