extends Node

const image_size = 512

func _ready() -> void:
	@warning_ignore("integer_division")
	var c := Compute.new(
			"res://addons/fusion_compute/examples/generate_image/generate_image.glsl",
			image_size / 8, image_size / 8, 1
		)

	c.create_image(
			image_size,
			image_size,
			RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
			
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		)

	c.submit()
	c.sync()

	var image_data := c.get_image(0)
	var image := Image.create_from_data(
			image_size, image_size, false, Image.FORMAT_RGBA8, image_data
		)

	$TextureRect.texture = ImageTexture.create_from_image(image)
