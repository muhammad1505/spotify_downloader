import json
import re
import os
import threading

try:
    import yt_dlp  # pyre-ignore[21]: Installed by Chaquopy at build time
except ImportError:
    yt_dlp = None  # pyre-ignore[9]

_download_thread = None
_cancel_flag = False


def validate_url(url):
    """Validate if the given URL is a valid Spotify link."""
    patterns = {
        'track': r'https?://open\.spotify\.com/track/[a-zA-Z0-9]+',
        'playlist': r'https?://open\.spotify\.com/playlist/[a-zA-Z0-9]+',
        'album': r'https?://open\.spotify\.com/album/[a-zA-Z0-9]+',
    }

    for url_type, pattern in patterns.items():
        if re.match(pattern, url):
            return json.dumps({
                'valid': True,
                'type': url_type,
                'url': url
            })

    return json.dumps({
        'valid': False,
        'type': None,
        'url': url,
        'message': 'Invalid Spotify URL'
    })


def _emit(status, progress, message, msg_type='info'):
    """Emit a JSON status line."""
    print(json.dumps({
        'status': status,
        'progress': progress,
        'message': message,
        'type': msg_type
    }), flush=True)


def _extract_spotify_id(url):
    """Extract the Spotify track/playlist/album ID from a URL."""
    match = re.search(r'spotify\.com/(track|playlist|album)/([a-zA-Z0-9]+)', url)
    if match:
        return match.group(1), match.group(2)
    return None, None


def start_download(url, output_dir, quality='320', skip_existing=True,
                    embed_art=True, normalize=False):
    """
    Start downloading audio from a Spotify URL using yt-dlp.
    Converts Spotify URL to a YouTube search and downloads.
    Streams progress as JSON lines to stdout.
    """
    global _cancel_flag
    _cancel_flag = False

    # Validate URL first
    validation = json.loads(validate_url(url))
    if not validation['valid']:
        _emit('error', 0, 'Invalid Spotify URL', 'error')
        return

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    _emit('downloading', 0, 'Starting download...', 'info')

    try:

        content_type, content_id = _extract_spotify_id(url)

        # For Spotify URLs, we search YouTube with the track info
        # yt-dlp supports ytsearch: prefix for YouTube searches
        if content_type == 'track':
            # Use the Spotify URL directly - yt-dlp has some Spotify support
            # Or search YouTube with the URL as a search query
            search_query = f"ytsearch:{url}"
        else:
            search_query = f"ytsearch:{url}"

        _emit('downloading', 5, 'Searching for audio...', 'info')

        # Map quality to audio bitrate
        bitrate_map = {'128': '128', '192': '192', '320': '320'}
        audio_quality = bitrate_map.get(quality, '320')

        # Progress hook for yt-dlp
        def progress_hook(d):
            if _cancel_flag:
                raise Exception("Download cancelled by user")

            if d['status'] == 'downloading':
                total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
                downloaded = d.get('downloaded_bytes', 0)
                if total > 0:
                    pct = int((downloaded / total) * 90) + 5  # 5-95%
                else:
                    pct = 10
                speed = d.get('speed', 0)
                speed_str = f"{speed / 1024:.0f} KB/s" if speed else "..."
                _emit('downloading', pct,
                      f"Downloading... {pct}% ({speed_str})", 'info')

            elif d['status'] == 'finished':
                _emit('converting', 95, 'Converting audio...', 'info')

        postprocessors = [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': audio_quality,
        }]

        if embed_art:
            postprocessors.append({
                'key': 'EmbedThumbnail',
            })

        ydl_opts = {
            'format': 'bestaudio/best',
            'outtmpl': os.path.join(output_dir, '%(title)s.%(ext)s'),
            'postprocessors': postprocessors,
            'progress_hooks': [progress_hook],
            'quiet': True,
            'no_warnings': True,
            'writethumbnail': embed_art,
            'noplaylist': content_type == 'track',
        }

        if skip_existing:
            ydl_opts['download_archive'] = os.path.join(output_dir, '.downloaded')

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:  # pyre-ignore[16]
            _emit('downloading', 10, 'Fetching metadata...', 'info')
            ydl.download([search_query])

        if not _cancel_flag:
            _emit('completed', 100, 'Download completed successfully!', 'success')

    except Exception as e:
        error_msg = str(e)
        if 'cancelled' in error_msg.lower():
            _emit('cancelled', 0, 'Download cancelled by user', 'warning')
        else:
            _emit('error', 0, f'Download failed: {error_msg}', 'error')


def cancel_download():
    """Cancel the current download."""
    global _cancel_flag
    _cancel_flag = True

    return json.dumps({
        'status': 'cancelled',
        'progress': 0,
        'message': 'Download cancellation requested',
        'type': 'warning'
    })


def get_version():
    """Return yt-dlp version info."""
    try:
        return json.dumps({
            'status': 'success',
            'version': f"yt-dlp {yt_dlp.version.__version__}",  # pyre-ignore[16]
            'type': 'info'
        })
    except Exception as e:
        return json.dumps({
            'status': 'error',
            'message': str(e),
            'type': 'error'
        })
