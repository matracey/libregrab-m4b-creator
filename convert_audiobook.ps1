[CmdletBinding()]
param (
  [Parameter(Mandatory = $false)]
  [string]$OutputDir = "$env:USERPROFILE\totag",
    
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$InputDirs
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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

# Display usage if no input directories provided
if ($InputDirs.Count -eq 0) {
  Write-Host 'Usage: .\convert_audiobook.ps1 [-OutputDir <output_directory>] <directory_path1> [directory_path2 ...]'
  Write-Host 'Example: .\convert_audiobook.ps1 -OutputDir ~\MyAudiobooks ~\Downloads\MyAudiobook1 ~\Downloads\MyAudiobook2'
  Write-Host 'Notes:'
  Write-Host '- Each directory should contain MP3 files'
  Write-Host '- Cover art (cover.jpg/png) and metadata.json are optional'
  Write-Host "- Default output directory: $env:USERPROFILE\totag"
  exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
  Write-Verbose "Created output directory: $OutputDir"
}

function Convert-AudiobookDirectory {
  param (
    [string]$Directory
  )
    
  if (-not (Test-Path $Directory -PathType Container)) {
    Write-Warning "$Directory is not a directory, skipping..."
    return
  }
    
  Push-Location $Directory
  try {
    $bookTitle = (Get-Item -Path .).Name
    $author = 'Unknown Author'
    $year = (Get-Date).Year
        
    Write-Verbose "Processing audiobook: $bookTitle"
        
    # Find all MP3 files
    $AudioFiles = Get-ChildItem -Path . -Filter *.mp3 | Sort-Object Name
        
    if ($AudioFiles.Count -eq 0) {
      Write-Warning "No MP3 files found in $Directory, skipping..."
      return
    }
        
    # Create audio files list
    $AudioFilesList = 'audiofiles.txt'
    $AudioFiles | ForEach-Object {
      "file '$($_.FullName.Replace('\', '/').Replace("'", "\'"))'"
    } | Out-File -FilePath $AudioFilesList -Encoding UTF8
        
    Write-Verbose 'Audio files list created:'
    Get-Content $AudioFilesList
        
    # Get bitrate from first file
    $firstFile = $AudioFiles[0].FullName
    $bitrateInfo = & ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$firstFile" 2>$null
        
    if ($bitrateInfo -and $bitrateInfo -ne 'N/A') {
      $bitrateOpt = "-b:a $bitrateInfo"
      Write-Verbose "Detected bitrate: $bitrateInfo"
    } else {
      Write-Warning "Could not detect input bitrate, will maintain input file's bitrate"
      $bitrateOpt = ''
    }
        
    # Check for metadata.json
    $ChaptersFile = 'ffmpeg_chapters.txt'
    if (Test-Path 'metadata\metadata.json') {
      Write-Verbose 'Found metadata.json, using it for chapter information...'
      & python "$ScriptDir\convert_chapters.py" 'metadata\metadata.json'
      & python "$ScriptDir\convert_to_ffmpeg_chapters.py" 'chapters.txt'
    } else {
      Write-Verbose 'No metadata.json found, using MP3 filenames for chapters...'
      # Generate chapters from MP3 files
      ';FFMETADATA1' | Out-File -FilePath $ChaptersFile -Encoding UTF8
            
      $currentTime = 0
      foreach ($file in $AudioFiles) {
        # Get duration
        $duration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $file.FullName 2>$null
        $duration = [Math]::Floor([double]$duration)
                
        # Write chapter metadata
        '[CHAPTER]' | Out-File -FilePath $ChaptersFile -Append -Encoding UTF8
        'TIMEBASE=1/1' | Out-File -FilePath $ChaptersFile -Append -Encoding UTF8
        "START=$currentTime" | Out-File -FilePath $ChaptersFile -Append -Encoding UTF8
        $nextTime = $currentTime + $duration
        "END=$nextTime" | Out-File -FilePath $ChaptersFile -Append -Encoding UTF8
        "title=$($file.BaseName)" | Out-File -FilePath $ChaptersFile -Append -Encoding UTF8
                
        $currentTime = $nextTime
      }
    }
        
    # Get number of logical processors for threading
    $threads = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
        
    # Construct FFmpeg command
    $OutputFile = "$bookTitle.m4b"
    $ffmpegArgs = @(
      '-hwaccel', 'auto',
      '-threads', $threads,
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', $AudioFilesList,
      '-i', $ChaptersFile,
      '-map', '0',
      '-metadata', "album=`"$bookTitle`"",
      '-metadata', "artist=`"$author`"",
      '-metadata', "title=`"$bookTitle`"",
      '-metadata', "date=`"$year`"",
      '-metadata', "genre=`"Audiobook`"",
      '-c:a', 'aac',
      '-aac_coder', 'twoloop',
      '-ac', '2',
      '-ar', '44100',
      '-movflags', '+faststart'
    )
        
    if ($bitrateOpt) {
      $ffmpegArgs += $bitrateOpt.Split(' ')
    }
        
    $ffmpegArgs += "`"$OutputFile`""
        
    Write-Verbose 'Converting to M4B format...'
        
    # Start FFmpeg process
    $process = Start-Process -FilePath 'ffmpeg' -ArgumentList $ffmpegArgs -NoNewWindow -PassThru
        
    # Show progress animation
    $spin = @('-', '\', '|', '/')
    $i = 0
    while (!$process.HasExited) {
      Write-Verbose "Converting... $($spin[$i % 4])"
      Start-Sleep -Milliseconds 100
      $i++
    }
        
    if ($process.ExitCode -eq 0) {
      Write-Verbose "`rConversion complete!     "
      Write-Verbose "Output file: $OutputFile"
      Write-Verbose 'Moving audiobook to output directory...'
      Move-Item -Path $OutputFile -Destination "$OutputDir\" -Force
      Write-Verbose 'You can now test the audiobook in your preferred player.'
    } else {
      Write-Error "`rConversion failed!     "
      throw "FFmpeg exited with code $($process.ExitCode)"
    }
        
    # Cleanup temporary files
    Write-Verbose 'Cleaning up temporary files...'
    Remove-Item -Path $AudioFilesList, $ChaptersFile, 'chapters.json' -ErrorAction SilentlyContinue
        
  } finally {
    Pop-Location
  }
}

# Process each provided directory
foreach ($dir in $InputDirs) {
  Convert-AudiobookDirectory -Directory $dir
  Write-Verbose "Completed processing: $dir"
  Write-Verbose '----------------------------------------'
}

Write-Host 'All audiobooks processed successfully!'
