extends Label
	
@onready var OtherNode = get_node("")

func _process(delta):
	text = ""
	text += "fps: " + str(Engine.get_frames_per_second())
