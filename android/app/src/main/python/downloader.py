import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import urllib.request
from typing import Dict, Optional

try:
    import yt_dlp  # pyre-ignore[21]
except ImportError:
    yt_dlp = None  # pyre-ignore[9]

try:
    from mutagen.easyid3 import EasyID3  # pyre-ignore[21]
    from mutagen.id3 import ID3, APIC  # pyre-ignore[21]
except Exception:
    EasyID3 = None  # pyre-ignore[9]
    ID3 = None  # pyre-ignore[9]
    APIC = None  # pyre-ignore[9]

_event_sink = None
_cancel_flags: Dict[str, bool] = {}
_ffmpeg_override: Optional[str] = None
_SPOTIFY_URI_RE = re.compile(r'spotify:(track|playlist|album):([a-zA-Z0-9]+)')


def set_event_sink(sink):
    global _event_sink
    _event_sink = sink


def set_ffmpeg_path(path: str):
    global _ffmpeg_override
    _ffmpeg_override = path


def _emit(payload: Dict):
    data = json.dumps(payload)
    try:
        if _event_sink is not None:
            _event_sink.emit(data)
            return
    except Exception:
        pass
    try:
        from com.spotify.downloader import PythonEmitter
        PythonEmitter.emit(data)
    except Exception:
        print(data, flush=True)


def _finalize(payload: Dict) -> str:
    _emit(payload)
    return json.dumps(payload)


def _ffmpeg_path() -> str:
    if _ffmpeg_override:
        return _ffmpeg_override
    return os.getenv("FFMPEG_PATH", "ffmpeg")


def _has_ffmpeg(ffmpeg_cmd: str) -> bool:
    return shutil.which(ffmpeg_cmd) is not None


def _fetch_oembed_title(url: str) -> Optional[str]:
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


def _safe_filename(name: str) -> str:
    return re.sub(r"[\\/:*?\"<>|]", "_", name).strip() or "download"


def _normalize_spotify_url(url: str) -> str:
    match = _SPOTIFY_URI_RE.search(url)
    if not match:
        return url
    return f"https://open.spotify.com/{match.group(1)}/{match.group(2)}"


def _tag_mp3(path: str, title: str, artist: str, album: str, cover_path: Optional[str]):
    if EasyID3 is None:
        return
    try:
        audio = EasyID3(path)
    except Exception:
        audio = EasyID3()
    if title:
        audio["title"] = title
    if artist:
        audio["artist"] = artist
    if album:
        audio["album"] = album
    audio.save(path)

    if cover_path and ID3 is not None and APIC is not None:
        try:
            with open(cover_path, "rb") as img:
                tags = ID3(path)
                tags.add(
                    APIC(
                        encoding=3,
                        mime="image/jpeg",
                        type=3,
                        desc="Cover",
                        data=img.read(),
                    )
                )
                tags.save(path)
        except Exception:
            pass


def _pick_downloaded_file(info: Dict, tmp_dir: str) -> Optional[str]:
    try:
        downloads = info.get("requested_downloads") or []
        if downloads:
            path = downloads[0].get("filepath")
            if path and os.path.exists(path):
                return path
    except Exception:
        pass
    path = info.get("_filename") or info.get("filepath")
    if path and os.path.exists(path):
        return path
    try:
        candidates = []
        for name in os.listdir(tmp_dir):
            full = os.path.join(tmp_dir, name)
            if os.path.isfile(full):
                candidates.append(full)
        if not candidates:
            return None
        candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return candidates[0]
    except Exception:
        return None


def cancel_task(task_id: str):
    _cancel_flags[task_id] = True


def cancel_all():
    for key in list(_cancel_flags.keys()):
        _cancel_flags[key] = True


