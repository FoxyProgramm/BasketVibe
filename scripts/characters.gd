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

static var LIST: Array[Character] = [
	PAPICH, GIGA_CHAD, GENDALF, REPER, VOLODYA, IVAN, GABEN, RAYAN
]
