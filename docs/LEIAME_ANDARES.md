# Andares, salas, portas e escadas

Testado no Godot 4.7.1. Comece pelo `andares/andar1.tscn` (1º andar). A escada da direita leva ao `andares/andar2.tscn`.

## Pastas do projeto

| Pasta | O que tem |
|---|---|
| `andares/` | As cenas dos andares (`andar1.tscn`, `andar2.tscn`) e o script da raiz de cada andar (`andar.gd`). |
| `mundo/` | Peças do cenário com comportamento: `agua/` (TileSet animado da piscina), `alavanca/`, `armadilha/` (espinhos), `bruxaria/` (caldeirão e círculo mágico da sala da bruxa), `escada/`, `fosso/` (TileSet do fosso de espinhos), `narrativa/` (bilhetes), `portas/` e `salas/`. |
| `personagens/pai/` | O Pai: cena, script e câmera. |
| `inimigos/` | Cenas dos monstros (`aranha`, `bruxa`, `zumbi`, `esqueleto`, `demonio`, `feiticeiro_espectral`, `frankie`) e o script `inimigo.gd`. |
| `jogo/` | Sistemas globais: autoload `Jogo`, HUD, livro, inventário, tabelas de itens, coletáveis, caixas quebráveis e projéteis. |
| `assets/` | Arte de terceiros. Cada pacote fica inteiro na sua pasta, como veio. |
| `assets/_originais/` | Arquivos que vieram com os pacotes e o jogo não usa (`.unitypackage`, changelog, prévia). |
| `addons/` | Pixel UI Fantasy (tema e ícones do HUD e do livro). |
| `docs/` | Este LEIAME, o `README.pdf` e o `modelo de sala.jpg`. |
| `_nao_usados/` | Arquivos que o jogo não usa (tocha antiga, cenas de teste, imagens soltas, wizard original). Dá para apagar quando quiser. |

Para mover arquivos depois, faça isso **pelo FileSystem do editor do Godot**: ele corrige os caminhos dentro das cenas. Movendo pelo Windows, as cenas podem perder as referências.

## Luz do Pai

- Não existe mais tocha: o Pai tem uma luz fixa que o acompanha (nó `Visao` do `personagens/pai/pai.tscn`, degradê suave).
- O raio é `base_vision_radius` (115 no 1º andar, 86 no 2º; o tamanho do antigo círculo da tocha erguida). A melhoria **Luz reforçada** multiplica o raio por `multiplicador_luz_reforcada` (1.3).
- Cor e brilho: `vision_color` e `vision_energy` no nó `pai`.
- O sprite do Pai fica na camada de luz 2 (`light_mask = 2`). Só a luz `Visao` ilumina essa camada (`range_item_cull_mask = 7`: piso, Pai e telhados). Por isso a luz das salas não soma no Pai e ele tem o mesmo brilho dentro e fora delas.

## Alavanca do 1º andar (`mundo/alavanca/alavanca.gd`)

- É o nó `Props/AnimatedSprite2D3`, na parede da **Sala 1**, atrás da caixa `Props/caixa sala 1` (ao lado do baú).
- **Escondida:** com `escondida_atras` apontando para a caixa, a alavanca fica invisível e não dá para puxar. Quando o Pai quebra a caixa, ela aparece com um brilho e a mensagem "Tinha uma alavanca escondida atrás da caixa!" (`mensagem_revelada`). O `quebravel.gd` ganhou o sinal `quebrou` para isso.
- A caixa quebrada fica no save (como as outras), então ao voltar ao jogo a alavanca já aparece.
- Chegue perto e aperte **E**: a alavanca vira e levanta o portão, que fica aberto de vez.
- Até lá o portão fica trancado (`trancado = true` no `portao sala aranha`) e avisa: "O portão não abre. A alavanca deve estar escondida em algum canto."
- O estado fica no save pela flag `portao_aranha_aberto` (campo `flag` da alavanca): ao voltar ao jogo, a alavanca já aparece puxada e o portão aberto.
- O portão antigo `portao sala 2` é só decoração e fica escondido. O que funciona é o `portao sala aranha`.
- A Sala da Aranha é um beco sem saída: o portão só guarda a própria sala.
- Para ligar outra alavanca a outro portão, use o script `alavanca.gd` e aponte o campo `alvo` para um nó que tenha a função `destrancar()`.

## Salas que acendem (`mundo/salas/sala.gd`)

- Cada filho do nó **Salas** é uma sala. Ela começa coberta por um telhado (`telhado.gd`, com os tiles de teto do pacote das paredes; só a luz do Pai o ilumina) e **acende quando o Pai pisa dentro dela**, depois de passar pela porta.
- A sala fica acesa para sempre, inclusive ao voltar de outro andar. O estado fica no autoload `Jogo`.
- Selecione uma sala no editor para ver os retângulos:
  - amarelo = `areas`, onde o Pai precisa pisar;
  - branco = `luz`;
  - azul = `nevoa`, o que o telhado cobre antes.
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
- Se o `destino` estiver vazio, aparece a `mensagem_sem_destino`. Hoje nenhuma escada usa isso: a escadaria bloqueada do 2º andar (para um 3º andar que não vai existir) saiu junto com a sala do sudeste.

