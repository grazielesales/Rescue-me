# Sons

Efeitos sonoros e músicas do jogo. Todos são `.wav` mono (efeitos a 44,1 kHz,
músicas a 22,05 kHz), gerados por síntese em `gerador/gerar_sons.gd`. Nada foi
baixado, então não há licença de terceiros.

## Música

`musica/<andar>_ambiente.wav` e `musica/<andar>_tensao.wav`: 32 s em laço,
mesmo tom e mesmos acordes. O autoload `Musica` (`jogo/musica.gd`) toca as
duas juntas e só muda o volume: a tensa entra quando o Pai está numa sala com
monstro acordado (ou numa arena trancada) e sai uns segundos depois que a sala
esvazia. O `andar.gd` escolhe a música pelo nome da cena (`andar1` →
`andar1_*.wav`); para outro nome, preencha `musica` no nó raiz do andar.

`musica/filho_perdido.wav`: lamento de ~30 s, sem laço, que toca uma vez
quando a luz do filho apaga (`Musica.tocar_lamento()`, chamado pelo `Jogo`).
Caixinha de música em ré menor que vai perdendo a corda.

Para trocar por músicas de verdade: grave os dois arquivos com o mesmo tamanho
e o laço marcado (ou marque *Loop Mode: Forward* na importação do Godot).

## Como o jogo toca os sons

O autoload `Som` (`jogo/som.gd`) toca pelo nome, que é o caminho dentro desta
pasta sem o `.wav`:

```gdscript
Som.tocar("pai/dano")                                  # sem posição (Pai, interface)
Som.tocar_em("inimigos/aranha_morte", global_position)  # no mundo: mais baixo longe da câmera
```

- **Variações:** `passo_1.wav`, `passo_2.wav`... são sorteadas quando o código
  pede `"pai/passo"`. Para ter mais variações, é só criar `passo_5.wav`.
- Cada vez o tom varia um pouquinho, e o mesmo som não toca mais de 3 vezes junto.
- Barramentos (`default_bus_layout.tres`): **Efeitos** para estes sons e
  **Musica**, já reservado para a música.

## Pastas

| Pasta | O que tem |
| --- | --- |
| `pai/` | passos (4 variações), dano (2), morte, cura |
| `armas/` | golpe no ar de cada arma (nome = id em `Itens.ARMAS`), impacto (2), bloqueado ("tink"), choque, veneno |
| `inimigos/` | `<família>_ataque`, `_dano`, `_morte` por família + `furia` e `projetil_impacto` |
| `mundo/` | portas, portão, alavanca, baú, chave, item, caixas, espinhos, arena, bilhete, bolha do filho, receita nova |
| `interface/` | livro, inventário, mover seleção, criar, erro, equipar |

Famílias de monstros (campo `"som"` em `Itens.INIMIGOS`): `aranha`, `esqueleto`,
`zumbi`, `olho`, `bruxa`, `chama`, `frankie`, `fantasma`, `magico`, `demonio`,
`feiticeiro`. Monstro sem o campo, ou família sem algum arquivo, usa `generico_*`.
Monstros maiores (escala do nó) soam mais graves.

## Trocar ou ajustar um som

- **Trocar por um gravado/baixado:** substitua o `.wav` com o mesmo nome e
  apague a linha dele no gerador (senão a próxima geração sobrescreve).
- **Ajustar o sintetizado:** edite o som em `gerador/gerar_sons.gd` (o segundo
  número de `salvar(...)` é o volume relativo) e gere de novo:

```powershell
& "<pasta do Godot>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://sons/gerador/gerar_sons.gd
```

Acrescente ` -- musica` no fim para gerar só as músicas, ou ` -- efeitos` para
só os efeitos. Depois abra o editor (ou rode com `--headless --import`) para importar.
