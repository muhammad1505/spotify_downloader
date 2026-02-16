import json
import os
import re
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


def set_event_sink(sink):
    global _event_sink
    _event_sink = sink


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


def _ffmpeg_path() -> str:
    return os.getenv("FFMPEG_PATH", "ffmpeg")


def _fetch_oembed_title(url: str) -> Optional[str]:
    try:
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
        _emit({
            "id": task_id,
            "status": "error",
            "progress": 0,
            "message": "yt-dlp not available",
        })
        return

    _cancel_flags[task_id] = False
    os.makedirs(output_dir, exist_ok=True)

    title_hint = _fetch_oembed_title(url)
    search_query = f"ytsearch:{title_hint}" if title_hint else f"ytsearch:{url}"

    _emit({
        "id": task_id,
        "status": "downloading",
        "progress": 3,
        "message": "Preparing download...",
    })

    tmp_dir = tempfile.mkdtemp(prefix="spotify_")
    output_template = os.path.join(tmp_dir, "%(title)s.%(ext)s")

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
    }

    if skip_existing:
        ydl_opts["download_archive"] = os.path.join(output_dir, ".downloaded")

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:  # pyre-ignore[16]
            info = ydl.extract_info(search_query, download=True)

        if _cancel_flags.get(task_id):
            _emit({
                "id": task_id,
                "status": "cancelled",
                "progress": 0,
                "message": "Download cancelled",
            })
            return

        if "entries" in info and info["entries"]:
            info = info["entries"][0]

        src_path = ydl.prepare_filename(info)
        base_name = _safe_filename(info.get("title") or "download")
        dest_path = os.path.join(output_dir, f"{base_name}.mp3")

        ffmpeg = _ffmpeg_path()
        _emit({
            "id": task_id,
            "status": "processing",
            "progress": 93,
            "message": "Converting to mp3...",
        })

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

        cover_path = None
        if embed_art:
            thumb = info.get("thumbnail")
            if thumb:
                cover_path = os.path.join(tmp_dir, f"{base_name}.jpg")
                try:
                    urllib.request.urlretrieve(thumb, cover_path)
                except Exception:
                    cover_path = None

        _tag_mp3(
            dest_path,
            info.get("title") or "",
            info.get("artist") or info.get("uploader") or "",
            info.get("album") or "",
            cover_path,
        )

        _emit({
            "id": task_id,
            "status": "completed",
            "progress": 100,
            "message": "Download completed",
            "filePath": dest_path,
        })
    except Exception as exc:
        msg = str(exc)
        status = "cancelled" if "cancelled" in msg.lower() else "error"
        _emit({
            "id": task_id,
            "status": status,
            "progress": 0,
            "message": f"Download failed: {msg}",
        })
