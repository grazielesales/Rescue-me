# Tocha e visão do Pai

**Segure T** para erguer a tocha. Sem ela, a visão é um círculo de 40 px; com ela, 64 px (+60% de raio).

## O que mudou no projeto

| Arquivo | Mudança |
|---|---|
| `pai.gd` | Lógica da tocha/visão. Movimento e animação continuam iguais. Removido o `print` do vetor de input, que rodava a cada frame. |
| `pai.tscn` | Novos nós `Tocha` (sprite animado da chama) e `Visao` (`PointLight2D`). Corrigido o `idle_side`, que olhava para o lado oposto do `walk_side`. |
| `tscn/floor.tscn` | Novo nó `Escuridao` (`CanvasModulate`): é ele que deixa a cena escura. |
| `project.godot` | Ação `torch` (tecla T) e fundo preto fora do mapa. |
| `tocha/tocha.png` | Sprite da tocha, 4 frames de 10×28 px, na mesma densidade do sprite do Pai. |

## Ajustes no Inspector do `pai`

- `base_vision_radius` (40): visão sem tocha. Diminua a cada andar (GDD 5.2).
- `torch_vision_multiplier` (1.6): +60% de **raio**, o que faz a área crescer 2,56×. Para +60% de **área**, use 1.265.
- `hold_to_raise` (ligado): segurar T, como no GDD 3.3. Desligado, T alterna.
- `torch_speed_multiplier` (0.75): anda mais devagar com a tocha (GDD 3.3).
- A cor do escuro fica no nó `Escuridao` do `floor.tscn`.

## Para os outros sistemas

```gdscript
var pai = get_tree().get_first_node_in_group("player")
pai.torch_changed             # sinal (raised: bool)
pai.is_torch_raised()         # fantasma atraído / aranha foge (GDD 6.1)
pai.is_point_visible(pos)     # monstro dentro do círculo de visão?
pai.get_vision_radius()
pai.can_use_two_handed()      # false com a tocha erguida (GDD 3.3)
```

## Pendências

- **A luz atravessa paredes.** Para a luz parar nas paredes, ligue `shadow_enabled` no nó `Visao` e desenhe polígonos de oclusão no TileSet (aba Occlusion Layers). Desenhe só no **topo** das paredes, nunca na face de tijolos: senão a face fica preta mesmo iluminada.
- **Velas e fogueiras ficam escuras.** Se elas devem brilhar, use um `CanvasItemMaterial` com `light_mode = Unshaded` no sprite, ou dê uma `PointLight2D` pequena a cada uma.
