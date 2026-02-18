import json
import re
import os
import threading
import urllib.request
import downloader

_download_thread = None
_cancel_flag = False
_event_sink = None
_SPOTIFY_URL_RE = re.compile(
    r'https?://open\.spotify\.com/(?:intl-[a-z]{2}/)?(track|playlist|album)/([a-zA-Z0-9]+)',
)
_SPOTIFY_URI_RE = re.compile(r'spotify:(track|playlist|album):([a-zA-Z0-9]+)')


def validate_url(url):
    """Validate if the given URL is a valid Spotify link."""
    match = _SPOTIFY_URL_RE.search(url) or _SPOTIFY_URI_RE.search(url)
    if match:
        return json.dumps({
            'valid': True,
            'type': match.group(1),
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
    payload = json.dumps({
        'status': status,
        'progress': progress,
        'message': message,
        'type': msg_type
    })
    try:
        if _event_sink is not None:
            _event_sink.emit(payload)
            return
    except Exception:
        pass
    try:
        from com.spotify.downloader import PythonEmitter
        PythonEmitter.emit(payload)
        return
    except Exception:
        print(payload, flush=True)


def set_event_sink(sink):
    """Set Kotlin event sink for streaming progress."""
    global _event_sink
    _event_sink = sink
    downloader.set_event_sink(sink)


def set_ffmpeg_path(path):
    downloader.set_ffmpeg_path(path)


def _extract_spotify_id(url):
    """Extract the Spotify track/playlist/album ID from a URL."""
    match = _SPOTIFY_URL_RE.search(url) or _SPOTIFY_URI_RE.search(url)
    if match:
        return match.group(1), match.group(2)
    return None, None


def _normalize_spotify_url(url):
    """Convert spotify: URIs to https URLs for oEmbed/YT search usage."""
    match = _SPOTIFY_URI_RE.search(url)
    if not match:
        return url
    return f"https://open.spotify.com/{match.group(1)}/{match.group(2)}"


def _fetch_spotify_oembed_title(url):
    """Fetch Spotify oEmbed data to build a better YouTube search query."""
    try:
        url = _normalize_spotify_url(url)
        oembed_url = f"https://open.spotify.com/oembed?url={url}"
        with urllib.request.urlopen(oembed_url, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        title = data.get("title", "").strip()
        if title:
            return title
    except Exception:
        return None
    return None


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
        task_id = "single"
        downloader.start_download(
            task_id,
            _normalize_spotify_url(url),
            output_dir,
            quality,
            skip_existing,
            embed_art,
            normalize,
        )
    except Exception as e:
        error_msg = str(e)
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
        import yt_dlp  # pyre-ignore[21]
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
