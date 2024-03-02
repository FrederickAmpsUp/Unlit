@tool
extends RigidBody2D

@export var lightmapMat: ShaderMaterial

# Called when the node enters the scene tree for the first time.
func _ready():
	var lRad = lightmapMat.get_shader_parameter("lightRad")
	lRad[-1] = 2.0;
	lightmapMat.set_shader_parameter("lightRad", lRad)
	
	var lCol = lightmapMat.get_shader_parameter("lightCol")
	lCol[-1] = Vector3(1.5,1.5,1)
	lightmapMat.set_shader_parameter("lightCol", lCol)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var lPos = lightmapMat.get_shader_parameter("lightPos")
	lPos[-1] = transform.get_origin()
	lightmapMat.set_shader_parameter("lightPos", lPos)
