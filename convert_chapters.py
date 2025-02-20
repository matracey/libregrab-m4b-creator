#!/usr/bin/env python3
import json
import os
import sys
import argparse

def seconds_to_timestamp(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    seconds = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

def get_json_path(input_path):
    """Find the appropriate JSON file to process."""
    print(f"Searching for JSON file in: {input_path}")
    if os.path.isfile(input_path):
        print(f"Found direct file: {input_path}")
        return input_path
    
    # Check for metadata.json in metadata directory
    metadata_path = os.path.join(input_path, "metadata", "metadata.json")
    if os.path.isfile(metadata_path):
        print(f"Found metadata.json: {metadata_path}")
        return metadata_path
        
    # Check for chapters.json in the directory
    chapters_path = os.path.join(input_path, "chapters.json")
    if os.path.isfile(chapters_path):
        print(f"Found chapters.json: {chapters_path}")
        return chapters_path
        
    raise FileNotFoundError(f"No valid JSON file found in {input_path}")

def process_metadata_json(metadata_path):
    """Process metadata.json to create chapters.json"""
    print(f"Reading metadata file: {metadata_path}")
    with open(metadata_path, 'r') as f:
        data = json.load(f)

    print("Processing spine durations...")
    spine_durations = {}
    for i, item in enumerate(data.get('spine', [])):
        spine_durations[i] = float(item.get('duration', 0))

    print("Processing chapters...")
    chapters = []
    current_time = 0
    for chapter in data.get('chapters', []):
        spine_index = chapter['spine']
        offset = float(chapter.get('offset', 0))
        
        # Calculate start time
        start_time = sum(spine_durations[i] for i in range(spine_index)) + offset
        
        # Convert to milliseconds and round
        start_time_ms = round(start_time * 1000)
        
        chapters.append({
            "start_time": start_time_ms,
            "title": chapter['title'].replace("&apos;", "'")
        })

    return {"chapters": chapters}

def main():
    parser = argparse.ArgumentParser(
        description='Process audiobook chapter metadata and create chapter timestamp files.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
python3 convert_chapters.py "/path/to/book/directory"
python3 convert_chapters.py "/path/to/chapters.json"
""")
    parser.add_argument('input_path', help='Path to book directory or JSON file')
    args = parser.parse_args()

    try:
        print(f"Processing input path: {args.input_path}")
        json_path = get_json_path(args.input_path)
        print(f"Found JSON file: {json_path}")
        
        with open(json_path, 'r') as f:
            data = json.load(f)
        
        if 'spine' in data:
            print("Processing metadata.json format")
            chapters_data = process_metadata_json(json_path)
        else:
            print("Processing chapters.json format")
            chapters_data = data
        
        output_dir = os.path.dirname(json_path)
        if 'metadata' in output_dir:
            output_dir = os.path.dirname(output_dir)
        output_path = os.path.join(output_dir, 'chapters.txt')

        # Save chapters.json
        json_output_path = os.path.join(output_dir, 'chapters.json')
        print(f"Writing JSON data to: {json_output_path}")
        with open(json_output_path, 'w') as f:
            json.dump(chapters_data, f, indent=2)
        print(f"Chapter data saved to {json_output_path}")

        # Continue with existing txt file creation...
        print(f"Writing chapters to: {output_path}")
        with open(output_path, 'w') as f:
            chapters = chapters_data.get('chapters', [])
            for chapter in chapters:
                start_time_seconds = float(chapter['start_time']) / 1000
                timestamp = seconds_to_timestamp(start_time_seconds)
                title = chapter['title']
                f.write(f"{timestamp} {title}\n")
        
        print(f"\nFound {len(chapters)} chapters")
        print(f"Chapter timestamps saved to {output_path}\n")
        print("First few chapters with timestamps:")
        for chapter in chapters[:5]:
            start_time_seconds = float(chapter['start_time']) / 1000
            timestamp = seconds_to_timestamp(start_time_seconds)
            print(f"{timestamp} {chapter['title']}")
            
    except Exception as e:
        print(f"Error: {str(e)}")
        raise

if __name__ == "__main__":
    main()
