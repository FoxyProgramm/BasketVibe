class_name Characters
extends Object

class Character extends Object:
	var head_texture: Texture
	var body_texture: Texture
	
	static func create(head:Texture, body:Texture) -> Character:
		var new_character := Character.new()
		new_character.head_texture = head
		new_character.body_texture = body
		return new_character

static var PAPICH := Character.create(preload("res://textures/persones/papich_head.png"), preload("res://textures/persones/papich_body.png"))
static var GIGA_CHAD := Character.create(preload("res://textures/persones/gigachad_head.png"), preload("res://textures/persones/gigachad_body.png"))
static var GENDALF := Character.create(preload("res://textures/persones/gendalf_head.png"), preload("res://textures/persones/gendalf_body.png"))
static var REPER := Character.create(preload("res://textures/persones/reper_head.png"), preload("res://textures/persones/reper_body.png"))
static var VOLODYA := Character.create(preload("res://textures/persones/volodya_head.png"), preload("res://textures/persones/volodya_body.png"))
static var IVAN := Character.create(preload("res://textures/persones/ivan_head.png"), preload("res://textures/persones/ivan_body.png"))
static var GABEN := Character.create(preload("res://textures/persones/gaben_head.png"), preload("res://textures/persones/gaben_body.png"))
static var RAYAN := Character.create(preload("res://textures/persones/rayan_head.png"), preload("res://textures/persones/rayan_body.png"))
static var KIHUN := Character.create(preload("res://textures/persones/kihun_head.png"), preload("res://textures/persones/kihun_body.png"))
static var MAGREGOR := Character.create(preload("res://textures/persones/magregor_head.png"), preload("res://textures/persones/magregor_body.png"))
static var BRUSLI := Character.create(preload("res://textures/persones/brusli_head.png"), preload("res://textures/persones/brusli_body.png"))
static var THEKI := Character.create(preload("res://textures/persones/dheki_head.png"), preload("res://textures/persones/dheki_body.png"))
static var GODOT := Character.create(preload("res://textures/persones/godot_head.png"), preload("res://textures/persones/godot_body.png"))
static var KONSTANTINTDEBLIKOW := Character.create(preload("res://textures/persones/konstantintDeblikow_head.png"), preload("res://textures/persones/konstantintDeblikow_body.png"))

static var LIST: Array[Character] = [
	PAPICH, GIGA_CHAD, GENDALF, REPER, VOLODYA, IVAN, GABEN, RAYAN, KIHUN, MAGREGOR, BRUSLI, THEKI, GODOT, KONSTANTINTDEBLIKOW
]
