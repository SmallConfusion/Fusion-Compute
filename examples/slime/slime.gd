extends Node

const width := 1024
const height := 1024

const wg_size := 64
const wg_count := 5000

const agent_count := wg_count * wg_size


@export_range(0.9, 1, 0.00001, "or_greater") var evaporation := 0.99
@export_range(0, 0.25, 0.0001) var diffusion := 0.1

@export_range(0, 10, 0.0001, "or_greater", "or_less") var trail_strength := 0.1
@export_range(0, PI, 0.01) var sensor_angle := PI / 180.0 * 30.0;
@export_range(0, 20, 0.01, "or_greater") var sensor_distance := 1.5;

@export_range(0, 20, 0.001, "or_greater", "or_less") var speed := 1.0;
@export_range(0, 0.2, 0.00001, "or_greater") var turning := 0.1;
@export_range(0, 0.2, 0.00001, "or_greater") var random := 0.005;

var c_agent: Compute
var c_diffuse: Compute


func _ready() -> void:
	c_agent = Compute.create("res://examples/slime/agents.glsl", wg_count)

	var a: Array[float] = []

	a.resize(agent_count * 4)
	
	for i in range(agent_count):
		a[i * 4] = randf_range(0, width)
		a[i * 4 + 1] = randf_range(0, height)
		a[i * 4 + 2] = randf_range(-1, 1)
		a[i * 4 + 3] = randf_range(-1, 1)
		

	var agent_data := PackedFloat32Array(a).to_byte_array()

	c_agent.create_data(agent_data)

	c_agent.create_image(
		width,
		height,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,

		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	@warning_ignore("integer_division")
	c_diffuse = Compute.create("res://examples/slime/diffuse.glsl", width / 8, height / 8)

	c_diffuse.create_image(
		width,
		height,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,

		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)

	c_diffuse.create_image(
		width,
		height,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,

		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	
func _process(_delta: float) -> void:
	c_agent.submit(PackedFloat32Array([trail_strength, float(width), float(height), sensor_angle, sensor_distance, speed, turning, random]).to_byte_array())
	c_agent. sync ()

	var image_data := c_agent.get_image(1)

	c_diffuse.update_image(0, image_data)

	c_diffuse.submit(PackedFloat32Array([evaporation, diffusion]).to_byte_array())
	c_diffuse. sync ()

	image_data = c_diffuse.get_image(1)

	c_agent.update_image(1, image_data)

	var image := Image.create_from_data(width, height, false, Image.FORMAT_RF, image_data)

	var texture := ImageTexture.create_from_image(image)

	$TextureRect.texture = texture