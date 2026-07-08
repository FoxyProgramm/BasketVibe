class_name PlayerInfo
extends Object

var name : String = ""
var skin : int = 0

func pack() -> PackedByteArray:
	var result := StreamPeerBuffer.new()
	result.put_utf8_string(name)
	result.put_u8(skin)
	return result.data_array

static func unpack(data:PackedByteArray) -> PlayerInfo:
	var new_info := PlayerInfo.new()
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	new_info.name = buffer.get_utf8_string()
	new_info.skin = buffer.get_u8()
	return new_info
