# Audiobook M4B Creator

A simple tool to convert audio files into M4B audiobooks with proper chapter markers. This tool automatically processes audio files and metadata to create professionally formatted M4B audiobooks that work great with audiobook players like Apple Books, Plex, and more.

## Quick Start

1. Install FFmpeg (see Prerequisites section)
2. Make the script executable (one-time setup):
```bash
chmod +x convert_audiobook.sh
```
3. Run the script and drag-and-drop your audiobook folders after the command:
```bash
./convert_audiobook.sh <drag folders here>
```

## Features

- Converts MP3 files to M4B format
- Automatically creates chapter markers
- Preserves audio quality
- Maintains original audio bitrate
- Supports metadata inclusion
- Easy to use with a simple command
- Automatically moves completed audiobooks to ~/totag directory

## Prerequisites

1. FFmpeg is required for audio conversion:
- macOS: `brew install ffmpeg`
- Linux: `sudo apt-get install ffmpeg`
- Windows: Download from https://ffmpeg.org/download.html

2. Create the ~/totag directory for completed audiobooks:
```bash
mkdir -p ~/totag
```

## Installation

1. Download and unzip this package
2. Open Terminal (macOS/Linux) or Command Prompt (Windows)
3. Navigate to the unzipped folder
4. Make the script executable (macOS/Linux only):
```bash
chmod +x convert_audiobook.sh
```

## Usage

### Single Audiobook Conversion
1. Create a folder for your audiobook with the following items:
- Your MP3 files in the root directory
- A `metadata` folder containing `metadata.json`

2. Run the conversion script by dragging your audiobook folder after the command:
```bash
./convert_audiobook.sh <drag audiobook folder here>
```

### Multiple Audiobooks Conversion
You can convert multiple audiobooks sequentially by dragging multiple folders:
```bash
./convert_audiobook.sh <drag folder 1> <drag folder 2> <drag folder 3>
```

The script will:
- Process each audiobook folder one at a time
- Create chapter markers using information from metadata.json
- Combine MP3 files into a single M4B audiobook for each folder
- Name each output file based on its folder name

Check the `example` directory for a complete working example.

## Directory Structure

```
your-audiobook-folder/
├── *.mp3                # Your audiobook MP3 files
└── metadata/
    └── metadata.json    # Chapter information file
```

## Example Usage

### Single Book Conversion
```bash
./convert_audiobook.sh "~/Downloads/My Audiobook"
```

### Multiple Books Conversion
```bash
./convert_audiobook.sh "~/Downloads/Book1" "~/Downloads/Book2" "~/Downloads/Book3"
```

This repository includes an example directory that demonstrates proper setup:
- Sample audio files in the correct format
- A properly formatted metadata.json
- An example cover image
- A README explaining usage

## Metadata Format

Create a `metadata.json` file in the metadata folder:

```json
{
"chapters": [
    {
    "title": "Introduction",
    "duration": 1234
    },
    {
    "title": "Chapter 1",
    "duration": 5678
    }
]
}
```

Notes:
- `duration`: Length of chapter in seconds
- `title`: Chapter title as it will appear in the audiobook

## Output

The script will create an M4B file with:
- Proper chapter markers
- Maintains original audio quality and bitrate
- Embedded cover art (if provided)
- The same name as your book folder


## Support

If you encounter any issues:
1. Make sure FFmpeg is installed and accessible
2. Check that your files follow the correct structure
3. Verify your metadata.json format
4. Check the terminal output for any error messages

