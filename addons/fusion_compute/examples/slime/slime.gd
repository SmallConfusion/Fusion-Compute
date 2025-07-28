extends Node

# This causes a whole bunch of errors in 4.4 because we are using the global
# RenderingDevice. I don't know what changed but it still seems to work and I
# can't be bothered to fix it right now.

const width := 1024
const height := 1024

const wg_size := 64

@warning_ignore("integer_division")
const wg_count := 1000000 / wg_size

const agent_count := wg_count * wg_size


@export_range(0, 1, 0.00001, "or_less") var evaporation := 0.99
@export_range(0, 0.25, 0.0001) var diffusion := 0.1

@export_range(0, 1, 0.0001, "or_greater", "or_less") var trail_strength := 0.1
@export_range(0, PI, 0.0001, "or_greater") var sensor_angle := PI / 180.0 * 30.0;
@export_range(0, 40, 0.01, "or_greater") var sensor_distance := 1.5;

@export_range(0, 5, 0.0001, "or_greater", "or_less") var speed := 1.0;
@export_range(0, 5, 0.00001, "or_greater") var turning := 0.1;
@export_range(0, 0.2, 0.00001, "or_greater") var random := 0.005;


var compute: Compute


func _ready() -> void:
	compute = Compute.new(
			"res://addons/fusion_compute/examples/slime/agents.glsl",
			wg_count, 1, 1, true
		)

	@warning_ignore("integer_division")
	compute.create_pipeline(
			"res://addons/fusion_compute/examples/slime/diffuse.glsl",
			width / 8, height / 8
		)

	var agent_data := _agents_circle().to_byte_array()

	compute.create_data(agent_data)

	compute.create_image(
		width,
		height,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,

		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	compute.create_image(
		width,
		height,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,

		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)
	
	for child in get_children():
		if child is TextureRect:
			var tex = child.texture
			
			if tex is Texture2DRD:
				tex.texture_rd_rid = compute.get_image_rid(2)

	
func _process(_delta: float) -> void:
	compute.submit(
			PackedFloat32Array([
					trail_strength,
					float(width),
					float(height),
					sensor_angle,
					sensor_distance,
					speed,
					turning,
					random,
					float(Time.get_ticks_msec()) / 1000.0
				]).to_byte_array(),
			0
		)

	compute.submit(
			PackedFloat32Array([evaporation, diffusion]).to_byte_array(), 1
		)

	var image_data := compute.get_image(2)
	compute.update_image(1, image_data)
	

func _agents_random() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(agent_count * 3)
	
	for i in range(agent_count):
		a[i * 3] = randf_range(0, width)
		a[i * 3 + 1] = randf_range(0, height)
		a[i * 3 + 2] = randf_range(0, TAU)
	
	return a


func _agents_circle() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(agent_count * 3)

	var radius := width / 2.0 - 100
	var center := Vector2(width, height) / 2

	for i in range(agent_count):
		var angle := Vector2.from_angle(randf() * TAU)
		var pos := angle * radius * sqrt(randf()) + center

		a[i * 3] = pos.x;
		a[i * 3 + 1] = pos.y;
		a[i * 3 + 2] = pos.angle_to_point(center)

	return a
