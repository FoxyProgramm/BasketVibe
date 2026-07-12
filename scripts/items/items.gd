class_name Items
extends Object

static var BAT : PackedScene = preload("res://scenes/items/bat.tscn")
static var BALL : PackedScene = preload("res://scenes/items/ball.tscn")
static var RADIO : PackedScene = preload("res://scenes/items/radio.tscn")
static var TRASH : PackedScene = preload("res://scenes/items/trash.tscn")
static var SEED : PackedScene = preload("res://scenes/items/seed.tscn")
static var BOX : PackedScene = preload("res://scenes/items/box.tscn")
static var BALLOON : PackedScene = preload("res://scenes/items/balloon.tscn")

static var ITEM_LIST:Array[PackedScene] = [
	BAT, BALL, RADIO, TRASH, SEED, BOX, BALLOON
]

static var ITEM_NAMES: Array[String] = [
	"bat", "ball", "radio", "trash", "seed", "box", "balloon"
]

static var ITEM_DICT:Dictionary[String, PackedScene] = {
	"ball": BALL,
	"bat": BAT,
	"radio": RADIO,
	"trash": TRASH,
	"seed": SEED,
	"box": BOX,
	"balloon": BALLOON
}
