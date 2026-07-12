@tool
extends EditorScript

func _run() -> void:
	var names:Array[String] = []
	
	var file := FileAccess.open("res://names.txt", FileAccess.READ)
	while file.get_position() < file.get_length():
		var line := file.get_line()
		names.append(line)
	
	var names_storer:= NameStorer.create(names)
	names_storer.take_over_path("res://resources/names.tres")
	if ResourceSaver.save(names_storer, "res://resources/names.tres") == OK:
		print("NAMES EXPORTED !!!")
	
