import os
import sys
import re

def time_to_seconds(time_str):
    """Convert HH:MM:SS to seconds"""
    h, m, s = map(int, time_str.split(':'))
    return h * 3600 + m * 60 + s

def convert_chapters(input_file):
    if not os.path.exists(input_file):
        print(f"Error: File {input_file} not found")
        sys.exit(1)
        
    # Read chapters
    chapters = []
    with open(input_file, 'r') as f:
        for line in f:
            # Extract timestamp and title
            match = re.match(r'(\d{2}:\d{2}:\d{2})\s+(.+)', line.strip())
            if match:
                time_str, title = match.groups()
                seconds = time_to_seconds(time_str)
                chapters.append((seconds, title))

    if not chapters:
        print("Error: No valid chapters found")
        sys.exit(1)

    # Create output file path
    output_file = os.path.join(os.path.dirname(input_file), 'ffmpeg_chapters.txt')
    
    # Write ffmpeg metadata format
    with open(output_file, 'w') as f:
        f.write(';FFMETADATA1\n\n')
        
        for i, (start_time, title) in enumerate(chapters):
            # For all chapters except the last one, end time is the start of the next chapter
            if i < len(chapters) - 1:
                end_time = chapters[i + 1][0]
            else:
                # For the last chapter, add 30 seconds
                end_time = start_time + 30
            
            f.write('[CHAPTER]\n')
            f.write('TIMEBASE=1/1\n')
            f.write(f'START={start_time}\n')
            f.write(f'END={end_time}\n')
            f.write(f'title={title}\n\n')

    print(f"Created {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python convert_to_ffmpeg_chapters.py <chapters_file>")
        sys.exit(1)
        
    convert_chapters(sys.argv[1])

