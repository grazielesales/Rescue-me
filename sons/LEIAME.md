# Sons

Efeitos sonoros do jogo (ainda sem música). Todos são `.wav` mono de 44,1 kHz,
gerados por síntese em `gerador/gerar_sons.gd`. Nada foi baixado, então não há
licença de terceiros.

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

Depois abra o editor (ou rode com `--headless --import`) para importar.
