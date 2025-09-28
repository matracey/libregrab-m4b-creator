[CmdletBinding()]
param (
  [Parameter(Mandatory = $false)]
  [ValidateScript({ Test-Path -Path $_ -PathType Container })]
  [string]$OutputDir = "$env:USERPROFILE\totag"
)

# Function to check if a command exists
function Test-CommandExists {
  param ($Command)
  return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Check for ffmpeg
if (-not (Test-CommandExists 'ffmpeg')) {
  Write-Error 'ffmpeg is not installed. Please install it before running this script.'
  exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
  Write-Verbose "Created output directory: $OutputDir"
}

# Get current directory name as book title
$BookTitle = $PWD.Name
$TempDir = "temp_{0}" -f ([System.IO.Path]::GetRandomFileName())

# Create temporary directory for processing
New-Item -ItemType Directory -Path $TempDir | Out-Null
Write-Verbose "Created temporary directory for processing: $TempDir"

try {
  # Find all audio files (mp3, m4a, m4b) in current directory
  $AudioFiles = Get-ChildItem -Path . -Recurse -Include *.mp3, *.m4a, *.m4b | Sort-Object { [regex]::Replace($_.Name, '\d+', { $Args[0].Value.PadLeft(20, '0') }) }

  if ($AudioFiles.Count -eq 0) {
    throw 'No audio files found in current directory!'
  }

  Write-Verbose "Found $($AudioFiles.Count) audio files. Processing..."

  # Create concatenation file
  $ConcatFile = Join-Path $TempDir 'concat.txt'
  $fileContent = $AudioFiles | ForEach-Object {
    # FFmpeg concat demuxer requires special characters to be escaped.
    $escapedPath = $_.FullName.Replace("'", "'\''")
    "file '$escapedPath'"
  }
  Set-Content -Path $ConcatFile -Value $fileContent -Encoding UTF8

  # Check for metadata.json and process chapters
  if (Test-Path 'metadata.json') {
    Write-Verbose 'Found metadata.json, using it for chapter information...'
    python convert_chapters.py 'metadata.json'
  }

  # Check for chapters file
  $ChaptersFile = ''
  if (Test-Path 'chapters.txt') {
    $ChaptersFile = 'chapters.txt'
  } elseif (Test-Path 'ffmpeg_chapters.txt') {
    $ChaptersFile = 'ffmpeg_chapters.txt'
  }

  # Concatenate files and convert to M4B
  Write-Verbose 'Converting files to M4B format...'
  $ProgressParams = @{
    Activity        = 'Converting audiobook to M4B'
    Status          = 'Processing files...'
    PercentComplete = 0
  }
  Write-Progress @progressParams

  $ffmpegArgs = @('-f', 'concat', '-safe', '0', '-i', $ConcatFile)
  if ($ChaptersFile) {
    Write-Verbose "Using chapters from $ChaptersFile"
    $ffmpegArgs += ('-i', $ChaptersFile, '-map_metadata', '1')
  }
  $ffmpegArgs += ('-c:a', 'aac', '-b:a', '64k', "$TempDir\temp.m4b")
  & ffmpeg @ffmpegArgs

  # Add cover art if available
  $CoverFile = Get-ChildItem -Path . -Include cover.jpg, cover.png | Select-Object -First 1
  if ($CoverFile) {
    Write-Verbose "Adding cover art from $($CoverFile.Name)"
    $tempWithCover = "$TempDir\temp_with_cover.m4b"
    & ffmpeg -i "$TempDir\temp.m4b" -i $CoverFile.FullName -map 0 -map 1 -c copy -disposition:v:0 attached_pic $tempWithCover
    Move-Item -Path $tempWithCover -Destination "$TempDir\temp.m4b" -Force
  }

  # Move the final file to output directory
  $OutputFile = Join-Path $OutputDir "$BookTitle.m4b"
  Move-Item -Path "$TempDir\temp.m4b" -Destination $OutputFile -Force
  Write-Host "Successfully created audiobook: $OutputFile"
  Write-Verbose 'You can now test the audiobook in your preferred player.'

} catch {
  Write-Error "An error occurred: $_"
} finally {
  # Cleanup
  if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force
    Write-Verbose 'Cleaned up temporary files.'
  }
}
