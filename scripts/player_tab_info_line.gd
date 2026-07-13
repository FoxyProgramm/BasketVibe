class_name PlayerTabInfoLine
extends HBoxContainer

func setup(id:int, p_name:String) -> void:
	$Id.text = str(id)
	$Name.text = p_name
