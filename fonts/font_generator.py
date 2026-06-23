import os
from PIL import Image

# Default fallback character string provided by you
DEFAULT_CHARS_STR = '{}[]()<>$*-+=/#_^@\\&|~?\'"`!,.;:1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz '

def get_png_files():
    """Scans the current working directory for PNG files."""
    files = [f for f in os.listdir('.') if f.lower().endswith('.png')]
    return files

def analyze_sfont(image_path):
    print(f"\n[1/3] Loading image: {image_path}...")
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    print(f"      Dimensions: {width}x{height} pixels")

    # Sample the very top-left pixel for our delimiter
    separator_color = img.getpixel((0, 0))
    
    char_slices = []
    in_char = False
    start_x = 0

    # Scan the top row horizontally
    for x in range(width):
        current_pixel = img.getpixel((x, 0))

        if current_pixel == separator_color:
            if in_char:
                char_width = x - start_x
                if char_width > 0:
                    char_slices.append((start_x, char_width))
                in_char = False
        else:
            if not in_char:
                start_x = x
                in_char = True

    if in_char:
        char_width = width - start_x
        if char_width > 0:
            char_slices.append((start_x, char_width))

    print(f"[2/3] Parsing complete. Found {len(char_slices)} character slices in the image.")
    return char_slices, width, height

def main():
    print("=== Interactive sfont BMFont Generator ===")
    
    # 1. Scan and pick PNG
    png_files = get_png_files()
    if not png_files:
        print("\n[ERROR] No .png files found in the current folder!")
        print(f"Make sure this script is running in the same directory as your image.")
        return

    print("\nAvailable PNG files:")
    for idx, filename in enumerate(png_files, start=1):
        print(f"  {idx}. {filename}")

    while True:
        try:
            choice = input(f"\nSelect an image number (1-{len(png_files)}): ").strip()
            choice_idx = int(choice) - 1
            if 0 <= choice_idx < len(png_files):
                selected_png = png_files[choice_idx]
                break
            else:
                print(f"Please enter a number between 1 and {len(png_files)}.")
        except ValueError:
            print("Invalid input. Please enter a valid number.")

    # 2. Choose Character Set
    print("\n--- Character Set Selection ---")
    print("Press Enter to use the default layout sequence, or paste a custom string.")
    print(f"Default: {DEFAULT_CHARS_STR}")
    
    user_input_chars = input("\nCustom string (or press Enter for default): ").strip()
    
    if user_input_chars:
        char_ids = [ord(c) for c in user_input_chars]
        print(f"Using custom layout with {len(char_ids)} mapped IDs.")
    else:
        char_ids = [ord(c) for c in DEFAULT_CHARS_STR]
        print(f"Using default layout with {len(char_ids)} mapped IDs.")

    # --- NEW: Interactive Spacing Controls ---
    print("\n--- Font Spacing Customization ---")
    
    # Horizontal Gap
    letter_gap = 0
    letter_gap_input = input("Add extra horizontal space between letters? (Default 0): ").strip()
    if letter_gap_input:
        try:
            letter_gap = int(letter_gap_input)
        except ValueError:
            print("Invalid entry. Defaulting to 0.")

    # Vertical Line Spacing
    line_spacing_mod = 0
    line_spacing_input = input("Adjust line height gap? (Use positive values to space out, negative to tighten. Default 0): ").strip()
    if line_spacing_input:
        try:
            line_spacing_mod = int(line_spacing_input)
        except ValueError:
            print("Invalid entry. Defaulting to 0.")

    # 3. Analyze and process
    slices, img_w, img_h = analyze_sfont(selected_png)

    if len(slices) == 0:
        print("[ERROR] No characters identified. Check if your pink borders match coordinate (0,0).")
        return

    # Dynamic slicing adjustment to match visual columns vs character definitions
    if len(slices) < len(char_ids):
        print(f"      Notice: Image contains fewer columns ({len(slices)}) than characters provided. Truncating.")
        active_ids = char_ids[: len(slices)]
    else:
        active_ids = char_ids[: len(slices)]
        if len(slices) > len(char_ids):
            print(f"      Notice: Image has more columns ({len(slices)}) than character IDs layout ({len(char_ids)}). Missing tracking IDs will be ignored.")

    # Calculate final line structural parameters
    calculated_line_height = img_h + line_spacing_mod

    # 4. Generate data structure
    base_name = os.path.splitext(selected_png)[0]
    output_fnt_path = f"{base_name}.fnt"

    lines = [
        f'info face="{base_name}" size={img_h} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
        f'common lineHeight={calculated_line_height} base={img_h} scaleW={img_w} scaleH={img_h} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0',
        f'page id=0 file="{selected_png}"',
        f"chars count={len(active_ids)}",
    ]

    for idx, char_id in enumerate(active_ids):
        x, char_w = slices[idx]
        calculated_advance = char_w + letter_gap
        lines.append(
            f"char id={char_id:<3} x={x:<4} y=0    width={char_w:<3} height={img_h:<2} "
            f"xoffset=0    yoffset=0    xadvance={calculated_advance:<3} page=0    chnl=15"
        )

    lines.append("kernings count=0")

    print(f"[3/3] Writing BMFont mapping file to: {output_fnt_path}")
    with open(output_fnt_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print("\nSuccess! Processing finished flawlessly.")

if __name__ == "__main__":
    main()