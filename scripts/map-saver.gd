@tool
extends Node

@export var mapCollider: StaticBody2D

# Called when the node enters the scene tree for the first time.
func _ready():
	var file = FileAccess.open("res://maps/test.unlit", FileAccess.WRITE)
	file.store_pascal_string("unlit")
	var children = mapCollider.find_children("", "CollisionShape2D")
	
	file.store_32(children.size())
	for child in children:
		file.store_float(child.shape.a.x)
		file.store_float(child.shape.a.y)
		file.store_float(child.shape.b.x)
		file.store_float(child.shape.b.y)
	file.close()
	print("Wrote " + String.num_int64(children.size()) + " children")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
