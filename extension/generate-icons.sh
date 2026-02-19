#!/bin/bash
# Generate simple brain extension icons using ImageMagick or Python
# Run this once to create the icon files

# Try Python (more likely available)
python3 -c "
import struct, zlib

def create_png(size, filename):
    # Create a simple colored square PNG
    # Blue circle-ish brain icon approximation
    bg = (13, 17, 23)      # dark bg
    fg = (88, 166, 255)    # blue accent

    pixels = []
    center = size // 2
    radius = size // 2 - 2

    for y in range(size):
        row = []
        for x in range(size):
            dx = x - center
            dy = y - center
            dist = (dx*dx + dy*dy) ** 0.5
            if dist < radius:
                row.extend(fg)
            else:
                row.extend([0, 0, 0, 0])  # transparent
                continue
            row.append(255)  # alpha
            continue
        # Fix: redo with RGBA
        pixels.append(row)

    # Actually just make simple solid PNGs
    import io
    width = height = size

    def make_png(w, h, color):
        def chunk(chunk_type, data):
            c = chunk_type + data
            return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

        header = b'\\x89PNG\\r\\n\\x1a\\n'
        ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))

        raw = b''
        for y in range(h):
            raw += b'\\x00'  # filter none
            for x in range(w):
                dx = x - w//2
                dy = y - h//2
                dist = (dx*dx + dy*dy) ** 0.5
                r = w//2 - 1
                if dist < r:
                    raw += bytes(color) + b'\\xff'
                else:
                    raw += b'\\x00\\x00\\x00\\x00'

        idat = chunk(b'IDAT', zlib.compress(raw))
        iend = chunk(b'IEND', b'')
        return header + ihdr + idat + iend

    return make_png(size, size, color)

for size, name in [(16, 'icon16.png'), (48, 'icon48.png'), (128, 'icon128.png')]:
    data = create_png(size, name)
    with open(name, 'wb') as f:
        f.write(data)
    print(f'Created {name}')
" 2>&1

echo "Icons generated. You can replace these with custom designs later."