## 2º andar (`andares/andar2.tscn`)

O contorno do prédio é quase o mesmo do 1º andar (sem a sala do sudeste), mas o miolo foi redesenhado. O Pai chega pelo poço, no **leste** (a escada do 1º andar fica no lado direito), e o chefe fica no **norte**, no alto de uma escadinha. As marcas de mãos pequenas perto do poço "seguem para o oeste": é para lá que o filho foi levado.

| Lugar | O que é |
|---|---|
| **Depósito** (nordeste, perto do poço) | Primeira sala, opcional: a aranha grande (solta as presas da Adaga), 2 olhos azuis, baú, materiais e a página de receita da Adaga venenosa. |
| **Laboratório** (sudoeste) | Arena com 2 criaturas, o desenho do filho e o relatório nº 14. |
| **Arena central** (sul) | Arena com 3 esqueletos. A parede leste dela agora é a parede de fora do prédio. |
| **Porão** (sul) | Arena com 3 zumbis e os riscos na parede contando os dias. Separado da Arena por uma parede inteira (a porta lateral saiu). |
| **Salão** | Aberto, sem colunas no meio. |
| **Refúgio** (noroeste) | A única sala segura, com cama, baú e bilhete. Dá para descansar antes do chefe. |
| **Santuário do Feiticeiro** (norte) | Fica mais alto: na frente há um patamar com escadinha (tiles em `Map/sombra` e `Map/escada`, colisão em `Colisoes/patamar do santuario`). Entrada pelo portão de grade (`Props/portao do santuario`); a placa ao lado diz "SÓ LEVA O MENINO QUEM PASSAR POR MIM.". Dentro: o chefão (wizard), 2 demônios, o trono, a mesa de velas e o **filho**, preso numa bolha de magia sobre um círculo mágico. |

- **Sala do sudeste removida:** a sala que foi do chefe e depois do Ninho saiu do andar, junto com as aranhas pequenas, a Aranha-mãe e a escadaria bloqueada. Os tiles dela viraram o bloco escuro de fora (`1,1` da `Map/wall`), e a coluna 21 virou a parede externa (tile `0,1`, com o canto `5,3` embaixo), fechando o vão da antiga porta lateral da Arena.
- **Poço da escada:** quem chega do 1º andar sai de um poço no chão, à direita do salão (`mundo/escada/poco.png`). Para voltar, ande até a beira e aperte **baixo**. O Pai desce os degraus, escurece e some atrás da borda; a borda é o nó `cobertura do poco`, que só aparece durante a descida.
- **Iluminação:** penumbra roxa e azul com luzes piscando. A visão base do Pai é 48.
- **Tochas e janelas da parede** vêm da pasta `assets/tile`, a mesma das paredes (a pasta `Dungeon Free` saiu do projeto):
  - `Props/tocha na parede 1` a `11`: a tocha de tigela de `Tiled_files/fire_animation.png` (colunas 2 e 3, 6 quadros de 48 px, `SpriteFrames_tocha_parede`), com `offset` (-6, 0) para a haste ficar no ponto do nó;
  - `Props/janela gradeada 4` (as 1, 2 e 3 saíram): a janela com grade de `Tiled_files/walls_floor.png`, recorte `Rect2(192, 416, 32, 32)`.

## O filho (`personagens/filho/`)

- Cena `filho.tscn` com o script `filho.gd`. No 2º andar ele é o nó `Entities/filho`, em (8, -30), na ponta leste do Santuário do Feiticeiro, sobre o círculo mágico `Props/circulo do santuario`.
- **Preso:** fica numa bolha de magia roxa (desenhada no `_draw`, com colisão `Bolha`, então o Pai não encosta), meio tingido de roxo. Com **E** ele chama o Pai ("Pai! Eu tô aqui!" e outras falas em `falas_preso`). A luz dele (o dom do filho) é fraca e treme como vela.
- **Livre:** o campo `sala` aponta para `Salas/SalaDoFeiticeiro`. Quando a arena é vencida (sinal `concluiu` do `sala.gd`), a bolha estoura, aparece "A magia que prendia o seu filho se desfez!" e a luz dele cresce. Se a sala já foi vencida no save, ele já começa livre.
- **Reencontro:** livre, **E** ("E: abraçar") mostra o texto `texto_reencontro`. Ao fechar, marca a flag `filho_resgatado` e salva. Depois disso ele só diz "Vamos pra casa, pai.".
- **Próximo passo (fim do jogo):** a fuga depois do chefe e o filho seguindo o Pai. As animações de andar já estão prontas para isso.
- **Arte:** o próprio Pai em versão criança. As folhas do Pai (`assets/Modern tiles_Free/Old/idle_32x32_2.png` e `mv/Character_2_32x32_RPGMAKER.png`) foram reduzidas a 75% e o cabelo virou castanho escuro, em `personagens/filho/filho_parado.png` e `filho_andando.png` (quadros de 24×48). O sprite usa escala 0,5 e `light_mask = 2`, como o Pai, e a luz do filho tem `range_item_cull_mask = 3` para iluminar o próprio sprite (igual à `Visao` do Pai). Animações: `parado`, `parado_lado`, `parado_cima`, `andando`, `andando_lado` e `andando_cima`.

