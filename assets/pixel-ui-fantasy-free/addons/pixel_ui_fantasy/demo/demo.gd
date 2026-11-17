extends Control
## The kit in use, five RPG screens of plain Controls styled by one Theme: an adventure (the hero's
## portrait and bars, settings, an inventory of rarity slots, a quest scroll, a hotbar, dialogue), a
## spellbook (skills by school, health and mana orbs, a hotbar cooling down), a smithy (tiered gear
## set against what the hero wears), the menus (pause, settings with switches and steppers, key
## bindings, save slots, a confirm box) and play (a bag and its item card, toasts, a radial quick
## menu, a hotbar, key prompts, dialogue). The buttons along the bottom swap the theme and the screen;
## ? shows again the card it opens with, saying how to use it.

const KIT := "res://addons/pixel_ui_fantasy/"
const ALL_THEMES: Array[String] = ["parchment", "leather", "iron", "gilded", "elven", "arcane"]
const ART_HEIGHT := 360.0
const FIRST := "gilded"
const SCREENS: Array[String] = ["adventure", "spells", "shop", "menus", "play"]
const SCREEN_ICONS := {"adventure": "quest", "spells": "spellbook", "shop": "coin", "menus": "gear", "play": "pouch"}
const HELP: Array[String] = [
	"The buttons at the bottom left change the theme, those at the bottom right the screen: an adventure, a spellbook, a smithy, the menus and play.",
	"Arrow keys or a pad move, Enter picks; or use the mouse.",
	"Point at a skill in the spellbook to read it, and at the smith's wares to weigh them against what you wear.",
	"? brings this card back.",
]
const SCHOOLS: Array[String] = ["fire", "frost", "storm", "nature", "holy", "shadow", "arcane", "might"]
const SKILLS: Array[String] = ["bolt", "nova", "ward", "mend", "strike", "rain", "aura", "summon"]
const DOES := {"bolt": "Hurls a bolt of %s at one foe.", "nova": "A burst of %s strikes every foe around you.",
	"ward": "A shield of %s soaks up the next blows.", "mend": "%s knits your wounds over time.",
	"strike": "Your next blow carries %s.", "rain": "%s falls on an area for a few seconds.",
	"aura": "Allies near you gain the strength of %s.", "summon": "Calls a spirit of %s to fight beside you."}
const ELEMENT := {"fire": "flame", "frost": "ice", "storm": "lightning", "nature": "thorns", "holy": "light",
	"shadow": "shadow", "arcane": "arcane force", "might": "steel"}
## A gear tier's rarity, and its attack (or armour) and price over the plain item's.
const TIERS := {"": ["common", 1.0, 1.0], "bronze": ["uncommon", 1.5, 2.5], "gold": ["rare", 2.2, 6.0],
	"moonsteel": ["epic", 3.2, 15.0]}
const GEAR := {"sword": ["Attack", 8, 40], "axe": ["Attack", 10, 45], "dagger": ["Attack", 5, 25],
	"hammer": ["Attack", 12, 55], "helmet": ["Armour", 3, 30], "chestplate": ["Armour", 7, 60]}
const RARITY_INK := {"common": Color("9e9e9e"), "uncommon": Color("5ac860"), "rare": Color("4892f0"),
	"epic": Color("b060e8")}

## Store capture only: switch to the next theme every this many frames.
@export var cycle_frames := 0
## The screen to open on, and the theme to open in when not FIRST.
@export_enum("adventure", "spells", "shop", "menus", "play") var screen := "adventure"
@export var first_theme := ""

var frame := 0
var theme_buttons := {}
var pages := {}
var page: Control
var cooldowns: Array[TextureProgressBar] = []
var cooling: Array[float] = []  # each one's time to go, past 100 a rest with it ready
var picked: PanelContainer
var details: VBoxContainer
var compare: VBoxContainer
var help: Control
var opened: Button


## Draws the UI at a whole-number scale so the art pixels stay square: the largest that still
## fits `art_height` pixels of art on screen.
static func pixel_scale(node: Node, art_height: float) -> void:
	var window := node.get_tree().root
	window.content_scale_factor = 1.0
	window.content_scale_factor = maxf(1.0, floorf(window.get_visible_rect().size.y / art_height))


static func themes() -> Array[String]:
	var installed: Array[String] = []
	for n in ALL_THEMES:
		if ResourceLoader.exists(KIT + "themes/%s.tres" % n):
			installed.append(n)
	return installed


## The named theme, or the first one installed.
static func kit_theme(name: String) -> Theme:
	return load(KIT + "themes/%s.tres" % (name if name in themes() else themes()[0]))


