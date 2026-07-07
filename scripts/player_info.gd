class_name PlayerInfo
extends Object

var name : String = ""
var skin : int = 0

func pack() -> PackedByteArray:
	return name.to_utf8_buffer()

static func unpack(data:PackedByteArray) -> PlayerInfo:
	var new_info := PlayerInfo.new()
	new_info.name = data.get_string_from_utf8()
	return new_info
