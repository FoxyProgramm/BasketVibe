extends MarginContainer

@onready var chat: RichTextLabel = $VBoxContainer/HBoxContainer/ChatHandler/MarginContainer/RichTextLabel
@onready var line_edit: LineEdit = $VBoxContainer/LineEdit
@onready var chat_dissapear: Timer = $ChatDissapear
@onready var chat_handler: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var main: Node3D = $"../.."

var tween : Tween
func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()

@rpc("any_peer", "reliable")
func send_message(data:PackedByteArray) -> void:
	var message := ChatMessage.unpack(data)
	var info: PlayerInfo = main.players.get(message.player_id)
	chat_handler.modulate = Color.WHITE
	chat_dissapear.start()
	if info:
		chat.text += "[%s] %s\n" % [info.name, message.message]
	else :
		chat.text += "[???] %s\n" % [message.message]

func _on_line_edit_text_submitted(new_text: String) -> void:
	chat.text += "[%s] %s\n" % [main.local_info.name, new_text]
	var message := ChatMessage.create(multiplayer.get_unique_id(), new_text)
	rpc("send_message", message.pack())
	line_edit.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chat_dissapear.start()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chat") and !line_edit.visible:
		line_edit.visible = true
		line_edit.text = ""
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		chat_handler.modulate = Color.WHITE
		chat_dissapear.stop()
		var tw := create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(line_edit.grab_focus)
	elif event.is_action_pressed("pause") and line_edit.visible:
		line_edit.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		chat_dissapear.start()

func _on_chat_dissapear_timeout() -> void:
	reset_tween()
	tween.tween_property(chat_handler, "modulate", Color.TRANSPARENT, 0.5)
