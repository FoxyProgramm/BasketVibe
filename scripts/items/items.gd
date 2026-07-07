class_name Items
extends Object

static var BAT : PackedScene = preload("res://scenes/items/bat.tscn")
static var BALL : PackedScene = preload("res://scenes/items/ball.tscn")
static var RADIO : PackedScene = preload("res://scenes/items/radio.tscn")
static var TRASH : PackedScene = preload("res://scenes/items/trash.tscn")

static var ITEM_LIST:Array[PackedScene] = [
	BAT, BALL, RADIO, TRASH
]

static var ITEM_DICT:Dictionary[String, PackedScene] = {
	"ball": BALL,
	"bat": BAT,
	"radio": RADIO,
	"trash": TRASH
	
}
