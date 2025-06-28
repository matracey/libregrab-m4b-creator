#!/bin/bash

# telegram-m4b - Create Telegram-compatible M4B audiobooks
# Full replacement for convert_audiobook.sh with AudioBookBinder-style encoding
# Uses minimal AAC configuration to achieve extradata_size: 2

set -e

# Script directory and helper paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONVERT_SCRIPTS_DIR="/Users/cerinawithasea/audiobooks/libregrab-m4b-creator"

usage() {
    echo "Usage: $0 [--output-dir <output_directory>] <input_directory_or_files>"
    echo ""
    echo "Directory Mode (replaces convert_audiobook.sh):"
    echo "  $0 --output-dir ~/totag /path/to/audiobook_directory"
    echo "  $0 /path/to/audiobook_directory  # uses default output dir"
    echo ""
    echo "Manual Mode:"
    echo "  $0 /path/to/audiofiles book.m4b [title] [artist]"
    echo "  $0 file1.mp3 file2.mp3 book.m4b [title] [artist]"
    echo ""
    echo "Features:"
    echo "- JSON chapter support (metadata/metadata.json)"
    echo "- AudioBookBinder-compatible encoding (extradata_size: 2)"
    echo "- Automatic Telegram compatibility verification"
}

# Default settings
OUTPUT_DIR="/Users/cerinawithasea/totag"
DIRECTORY_MODE=false
INPUT_DIRS=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            if [[ -n "$2" ]]; then
                OUTPUT_DIR="$2"
                shift 2
            else
                echo "Error: --output-dir requires a directory path"
                exit 1
            fi
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [ -d "$1" ]; then
                INPUT_DIRS+=("$1")
                DIRECTORY_MODE=true
                shift
            else
                # Remaining args are for manual mode
                break
            fi
            ;;
    esac
done

# Check dependencies
if ! command -v "ffmpeg" &> /dev/null; then
    echo "Error: ffmpeg is required but not found."
    exit 1
fi

# Verify output directory exists and is writable (for directory mode)
if [ "$DIRECTORY_MODE" = true ]; then
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR" || {
            echo "Error: Failed to create output directory: $OUTPUT_DIR"
            exit 1
        }
    fi
    
    if [ ! -w "$OUTPUT_DIR" ]; then
        echo "Error: Output directory is not writable: $OUTPUT_DIR"
        exit 1
    fi
fi