## Decoração do 1º andar

- Objetos recortados do `assets/tile/Tiled_files/Objects.png` (o mesmo pacote das paredes), como `Sprite2D` em `Props` com `region_rect`. A origem fica na base do objeto, para o y-sort.
- Os grandes têm um filho `Colisao` (StaticBody2D) na base; montes de ouro, vasinhos e os escudos na parede não têm.
- **Nome começando com "caixa" ou "barril" = quebrável** (`jogo/quebravel.gd`, solta madeira e às vezes sucata). Os enfeites que não devem quebrar começam com "deco".
- Onde está: Sala de Comando (2 caixas e 1 barril quebráveis: a primeira madeira), Nordeste (sala de bruxaria, ver abaixo; sobraram 1 barril e 1 caixa quebráveis), Sul (tumba com baú aberto, ouro, vasos e escudos), Sudeste (baú fechado, vasos, caixa e barril), Sala da Aranha (caixas e vasos).
- Cuidado ao mover objetos com colisão para muito perto de cantos de parede: a malha de navegação dos monstros é montada ao abrir o andar, e um obstáculo quase encostado num canto pode desligar uma sala da outra. Depois de mudar a decoração, confira se os monstros ainda chegam até o Pai.

## Planta dos salões: sombra, plataformas, braseiros e espinhos

Os dois andares ganharam o visual do mapa de exemplo do pacote de tiles (`assets/tile/Tiled_files/Dungeon1.tmx`). Tudo foi **acrescentado**: nenhum nó antigo mudou.

- **Sombra no piso** (`Map/sombra`, TileMapLayer entre o chão e as paredes, sem colisão):
  - piso mais escuro junto às paredes: 2 células embaixo delas e 1 nas laterais, com bordas arredondadas;
  - rachaduras soltas em grupos de 2×2;
  - os tiles das plataformas elevadas.
  - Tiles: piso escuro em `assets/tile/PNG/walls_floor.png` (colunas 0 a 4, linhas 9 a 11: bordas e cantos internos) e rachaduras em `assets/tile/Tiled_files/decorative_cracks_floor.png` (linhas 12 e 13). Para mudar, pinte nessa camada no editor.
- **Plataformas elevadas** (3×4 tiles, com braseiro em cima): os tiles ficam em `Map/sombra` e a colisão é o nó `Props/plataforma ...`. Para mover, mova os tiles, a colisão e o `braseiro da plataforma ...` juntos.
- **Braseiros** (`Props/braseiro ...`): `fire_animation.png` em 6 quadros, com material Unshaded (o fogo aparece no escuro) e um filho `Luz` (PointLight2D com `luz_oscilante.gd`). Os soltos têm uma colisão pequena na base. Servem de ponto de referência no escuro.
- **Espinhos** (`mundo/armadilha/espinhos.gd`, nós `Props/armadilha ...`):
  - a posição é o canto superior esquerdo e `tamanho` é a área em tiles (mínimo 2×2);
  - ciclo: recolhida (`tempo_recolhida`, 1,6 s) → pontas avisando (`tempo_aviso`, 0,5 s) → erguida (`tempo_erguida`, 0,7 s) → desce;
  - erguida, tira `dano` (1) do Pai e o empurra para fora. Monstros passam por cima sem se machucar;
  - `atraso` desencontra armadilhas vizinhas. No editor elas aparecem com as pontas de fora e um contorno vermelho.
- **Onde ficou cada coisa:**

| Andar | Plataformas | Braseiros soltos | Espinhos | Objetos novos |
|---|---|---|---|---|
| 1º | salão leste (embaixo) | salão oeste, perto da escada | fosso do bolsão oeste (ver abaixo), salão leste, perto da Sala Sudeste | 11 caixas e barris quebráveis, pilhas de caixas, vasos, ouro, escudos na parede; teias, ossos e caveira na Sala da Aranha |
| 2º | 2 no salão | salão (esquerda), perto da arena | salão (esquerda), salão (entre as plataformas), corredor entre o Santuário e o Porão (guarda caixas e barris) | 8 caixas e barris quebráveis, pilha de caixas, vasos, ouro, ossos |

- **Cuidados:**
  - o nó `Props` do 1º andar está em (-327, 150); quem posiciona algo por código precisa descontar isso;
  - no Porão do 2º andar há tiles de piso claro, o (1, 6), pintados na camada `Map/wall`, sem colisão: são chão, não parede.

## Piscina animada do 1º andar (`mundo/agua/agua.tres`)

A água da piscina se mexe sozinha, como no mapa de exemplo do pacote (`Dungeon1.tmx`): 6 quadros de 0,15 s, todos os tiles no mesmo ritmo. Não tem script: são tiles animados do TileSet `mundo/agua/agua.tres`.

- **Três camadas em `Map`**, nesta ordem de desenho (cada uma fica por cima da anterior):

