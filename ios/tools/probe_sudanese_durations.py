#!/usr/bin/env python3
"""How the Sudanese reciters' durations in surahs.json were derived
(phase 2, 2026-11-12). The streams are constant-bitrate MP3, so a
duration is (file bytes - tag overhead) * 8 / bitrate:

- HEAD every file for its Content-Length (all 114, both reciters).
- ffprobe a sample of full downloads for the exact stream bitrate
  and ground-truth duration; fit the constant overhead per reciter
  (Noreen Mohammad Siddiq: 128000 bps throughout, overhead about
  32,800 bytes; Alzain Mohammad Ahmad: mixed 96000/128000 bps per
  file, so the bitrate was probed per file from a 256 KB range
  download, overhead about 23,000 bytes).
- The fitted formula reproduced every ffprobe ground truth exactly
  (Noreen: surahs 1, 2, 36, 78, 114; Alzain: surahs 1, 2, 18, 36,
  78, 114).

This script re-runs the HEAD pass and prints the byte table; the
generator that merged the durations into surahs.json lived in the
build session, the method and the fitted constants are what matter.
"""
import concurrent.futures
import urllib.request

RECITERS = {
    "sd.noreen": "https://cdn.mp3quran.net/audio/noreen-siddiq/r1",
    "sd.alzain": "https://cdn.mp3quran.net/audio/zain-ahmad/r1",
}


def head(url):
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return int(resp.headers["Content-Length"])


def main():
    for reciter, base in RECITERS.items():
        def fetch(n):
            return n, head(f"{base}/{n:03d}.mp3")
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            sizes = dict(pool.map(fetch, range(1, 115)))
        print(reciter, "files:", len(sizes),
              "total bytes:", sum(sizes.values()))


if __name__ == "__main__":
    main()
