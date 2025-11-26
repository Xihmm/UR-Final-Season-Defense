import os
from PIL import Image

def make_transparent(image_path):
    try:
        img = Image.open(image_path)
        img = img.convert("RGBA")
        datas = img.getdata()

        newData = []
        # 假设背景是白色或接近白色
        # 调整阈值以适应不同的"不干净"程度
        threshold = 240 
        
        found_background = False
        for item in datas:
            if item[0] > threshold and item[1] > threshold and item[2] > threshold:
                newData.append((255, 255, 255, 0))
                found_background = True
            else:
                newData.append(item)

        if found_background:
            img.putdata(newData)
            img.save(image_path, "PNG")
            print(f"Processed: {image_path}")
        else:
            print(f"Skipped (no white background found): {image_path}")
            
    except Exception as e:
        print(f"Error processing {image_path}: {e}")

target_dir = "Final Season Defense/Final Season Defense/Assets.xcassets"
skip_files = ["background.png"] # 跳过背景图

for root, dirs, files in os.walk(target_dir):
    for file in files:
        if file.endswith(".png") and file not in skip_files:
            full_path = os.path.join(root, file)
            make_transparent(full_path)