def start_download(
    task_id: str,
    url: str,
    output_dir: str,
    quality: str = "320",
    skip_existing: bool = True,
    embed_art: bool = True,
    normalize: bool = False,
):
    if yt_dlp is None:
        return _finalize({
            "id": task_id,
            "status": "error",
            "progress": 0,
            "message": "yt-dlp not available",
        })

    _cancel_flags[task_id] = False
    os.makedirs(output_dir, exist_ok=True)

    _emit({
        "id": task_id,
        "status": "downloading",
        "progress": 2,
        "message": "Resolving Spotify metadata...",
    })

    url = _normalize_spotify_url(url)
    title_hint = _fetch_oembed_title(url)
    if title_hint:
        search_query = f"ytsearch1:{title_hint}"
    else:
        # Fallback: spotify URL as query text (less accurate, but keeps flow alive).
        search_query = f"ytsearch1:{url}"

    _emit({
        "id": task_id,
        "status": "downloading",
        "progress": 5,
        "message": "Searching matching audio source...",
    })

    tmp_dir = tempfile.mkdtemp(prefix="spotify_")
    output_template = os.path.join(tmp_dir, "%(id)s.%(ext)s")

    def progress_hook(d):
        if _cancel_flags.get(task_id):
            raise Exception("Download cancelled by user")
        if d.get("status") == "downloading":
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
            downloaded = d.get("downloaded_bytes", 0)
            pct = int((downloaded / total) * 80) + 10 if total else 15
            _emit({
                "id": task_id,
                "status": "downloading",
                "progress": pct,
                "message": f"Downloading... {pct}%",
            })
        elif d.get("status") == "finished":
            _emit({
                "id": task_id,
                "status": "processing",
                "progress": 90,
                "message": "Processing audio...",
            })

    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "progress_hooks": [progress_hook],
        "quiet": True,
        "no_warnings": True,
        "writethumbnail": embed_art,
        "noplaylist": True,
        "restrictfilenames": True,
        "socket_timeout": 20,
        "retries": 3,
        "fragment_retries": 3,
    }

    if skip_existing:
        ydl_opts["download_archive"] = os.path.join(output_dir, ".downloaded")

    try:
        _emit({
            "id": task_id,
            "status": "downloading",
            "progress": 8,
            "message": "Connecting to source...",
        })
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:  # pyre-ignore[16]
            info = ydl.extract_info(search_query, download=True)

        if _cancel_flags.get(task_id):
            return _finalize({
                "id": task_id,
                "status": "cancelled",
                "progress": 0,
                "message": "Download cancelled",
            })

        if "entries" in info and info["entries"]:
            info = info["entries"][0]

        src_path = _pick_downloaded_file(info, tmp_dir) or ydl.prepare_filename(info)
        if (not src_path) and info.get("id"):
            try:
                vid = info.get("id")
                for name in os.listdir(tmp_dir):
                    if name.startswith(f"{vid}."):
                        src_path = os.path.join(tmp_dir, name)
                        break
            except Exception:
                pass
        if not os.path.exists(src_path):
            return _finalize({
                "id": task_id,
                "status": "error",
                "progress": 0,
                "message": f"Download output not found: {src_path}",
            })
        base_name = _safe_filename(info.get("title") or "download")
        dest_path = os.path.join(output_dir, f"{base_name}.mp3")

        ffmpeg = _ffmpeg_path()
        _emit({
            "id": task_id,
            "status": "processing",
            "progress": 93,
            "message": "Converting to mp3...",
        })

        ffmpeg_available = _has_ffmpeg(ffmpeg)
        if ffmpeg_available:
            if not os.path.exists(dest_path):
                cmd = [
                    ffmpeg,
                    "-y",
                    "-i",
                    src_path,
                    "-vn",
                    "-b:a",
                    f"{quality}k",
                    dest_path,
                ]
                subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            # Fallback for devices without ffmpeg binary: keep original downloaded format.
            src_ext = os.path.splitext(src_path)[1] or ".m4a"
            dest_path = os.path.join(output_dir, f"{base_name}{src_ext}")
            if not os.path.exists(dest_path):
                shutil.copy2(src_path, dest_path)

        cover_path = None
        if embed_art:
            thumb = info.get("thumbnail")
            if thumb:
                cover_path = os.path.join(tmp_dir, f"{base_name}.jpg")
                try:
                    urllib.request.urlretrieve(thumb, cover_path)
                except Exception:
                    cover_path = None

        if dest_path.lower().endswith(".mp3"):
            _tag_mp3(
                dest_path,
                info.get("title") or "",
                info.get("artist") or info.get("uploader") or "",
                info.get("album") or "",
                cover_path,
            )

        return _finalize({
            "id": task_id,
            "status": "completed",
            "progress": 100,
            "message": "Download completed" if ffmpeg_available else "Download completed (no ffmpeg: original format)",
            "filePath": dest_path,
        })
    except Exception as exc:
        msg = str(exc)
        status = "cancelled" if "cancelled" in msg.lower() else "error"
        return _finalize({
            "id": task_id,
            "status": status,
            "progress": 0,
            "message": f"Download failed: {msg}",
        })
