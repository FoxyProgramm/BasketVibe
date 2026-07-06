class_name Items
extends Object

static var BAT : PackedScene = preload("res://Bat.tscn")
static var BALL : PackedScene = preload("res://Ball.tscn")
static var RADIO : PackedScene = preload("res://scene/radio.tscn")

static var ITEM_LIST:Array[PackedScene] = [
	BAT, BALL, RADIO
]

static var ITEM_DICT:Dictionary[String, PackedScene] = {
	"ball": BALL,
	"bat": BAT,
	"radio": RADIO
	
}
