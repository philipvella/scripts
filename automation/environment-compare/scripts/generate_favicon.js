const fs = require('fs');
const path = require('path');

// Create a simple favicon.ico generator
function generateFavicon() {
  const srcDir = path.join(__dirname, '../src');
  const faviconPath = path.join(srcDir, 'favicon.ico');

  // Ensure src directory exists
  if (!fs.existsSync(srcDir)) {
    fs.mkdirSync(srcDir, { recursive: true });
  }

  // Create a 16x16 favicon with ICO format
  // ICO file structure: Header (6 bytes) + Directory Entry (16 bytes) + Bitmap Header (40 bytes) + Pixel Data

  const width = 16;
  const height = 16;
  const bpp = 32; // bits per pixel (RGBA)

  // ICO Header (6 bytes)
  const icoHeader = Buffer.alloc(6);
  icoHeader.writeUInt16LE(0, 0);     // Reserved (must be 0)
  icoHeader.writeUInt16LE(1, 2);     // Type (1 = ICO)
  icoHeader.writeUInt16LE(1, 4);     // Number of images

  // Directory Entry (16 bytes)
  const dirEntry = Buffer.alloc(16);
  dirEntry.writeUInt8(width, 0);     // Width (16)
  dirEntry.writeUInt8(height, 1);    // Height (16)
  dirEntry.writeUInt8(0, 2);         // Color palette (0 = no palette)
  dirEntry.writeUInt8(0, 3);         // Reserved
  dirEntry.writeUInt16LE(1, 4);      // Color planes
  dirEntry.writeUInt16LE(bpp, 6);    // Bits per pixel

  // Calculate sizes
  const bitmapHeaderSize = 40;
  const pixelDataSize = width * height * 4; // 4 bytes per pixel (RGBA)
  const totalBitmapSize = bitmapHeaderSize + pixelDataSize;

  dirEntry.writeUInt32LE(totalBitmapSize, 8);  // Size of bitmap data
  dirEntry.writeUInt32LE(22, 12);              // Offset to bitmap data (6 + 16 = 22)

  // Bitmap Header (40 bytes) - BITMAPINFOHEADER
  const bitmapHeader = Buffer.alloc(40);
  bitmapHeader.writeUInt32LE(40, 0);           // Header size
  bitmapHeader.writeInt32LE(width, 4);         // Width
  bitmapHeader.writeInt32LE(height * 2, 8);    // Height * 2 (ICO format requirement)
  bitmapHeader.writeUInt16LE(1, 12);           // Planes
  bitmapHeader.writeUInt16LE(bpp, 14);         // Bits per pixel
  bitmapHeader.writeUInt32LE(0, 16);           // Compression (0 = none)
  bitmapHeader.writeUInt32LE(pixelDataSize, 20); // Image size
  bitmapHeader.writeInt32LE(0, 24);            // X pixels per meter
  bitmapHeader.writeInt32LE(0, 28);            // Y pixels per meter
  bitmapHeader.writeUInt32LE(0, 32);           // Colors used
  bitmapHeader.writeUInt32LE(0, 36);           // Important colors

  // Create pixel data (BGRA format, bottom-up)
  const pixelData = Buffer.alloc(pixelDataSize);

  // Define colors (BGRA format)
  const blue = [52, 152, 219, 255];   // #3498db
  const white = [255, 255, 255, 255];
  const darkBlue = [41, 128, 185, 255]; // #2980b9

  let offset = 0;

  // Draw pixel by pixel (bottom-up, left-right)
  for (let y = height - 1; y >= 0; y--) {
    for (let x = 0; x < width; x++) {
      let color = blue;

      // Create a simple "EC" pattern
      // Letter "E" (left side)
      if (x >= 1 && x <= 5) {
        if (y >= 3 && y <= 12) {
          if (y === 3 || y === 7 || y === 12 || x === 1) {
            color = white;
          } else {
            color = darkBlue;
          }
        }
      }

      // Letter "C" (right side)
      if (x >= 10 && x <= 14) {
        if (y >= 3 && y <= 12) {
          if ((y === 3 || y === 12) && x >= 11 && x <= 13) {
            color = white;
          } else if (x === 10 && y >= 4 && y <= 11) {
            color = white;
          } else if (y >= 4 && y <= 11) {
            color = darkBlue;
          }
        }
      }

      // Write BGRA values
      pixelData[offset] = color[0];     // B
      pixelData[offset + 1] = color[1]; // G
      pixelData[offset + 2] = color[2]; // R
      pixelData[offset + 3] = color[3]; // A
      offset += 4;
    }
  }

  // Combine all parts
  const favicon = Buffer.concat([icoHeader, dirEntry, bitmapHeader, pixelData]);

  // Write to file
  fs.writeFileSync(faviconPath, favicon);

  console.log('✓ Generated favicon.ico successfully!');
  console.log(`  Location: ${faviconPath}`);
  console.log(`  Size: ${favicon.length} bytes`);
  console.log(`  Format: 16x16 ICO with "EC" pattern`);

  return faviconPath;
}

// Run the generator
if (require.main === module) {
  try {
    generateFavicon();
  } catch (error) {
    console.error('Error generating favicon:', error.message);
    process.exit(1);
  }
}

module.exports = generateFavicon;
