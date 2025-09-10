# Serena Icon Setup for Windows Builds

## Required Icon File

The PyInstaller build process requires an icon file at:
```
scripts/pyinstaller/serena.ico
```

## Icon Requirements

### Format and Specifications
- **File format**: Windows Icon (.ico)
- **Recommended sizes**: Multiple sizes embedded in a single .ico file
  - 16x16 pixels (small icons, file explorer)
  - 32x32 pixels (medium icons, taskbar)
  - 48x48 pixels (large icons, desktop)
  - 256x256 pixels (extra large icons, modern Windows)
- **Color depth**: 32-bit with alpha channel (RGBA) for best quality
- **Background**: Transparent background recommended

### Design Guidelines
- **Style**: Modern, professional icon representing AI/coding
- **Colors**: Consider using Oraios AI brand colors
- **Clarity**: Should be clearly visible at all sizes
- **Simplicity**: Avoid complex details that don't scale well

## How to Add the Icon

### Option 1: Create with Professional Tools
1. Design the icon in Adobe Illustrator, Figma, or similar
2. Export as PNG at multiple sizes (16x16, 32x32, 48x48, 256x256)
3. Use a tool like IcoFX, IconWorkshop, or online converters to create .ico file
4. Save as `scripts/pyinstaller/serena.ico`

### Option 2: Use Free Online Converters
1. Create a high-resolution PNG (512x512 or larger)
2. Use online services like:
   - https://convertio.co/png-ico/
   - https://favicon.io/favicon-converter/
   - https://icoconvert.com/
3. Select multi-size option to include 16x16, 32x32, 48x48, 256x256
4. Download and rename to `serena.ico`

### Option 3: Use ImageMagick (Command Line)
```bash
# Convert PNG to ICO with multiple sizes
magick convert icon-source.png -resize 256x256 -define icon:auto-resize=256,48,32,16 serena.ico
```

### Option 4: Use Python PIL/Pillow
```python
from PIL import Image

# Load source image
img = Image.open('icon-source.png')

# Resize and save as ICO with multiple sizes
sizes = [(16, 16), (32, 32), (48, 48), (256, 256)]
img.save('serena.ico', format='ICO', sizes=sizes)
```

## Current Status

⚠️ **Icon file is missing** - The build will work without an icon but will use the default Python executable icon.

To add the icon:
1. Create or obtain a suitable icon file
2. Save it as `scripts/pyinstaller/serena.ico`
3. Rebuild using PyInstaller

## Suggested Icon Concepts

Consider these themes for the Serena icon:
- **AI/Brain**: Circuit board patterns, neural network nodes
- **Coding**: Code brackets, terminal window, binary patterns  
- **Agent**: Robot, assistant, or helper symbol
- **Tools**: Wrench, gear, or multi-tool representing development toolkit
- **Language Servers**: Multiple connected nodes representing different languages

## Testing the Icon

After adding the icon:
1. Run the build process: `pyinstaller serena.spec`
2. Check the generated executable has the correct icon
3. Test icon appearance in:
   - File Explorer
   - Taskbar when running
   - Desktop shortcut
   - System tray (if applicable)

## File Verification

To verify your .ico file is valid:
```bash
# Check file format
file serena.ico

# List embedded icon sizes (Windows)
iconsext /stext icon_info.txt serena.ico
```

The PyInstaller spec file will automatically use the icon if present at the expected location.