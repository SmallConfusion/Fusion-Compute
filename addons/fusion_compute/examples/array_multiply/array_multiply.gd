extends Node


func _ready() -> void:
	var c := Compute.new(
			"res://addons/fusion_compute/examples/array_multiply/array_multiply.glsl",
			1, 1, 1
		)

	var data := PackedFloat32Array(range(64))

	print("Data before: ", data)
	c.create_data(data.to_byte_array())

	print("Submitting")
	c.submit([4.0])
	c.sync()
	print("Synced")

	data = c.get_data(0).to_float32_array()
	print("Data after: ", data)
