# Pixel UI Fantasy

An RPG pixel-art GUI skin for Godot 4.3+: themes as ready-made `Theme` resources with trimmed
windows, rarity item slots, skill frames, orbs, portrait frames and character portraits, a quick-pick wheel, nameplates, ribbons, a parchment
scroll and bar frames, plus coloured item and skill icons, bar and orb fills, a cooldown sweep, a
cursor and the Quill bitmap font. Every image is also a
plain PNG, with its 9-slice margins listed for any other engine.

**The full pack:** **[Pixel UI Fantasy](https://heyheythere.itch.io/pixel-ui-fantasy)** has six themes (parchment,
leather, iron, gilded, elven and arcane), 8 character portraits, 64 skill icons in eight schools, and 76 item icons
(weapons and armour in bronze, gold and moonsteel, rings, amulets, food, herbs, spellbooks, runes,
crowns, maps, torches and a full menu set), and the pieces a game's screens need: menu lines,
save slots, item slots with counts, key caps, switches, steppers and toasts. Same files and names: install it over this one.

## Use it in Godot

1. Copy `addons/pixel_ui_fantasy/` into your project.
2. Project Settings:
   - *Rendering > Textures > Default Texture Filter*: **Nearest**, or the pixels blur.
   - *GUI > Theme > Custom*: `res://addons/pixel_ui_fantasy/themes/gilded.tres` (or any theme),
     so every Control uses it. Or set `theme` on one Control and its children follow.
3. Draw the UI at a whole-number scale. The art is 1x (the font is 10px on a 13px line), made for
   a UI about 360 pixels high: set *Display > Window > Stretch > Mode* to `canvas_items` and either
   use a small viewport (for example 640x360), or keep yours and set
   `get_tree().root.content_scale_factor` to 2 or 3, as `demo/demo.gd` does.

## Themes

Each `themes/<name>.tres` styles Button, OptionButton, CheckBox (check and radio), Label, Panel,
PanelContainer, LineEdit, HSlider, ProgressBar, TabContainer, PopupMenu, tooltips, scroll bars and
HSeparator (an ornamental divider). Set `theme_type_variation` for the extras:

| Variation | On | Looks like |
|---|---|---|
| `WindowPanel` | PanelContainer | a window with a title bar; its first line of content sits in the bar |
| `Title` | Label | the text for that title bar |
| `InsetPanel` | PanelContainer | a sunken item slot, 24x24 around a 16px icon |
| `CommonSlot`, `UncommonSlot`, `RareSlot`, `EpicSlot`, `LegendarySlot` | PanelContainer | the slot rimmed and lit in its rarity's colour (grey, green, blue, purple, orange) |
| `SkillSlot`, `ActiveSkillSlot` | PanelContainer | a 20x20 frame round a 16px skill icon; the active one lit in the theme's gem |
| `PortraitPanel` | PanelContainer | a heavy riveted frame for a face or a big icon, 8px in from each side |
| `ParchmentPanel` | PanelContainer | a paper scroll between two wooden rolls, the same in every theme |
| `Ink` | Label | dark text for the parchment |
| `Nameplate` | Label | text on a trim-coloured plate |
| `Ribbon` | Label | text on a banner with forked tails |
| `RedBar`, `BlueBar`, `GreenBar`, `GoldBar` | ProgressBar | health, mana, stamina and experience fills |
| `MenuItem` | Button | a line of a menu: its band and pointer show when hovered or pressed (`toggle_mode` keeps one picked) |
| `SaveSlot` | Button | a save or level slot for an icon and two lines, lit when picked |
| `ItemSlot`, `ItemSlotSelected` | PanelContainer | a 24x24 slot round a 16px item, and the picked one |
| `Count` | Label | white shadowed text for a slot's corner: a stack's count, a hotbar key |
| `KeyCap` | Label | a key on its cap, for prompts and key bindings |
| `ToastPanel` | PanelContainer | a notice: an icon and a line |
| `StepLeft`, `StepRight` | Button | the arrows of a `< value >` stepper (no text) |

CheckButton is drawn as a toggle switch, a CheckBox's height, so a settings list can mix them.
The rows from `MenuItem` down and the switch are the game pieces of the full kit (the free sampler's
theme has none); `demo/demo.gd`'s menus and play screens put them together.

A window: PanelContainer (`WindowPanel`) > VBoxContainer > Label (`Title`) first, then the content.
The shared variation names are the same as in Pixel UI and Pixel UI Sci-Fi, so a project can
switch between the kits by switching its theme.

## Orbs and cooldowns

