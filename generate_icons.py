import os
import sys
import subprocess

def install_and_import(package):
    try:
        __import__(package)
    except ImportError:
        print(f"Installing {package}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])

# Make sure Pillow is installed
install_and_import("Pillow")

from PIL import Image, ImageOps

def generate_icons():
    logo_path = os.path.join("public", "logo.png")
    icons_dir = os.path.join("public", "images", "icons")
    
    if not os.path.exists(logo_path):
        print(f"Error: logo.png not found at {logo_path}")
        return
        
    os.makedirs(icons_dir, exist_ok=True)
    
    # Open the base logo
    with Image.open(logo_path) as img:
        print(f"Loaded logo.png: size={img.size}, format={img.format}")
        
        # Standard sizes for PWA
        sizes = {
            "72x72": (72, 72),
            "96x96": (96, 96),
            "128x128": (128, 128),
            "144x144": (144, 144),
            "152x152": (152, 152),
            "192x192": (192, 192),
            "384x384": (384, 384),
            "512x512": (512, 512)
        }
        
        # Generate standard resized icons (transparent/original background)
        for size_str, size in sizes.items():
            resized = img.resize(size, Image.Resampling.LANCZOS)
            icon_path = os.path.join(icons_dir, f"icon-{size_str}.png")
            resized.save(icon_path, "PNG")
            print(f"Generated standard icon: {icon_path}")
            
        # Apple touch icon (180x180)
        apple_size = (180, 180)
        apple_icon = img.resize(apple_size, Image.Resampling.LANCZOS)
        apple_path = os.path.join(icons_dir, "apple-touch-icon.png")
        apple_icon.save(apple_path, "PNG")
        print(f"Generated Apple Touch icon: {apple_path}")
        
        # Generate maskable icons: safe zone is 80% of the area
        # We put the logo with 10% padding on all sides over a white background
        for size_str, size in [("192x192", (192, 192)), ("512x512", (512, 512))]:
            # Create a blank white canvas
            canvas = Image.new("RGBA", size, (255, 255, 255, 255))
            
            # Resize original logo to 80% of the target dimension
            content_size = int(size[0] * 0.8)
            logo_resized = img.resize((content_size, content_size), Image.Resampling.LANCZOS)
            
            # Calculate position to center the logo
            offset = ((size[0] - content_size) // 2, (size[1] - content_size) // 2)
            
            # Paste the logo on the canvas
            canvas.paste(logo_resized, offset, logo_resized if logo_resized.mode == "RGBA" else None)
            
            # Save maskable icon
            maskable_path = os.path.join(icons_dir, f"icon-{size_str}-maskable.png")
            canvas.save(maskable_path, "PNG")
            print(f"Generated maskable icon: {maskable_path}")

        # Also generate a favicon.ico if possible
        favicon_path = os.path.join("public", "favicon.ico")
        # Resize to 32x32 and save as ICO
        favicon_img = img.resize((32, 32), Image.Resampling.LANCZOS)
        favicon_img.save(favicon_path, format="ICO")
        print(f"Generated favicon.ico: {favicon_path}")

if __name__ == "__main__":
    generate_icons()
    print("All icons successfully generated!")
