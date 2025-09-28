param (
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "$env:USERPROFILE\totag"
)

# Function to check if a command exists
function Test-Command {
    param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) { return $true }
    }
    catch { return $false }
    finally { $ErrorActionPreference = $oldPreference }
}

# Check for ffmpeg
if (-not (Test-Command "ffmpeg")) {
    Write-Error "ffmpeg is not installed. Please install it before running this script."
    exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
    Write-Host "Created output directory: $OutputDir"
}

# Get current directory name as book title
$BOOK_TITLE = Split-Path -Leaf (Get-Location)
$TEMP_DIR = "temp_$([System.IO.Path]::GetRandomFileName())"

# Create temporary directory for processing
New-Item -ItemType Directory -Path $TEMP_DIR
Write-Host "Created temporary directory for processing: $TEMP_DIR"

try {
    # Find all audio files (mp3, m4a, m4b) in current directory
    $audioFiles = Get-ChildItem -Path . -Recurse -Include *.mp3,*.m4a,*.m4b | 
                Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(20, '0') }) }

    if ($audioFiles.Count -eq 0) {
        throw "No audio files found in current directory!"
    }

    Write-Host "Found $($audioFiles.Count) audio files. Processing..."

    # Create concatenation file
    $concatFile = Join-Path $TEMP_DIR "concat.txt"
    $audioFiles | ForEach-Object {
        "file '$($_.FullName -replace "'", "''")'" | Add-Content -Path $concatFile -Encoding UTF8
    }

    # Check for metadata.json and process chapters
    if (Test-Path "metadata.json") {
        Write-Host "Found metadata.json, using it for chapter information..."
        python convert_chapters.py "metadata.json"
    }

    # Check for chapters file
    $chaptersFile = ""
    if (Test-Path "chapters.txt") {
        $chaptersFile = "chapters.txt"
    } elseif (Test-Path "ffmpeg_chapters.txt") {
        $chaptersFile = "ffmpeg_chapters.txt"
    }

    # Concatenate files and convert to M4B
    Write-Host "Converting files to M4B format..."
    $progressParams = @{
        Activity = "Converting audiobook to M4B"
        Status = "Processing files..."
        PercentComplete = 0
    }
    Write-Progress @progressParams

    if ($chaptersFile) {
        Write-Host "Using chapters from $chaptersFile"
        ffmpeg -f concat -safe 0 -i $concatFile -i $chaptersFile -map_metadata 1 -c copy "$TEMP_DIR\temp.m4b"
    } else {
        ffmpeg -f concat -safe 0 -i $concatFile -c copy "$TEMP_DIR\temp.m4b"
    }

    # Add cover art if available
    if (Test-Path "cover.jpg" -or Test-Path "cover.png") {
        $coverFile = if (Test-Path "cover.jpg") { "cover.jpg" } else { "cover.png" }
        Write-Host "Adding cover art from $coverFile"
        ffmpeg -i "$TEMP_DIR\temp.m4b" -i $coverFile -map 0 -map 1 -c copy -disposition:v:0 attached_pic "$TEMP_DIR\temp_with_cover.m4b"
        Move-Item -Path "$TEMP_DIR\temp_with_cover.m4b" -Destination "$TEMP_DIR\temp.m4b" -Force
    }

    # Move the final file to output directory
    $outputFile = Join-Path $OutputDir "$BOOK_TITLE.m4b"
    Move-Item -Path "$TEMP_DIR\temp.m4b" -Destination $outputFile -Force
    Write-Host "Successfully created audiobook: $outputFile"
    Write-Host "You can now test the audiobook in your preferred player."

} catch {
    Write-Error "An error occurred: $_"
} finally {
    # Cleanup
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
        Write-Host "Cleaned up temporary files."
    }
}
