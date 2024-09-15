extends Node


func _ready() -> void:
	var c := Compute.create("res://examples/array_multiply/array_multiply.glsl", 1, 1, 1)

	var data := PackedFloat32Array(range(64))

	print("Data before: ", data)
	c.create_data_buffer(data.to_byte_array())

	print("Submitting")
	c.submit(PackedFloat32Array([4]).to_byte_array())
	c.sync()
	print("Synced")

	data = c.get_data_buffer(0).to_float32_array()
	print("Data after: ", data)
