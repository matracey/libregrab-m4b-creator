# LibreGrab M4B Creator

A cross-platform tool designed to convert Libby audiobook downloads into M4B format with proper chapter markers. This tool automatically processes audio files and metadata to create professionally formatted M4B audiobooks that work great with audiobook players like Apple Books, Plex, and more.

Perfect for processing audiobooks downloaded from Libby (Overdrive) into a format compatible with most audiobook players while preserving chapter information.

## Quick Start

1. Install FFmpeg (see Prerequisites section)
2. Make the script executable (one-time setup):
```bash
chmod +x convert_audiobook.sh
```
3. Run the script and drag-and-drop one or more audiobook folders after the command:
```bash
./convert_audiobook.sh <drag folders here>          # Process multiple folders
./convert_audiobook.sh --output-dir ~/Books <folders>  # Specify output directory
```

## Getting Audiobook Files

This tool is designed to work with audiobook files downloaded from Libby/Overdrive using the LibreGrab userscript, available at https://greasyfork.org/en/scripts/498782-libregrab.

Files downloaded using LibreGrab will already be in the correct format with proper metadata structure, which ensures optimal compatibility with this script. This tool is specifically optimized for processing audiobooks obtained through LibreGrab.

## Features

- Cross-platform support (Windows PowerShell and Unix/Linux shell)
- Specifically designed for Libby audiobook downloads
- Converts MP3 files to M4B format
- Automatically creates chapter markers
- Preserves audio quality
- Maintains original audio bitrate
- Supports metadata inclusion
- Multiple folder support (process multiple audiobooks in one command)
- Easy to use with a simple command
- Automatically moves completed audiobooks to ~/totag directory
- Handles file/directory names with spaces and special characters
- Progress tracking during conversion

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

### Unix/Linux/macOS
1. Clone or download this repository
2. Open Terminal
3. Navigate to the downloaded folder
4. Make the script executable:
```bash
chmod +x convert_audiobook.sh
```

### Windows
1. Clone or download this repository
2. Ensure PowerShell execution policy allows local scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
3. No additional setup required - use convert_audiobook.ps1

## Usage

### Single Audiobook Conversion
1. Keep your Libby downloaded audiobook files in their original structure:
- MP3 files in the root directory
- A `metadata` folder containing `metadata.json`

2. Run the conversion script:

Unix/Linux/macOS:
```bash
./convert_audiobook.sh "path/to/audiobook folder"
```

Windows:
```powershell
.\convert_audiobook.ps1 -Path "path\to\audiobook folder"
```

### Multiple Audiobooks Conversion
You can convert multiple audiobooks sequentially by dragging multiple folders:
```bash
./convert_audiobook.sh <drag folder 1> <drag folder 2> <drag folder 3>
```

You can also specify a custom output directory for all converted books:
```bash
./convert_audiobook.sh --output-dir ~/MyAudiobooks <folder 1> <folder 2> <folder 3>
```

The script will:
- Process each audiobook folder one at a time
- Create chapter markers using information from metadata.json
- Combine MP3 files into a single M4B audiobook for each folder
- Name each output file based on its folder name
- Save all M4B files to the specified output directory (if --output-dir is used)

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


## Related Projects

- LibbyRip/LibreGrab (https://github.com/HeronErin/LibbyRip) - A userscript that enables downloading audiobooks from Libby/Overdrive in a format compatible with this tool. Also available on [Greasyfork](https://greasyfork.org/en/scripts/498782-libregrab).

## Support

If you encounter any issues:
1. Make sure FFmpeg is installed and accessible
2. Check that your files follow the correct structure
3. Verify your metadata.json format
4. Check the terminal output for any error messages

