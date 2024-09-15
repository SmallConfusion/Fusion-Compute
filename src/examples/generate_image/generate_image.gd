extends Node


func _ready() -> void:
	@warning_ignore("integer_division")
	var c := Compute.create("res://examples/generate_image/generate_image.glsl", 512 / 8, 512 / 8, 1);

	var usage := \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT

	c.create_image(512, 512, RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, usage)

	c.submit()
	c.sync()

	var image_data := c.get_image(0)
	var image := Image.create_from_data(512, 512, false, Image.FORMAT_RGBA8, image_data)

	$TextureRect.texture = ImageTexture.create_from_image(image)