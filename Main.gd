extends Node3D

var names : Array[String] = [
	"Чебоксар",
	"Редиски",
	"Чаполах",
	"Сувенир",
	"Анальный гром",
	"Средиземный паук",
	"Крит на 20",
	"Силиконовая Сиська",
	"Лапух Дубравый",
	"Окупант"
]

const PORT = 7777
const MAX_CLIENTS = 2

@onready var main_menu = $UI/MainMenu
@onready var address_entry = $UI/MainMenu/AddressEntry
@onready var port_entry = $UI/MainMenu/PortEntry
@onready var players_node = $Players
@onready var level_node = $Level
@onready var level_items: Node3D = $Level/Items

var players : Dictionary[int, String] = {}

var player_scene = preload("res://Player.tscn")
var ball_scene = preload("res://Ball.tscn")
var bat_scene = preload("res://Bat.tscn")
var radio_scene = preload("res://scene/radio.tscn")

func _ready():
	$LevelSpawner.add_spawnable_scene("res://Ball.tscn")
	$LevelSpawner.add_spawnable_scene("res://Bat.tscn")
	$LevelSpawner.add_spawnable_scene("res://scene/radio.tscn")
	$PlayerSpawner.add_spawnable_scene("res://Player.tscn")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Привязываем функции к кнопкам
	$UI/MainMenu/HostButton.pressed.connect(_on_host_pressed)
	$UI/MainMenu/JoinButton.pressed.connect(_on_join_pressed)
	$UI/MainMenu/Username.text = names.pick_random()

func _on_host_pressed():
	players[1] = $UI/MainMenu/Username.text
	main_menu.hide()
	var port = port_entry.text.to_int()
	if port <= 0: port = 7777

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		print("Cannot host: ", err)
		return
	multiplayer.multiplayer_peer = peer

	# Хост сразу спавнит себя
	_spawn_player(multiplayer.get_unique_id())
	# И спавнит предметы
	_spawn_ball()
	_spawn_bat()

func _on_join_pressed():
	main_menu.hide()
	var port = port_entry.text.to_int()
	if port <= 0: port = 7777

	var peer = ENetMultiplayerPeer.new()
	var addr = address_entry.text
	if addr == "": addr = "127.0.0.1"
	var err = peer.create_client(addr, port)
	if err != OK:
		print("Cannot join: ", err)
		return
	multiplayer.multiplayer_peer = peer

@rpc("any_peer", "reliable")
func add_player(id:int, name_:String) -> void:
	players[id] = name_
	var player:Player = $Players.get_node_or_null(str(id))
	if player:
		player.get_node("Username").text = name_

func _on_peer_connected(id) -> void:
	if multiplayer.is_server():
		_spawn_player(id)
	rpc_id(id, "add_player", multiplayer.get_unique_id(), $UI/MainMenu/Username.text)
	
func _on_peer_disconnected(id) -> void:
	if not multiplayer.is_server():return 
		
	if players_node.has_node(str(id)):
		players_node.get_node(str(id)).queue_free()
	# Если игрок вышел и он держал мяч, освобождаем мяч
	var balls = get_tree().get_nodes_in_group("ball")
	if not balls.is_empty():
		var ball = balls[0]
		if ball.held_by_id == id:
			ball.held_by_id = 0
			ball.freeze = false

	var bats = get_tree().get_nodes_in_group("bat")
	if not bats.is_empty():
		var bat = bats[0]
		if bat.held_by_id == id:
			bat.held_by_id = 0
			bat.freeze = false

	var radios = get_tree().get_nodes_in_group("radio")
	if not radios.is_empty():
		var radio = radios[0]
		if radio.held_by_id == id:
			radio.held_by_id = 0
			radio.freeze = false

func _spawn_player(id: int):
	var p = player_scene.instantiate()
	p.name = str(id)
	#var offset = (id % 3) * 10.0
	p.position = Vector3(randf_range(-10, 10), 2, randf_range(-10, 10))
	players_node.add_child(p, true)

func _spawn_ball():
	var b = ball_scene.instantiate()
	b.name = "Ball"
	b.position = Vector3(0, 3, -4)
	level_items.add_child(b, true)

func _spawn_bat():
	var b = bat_scene.instantiate()
	b.name = "Bat"
	# Спавним чуть левее от мяча
	b.position = Vector3(-2, 3, -4)
	level_items.add_child(b, true)