| Camada | O que tem | Fonte do `agua.tres` |
|---|---|---|
| `agua` | fundo parado, inclusive embaixo das margens (a linha d'água tem falhas de 1 px por onde ele aparece) | "margens e fundo", linha 30 |
| `agua_ondas` | reflexos claros que se mexem na superfície, em 5 manchas | "ondas" (`water_details_animation.png`) |
| `agua_margem` | bordas de pedra com a linha d'água animada | "margens e fundo" (`Water_coasts_animation.png`) |

- **Para pintar mais água:**
  - margens: use só o bloco do canto superior esquerdo da folha (colunas 0 a 13, linhas 0 a 9). O resto da folha são os outros quadros da animação, que o Godot reserva e não mostra como tiles soltos;
  - fundo: linha 30 da mesma folha;
  - ondas: linhas 0 a 12 da folha de ondas. Pinte a mancha inteira, sem cortar no meio: os reflexos atravessam vários tiles.
- **Velocidade:** no painel do TileSet, selecione os tiles (dá para selecionar vários) e mude `Animation > Speed`. Com 1, cada quadro dura 0,15 s.
- **Colisão:** continua no nó `Colisoes/piscina`, que cobre só a água. Se a piscina crescer, aumente esse retângulo junto.

## Fosso de espinhos do bolsão oeste (1º andar)

Cópia do fosso do mapa de exemplo do pacote (`Dungeon1.tmx`): um buraco com borda de pedra clara, a parede do fundo com rachaduras e uma escada no meio, espinhos no chão e, lá embaixo, uma chave e dois montes de ouro. Ocupa 5×6 tiles no canto de baixo à esquerda do salão oeste. A escada desce logo abaixo da entrada do bolsão.

| Peça | Onde está |
|---|---|
| Chão escuro do fosso | camada `Map/fosso_fundo` |
| Bordas, parede do fundo e escada | camada `Map/fosso` (TileSet `mundo/fosso/fosso.tres`: paredes e chão de `Tiled_files/walls_floor.png` e as duas folhas de rachaduras) |
| Colisão | `Colisoes/fosso`: as 3 bordas (finas, só a linha clara) e a parede do fundo dos dois lados da escada. **Só dá para entrar pela escada.** |
| Espinhos | `Props/armadilha bolsao oeste`, agora com 3×2, logo no pé da escada |
| Chave e ouro | `Props/chave da tumba` é a chave de verdade: o Pai pega passando por cima e ela abre as portas da Sala Sul (ver a progressão). `deco ouro fosso 1` e `2` são só enfeite. |

- O barril, a caixa e o ouro que já estavam no bolsão ficaram onde estavam, na faixa à esquerda do fosso. Dá para chegar lá pelo beiral entre a parede e o fosso.
- **Para mover o fosso,** mova junto: os tiles das duas camadas, o nó `Colisoes/fosso`, a armadilha e os três enfeites.

## Sala de bruxaria (Sala Nordeste, 1º andar)

A antiga sala dos olhos virou o covil da **bruxa**: o depósito de caixas e os 3 olhos da parede saíram. Os móveis são recortes do Medieval Free Pack, os mesmos do laboratório do 2º andar.

| Peça | Nó em `Props` | Detalhe |
|---|---|---|
| Caldeirão borbulhando | `caldeirao nordeste` | `mundo/bruxaria/caldeirao.gd` desenha a poção verde, as bolhas e o vapor por cima do caldeirão. Tem colisão e uma luz verde que oscila (`Luz`). |
| Círculo mágico | `circulo magico nordeste` | `mundo/bruxaria/circulo_magico.gd`: duas elipses, pentagrama, runas e 5 velas, tudo em pixel art. As linhas pulsam, as chamas tremem e ele brilha no escuro (Unshaded). Fica na frente da porta, sem colisão, com uma luz roxa (`Luz`). No Inspector: `raio`, `achatamento`, `cor`, `velas`. |
| Estantes | `deco estante de pocoes`, `deco estante de frascos` | na parede do fundo, com colisão |
| Mesa de feitiços | `deco mesa de feiticos` | escrivaninha com livro aberto, na parede do fundo |
| Mesa de velas | `deco mesa de velas nordeste` | velas, caveiras e ervas, com luz quente |
| Chão | `deco caveira nordeste`, `deco caveira do circulo`, `deco pocao nordeste`, `deco pergaminho nordeste`, `deco livro de feiticos` | enfeites em `z_index` -1, sem colisão |

- Os dois scripts têm `@tool`: o caldeirão e o círculo aparecem animados também no editor.
- O barril e a caixa quebráveis do canto direito continuaram (a madeira do 1º andar não mudou muito).
- Depois de mexer nos móveis, confira se a bruxa ainda alcança o Pai: o círculo é a entrada da sala.

## Laboratório do Frankie (Sala Sudeste, 1º andar)

A Sala Sudeste continua uma sala comum (paredes e a porta lateral) e virou o **laboratório do Frankie**: o lugar onde ele foi criado. Ele é o mini-chefe da arena (1 Frankie só).

Os móveis são todos da pasta `assets/Demo` (a mesma dos computadores da Sala de Comando), sem script:

| Peça | Nó em `Props` | Arquivo | Onde |
|---|---|---|---|
| Console de laboratório | `deco console do laboratorio` | `Furniture (106).png` | parede do fundo |
| Estante de poções | `deco estante de pocoes lab` | `Furniture (514).png` | parede do fundo |
| Mesa com braço robótico | `deco mesa do braco robotico` | `Furniture (892).png` | parede do fundo |
| Maca médica | `deco maca do laboratorio` | `Furniture (658).png` | em cima da plataforma |
| Tanque de criação | `deco tanque de criacao` | `Furniture (1038).png` | em cima da plataforma |
| Carregador elétrico | `deco carregador eletrico` | `Furniture (640).png` | em cima da plataforma |

- **Plataforma elevada no meio da sala** (o quadrado de chão claro, células 23 a 30 por 13 a 16), igual à do salão leste: 3 fileiras de tampo e 1 de tijolos na frente, com os tiles 0 a 2 x 5 a 8 de `assets/tile/PNG/walls_floor.png` na camada `Map/sombra`.
  - A colisão é o nó `Props/plataforma do laboratorio` (126×58, a plataforma inteira): ninguém sobe nela; a luta é nos corredores em volta (16 px dos lados e na frente, mais largo no fundo).
  - Para mover a plataforma, mova os tiles, a colisão e os três móveis de cima juntos.
- O Frankie começa no corredor da frente, à direita da plataforma.
- **Desafio dos geradores:** o Frankie começa **carregado de energia** (brilho azul): os golpes só fazem um "tink" azul e não tiram vida. Na parede do fundo há duas alavancas, `Props/alavanca do gerador 1` e `2` (E: puxar, `mundo/alavanca/alavanca.gd`, flags `energia_lab_1` e `energia_lab_2`). Com uma puxada aparece "Ainda falta desligar um gerador."; com as duas, "A energia caiu!" e ele passa a levar dano. Então a luta é correr pelo corredor de trás da plataforma até as alavancas, fugindo dele.
- **Recompensa:** vencer o Frankie ensina a receita **Arma eletrificada** (melhoria, 3 sucatas; ele solta 2 sucatas além do fragmento sombrio, então dá para fazer na hora). Com ela, qualquer golpe do Pai dá choque e o monstro fica **atordoado** por `Itens.TEMPO_CHOQUE` (0,6 s): não anda e o ataque que ele preparava não sai.
- A luz da sala é fria e **pisca** (`cor_da_luz` e `piscar` = 0,3 na `SalaSudeste`), como se a energia do laboratório oscilasse.
- Antes disso a sala foi um fosso e depois uma cisterna; o que sobrou disso é o `mundo/portas/grade_escada.gd` (grade de escada que tranca como porta de arena ou com chave), que ficou sem uso.

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
| `bruxa.tscn` | Bruxa | 12 / 1 | mantém distância e lança feitiços verdes | 3 pós mágicos, poção de vida, receita Cajado de fogo |
| `olho_vermelho.tscn` | Olho maligno vermelho | 3 / 1 | fixo na parede, atira e fecha quando o Pai chega perto. **Fora de uso**: saiu da Sala Nordeste | pó mágico |
| `olho_azul.tscn` | Olho maligno azul | 4 / 1 | voa e chicoteia com a cauda | teia |
| `frankie.tscn` (com `inimigo.gd` na instância) | Frankie | 22 / 2 | mini-chefe do laboratório: carregado até o Pai desligar os 2 geradores; lento, bate de perto; abaixo da metade da vida fica furioso (1,7x mais rápido) | fragmento sombrio, 2 sucatas, poção de vida, receita Arma eletrificada |
| `chama_sombria.tscn` | Chama sombria | 18 / 2 | mantém distância e atira bolas de fogo. **Fora de uso**: o Frankie ficou no lugar dela na Sala Sudeste | fragmento sombrio |

| Sala | Monstros |
|---|---|
| Sala de Comando | nenhum: **o Pai começa aqui**, em frente ao console. Os monitores (`Props/centro-controle`, E: olhar) mostram o filho e têm um brilho azul que oscila de leve (`BrilhoMonitores`, `mundo/salas/luz_oscilante.gd`) |
| Sala da Aranha (alavanca) | 3 mini aranhas (aranha pequena em escala 0,6) |
| Sala 1 | nenhum. O bilhete `Props/bilhete curativo` ensina a receita de curativo |
| Sala Sul (tumba) | 3 esqueletos que só **aparecem** quando o baú abre. As portas pedem a chave do fosso |
| Sala Nordeste | a **Bruxa**, na sala de bruxaria. A porta abre só com a chave |
| Sala Sudeste | **Frankie**, mini-chefe da arena, no laboratório. Vencer libera a escada |

### Arma certa para cada monstro do 1º andar

Nenhum monstro morre com 1 golpe, nem com a arma mais forte contra ele (por isso a aranha pequena tem vida 9 e o esqueleto, 12). Cada monstro tem uma fraqueza: a arma dele tem `bonus` contra aquele `tipo` (campo `bonus` em `Itens.ARMAS`; o Pai soma o bônus ao dano no golpe).

| Monstro | Arma mais forte | Dano contra ele | Como conseguir a arma |
|---|---|---|---|
| Aranha pequena (vida 9) | Porrete de madeira | 3 + 2 = 5 (2 golpes; as outras armas, 3) | já vem no livro: 3 madeiras |
| Esqueleto (vida 12) | Clava de osso | 4 + 3 = 7 (2 golpes; as outras armas, 4) | já vem no livro: 3 ossos + 2 madeiras |
| Bruxa (vida 12) | Lança de teia | 3 + 3 = 6 (2 golpes; a clava, 3; as outras, 4) | já vem no livro: **3 teias** (era 4; o andar só tem 3 aranhas) + 2 madeiras + 1 sucata |
| Frankie (vida 22) | Cajado de fogo | 3 + 4 = 7 (4 golpes; a clava, 6; as outras, 8) | a **Bruxa ensina** ao morrer: 2 pós mágicos + 2 madeiras (ela solta 3 pós) |

O Cajado de fogo usa `assets/staffs/6.png`. A ordem natural é: aranhas → teias → lança → Bruxa → cajado → Frankie.

### Arma certa para cada monstro do 2º andar

Mesma regra do 1º andar: a arma forte mata em 2 golpes e as outras armas da época em 3 ou mais. Para isso, as vidas da Aranha grande (8 → 9), da Criatura mágica (5 → 9), do Zumbi (8 → 12) e do Demônio (10 → 13) subiram em `Itens.INIMIGOS`.

| Monstro | Arma mais forte | Dano contra ele | Como conseguir a arma |
|---|---|---|---|
| Aranha grande (vida 9) | Adaga venenosa | 2 + 3 = 5, mais veneno (2 golpes; clava e espada, 3) | página no Depósito; a aranha grande solta 2 presas (garantidas) |
| Criatura mágica (vida 9) | Lança de teia | 3 + 2 = 5 (2 golpes; clava, 3) | já vem no livro |
| Esqueleto (vida 12) | Clava de osso | 4 + 3 = 7 (2 golpes) | já vem no livro |
| Zumbi (vida 12) | Machado sombrio | 6 + 3 = 9, golpe em área (2 golpes; clava e espada, 3) | página no Porão: 1 fragmento + 3 ossos + 2 sucatas |
| Demônio (vida 13) | Espada espectral | 4 + 3 = 7 (2 golpes; machado e lâmina, 3) | página na Arena central; os 4 ectoplasmas vêm do baú do Depósito |
| Feiticeiro espectral (vida 20) | Lâmina de luz | 6 + 2 = 8 (3 golpes; machado, 4; espada, 5) | página no Refúgio; o baú do Refúgio completa os materiais |

- A Espada **não** tem bônus contra o Feiticeiro: com ela antes do chefe, a luta ficaria fácil demais.
- O livro de receitas e o inventário mostram "Forte contra" lendo o `bonus` de `Itens.ARMAS`. Mudou o bônus, mudou o texto. O `efeito` das receitas não repete a fraqueza.

### Baús (`mundo/bau/bau.gd`, campo `itens`)

O baú solta sempre os mesmos itens no chão, à frente dele, ao abrir com **E**. Eles fecham a conta das receitas que o mapa sozinho não paga. A flag de cada baú vai no save (aberto continua aberto).

| Baú | Itens | Para quê | Flag |
|---|---|---|---|
| Sala 1 (1º andar) | 2 teias, 1 maçã | o andar só tem 3 teias e a Lança gasta as 3: sem o baú não sobra para o curativo | `bau_sala1_aberto` |
| Depósito (2º andar) | 4 ectoplasmas | Espada espectral (antes, o único ectoplasma era o do chefe) | `bau_deposito_aberto` |
| Refúgio (2º andar) | 1 ectoplasma, 2 fragmentos, 1 pó mágico | o que falta para a Lâmina de luz antes do chefe | `bau_refugio_aberto` |

- Mensagem vazia com `itens` = o baú lista o que saiu ("No baú: 2 Teia resistente, 1 Maçã.").
- O baú da Sala 1 deixou de ser a animação em laço: é um `Sprite2D` com os quadros fechado e aberto da mesma folha (`assets/tile/PNG/doors_lever_chest_animation.png`).

| Quem | Cura que solta |
|---|---|
| Caixas e barris | maçã (20%) |
| Aranha pequena | maçã (30%) |
| Esqueleto | poção de vida (34%) |
| Bruxa e Frankie | poção de vida (sempre) |

## Projéteis (`jogo/projetil.gd`)

A Area2D do projétil só percebe o que se move (o Pai e os monstros). Para que ele pare em paredes de tile e em móveis, um raio curto testa, a cada quadro, o caminho do ponto atual até o próximo. Piscina, poço e muretas continuam sendo atravessados.

## Progressão do 1º andar (flags do Jogo)

| Passo | Onde | Como funciona |
|---|---|---|
| 1 | Sala de Comando | O Pai começa **sem arma**, com socos (dano 1, alcance curto). Os socos quebram caixas e barris, que dão madeira. O **Porrete de madeira** (dano 3, 3 madeiras) já vem no livro. |
| 2 | Sala 1 | O bilhete ensina o **curativo** (deixou de ser receita inicial). |
| 3 | Sala 1 → Sala da Aranha | Quebrar a caixa ao lado do baú, na Sala 1, revela a alavanca, que levanta o portão (flag `portao_aranha_aberto`). |
| 4 | Fosso do bolsão oeste | A chave no fundo do fosso (`Props/chave da tumba`, `mundo/bau/chave_no_chao.gd`) é pega passando por cima, depois dos espinhos. Dá a flag `chave_tumba` e salva na hora. |
| 5 | Sala Sul | As duas portas (`porta sala sul oeste` e `leste`) têm `flag_necessaria = "chave_tumba"`: sem a chave do fosso, mostram "Trancada. A chave deve estar em algum lugar perigoso.". |
| 6 | Sala Sul | O baú `Props/bau tumba` (`mundo/bau/bau.gd`, E: abrir) dá as flags `tumba_aberta` e `chave_nordeste` e mostra "Você encontrou uma chave enferrujada.". Só então os 3 esqueletos **aparecem** (`flag_aparecer` no `inimigo.gd`: até lá ficam invisíveis, sem colisão e sem levar golpe) e acordam. `tumba_aberta` também ativa a arena (`flag_para_ativar` no `sala.gd`). |
| 7 | Sala Nordeste | A porta (`flag_necessaria = "chave_nordeste"` no `porta.gd`) mostra "Trancada. Precisa de uma chave." até o Pai ter a chave. Trancada, ela não acende a sala. |
| 8 | Sala Sudeste | Arena com `flag_ao_vencer = "escada_liberada"`: o Frankie só leva dano depois das duas alavancas dos geradores; matá-lo libera a escada e ensina a Arma eletrificada. Sem monstros, ela contaria como vencida quando o Pai entrasse. |
| 9 | Escada | `flag_necessaria = "escada_liberada"` no `escada.gd`. Antes disso aparece "Algo sombrio bloqueia a passagem.". |

- Alavanca, baú e arena vencida **salvam na hora** (`Jogo.salvar_progresso()`).
- Um monstro dormindo também acorda se levar um golpe. Um monstro com `flag_aparecer` não pode levar golpe antes de aparecer.
- Os exports novos servem para qualquer sala, porta, escada ou monstro: basta preencher o nome da flag no Inspetor.
- **Arte:** o porrete é `assets/staffs/7.png` (32 px, encolhido para o tamanho dos outros ícones). O baú (fechado e aberto) e a chave são recortes de `assets/tile/Tiled_files/Objects.png`.

Os olhos azuis têm cena pronta e vão para o 2º andar.

### Bruxa (Nordeste) e Frankie (Sudeste)

Tudo fica no `inimigo.gd` e os números ficam em `Itens.INIMIGOS`, para ajustar.

- **Bruxa** (`inimigos/bruxa.tscn`): vida 12, dano 1. Fica a `distancia` (64 px) do Pai e lança um feitiço verde (`cor_projetil`, `velocidade_projetil` 75) a cada `recarga` (1,6 s) quando vê o Pai na sala acesa.
  - Antes de o Pai entrar, ela anda pela sala entre o caldeirão e as estantes.
  - Drop: **3 pós mágicos**, o mesmo que os 3 olhos que ela substituiu soltavam somados (o pó mágico é usado na Luz reforçada e na Lâmina de luz).
  - Pés em (172, -48), ao lado do caldeirão.
  - Animações: a folha tem as 4 direções, mas o `inimigo.gd` só espelha para os lados. Por isso a cena usa as linhas viradas para a direita (parada 3, andando 7, ataque 15) e a morte (linha 16). Não tem animação de dano: ela só pisca vermelho. Na linha 17 da folha ainda sobram efeitos (chama azul, clarão e anéis) para usar depois.
- **Olho maligno vermelho** (`fixo`, fora de uso desde que a bruxa entrou): não anda. Atira um projétil lento e **fecha** por `tempo_fechado` (2,5 s) quando o Pai chega a `distancia_fechar` (28 px). Fechado, fica invulnerável. A cena continua pronta para outra sala.
- **Frankie** (mini-chefe do laboratório; ver o desafio dos geradores na seção do laboratório): a cena `inimigos/frankie.tscn` (a mesma das criaturas do Laboratório do 2º andar) com o `inimigo.gd` e `tipo = "Frankie"` na instância `Entities/frankie SalaSudeste`. Vida 22, dano 2, no tamanho natural da folha (sem `escala`).
  - Lento (26), bate de perto (`alcance` 18) a cada 1,3 s.
  - Abaixo de `furia_vida` (50%): fica 1,7x mais rápido e bate mais vezes. Não deixa rastro (sem `rastro_dano` na tabela, a fúria só acelera).
  - Drop: fragmento sombrio. A morte dele vence a arena e dá `escada_liberada`.
  - A cena ganhou as animações `hurt` (linha 4 da folha) e `death` (linha 5: ele pega fogo, vira esqueleto e cinzas), e o ataque ficou mais rápido (8 quadros/s). Isso vale também para as 2 criaturas do 2º andar, que usam a mesma cena.
- **Chama Sombria** (fora de uso desde que o Frankie entrou; a cena continua pronta): vida 18, `escala` 1,5. Mantém distância e atira.
  - O projétil que acerta **apaga a luz do Pai** por `apagar_luz` (3 s), com `pai.apagar_luz()`. As luzes da sala continuam.
  - Abaixo de `furia_vida` (50%): fica 1,6x mais rápida, atira mais e deixa um **rastro de fogo** (`RastroFogo`, no fim do `inimigo.gd`). O rastro é a própria chama sombria em miniatura, que dá `rastro_dano` a quem pisar e some em `rastro_duracao` (3 s).
  - Drop: fragmento sombrio.

Arte: **Evil Eye | Pixel Monsters Vol. 13** de elesrech (`assets/EvilEye_Pixel_Monsters_Vol_13_COLOR_OUTLINES/`, cores red e blue) e **32x32 Micro Pixel Art - Elemental Monsters Pack** (`assets/32x32_Pixel_Art_Monsters_Pack/`, `03_Shadow_Flame`). As duas licenças permitem uso comercial e pedem crédito opcional. O pacote do Evil Eye também tem as cores green e purple, prontas para virar variações.

A bruxa é a **Wizard sheet** de GandalfHardcore (`bruxa/Wizard sheet.png`, quadros de 48×48). A licença permite usar e modificar em jogos, inclusive comerciais, mas proíbe redistribuir os arquivos do pacote. Pela regra das pastas, a pasta `bruxa/` pode ir para `assets/bruxa/`. Mova pelo FileSystem do Godot, para a `inimigos/bruxa.tscn` acompanhar.

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
- **Cura no chão** (`Itens.CURAS`): a **maçã** (cura 1) e a **poção de vida** (cura 3) curam na hora em que o Pai passa por cima e não vão para o inventário (`coletavel.gd` chama `pai.curar()`). O curativo continua sendo feito no livro e usado com Q. Sprites: `assets/itens-armas/warrior-items__asset.png`.
- **Receitas novas:** um bilhete com o campo `receita` preenchido é uma página do livro. No 2º andar: Adaga venenosa (Depósito), Machado sombrio (Porão), Espada espectral (Arena central) e Lâmina de luz (Refúgio). Derrotar a criatura mágica libera a Luz reforçada.
- **Livro de receitas:** a página da direita mostra o dano (e o dano por segundo), o alcance e a abertura do golpe, o veneno, contra quem a arma é forte e a diferença de dano por segundo para a arma equipada (verde = melhor). Em cada material que falta aparece de onde ele vem (`onde` em `Itens.MATERIAIS`). Quando não cabe tudo, a página rola (roda do mouse ou PgUp/PgDn) e uma setinha avisa.
- **HUD** (`jogo/hud.gd`) e **livro/inventário** (`jogo/livro.gd`) são criados pelo autoload `Jogo`.

## Autoload `Jogo` (`jogo/jogo.gd`)

- Guarda as salas visitadas e a escada de chegada.
- Faz o fade entre andares.
- Mostra:
  - o título do andar;
  - mensagens curtas;
  - a dica "E: ler";
  - o painel de texto dos bilhetes.

## Save (`jogo/jogo.gd`)

- Arquivo: `user://save.json` (no Windows, `%APPDATA%\Godot\app_userdata\RescueMe\save.json`). É JSON legível.
- Guarda: inventário, armas, atalhos (slots e o atual), curativos, receitas, melhorias, monstros e caixas destruídos, salas visitadas e vencidas, tipos derrotados, materiais no chão, `flags` e o checkpoint.
- **Quando grava:**
  - sempre que o checkpoint muda (`Jogo.definir_checkpoint()`): primeira entrada num andar, chegada por escada e sala-arena vencida;
  - ao fechar a janela. O Pai volta ao último checkpoint, mas o que ele pegou depois disso fica.
- **Ao abrir o jogo:** se houver save, continua dele. Se o checkpoint for de outro andar, o jogo já abre nesse andar. Rodar uma cena solta (F6) carrega o estado, mas não troca de andar.
- **Novo jogo:** ainda não há tela inicial. Em desenvolvimento, **Ctrl+Shift+N** apaga o save e recomeça no 1º andar. Esse atalho não existe no jogo exportado.
- **Flags:** `Jogo.set_flag("alavanca_porao", true)` e `Jogo.get_flag("alavanca_porao", false)`. Use valores simples (bool, número ou texto). Elas entram no próximo save.
- **Versão:** `VERSAO_SAVE` (hoje 1). Um save de versão mais nova que o jogo não é carregado nem apagado. Para mudar o formato, suba a versão e trate a diferença em `_migrar_save()`.
- Um save ilegível não trava o jogo: ele começa do zero e avisa no console.

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
- Página esquerda: lista de **todas** as receitas do jogo (✓ já criada, ! dá para criar). As não descobertas aparecem com o nome, mas apagadas: ícone cinza e transparente (`COR_BLOQUEADA`), texto fraco e cadeado.
- Página direita: ícone, efeito, materiais (tem/precisa) e o botão Criar. Numa receita não descoberta, no lugar do botão aparece "Ainda não descoberta" e a dica de como liberar: "Derrote: <monstro>" (campo `receita` em `Itens.INIMIGOS`) ou "Procure a página perdida nos andares." (bilhete).
- `Jogo.pode_criar()` só aceita receitas descobertas, então ter os materiais não basta.
- Fitas na lateral filtram por categoria (todas, armas, cura, melhorias).
- Teclado: setas cima/baixo escolhem, esquerda/direita trocam a fita, Enter/Espaço criam, R/Esc fecham.
- O livro é desenhado em 428x242 pixels e ampliado pela maior escala inteira que cabe na janela.
