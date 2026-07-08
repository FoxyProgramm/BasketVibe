class_name ChatMessage
extends Object

var player_id: int
var message: String

static func create(player_id_:int, message_:String) -> ChatMessage:
	var new_message := ChatMessage.new()
	new_message.player_id = player_id_
	new_message.message = message_
	return new_message

func pack() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_u32(player_id)
	buffer.put_utf8_string(message)
	
	return buffer.data_array

static func unpack(data:PackedByteArray) -> ChatMessage:
	var new_message := ChatMessage.new()
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	
	new_message.player_id = buffer.get_u32()
	new_message.message = buffer.get_utf8_string()
	
	return new_message
