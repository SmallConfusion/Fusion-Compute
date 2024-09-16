# Fusion Compute

This is an addon for Godot 4.3 designed to make using compute shader less painful.

When using compute shaders normally, you have to write many lines of boilerplate just to make a basic "hello world" program. I wrote this addon to fix that.

For example, [the godot docs tutorial for compute shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html), which multiplies an array by two, uses around ~20 lines of gdscript. This plugin reduces it to much less:

```gdscript
func _ready() -> void:
	var compute := Compute.create("res://shader.glsl", 1, 1, 1)

	var data := PackedFloat32Array(range(16))
	compute.create_data(data.to_byte_array())
	
	compute.submit()
	compute.sync()

	var result := compute.get_data(0).to_float32_array())
```

More examples can be found in the [examples folder.](./addons/fusion_compute/examples/)

Full documentation can be found in the [documentation.](./addons/fusion_compute/docs/main.md)