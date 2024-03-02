@tool
extends Node

var file: FileAccess
@export var filePath: String
@export var mapCollider: StaticBody2D
@export var lightmapMat: ShaderMaterial

# Called when the node enters the scene tree for the first time.
func _ready():
	file = FileAccess.open(filePath, FileAccess.READ)
	var head = file.get_pascal_string()
	if (head != "unlit"):
		push_error("Unrecognized header in map file " + filePath + ", got \"" + head + "\", expected \"unlit\"")
		return
	
	var numSegments = file.get_32()
	print("loading " + String.num_int64(numSegments) + " segments")
	var segments: Array
	for c in mapCollider.get_children():
		mapCollider.remove_child(c)
		
	for i in numSegments:
		var aX = file.get_float()
		var aY = file.get_float()
		var bX = file.get_float()
		var bY = file.get_float()
		
		var a = Vector2(aX,aY)
		var b = Vector2(bX,bY)
		print(a,b)
		var coll = CollisionShape2D.new()
		coll.shape = SegmentShape2D.new()
		coll.shape.a = a
		coll.shape.b = b
		mapCollider.add_child(coll)
		
		segments.append([a,b])
	file.close()
	
	lightmapMat.set_shader_parameter("nSegments", numSegments)
	
	var segA = Array()
	var segB = Array()
	var segC = Array()
	
	for seg in segments:
		segA.append(seg[0])
		segB.append(seg[1])
		segC.append(Vector3(1,0,0)) # TODO: get the color from the file
		
	
	lightmapMat.set_shader_parameter("segment0", segA)
	lightmapMat.set_shader_parameter("segment1", segB)
	lightmapMat.set_shader_parameter("segmentCol", segC)