An orb is a TextureProgressBar: *Fill Mode* **Bottom to Top**, *Under* `themes/<name>/orb.png`
(the ring and its dark well, 40x40), *Progress* `bars/orb_red.png` (or `_blue`, `_green`, 32x32)
with *Progress Offset* (4, 4), and *Over* `bars/orb_glass.png`.

A quick-pick wheel is `themes/<name>/wheel.png` (141x141) under eight 24x24 slots 64 pixels out
from its centre pixel, (70, 70), at the angles halfway between its spokes; the hub, 72 across,
takes the picked item's name. `demo/demo.gd`'s `_radial()` lays one out.

A cooldown is a TextureProgressBar over a skill icon: *Fill Mode* **Clockwise**, *Progress*
`bars/cooldown.png`, its value the share of the cooldown left. `demo/demo.gd`'s `orb()` and
`_casting()` build both.

## Icons

The icons are coloured, with a dark outline. The themes leave Button icons untinted (and fade them
when disabled).

- `icons/*.png`: the items. The sword, axe, dagger, hammer, helmet and chestplate also come in three
  tiers, `<item>_bronze`, `<item>_gold` and `<item>_moonsteel`.
- `icons/skills/<school>_<skill>.png`: framed ability squares, every skill (bolt, nova, ward, mend,
  strike, rain, aura, summon) in every school (fire, frost, storm, nature, holy, shadow, arcane,
  might). Every school's bolt is its own.

Each folder's `_sheet.png` has its icons on one 8-column sheet.

## Portraits

`portraits/*.png` are 32x32 busts, lit from the top left like the icons, made to sit in a
`PortraitPanel` at 1x: `aria` (the hero), `sage`, `brannoc` (a smith), `rogue`, `ranger` (an elf),
`troll`, `queen` and `lich`. `demo/demo.gd`'s `portrait()` frames one.

## Other engines

Every part is a PNG in `themes/<name>/`. `themes/slices.json` lists each one's 9-slice borders
(left, top, right, bottom, in pixels; the same in every theme):

| Parts | Borders |
|---|---|
| `button_*`, `panel_inset`, `slot_*` | 5, 5, 5, 5 |
| `panel` | 6, 6, 6, 6, with the grainy middle **tiled**, not stretched |
| `window` | 6, 19, 6, 6 (the title bar is rows 4 to 16), middle tiled |
| `parchment` | 6, 9, 6, 9, middle tiled |
| `portrait` | 9, 9, 9, 9 |
| `skill_slot`, `skill_slot_active` | 3, 3, 3, 3 |
| `nameplate` | 5, 4, 5, 4 |
| `ribbon` | 9, 3, 9, 5 |
| `divider` | 8, 0, 8, 0 (7 rows tall) |
| `focus` | 4, 4, 4, 4 |
| `line_edit` | 4, 4, 4, 4 |
| `progress_bg` | 4, 3, 4, 3 |
| `progress_fill`, `bars/bar_*` | 5, 2, 5, 2, drawn over the whole bar: their colour sits inside `progress_bg`'s frame |
| `tooltip` | 3, 3, 3, 3 |
| `slider`, `slider_fill` | 3, 2, 3, 2 |
| `tab_selected` | 4, 4, 4, 1 |
| `tab_unselected`, `tab_hover` | 4, 5, 4, 2 |
| `scroll*`, `menu_hover` | 2, 2, 2, 2 |
| `slot_selected` | 5, 5, 5, 5 |
| `key` | 4, 4, 4, 5 |
| `toast` | 6, 4, 4, 4 |

The rest are drawn as they are: `checkbox_*` and `radio_*` (11x11), `switch_*` (21x11),
`grabber*` (7x11), `arrow` (the option button's, 7x4), `pointer` (5x7), `step_*` (4x7), `orb`
(40x40) and `wheel` (141x141).

## Files

- `themes/<name>.tres` and `themes/<name>/*.png`: the Theme and its parts.
- `icons/*.png`: 16x16, coloured, outlined, on a transparent background; `icons/skills/*.png`: 16x16
  squares.
- `portraits/*.png`: 32x32 character busts on a transparent background.
- `bars/bar_*.png`: the bar fills; `bars/orb_*.png` and `bars/cooldown.png`: the orb's fills and
  glint, and the cooldown's shadow.
- `cursor.png` and `cursor_2x/3x/4x.png`: a gold pointer, hotspot at the top-left pixel. The OS
  draws cursors unscaled, so pick the copy that matches your UI scale for *Display > Mouse Cursor >
  Custom Image*.
- `font/pixel_ui_fantasy_font.fnt`: Quill, a proportional serif BMFont with printable ASCII and
  Latin-1, 10px on a 13px line. Keep it at size 10 and scale the UI instead.