# Function to handle JSON chapters and generate ffmpeg metadata
generate_chapters() {
    local workdir="$1"
    local chapters_file="$2"
    
    cd "$workdir"
    
    echo ";FFMETADATA1" > "$chapters_file"
    
    if [ -f "metadata/metadata.json" ]; then
        echo "Found metadata.json, using it for chapter information..."
        python3 "$CONVERT_SCRIPTS_DIR/convert_chapters.py" metadata/metadata.json
        python3 "$CONVERT_SCRIPTS_DIR/convert_to_ffmpeg_chapters.py" chapters.txt
        cat ffmpeg_chapters.txt >> "$chapters_file"
    else
        echo "No metadata.json found, using MP3 filenames for chapters..."
        # Create chapters from MP3 files
        current_time=0
        while IFS= read -r line; do
            # Extract filename without path and extension
            filename=$(basename "$line" .mp3)
            filename=${filename#"file '"}
            filename=${filename%"'"}
            
            # Get duration of current file
            duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filename.mp3")
            duration=${duration%.*} # Remove decimal places
            
            # Write chapter metadata
            echo "[CHAPTER]" >> "$chapters_file"
            echo "TIMEBASE=1/1" >> "$chapters_file"
            echo "START=$current_time" >> "$chapters_file"
            next_time=$((current_time + duration))
            echo "END=$next_time" >> "$chapters_file"
            echo "title=$filename" >> "$chapters_file"
            
            current_time=$next_time
        done < audiofiles.txt
    fi
}

# Function to extract metadata from JSON
extract_metadata() {
    local json_file="$1"
    if [ -f "$json_file" ]; then
        TITLE=$(python3 -c "import json; data=json.load(open('$json_file')); print(data.get('title', 'Unknown Title'))")
        # Extract author from creator array
        AUTHOR=$(python3 -c "
import json
data = json.load(open('$json_file'))
creators = data.get('creator', [])
author = next((c['name'] for c in creators if c.get('role') == 'author'), 'Unknown Author')
print(author)
")
    else
        TITLE=$(basename "$(pwd)")
        AUTHOR="Unknown Author"
    fi
}

# Directory processing function (AudioBookBinder-style encoding)
process_directory() {
    local dir="$1"
    local workdir=$(cd "$dir" && pwd)
    local book_title=$(basename "$workdir")
    
    echo "Processing audiobook: $book_title"
    cd "$workdir"
    
    # Extract metadata if available
    extract_metadata "metadata/metadata.json"
    
    # Create list of audio files
    echo "Creating list of audio files..."
    find . -maxdepth 1 -name "*.mp3" -type f | sort | sed "s/^\\.\\/*/file '/;s/$/'/" > audiofiles.txt
    
    if [ ! -s audiofiles.txt ]; then
        echo "Error: No MP3 files found in $workdir"
        return 1
    fi
    
    echo "Audio files found:"
    cat audiofiles.txt
    
    # Generate chapter metadata
    generate_chapters "$workdir" "ffmpeg_chapters.txt"
    
    # AudioBookBinder-compatible encoding
    echo "Converting to Telegram-compatible M4B format..."
    
    # Use AudioBookBinder-style parameters for maximum compatibility
    ffmpeg -hwaccel auto -threads $(nproc) -y \
        -f concat -safe 0 -i audiofiles.txt \
        -i ffmpeg_chapters.txt \
        -map 0 \
        -c:a aac \
        -profile:a aac_low \
        -b:a 64k \
        -ar 44100 \
        -ac 2 \
        -movflags +faststart \
        -avoid_negative_ts make_zero \
        -fflags +genpts \
        -metadata album="$TITLE" \
        -metadata artist="$AUTHOR" \
        -metadata title="$TITLE" \
        -metadata date="2024" \
        -metadata genre="Audiobook" \
        -metadata media_type=1 \
        "${book_title}.m4b"
    
    if [ $? -eq 0 ]; then
        echo "✅ Conversion complete!"
        echo "Moving audiobook to output directory..."
        mv "${book_title}.m4b" "$OUTPUT_DIR/"
        
        # Remove quarantine attribute
        xattr -d com.apple.quarantine "$OUTPUT_DIR/${book_title}.m4b" 2>/dev/null || true
        
        # Verify Telegram compatibility
        echo ""
        echo "Verifying Telegram compatibility..."
        extradata_size=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=extradata_size -of csv=p=0 "$OUTPUT_DIR/${book_title}.m4b")
        
        if [ "$extradata_size" = "2" ]; then
            echo "✅ SUCCESS: extradata_size = 2 (Telegram compatible!)"
        else
            echo "⚠️  WARNING: extradata_size = $extradata_size (may not work on Telegram)"
        fi
        
        # Show file info
        echo ""
        echo "Output file: $OUTPUT_DIR/${book_title}.m4b"
        echo "Size: $(ls -lh "$OUTPUT_DIR/${book_title}.m4b" | awk '{print $5}')"
        duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT_DIR/${book_title}.m4b")
        hours=$(echo "$duration / 3600" | bc -l | cut -d. -f1)
        minutes=$(echo "($duration % 3600) / 60" | bc -l | cut -d. -f1)
        echo "Duration: ${hours}h ${minutes}m"
        echo "Ready for Telegram upload! 🚀"
        
    else
        echo "❌ Conversion failed!"
        return 1
    fi
    
    # Cleanup temporary files
    echo "Cleaning up temporary files..."
    rm -f audiofiles.txt ffmpeg_chapters.txt chapters.txt chapters.json
}

# Manual file processing function
process_manual() {
    local input_path="$1"
    local output_file="$2"
    local title="${3:-$(basename "$output_file" .m4b)}"
    local artist="${4:-Unknown Artist}"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    echo "Creating Telegram-compatible M4B: $output_file"
    echo "Title: $title"
    echo "Artist: $artist"
    
    # Get audio files
    if [ -d "$input_path" ]; then
        audio_files=$(find "$input_path" -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.m4b" -o -name "*.aac" -o -name "*.wav" -o -name "*.flac" \) | sort)
    else
        # Multiple files passed as arguments
        audio_files=""
        for file in "$@"; do
            if [ -f "$file" ]; then
                audio_files="$audio_files$file\n"
            fi
        done
        audio_files=$(echo -e "$audio_files" | head -n -1)  # Remove last newline
    fi
    
    if [ -z "$audio_files" ]; then
        echo "Error: No audio files found"
        exit 1
    fi
    
    echo "Found $(echo "$audio_files" | wc -l) audio files"
    
    # Create file list for ffmpeg
    file_list="$temp_dir/filelist.txt"
    echo "$audio_files" | while read -r file; do
        echo "file '$file'" >> "$file_list"
    done
    
    echo "Encoding with AudioBookBinder-compatible settings..."
    
    ffmpeg -f concat -safe 0 -i "$file_list" \
        -c:a aac \
        -profile:a aac_low \
        -b:a 64k \
        -ar 44100 \
        -ac 2 \
        -movflags +faststart \
        -avoid_negative_ts make_zero \
        -fflags +genpts \
        -metadata title="$title" \
        -metadata artist="$artist" \
        -metadata album="$title" \
        -metadata album_artist="$artist" \
        -metadata genre="Audiobook" \
        -metadata media_type=1 \
        -y "$output_file"
    
    # Verify the extradata_size
    echo ""
    echo "Verifying Telegram compatibility..."
    extradata_size=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=extradata_size -of csv=p=0 "$output_file")
    
    if [ "$extradata_size" = "2" ]; then
        echo "✅ SUCCESS: extradata_size = 2 (Telegram compatible!)"
    else
        echo "⚠️  WARNING: extradata_size = $extradata_size (may not work on Telegram)"
    fi
    
    # Show file info
    echo ""
    echo "File created: $output_file"
    echo "Size: $(ls -lh "$output_file" | awk '{print $5}')"
    duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$output_file")
    hours=$(echo "$duration / 3600" | bc -l | cut -d. -f1)
    minutes=$(echo "($duration % 3600) / 60" | bc -l | cut -d. -f1)
    echo "Duration: ${hours}h ${minutes}m"
    
    echo ""
    echo "Ready for Telegram upload! 🚀"
}

# Main execution logic
if [ "$DIRECTORY_MODE" = true ]; then
    # Directory processing mode (replaces convert_audiobook.sh)
    if [ ${#INPUT_DIRS[@]} -eq 0 ]; then
        echo "Error: No directories specified for processing"
        usage
        exit 1
    fi
    
    echo "🎵 Telegram-Compatible M4B Creator (Directory Mode)"
    echo "=================================================="
    
    for dir in "${INPUT_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Warning: $dir is not a directory, skipping..."
            continue
        fi
        process_directory "$dir"
        echo "Completed processing: $dir"
        echo "----------------------------------------"
    done
    
    echo "All audiobooks processed successfully! 🎉"
    
elif [ $# -ge 2 ]; then
    # Manual file processing mode
    echo "🎵 Telegram-Compatible M4B Creator (Manual Mode)"
    echo "================================================"
    process_manual "$@"
    
else
    echo "Error: Invalid arguments"
    usage
    exit 1
fi
