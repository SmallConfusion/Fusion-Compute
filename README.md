# Fusion Compute

This is an addon for Godot designed to make using compute shader less painful. Supports Godot 4.0 - 4.4dev2 and probably future releases.

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

There are only a few ways to interact with compute shaders. This plugin supports data buffers, images, and push constants. In addition, this plugin also supports multiple pipelines using the same buffers. Anything more than that (eg. [recreating this example project with swapping RIDs through uniform sets](https://github.com/godotengine/godot-demo-projects/tree/master/compute/texture/water_plane)) is not supported. I potentially want to add support for more things like that in the future, but the first priortiy of this plugin is to make interacting with compute shaders as simple as possible, rather than abstracting everything you could want to do with a compute shader.

Shaders themselves are not changed by this plugin, they are written exactly the same, only the gdscript boilerplate is abstracted away.

## Documentation

Documentation of functions and usage can be found by reading the generated documentation of the Compute class in the Godot engine. Reading the [multiply_arrays](./addons/fusion_compute/examples/array_multiply/) and [generate_image](./addons/fusion_compute/examples/generate_image/) will be helpful too. The [slime](./addons/fusion_compute/examples/slime/) example is a more complex example.
