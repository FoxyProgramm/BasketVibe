class_name PlayerTabInfoLine
extends HBoxContainer

signal on_spawn_clicked
signal on_kick_clicked

func _ready() -> void:
	if not multiplayer.is_server():
		$Spawn.hide()
		$Kick.hide()
		$VSeparator2.hide()
	else:
		$Spawn.pressed.connect(func(): on_spawn_clicked.emit())
		$Kick.pressed.connect(func(): on_kick_clicked.emit())

func setup(id:int, p_name:String) -> void:
	$Id.text = str(id)
	$Name.text = p_name
