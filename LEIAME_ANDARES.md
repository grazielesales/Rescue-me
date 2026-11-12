# Andares, salas, portas e escadas

Testado no Godot 4.7.1. Comece pelo `tscn/floor.tscn` (1º andar). A escada da direita leva ao `tscn/andar2.tscn`.

## Luz do Pai

- Não existe mais tocha: o Pai tem uma luz fixa que o acompanha (nó `Visao` do `pai.tscn`, degradê suave).
- O raio é `base_vision_radius` (115 no 1º andar, 86 no 2º; o tamanho do antigo círculo da tocha erguida). A melhoria **Luz reforçada** multiplica o raio por `multiplicador_luz_reforcada` (1.3).
- Cor e brilho: `vision_color` e `vision_energy` no nó `pai`.
- O sprite do Pai fica na camada de luz 2 (`light_mask = 2`). Só a luz `Visao` ilumina essa camada (`range_item_cull_mask = 3`). Por isso a luz das salas não soma no Pai e ele tem o mesmo brilho dentro e fora delas.

## Alavanca do 1º andar (`alavanca/alavanca.gd`)

- É o nó `Props/AnimatedSprite2D3`, perto do portão da sala da aranha.
- Chegue perto e aperte **E**: a alavanca vira e levanta o portão, que fica aberto de vez.
- Até lá o portão fica trancado (`trancado = true` no `portao sala aranha`) e avisa que existe uma alavanca.
- Para ligar outra alavanca a outro portão, use o script `alavanca.gd` e aponte o campo `alvo` para um nó que tenha a função `destrancar()`.

## Salas que acendem (`salas/sala.gd`)

- Cada filho do nó **Salas** é uma sala. Ela começa coberta de preto e **acende quando o Pai pisa dentro dela**, depois de passar pela porta.
- A sala fica acesa para sempre, inclusive ao voltar de outro andar. O estado fica no autoload `Jogo`.
- Selecione uma sala no editor para ver os retângulos:
  - amarelo = `areas`, onde o Pai precisa pisar;
  - branco = `luz`;
  - azul = `nevoa`, o que fica preto antes.
- No Inspector: `cor_da_luz`, `energia`, `piscar` (luz tremendo, usada no 2º andar) e `acesa_no_inicio`.
- `arena` e `trancar_ao_entrar` são o encaixe da sala bloqueada do GDD 3.5. As arenas já sabem quais inimigos estão dentro (`inimigos()`). **Trancar ainda não faz nada**, porque o projeto não tem combate.

## Portas (`portas/`)

| Cena | Uso |
|---|---|
| `porta.tscn` | Porta de madeira com animação de 5 quadros. Usa o `tscn/door.gd` de vocês. |
| `portao.tscn` | Portão de grade (`portas/portao.gd`). Destrancado, abre como as portas. Com `trancado`, só abre pela alavanca. |
| `porta_lateral.tscn` | Porta em parede vertical. O sprite é provisório, desenhado por mim. |

**Posição de uma porta comum:** para um vão de 2 tiles nas colunas X e X+1, com o arco na linha L, a posição é `(X*16+16, L*16+19)`.

**Portas novas no 1º andar:**
- sala nordeste;
- 2 portas da sala sul;
- porta lateral da sala sudeste;
- portão da sala da aranha.

O antigo `portao sala 2`, que era só um sprite em loop e não bloqueava nada, ficou **invisível**, não foi apagado.

## Escadas (`escada/escada.gd`)

- No pé da escada, aperte **cima**. O Pai passa a andar pelos degraus seguindo o `caminho`: cima sobe, baixo desce e volta ao chão.
- No topo ele some no escuro, a tela escurece e carrega o `destino`.
- No outro andar, a escada com id igual a `chegada_no_destino` faz o Pai aparecer no fim do caminho e voltar sozinho.
- `animacao_avancar`:
  - `"up"` para escada que sobe (o Pai fica de costas ao avançar);
  - `"down"` para escada que desce, como o poço do 2º andar.
- `cobertura`: nó desenhado por cima do Pai só enquanto ele está na escada. Serve para ele sumir atrás da borda de um poço.
- Selecione a escada no editor para ver o caminho (laranja) e a área do pé (verde).
- Se o `destino` estiver vazio, aparece a `mensagem_sem_destino`. É o caso da escadaria para o 3º andar.

## 2º andar (`tscn/andar2.tscn`)

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

- **Poço da escada:** quem chega do 1º andar sai de um poço no chão, à direita do salão (`escada/poco.png`). Para voltar, ande até a beira e aperte **baixo**. O Pai desce os degraus, escurece e some atrás da borda; a borda é o nó `cobertura do poco`, que só aparece durante a descida.
- **Iluminação:** penumbra roxa e azul com luzes piscando. A visão base do Pai é 48.

## Monstros (`inimigos/`)

- Os monstros posicionados usam `inimigo.gd`:
  - ficam parados até o Pai entrar na sala deles (ou chegar a `raio_alerta`, fora de salas);
  - perseguem e atacam corpo a corpo; criatura mágica e feiticeiro mantêm distância e atiram (`jogo/projetil.gd`);
  - vida, dano, velocidade e drops vêm da tabela `Itens.INIMIGOS` pelo `tipo` (campos com 0 usam a tabela);
  - ao morrer soltam materiais e não voltam mais, nem depois que o Pai morre.
- `feiticeiro_espectral.tscn` é o **chefão**: usa os sprites do wizard (`inimigos/wizard/`, cópias com o fundo cinza removido dos arquivos `wizard *.png` da raiz; a folha de ataque original vinha ampliada 16x e foi reduzida para 80 px).
- `demonio.tscn` é o **Demônio** (Tiny RPG, `Demon_A`): corpo a corpo, solta fragmento sombrio. Dois guardam a Sala do Feiticeiro.

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
- **Pai** (`pai.gd`): 10 de vida, ataque em arco com a arma equipada. Qualquer arma pode ser usada a qualquer momento.
- **Salas bloqueadas** (`salas/sala.gd`): toda sala com `arena = true` tranca as `portas` quando o Pai entra e destranca quando o último monstro dela morre. Vencer a sala vira ponto de salvamento.
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

- **A origem do Pai agora fica nos pés.** O sprite subiu 16 px dentro do `pai.tscn`.
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
