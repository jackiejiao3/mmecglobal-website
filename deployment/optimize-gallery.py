#!/usr/bin/env python3
"""Rebuild Gallery WebP derivatives (requires Pillow); never overwrite originals.

Run from any directory: python deployment/optimize-gallery.py
The manifest points to quarantined originals so derivatives remain reproducible.
"""
import hashlib
import io
import json
import re
from html import unescape
from html.parser import HTMLParser
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'deployment/gallery-assets.json'


class Images(HTMLParser):
    def __init__(self):
        super().__init__()
        self.sources = set()

    def handle_starttag(self, tag, attrs):
        src = dict(attrs).get('src', '')
        if tag == 'img' and '/Gallery/' in src:
            self.sources.add(src)


def main():
    page = ROOT / 'gallery.html'
    html = page.read_text()
    parser = Images()
    parser.feed(html)
    previous = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else []
    sources = parser.sources | {entry['source'] for entry in previous}
    sources.add('quarantine/gallery-loading-2026-10-29/replaced-assets/images/gallery-banner.png')
    output = ROOT / 'images/gallery-optimized'
    output.mkdir(exist_ok=True)
    entries = []
    for source in sorted(sources):
        original = ROOT / source
        digest = hashlib.sha256(original.read_bytes()).hexdigest()[:12]
        name = re.sub(r'[^a-z0-9]+', '-', '-'.join(Path(source).parts[-2:]).lower()).strip('-')
        target = output / f'{name}-{digest}.webp'
        with Image.open(original) as image:
            image = ImageOps.exif_transpose(image).convert('RGB')
            width, height = image.size
            buffer = io.BytesIO()
            image.save(buffer, 'WEBP', quality=82, method=6)
        # Never expose a partially encoded derivative to a preview/server.
        temporary = target.with_suffix('.webp.tmp')
        temporary.write_bytes(buffer.getvalue())
        temporary.replace(target)
        entries.append(dict(source=source, output=target.relative_to(ROOT).as_posix(),
                            width=width, height=height, source_bytes=original.stat().st_size,
                            output_bytes=target.stat().st_size))
    # Update the exact original paths, including paths from the previous manifest.
    old_paths = {entry['source']: entry['source'] for entry in entries}
    old_paths.update({entry['output']: entry['source'] for entry in previous})
    by_source = {entry['source']: entry for entry in entries}
    for old, source in sorted(old_paths.items(), key=lambda item: -len(item[0])):
        html = html.replace(old, by_source[source]['output'])
    by_output = {entry['output']: entry for entry in entries}
    photo_number = 0

    def dimensions(match):
        nonlocal photo_number
        tag = match.group()
        src_match = re.search(r'\bsrc="([^"]+)"', tag)
        if not src_match:
            return tag
        src = unescape(src_match[1])
        if src in by_output:
            entry = by_output[src]
            width, height = entry['width'], entry['height']
            # Each card has a front and a flip-side image; keep the first row eager.
            eager = photo_number < 8
            photo_number += 1
            tag = re.sub(r'\s+(?:width|height|loading|decoding)="[^"]*"', '', tag)
            return tag[:-1] + f' width="{width}" height="{height}" loading="{"eager" if eager else "lazy"}" decoding="async">'
        if (ROOT / src).is_file():
            with Image.open(ROOT / src) as image:
                width, height = image.size
            tag = re.sub(r'\s+(?:width|height)="[^"]*"', '', tag)
            return tag[:-1] + f' width="{width}" height="{height}">'
        return tag

    html = re.sub(r'<img\b[^>]*>', dimensions, html)
    html = re.sub(r'(<img\b[^>]*>)[\t ]+(?=\n)', r'\1', html)
    page.write_text(html.rstrip() + '\n')
    MANIFEST.write_text(json.dumps(entries, indent=2) + '\n')
    before = sum(entry['source_bytes'] for entry in entries)
    after = sum(entry['output_bytes'] for entry in entries)
    print(f'{len(entries)} assets: {before:,} -> {after:,} bytes ({1 - after / before:.1%} smaller)')


if __name__ == '__main__':
    main()
