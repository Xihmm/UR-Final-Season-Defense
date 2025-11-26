from PIL import Image, ImageDraw

# 创建一个 64x64 的透明背景图像
size = (64, 64)
img = Image.new('RGBA', size, (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 在中心画一个白色的圆
# 留一点边缘缓冲
margin = 2
draw.ellipse([margin, margin, size[0]-margin, size[1]-margin], fill=(255, 255, 255, 255))

# 保存到 snowball.imageset
output_path = "Final Season Defense/Final Season Defense/Assets.xcassets/snowball.imageset/snowball.png"
img.save(output_path, "PNG")
print(f"Restored snowball.png at {output_path}")

