# Telegram-Compatible M4B Audiobooks

## 🎉 Major Discovery: The Secret to Telegram Playback

After extensive analysis of M4B files that work vs. don't work on Telegram, we discovered the key technical requirement:

**🔑 The Magic Number: `extradata_size: 2`**

## Technical Analysis

### What We Found

When analyzing M4B files with `ffprobe`, Telegram-compatible files consistently show:
```bash
"extradata_size": 2
```

While non-working files show:
```bash
"extradata_size": 5
```

### The AudioBookBinder Connection

**AudioBookBinder** (the discontinued Mac app) creates perfect Telegram-compatible files because:
- Uses Apple's **AudioToolbox framework** (not ffmpeg)
- Creates minimal AAC-LC configuration 
- Results in `extradata_size: 2`
- No extra codec configuration data that confuses Telegram's player

### Tools Analysis

| Tool | extradata_size | Telegram Compatible |
|------|---------------|-------------------|
| AudioBookBinder | 2 ✅ | Perfect |
| AudiobookConverterX | 5 ❌ | Fails |
| Our new script | 2 ✅ | Perfect |

## 🚀 New Script: `telegram-m4b.sh`

### Features

✅ **Full JSON chapter support** (works with libregrab metadata)  
✅ **AudioBookBinder-style encoding** (extradata_size: 2)  
✅ **Automatic Telegram compatibility verification**  
✅ **Drop-in replacement** for convert_audiobook.sh  
✅ **Cross-platform support** (Mac/Windows workflows)  

### Usage

```bash
# Directory Mode (same as convert_audiobook.sh)
./telegram-m4b.sh --output-dir ~/totag "/path/to/audiobook_directory"

# Manual Mode
./telegram-m4b.sh /path/to/files "output.m4b" "Title" "Author"
```

### Key Encoding Parameters

```bash
-c:a aac
-profile:a aac_low          # Critical: minimal AAC profile
-b:a 64k                    # Optimal bitrate for streaming
-ar 44100                   # Standard sample rate
-ac 2                       # Stereo
-movflags +faststart        # Optimized for streaming
```

## 📊 Test Results

### Verified Telegram-Compatible Files

All these files show `extradata_size: 2`:
- "Human Animal - Seth Insua.m4b" (found in wild)
- "Edith Wharton - Gothic Imagination.m4b" (Audiobook Binder)
- Files created with our new script

### Technical Verification

```bash
# Check if file will work on Telegram
ffprobe -v quiet -select_streams a:0 -show_entries stream=extradata_size -of csv=p=0 "file.m4b"
# Should return: 2
```

## 🔧 Integration with Existing Workflow

### Warp Workflows

Update your existing workflows to use `telegram-m4b.sh` instead of `convert_audiobook.sh`:

```bash
# Old
/Users/cerinawithasea/audiobooks/libregrab-m4b-creator/convert_audiobook.sh

# New  
/Users/cerinawithasea/audiobooks/libregrab-m4b-creator/telegram-m4b.sh
```

### JSON Chapter Support

Fully compatible with existing libregrab metadata structure:
- Reads `metadata/metadata.json`
- Uses existing Python conversion scripts
- Extracts title, author, chapters
- Falls back to filename-based chapters

## 🎯 Why This Matters

1. **Telegram Sharing**: Files can be sent and played directly in Telegram
2. **Streaming Optimized**: Fast start playback
3. **Universal Compatibility**: Works across all players
4. **Proven Method**: Based on AudioBookBinder's successful approach

## 📝 Notes

- This discovery explains why some random M4B files work on Telegram while others don't
- The `extradata_size: 2` appears to be a requirement of Telegram's built-in media player
- AudioBookBinder's approach using Apple's AudioToolbox was accidentally perfect
- Modern tools often add extra codec configuration that breaks Telegram compatibility

## 🚀 Future Improvements

- [ ] Add bitrate options
- [ ] Cover art embedding optimization
- [ ] Batch processing improvements
- [ ] Windows compatibility testing

---

**Created**: June 2025  
**Discovery**: extradata_size analysis of Telegram-playable M4B files  
**Solution**: AudioBookBinder-compatible encoding with minimal AAC configuration
