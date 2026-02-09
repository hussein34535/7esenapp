from PIL import Image
import os

def create_ios_icon():
    source_path = 'assets/icon/logo.png'
    output_path = 'web/apple-touch-icon-v3.png'
    
    # Target size (iOS standard usually 180 or 192)
    target_size = (192, 192)
    bg_color = (0, 0, 0, 255) # Black opaque

    if not os.path.exists(source_path):
        print(f"Error: {source_path} not found")
        return

    try:
        # Open source
        img = Image.open(source_path).convert("RGBA")
        
        # Calculate aspect ratio preserving resize
        img.thumbnail((150, 150), Image.Resampling.LANCZOS) # Make logo slightly smaller than full box for padding
        
        # Create new black image
        new_img = Image.new("RGBA", target_size, bg_color)
        
        # Center the logo
        x = (target_size[0] - img.width) // 2
        y = (target_size[1] - img.height) // 2
        
        # Paste logo
        new_img.paste(img, (x, y), img)
        
        # Save
        new_img.save(output_path, "PNG")
        print(f"Successfully created {output_path}")
        
    except Exception as e:
        print(f"Error processing image: {e}")

if __name__ == "__main__":
    create_ios_icon()
