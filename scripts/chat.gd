extends MarginContainer

@onready var chat: RichTextLabel = $VBoxContainer/HBoxContainer/Sprite2D/MarginContainer/RichTextLabel
@onready var line_edit: LineEdit = $VBoxContainer/LineEdit
@onready var chat_dissapear: Timer = $ChatDissapear
@onready var chat_handler: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var main: Node3D = $"../.."

@onready var background = get_tree().get_first_node_in_group("background")




var tween : Tween
func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = null

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
	chat.scroll_to_line(chat.get_line_count() - 1)

func _on_line_edit_text_submitted(new_text: String) -> void:
	chat.text += "[%s] %s\n" % [main.local_info.name, new_text]
	var message := ChatMessage.create(multiplayer.get_unique_id(), new_text)
	rpc("send_message", message.pack())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chat_dissapear.start(3.0)
	line_edit.editable = false
	var tween2 = create_tween()
	tween2.tween_property(line_edit, "modulate", Color.TRANSPARENT, 0.1)
	reset_tween()
	chat.scroll_to_line(chat.get_line_count() - 1)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chat") and !line_edit.editable and !background.visible and line_edit.modulate.a <= 0:
		reset_tween()
		line_edit.modulate = Color.WHITE
		line_edit.text = ""
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		chat_handler.modulate = Color.WHITE
		chat_dissapear.stop()
		var tw := create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(line_edit.grab_focus)
		await get_tree().create_timer(0.03).timeout
		line_edit.editable = true
	elif event.is_action_pressed("pause") and line_edit.editable and !background.visible:
		reset_tween()
		line_edit.editable = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		chat_dissapear.start(0.1)
		var tween2 = create_tween()
		tween2.tween_property(line_edit, "modulate", Color.TRANSPARENT, 0.5)
	if event is InputEventMouseButton and chat_handler.modulate.a > 0:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var v = chat.get_v_scroll_bar()
			v.value -= 20
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var v = chat.get_v_scroll_bar()
			v.value += 20

func _on_chat_dissapear_timeout() -> void:
	reset_tween()
	var tween = create_tween()
	tween.tween_property(chat_handler, "modulate", Color.TRANSPARENT, 0.5)