## Null when the icon isn't installed. Skill icons are "skills/<school>_<skill>".
static func icon_texture(name: String) -> Texture2D:
	var path := KIT + "icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func icon(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## The installed skill icons' names, school by school.
static func skills() -> Array[String]:
	var installed: Array[String] = []
	for school in SCHOOLS:
		for s in SKILLS:
			if icon_texture("skills/%s_%s" % [school, s]):
				installed.append("%s_%s" % [school, s])
	return installed


## A titled window; add its content to the returned VBox.
static func window(parent: Control, title: String, at: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = at
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"Title"
	box.add_child(label)
	return box


static func row(parent: Control, separation := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


static func bar(parent: Control, colour: String, value: float, width: float) -> ProgressBar:
	var b := ProgressBar.new()
	if colour != "":
		b.theme_type_variation = StringName(colour + "Bar")
	b.show_percentage = false
	b.value = value
	b.custom_minimum_size = Vector2(width, 10)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


static func slider(parent: Control, label: String, value: float, width := 42.0) -> void:
	var r := row(parent)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = width
	r.add_child(l)
	var s := HSlider.new()
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(s)


static func label(parent: Control, text: String, variation := &"") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	parent.add_child(l)
	return l


## A 24x24 item slot (`rarity` "" for a plain one) holding an icon and a count above 1.
static func slot(parent: Control, item: String, count := 1, rarity := "") -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = StringName(rarity.capitalize() + "Slot") if rarity else &"InsetPanel"
	s.custom_minimum_size = Vector2(24, 24)
	parent.add_child(s)
	if item == "" or icon_texture(item) == null:
		return s
	var art := icon(item)
	s.tooltip_text = item.capitalize()
	s.add_child(art)
	if count > 1:
		var n := Label.new()
		n.text = str(count)
		n.add_theme_color_override("font_color", Color.WHITE)
		n.add_theme_color_override("font_shadow_color", Color.BLACK)
		art.add_child(n)
		n.position = Vector2(19, 6) - Vector2(n.get_minimum_size().x, 0)
	return s


## Whether the theme has the game pieces (MenuItem, ItemSlot, KeyCap ...): the free sampler's hasn't.
static func has_game_pieces(t: Theme) -> bool:
	return t.get_type_variation_base(&"KeyCap") == &"Label"


## A line of a menu: the band and pointer show on the one picked (pressed in its ButtonGroup).
static func menu_item(parent: Control, text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"MenuItem"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_group = group
	parent.add_child(b)
	return b


## A toggle switch, its text on the left and the switch at the right end.
static func switch(parent: Control, text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	parent.add_child(c)
	return c


## A label, then < value > stepping through the options.
static func stepper(parent: Control, text: String, options: Array, index: int, width := 42.0) -> Label:
	var r := row(parent, 2)
	label(r, text).custom_minimum_size.x = width
	var left := Button.new()
	left.theme_type_variation = &"StepLeft"
	r.add_child(left)
	var value := label(r, options[index])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := Button.new()
	right.theme_type_variation = &"StepRight"
	r.add_child(right)
	var step := func(by: int) -> void:
		value.text = options[(options.find(value.text) + by + options.size()) % options.size()]
	left.pressed.connect(step.bind(-1))
	right.pressed.connect(step.bind(1))
	return value


## Keys on their caps, then what they do.
static func prompt(parent: Control, keys: Array, text: String) -> HBoxContainer:
	var r := row(parent, 2)
	for k in keys:
		label(r, k, &"KeyCap")
	if text != "":
		label(r, text).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## A 24x24 ItemSlot (ItemSlotSelected when `picked`) with the item's icon and its count above 1.
static func item_slot(parent: Control, item: String, count := 1, picked := false) -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = &"ItemSlotSelected" if picked else &"ItemSlot"
	s.custom_minimum_size = Vector2(24, 24)
	parent.add_child(s)
	if item == "" or icon_texture(item) == null:
		return s
	var art := icon(item)
	s.tooltip_text = item.capitalize()
	s.add_child(art)
	if count > 1:
		var n := label(art, str(count), &"Count")
		n.position = Vector2(19, 6) - Vector2(n.get_minimum_size().x, 0)
	return s


## A notice: an icon and a line in a ToastPanel.
static func toast(parent: Control, item: String, text: String) -> PanelContainer:
	var t := PanelContainer.new()
	t.theme_type_variation = &"ToastPanel"
	parent.add_child(t)
	var r := row(t, 4)
	r.add_child(icon(item))
	label(r, text).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## A 20x20 skill frame (`SkillSlot`) round a skill icon, or empty for "".
static func skill(parent: Control, name: String) -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = &"SkillSlot"
	s.custom_minimum_size = Vector2(20, 20)
	parent.add_child(s)
	if name != "":
		s.add_child(icon("skills/" + name))
		s.tooltip_text = name.capitalize()
	return s


## A 40x40 orb filled `value` percent from the bottom with a bars/orb_<colour>.png, glinting under
## bars/orb_glass.png, in the ring of whichever kit theme it is under.
static func orb(parent: Control, colour: String, value: float) -> TextureProgressBar:
	var o := TextureProgressBar.new()
	o.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	o.texture_progress = load(KIT + "bars/orb_%s.png" % colour)
	o.texture_progress_offset = Vector2(4, 4)
	o.texture_over = load(KIT + "bars/orb_glass.png")
	o.value = value
	o.theme_changed.connect(func() -> void: o.texture_under = theme_art(o, "orb.png"))
	parent.add_child(o)
	return o


## A character's 32x32 portrait (portraits/<who>.png) in the portrait frame, 48x48 in all; or the
## icon `who` names, else the icon `stand_in`, at twice its size.
static func portrait(parent: Control, who: String, stand_in := "helmet") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"PortraitPanel"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var path := KIT + "portraits/%s.png" % who
	var face := icon(who if icon_texture(who) else stand_in)
	if ResourceLoader.exists(path):
		face.texture = load(path)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(32, 32)
	p.add_child(face)
	parent.add_child(p)
	return p


## A picture of whichever kit theme `c` is under: its themes/<theme>/`file`, beside the theme's portrait.png.
static func theme_art(c: Control, file: String) -> Texture2D:
	var frame := c.get_theme_stylebox(&"panel", &"PortraitPanel") as StyleBoxTexture
	if frame == null or frame.texture == null:
		return null
	var path := frame.texture.resource_path.get_base_dir().path_join(file)
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # project.godot's, for a project without it
	pixel_scale(self, ART_HEIGHT)
	add_child(Backdrop.new())
	var first := first_theme if first_theme != "" else FIRST
	theme = kit_theme(first)
	var shown := SCREENS.filter(func(s: String) -> bool: return has_game_pieces(theme) or s not in ["menus", "play"])
	for s in shown:
		pages[s] = Control.new()
		pages[s].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages[s].mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pages[s])
	page = pages["adventure"]
	_hud()
	_settings()
	_inventory()
	_hotbar()
	_quests()
	_dialogue()
	page = pages["spells"]
	_spellbook()
	_effects()
	_casting()
	page = pages["shop"]
	_purse()
	_wares()
	_bag()
	_smith()
	if "menus" in pages:
		page = pages["menus"]
		_menus()
		page = pages["play"]
		_play()
	var switcher := row(self, 3)
	switcher.position = Vector2(6, 334)
	var group := ButtonGroup.new()
	for name in themes():
		var b := Button.new()
		b.text = name.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = name == kit_theme(first).resource_path.get_file().get_basename()
		b.toggled.connect(func(on: bool) -> void:
			if on:
				theme = kit_theme(name))
		switcher.add_child(b)
		theme_buttons[name] = b
	var ask := Button.new()
	ask.text = "?"
	ask.tooltip_text = "How to use this demo"
	ask.pressed.connect(func() -> void: show_help(true))
	switcher.add_child(ask)
	var screens := row(self, 3)
	var screen_group := ButtonGroup.new()
	for s in shown:  # named while open, an icon (and a tooltip) otherwise, to share the line with the themes
		var b := Button.new()
		b.icon = icon_texture(SCREEN_ICONS[s])
		b.tooltip_text = s.capitalize()
		b.toggle_mode = true
		b.button_group = screen_group
		b.toggled.connect(func(on: bool) -> void:
			b.text = s.capitalize() if on else ""
			if on:
				_show(s))
		b.button_pressed = s == screen
		screens.add_child(b)
		if b.button_pressed:
			opened = b
	screens.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	screens.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_show(screen if screen in pages else "adventure")
	help = _help()
	show_help(Engine.get_write_movie_path() == "" and cycle_frames <= 0)  # the store's shots go without it


## The opening card: the sage's welcome and how to use the demo, over the screens until Start or Esc.
func _help() -> Control:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var box := window(veil, "How to use this demo", Vector2.ZERO, 300)
	var top := row(box, 6)
	portrait(top, "sage", "scroll")
	var hello := label(top, "Welcome, traveller. Every window\nhere is Godot's own Controls,\nstyled by one Theme.")
	hello.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for t in HELP:
		var l := label(box, t)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = 288
	var start := Button.new()
	start.text = "Start"
	start.custom_minimum_size.x = 60
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(func() -> void: show_help(false))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:  # keys stay on the card while it is up
		start.set_focus_neighbor(side, ^".")
	start.focus_next = ^"."
	start.focus_previous = ^"."
	box.add_child(start)
	var panel: Control = box.get_parent()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	veil.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed(&"ui_cancel"):
			show_help(false))
	return veil


func show_help(on: bool) -> void:
	help.visible = on
	if on:
		(help.find_children("*", "Button", true, false)[0] as Button).grab_focus()
	elif opened:
		opened.grab_focus()  # keys and a pad work before any click


func _show(which: String) -> void:
	for s in pages:
		pages[s].visible = s == which


func _process(delta: float) -> void:
	for i in cooldowns.size():  # each hotbar skill comes round at its own pace, with a rest between
		cooling[i] = fposmod(cooling[i] - delta * 100.0 / (2.0 + i), 160.0)
		cooldowns[i].value = cooling[i] if cooling[i] <= 100.0 else 0.0
	if cycle_frames <= 0:
		return
	frame += 1
	if frame % cycle_frames == 0:
		var names := themes()
		var start := first_theme if first_theme != "" else FIRST
		var next: String = names[(maxi(0, names.find(start)) + frame / cycle_frames) % names.size()]
		theme_buttons[next].button_pressed = true


func _hud() -> void:
	var top := row(page, 4)
	top.position = Vector2(6, 6)
	portrait(top, "aria")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	top.add_child(rows)
	label(rows, "Aria  Lv 7", &"Nameplate")
	for pair in [["heart", "Red", 72], ["mana", "Blue", 48], ["xp", "Gold", 64]]:
		var r := row(rows, 2)
		r.add_child(icon(pair[0]))
		bar(r, pair[1], pair[2], 96)
	_purse()


func _purse() -> void:
	var purse := PanelContainer.new()
	page.add_child(purse)
	var money := row(purse, 2)
	for pair in [["coin", "1250"], ["gem", "12"], ["key", "3"]]:
		money.add_child(icon(pair[0]))
		label(money, pair[1]).custom_minimum_size.x = 28
	purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)


func _settings() -> void:
	var box := window(page, "Settings", Vector2(6, 76), 166)
	slider(box, "Music", 70)
	slider(box, "Sound", 45)
	var hints := CheckBox.new()
	hints.text = "Show hints"
	hints.button_pressed = true
	box.add_child(hints)
	var group := ButtonGroup.new()
	var modes := row(box, 6)
	for m in ["Classic", "Heroic"]:
		var radio := CheckBox.new()
		radio.text = m
		radio.button_group = group
		radio.button_pressed = m == "Heroic"
		modes.add_child(radio)
	var speed := OptionButton.new()
	for s in ["Text: normal", "Text: fast", "Text: instant"]:
		speed.add_item(s)
	box.add_child(speed)
	var hero := LineEdit.new()
	hero.placeholder_text = "Hero name"
	box.add_child(hero)
	var buttons := row(box)
	for t in ["Back", "Apply"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _inventory() -> void:
	var box := window(page, "Inventory", Vector2(178, 30), 256)
	var tabs := TabContainer.new()
	box.add_child(tabs)
	var bag := GridContainer.new()
	bag.name = "Bag"
	bag.columns = 9
	bag.add_theme_constant_override("h_separation", 2)
	bag.add_theme_constant_override("v_separation", 2)
	tabs.add_child(bag)
	var items := [["sword", 1, "rare"], ["shield", 1, "uncommon"], ["bow", 1, "common"], ["staff", 1, "epic"],
		["amulet", 1, "legendary"], ["ring", 1, "rare"], ["potion_red", 5, "common"], ["potion_blue", 3, "common"],
		["potion_green", 2, "uncommon"], ["bread", 4, "common"], ["meat", 2, "common"], ["herb", 9, "common"],
		["mushroom", 3, "uncommon"], ["scroll", 2, "rare"], ["gem", 12, "epic"], ["key", 1, "common"],
		["apple", 6, "common"], ["", 1, ""]]
	for it in items:
		var shown: bool = it[0] != "" and icon_texture(it[0]) != null
		slot(bag, it[0] if shown else "", it[1], it[2] if shown else "")
	var gear := VBoxContainer.new()
	gear.name = "Gear"
	tabs.add_child(gear)
	for pair in [["helmet", "Iron helm", "+4"], ["chestplate", "Knight's plate", "+9"], ["boots", "Swift boots", "+2"]]:
		var r := row(gear)
		slot(r, pair[0])
		var l := label(r, pair[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(r, pair[2])
	box.add_child(HSeparator.new())
	var weight := row(box)
	weight.add_child(icon("pouch"))
	label(weight, "Weight 34/50")
	bar(weight, "Green", 68, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := row(box)
	for pair in [["check", "Use"], ["cross", "Drop"], ["quest", "Info"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)


func _hotbar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(183, 198)
	page.add_child(panel)
	var r := row(panel, 2)
	var keys := ["sword", "bow", "fireball", "frost", "lightning", "potion_red", "potion_blue", "torch", "map"]
	for i in keys.size():
		_key(slot(r, keys[i]), i + 1)


## The hotkey's number in a slot's corner.
func _key(s: Control, n: int) -> void:
	var l := Label.new()
	l.text = str(n)
	l.position = Vector2(3, -1)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	s.add_child(l)
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)


func _quests() -> void:
	var scroll := PanelContainer.new()
	scroll.theme_type_variation = &"ParchmentPanel"
	scroll.position = Vector2(442, 42)
	scroll.custom_minimum_size.x = 192
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)
	var head := label(box, "Quest Log", &"Ribbon")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for q in [["check", "Find the lost key"], ["check", "Light the old beacon"], ["quest", "Slay the swamp troll"],
			["quest", "Return to the sage"], ["lock", "The sunken crypt"]]:
		var r := row(box, 3)
		r.add_child(icon(q[0]))
		label(r, q[1], &"Ink")
	label(box, "Reward: 300 gold", &"Ink").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## A line of dialogue across the bottom, a portrait beside it.
func _speech(face: String, who: String, line: String) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 262)
	panel.custom_minimum_size.x = 628
	page.add_child(panel)
	var r := row(panel, 6)
	portrait(r, face, "scroll")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(box)
	label(box, who, &"Ribbon").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(box, line)
	var next := Button.new()
	next.icon = icon_texture("arrow_right")
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(next)


func _dialogue() -> void:
	_speech("sage", "Old Sage",
		"The troll guards the bridge by night. Take this torch,\nand the frost scroll: fire alone won't do.")


## Every installed skill, a row per school; pointing at one shows it in the details window.
func _spellbook() -> void:
	var box := window(page, "Spellbook", Vector2(6, 6), 0)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var known := skills()
	for school in SCHOOLS:
		if not known.any(func(n: String) -> bool: return n.begins_with(school + "_")):
			continue
		label(grid, school.capitalize()).custom_minimum_size.x = 38
		for s in SKILLS:
			var name := "%s_%s" % [school, s]
			var cell := skill(grid, name if name in known else "")
			if name in known:
				cell.mouse_entered.connect(_pick.bind(cell, name))
	details = window(page, "Skill", Vector2(250, 6), 190)
	if not known.is_empty():
		_pick(grid.get_child(1) as PanelContainer, known[0])


## Shows a skill in the details window and lights its frame.
func _pick(cell: PanelContainer, name: String) -> void:
	if picked:
		picked.theme_type_variation = &"SkillSlot"
	picked = cell
	cell.theme_type_variation = &"ActiveSkillSlot"
	for c in details.get_children().slice(1):
		c.queue_free()
	var school := name.get_slice("_", 0)
	var kind := name.get_slice("_", 1)
	var level := SKILLS.find(kind)
	var top := row(details, 6)
	portrait(top, "skills/" + name)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 1)
	top.add_child(titles)
	label(titles, name.capitalize(), &"Ribbon").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(titles, "%s school" % school.capitalize())
	label(titles, "Rank %d / 5" % (level % 5 + 1))
	var text: String = DOES[kind] % ELEMENT[school]
	var about := label(details, text[0].to_upper() + text.substr(1))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size.x = 176
	for pair in [["mana", "%d mana" % (8 + level * 4)], ["hourglass", "%ds cooldown" % (2 + level * 3)]]:
		var r := row(details, 3)
		r.add_child(icon(pair[0]))
		label(r, pair[1])
	details.add_child(HSeparator.new())
	var buttons := row(details)
	for pair in [["plus", "Learn"], ["arrow_down", "Assign"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _effects() -> void:
	var box := window(page, "Effects", Vector2(446, 6), 188)
	var known := skills()
	var shown := 0
	for pair in [["holy_ward", 80], ["nature_mend", 55], ["might_aura", 30], ["fire_ward", 90], ["fire_aura", 45],
			["fire_mend", 60]]:
		if pair[0] not in known or shown == 4:
			continue
		shown += 1
		var r := row(box, 4)
		skill(r, pair[0])
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(lines)
		label(lines, pair[0].capitalize())
		bar(lines, "Gold", pair[1], 0)
	box.add_child(HSeparator.new())
	var points := row(box, 3)
	points.add_child(icon("xp"))
	label(points, "Skill points: 3")


## The orbs either side of a hotbar of skills cooling down, and a spell being cast above it.
func _casting() -> void:
	var known := skills()
	var keys: Array[String] = []
	for name in ["fire_bolt", "frost_nova", "storm_bolt", "holy_mend", "shadow_strike", "nature_rain", "arcane_summon",
			"might_ward"]:
		if name in known:
			keys.append(name)
	for name in known:
		if keys.size() < 8 and name not in keys:
			keys.append(name)
	var cast := VBoxContainer.new()
	cast.add_theme_constant_override("separation", 0)
	cast.position = Vector2(226, 232)
	cast.custom_minimum_size.x = 188
	page.add_child(cast)
	label(cast, "Casting %s" % (keys[1].capitalize() if keys.size() > 1 else "...")) \
		.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar(cast, "Blue", 62, 0)
	var line := row(page, 6)
	line.position = Vector2(174, 258)
	_meter(line, "red", 76, "heart", "152/200")
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(panel)
	var r := row(panel, 2)
	for i in 8:
		var s := skill(r, keys[i] if i < keys.size() else "")
		if i < keys.size():
			var c := TextureProgressBar.new()
			c.fill_mode = TextureProgressBar.FILL_CLOCKWISE
			c.texture_progress = load(KIT + "bars/cooldown.png")
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(c)
			cooldowns.append(c)
			cooling.append(150.0 - i * 37)
		_key(s, i + 1)
	_meter(line, "blue", 48, "mana", "96/200")


## An orb with its amount under it.
func _meter(parent: Control, colour: String, value: float, sign: String, amount: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	orb(box, colour, value).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r := row(box, 1)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_child(icon(sign))
	label(r, amount)


## The smith's wares, every tier installed by kind, priced; pointing at one weighs it.
func _wares() -> void:
	var box := window(page, "Brannoc's Smithy", Vector2(6, 6), 290)
	var tabs := TabContainer.new()
	box.add_child(tabs)
	for tab in [["Weapons", ["sword", "axe", "dagger", "hammer"]], ["Armour", ["helmet", "chestplate"]]]:
		var grid := GridContainer.new()
		grid.name = tab[0]
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 2)
		tabs.add_child(grid)
		for tier in ["moonsteel", "gold", "bronze", ""]:
			for item: String in tab[1]:
				var name: String = item + ("_" + tier if tier else "")
				if icon_texture(name) == null or grid.get_child_count() >= 12:
					continue
				var r := row(grid, 4)
				r.mouse_filter = Control.MOUSE_FILTER_STOP
				slot(r, name, 1, TIERS[tier][0])
				var lines := VBoxContainer.new()
				lines.add_theme_constant_override("separation", -1)
				r.add_child(lines)
				label(lines, _title(name))
				var price := row(lines, 2)
				price.add_child(icon("coin"))
				label(price, str(_price(name)))
				r.mouse_entered.connect(_weigh.bind(name))
	compare = window(page, "Compare", Vector2(327, 30), 160)
	for name in ["sword_moonsteel", "sword"]:
		if icon_texture(name):
			_weigh(name)
			break


func _tier(name: String) -> String:
	return name.get_slice("_", 1) if "_" in name else ""


func _title(name: String) -> String:
	var item: String = {"chestplate": "plate"}.get(name.get_slice("_", 0), name.get_slice("_", 0))
	return ("%s %s" % [_tier(name), item] if _tier(name) else "Iron " + item).capitalize()


func _stat(name: String) -> int:
	return roundi(GEAR[name.get_slice("_", 0)][1] * TIERS[_tier(name)][1])


## Moonsteel is light, gold heavy.
func _weight(name: String) -> int:
	return 4 + GEAR[name.get_slice("_", 0)][1] / 2 + {"": 0, "bronze": 1, "gold": 3, "moonsteel": -1}[_tier(name)]


func _price(name: String) -> int:
	return roundi(GEAR[name.get_slice("_", 0)][2] * TIERS[_tier(name)][2])


## Sets an item against the hero's own of its kind.
func _weigh(name: String) -> void:
	for c in compare.get_children().slice(1):
		c.queue_free()
	var item := name.get_slice("_", 0)
	var rarity: String = TIERS[_tier(name)][0]
	var worn: String = item if item in ["helmet", "chestplate"] else "sword"
	label(compare, _title(name), &"Nameplate").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var top := row(compare, 5)
	slot(top, name, 1, rarity)
	var kind := label(top, rarity.capitalize())
	kind.add_theme_color_override("font_color", RARITY_INK[rarity])
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for pair in [[GEAR[item][0], _stat(name), _stat(worn)], ["Weight", _weight(name), _weight(worn)]]:
		var r := row(compare, 3)
		label(r, pair[0]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(r, str(pair[1]))
		var gain: int = pair[1] - pair[2]
		var d := label(r, ("+%d" % gain if gain > 0 else str(gain)) if gain else "=")
		d.custom_minimum_size.x = 22
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if gain:
			var better := gain > 0 if pair[0] != "Weight" else gain < 0
			d.add_theme_color_override("font_color", Color("6ee070") if better else Color("f06058"))
	var on := row(compare, 3)
	label(on, "Worn: " + _title(worn)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on.add_child(icon(worn))
	compare.add_child(HSeparator.new())
	var buy := Button.new()
	buy.text = "Buy  %d" % _price(name)
	buy.icon = icon_texture("coin")
	compare.add_child(buy)


func _bag() -> void:
	var box := window(page, "Your bag", Vector2.ZERO, 0)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for it in [["sword", 1, "common"], ["helmet", 1, "common"], ["shield", 1, "uncommon"], ["potion_red", 4, "common"],
			["gem", 12, "epic"], ["ring", 1, "rare"], ["bread", 3, "common"], ["meat", 2, "common"], ["herb", 6, "common"],
			["", 1, ""]]:
		var shown: bool = it[0] != "" and icon_texture(it[0]) != null
		slot(grid, it[0] if shown else "", it[1], it[2] if shown else "")
	var buttons := row(box)
	for pair in [["coin", "Sell"], ["gear", "Repair"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	var panel: Control = box.get_parent()  # under the purse, at the right edge
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	panel.offset_top = 30


func _smith() -> void:
	_speech("brannoc", "Brannoc the Smith",
		"Moonsteel keeps its edge through dragonfire. Bronze is for\npractice, and gold is for show.")


func _menus() -> void:
	var pause := window(page, "Paused", Vector2(6, 6), 120)
	var group := ButtonGroup.new()
	for t in ["Resume", "Save", "Load", "Settings", "Controls", "Quit"]:
		menu_item(pause, t, group).button_pressed = t == "Settings"
	var quit := window(page, "Quit?", Vector2(6, 150), 120)
	label(quit, "Progress since the\nlast save will be\nlost.")
	var answer := row(quit)
	for t in ["Yes", "No"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer.add_child(b)

	var box := window(page, "Settings", Vector2(132, 6), 220)
	slider(box, "Music", 70, 60)
	slider(box, "Sound", 40, 60)
	switch(box, "Vsync", true)
	switch(box, "Subtitles", false)
	stepper(box, "Difficulty", ["Easy", "Normal", "Hard"], 1, 60)
	stepper(box, "Window", ["Windowed", "Fullscreen", "Borderless"], 1, 60)
	box.add_child(HSeparator.new())
	var buttons := row(box)
	for t in ["Back", "Apply"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)

	var rebind := window(page, "Press a key", Vector2(132, 210), 220)
	label(rebind, "Press a key for Attack").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt(rebind, ["Esc"], "Cancel").alignment = BoxContainer.ALIGNMENT_CENTER

	var keys := window(page, "Controls", Vector2(358, 6), 276)
	for pair in [["Move", ["W", "A", "S", "D"]], ["Attack", ["Space"]], ["Use", ["E"]], ["Spells", ["1", "2", "3"]],
			["Pause", ["Esc"]]]:
		var r := row(keys, 2)
		label(r, pair[0]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prompt(r, pair[1], "")

	var saves := window(page, "Load game", Vector2(358, 150), 276)
	var picked_save := ButtonGroup.new()
	for s in [["crown", "Castle Varn", "Aria  Lv 7   12h 40m"], ["skull", "The Sunken Crypt", "Aria  Lv 5   8h 02m"],
			["plus", "New game", ""]]:
		var b := Button.new()
		b.theme_type_variation = &"SaveSlot"
		b.text = s[1] + "\n" + s[2]
		b.icon = icon_texture(s[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_group = picked_save
		b.button_pressed = s[1] == "Castle Varn"
		saves.add_child(b)


func _play() -> void:
	var bag := window(page, "Bag", Vector2(6, 6), 0)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	bag.add_child(grid)
	var stock := [["sword", 1], ["potion_blue", 3], ["shield", 1], ["bread", 5], ["herb", 9], ["key", 2], ["gem", 12],
		["potion_red", 2], ["ring", 1], ["scroll", 4], ["torch", 1], ["mushroom", 3], ["bomb", 3]]
	stock = stock.filter(func(pair: Array) -> bool: return icon_texture(pair[0]) != null)
	for i in 32:
		item_slot(grid, stock[i][0] if i < stock.size() else "", stock[i][1] if i < stock.size() else 0, i == 1)

	var card := PanelContainer.new()
	card.theme_type_variation = &"ParchmentPanel"
	card.position = Vector2(226, 6)
	card.custom_minimum_size.x = 150
	page.add_child(card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	card.add_child(lines)
	var top := row(lines, 3)
	top.add_child(icon("potion_blue"))
	label(top, "Blue potion", &"Nameplate").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var about := label(lines, "Restores 40 mana over five seconds.", &"Ink")
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size.x = 130
	var worth := row(lines, 2)
	worth.add_child(icon("coin"))
	label(worth, "15", &"Ink").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var use := row(lines, 6)
	for pair in [["E", "Use"], ["Q", "Drop"]]:
		var r := prompt(use, [pair[0]], "")
		label(r, pair[1], &"Ink").size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var toasts := VBoxContainer.new()
	toasts.add_theme_constant_override("separation", 3)
	page.add_child(toasts)
	for pair in [["quest", "Quest updated"], ["coin", "+50 gold"], ["scroll", "Game saved"]]:
		toast(toasts, pair[0], pair[1])
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)

	_radial(Vector2(548, 190), 64)

	var talk := PanelContainer.new()
	talk.position = Vector2(6, 188)
	talk.custom_minimum_size.x = 440
	page.add_child(talk)
	var r := row(talk, 6)
	portrait(r, "ranger")
	var said := VBoxContainer.new()
	said.add_theme_constant_override("separation", 2)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(said)
	label(said, "Lirael the Ranger", &"Nameplate").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(said, "The east tunnel caved in. Bring three bombs\nfrom the crypt and we can clear it.")
	prompt(said, ["E"], "Next").size_flags_horizontal = Control.SIZE_SHRINK_END

	var hotbar := PanelContainer.new()
	hotbar.position = Vector2(6, 142)
	page.add_child(hotbar)
	var keys := row(hotbar, 2)
	var items := ["sword", "shield", "bow", "potion_red", "potion_blue", "bread", "torch", "map", "herb"]
	for i in items.size():
		var s := item_slot(keys, items[i], 1, i == 2)
		label(s.get_child(0), str(i + 1), &"Count").position = Vector2(-2, -4)

	var hints := VBoxContainer.new()
	hints.add_theme_constant_override("separation", 3)
	hints.position = Vector2(276, 144)
	page.add_child(hints)
	prompt(hints, ["Tab"], "Bag")
	prompt(hints, ["Esc"], "Menu")


## A quick-pick wheel: slots round a centre naming the one picked, on the theme's wheel.png.
func _radial(centre: Vector2, radius: float) -> void:
	var ring := TextureRect.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.theme_changed.connect(func() -> void:
		ring.texture = theme_art(ring, "wheel.png")
		if ring.texture:
			ring.position = (centre - ring.texture.get_size() / 2).floor() + Vector2.ONE)
	page.add_child(ring)
	var items := ["sword", "shield", "bow", "potion_red", "potion_blue", "bread", "torch", "map"]
	for i in items.size():
		var a := -PI / 2 + TAU * i / items.size()
		var s := item_slot(page, items[i], 1, i == 3)
		s.position = (centre + Vector2(cos(a), sin(a)) * radius - Vector2(12, 12)).round()
	var name := label(page, "Red potion")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.x = 70
	name.position = centre - Vector2(35, 12)
	prompt(page, ["Q"], "").position = centre - Vector2(6, -1)


## A dungeon wall behind the UI, each stone lit on its top edge, under a torchlight that flickers.
class Backdrop extends Control:
	const STONE := Vector2i(24, 12)
	var light := 1.0
	var rest := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _process(delta: float) -> void:
		rest -= delta
		if rest <= 0.0:  # a new flame strength now and then, not every frame
			rest = randf_range(0.08, 0.2)
			light = randf_range(0.94, 1.04)
			queue_redraw()

	func _draw() -> void:
		var area := get_rect().size
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.035, 0.028, 0.03))
		var glow := Vector2(area.x * 0.5, area.y * 0.42)
		var reach := area.length() * 0.55
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for y in range(0, int(area.y) + STONE.y, STONE.y):
			var shift := STONE.x / 2 if (y / STONE.y) % 2 else 0
			for x in range(-STONE.x, int(area.x) + STONE.x, STONE.x):
				var at := Vector2(x + shift, y)
				var lit := clampf(1.0 - at.distance_to(glow) / reach, 0.0, 1.0) * light
				var v := rng.randf_range(0.075, 0.115) * (0.55 + 0.75 * lit)
				var face := Color(v * 1.18, v * 0.92, v * 0.84)
				draw_rect(Rect2(at, STONE - Vector2i.ONE), face)
				draw_rect(Rect2(at, Vector2(STONE.x - 1, 1)), face.lightened(0.18 + 0.2 * lit))
				draw_rect(Rect2(at + Vector2(0, STONE.y - 2), Vector2(STONE.x - 1, 1)), face.darkened(0.35))
