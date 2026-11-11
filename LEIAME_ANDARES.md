# Andares, salas, portas e escadas

Testado no Godot 4.7.1. Comece pelo `tscn/floor.tscn` (1º andar). A escada da direita leva ao `tscn/andar2.tscn`.

## Tocha

- A tocha acesa usa uma textura de luz própria, com **6 camadas**. É o `GradientTexture2D_tocha` no `pai.tscn`, ligado no campo **Torch Light Texture** do nó `pai`.
- Para mudar as camadas, edite o Gradient dessa textura. Cada ponto é uma camada; mantenha **Interpolation = Constant**, 256×256 e preenchimento radial.
- Sem tocha, continua valendo a textura do nó `Visao`.
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
| **Sala do Feiticeiro espectral** (sudeste) | Entrada pela porta lateral da Arena. Guarda a escadaria para o 3º andar. |

- **Poço da escada:** quem chega do 1º andar sai de um poço no chão, à direita do salão (`escada/poco.png`). Para voltar, ande até a beira e aperte **baixo**. O Pai desce os degraus, escurece e some atrás da borda; a borda é o nó `cobertura do poco`, que só aparece durante a descida.
- **Iluminação:** penumbra roxa e azul com luzes piscando. A visão base do Pai é 48.

## Monstros (`inimigos/`)

- Os monstros posicionados usam `inimigo.gd`, que só faz três coisas:
  - coloca o monstro no grupo `inimigos`;
  - toca uma animação parada;
  - guarda o `tipo` e a `reacao_a_tocha` do GDD.
- Quem fizer o combate chama `morrer()`.
- `fantasma.tscn` foi feito a partir do `fantasma.gif`, que o Godot não importa.
- `feiticeiro_espectral.tscn` é um **placeholder**: o fantasma maior, roxo e com brilho.

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
