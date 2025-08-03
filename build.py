import zipfile
import os

build_file_name = "fusion-compute-plugin.zip"

compress_type = zipfile.ZIP_DEFLATED
compress_level = 9

with zipfile.ZipFile(
			build_file_name,
			"w",
			compress_type,
			compresslevel=compress_level
		) as zf:

	for root, dirs, files in os.walk("addons"):
		for file in files:
			filepath = os.path.join(root, file)
			zf.write(filepath, filepath)
	
	zf.write("README.md", os.path.join("addons", "fusion_compute", "README.md"))