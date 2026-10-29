#!/usr/bin/env python3
"""Inventory every root HTML page and its local loading dependencies.

Run: python deployment/audit-loading.py > deployment/loading-inventory.json
Byte totals describe declared, unique local assets, not first-viewport transfers.
CSS URL references are checked for existence, not assumed to be requested.
"""
import hashlib
import json
import re
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
CSS_URL = re.compile(r'url\(\s*[\'"]?([^\'"\)]+)[\'"]?\s*\)')


def local_path(url, parent):
    parsed = urlsplit(url.strip())
    if parsed.scheme or parsed.netloc or not parsed.path:
        return None
    path = (ROOT / unquote(parsed.path).lstrip('/') if parsed.path.startswith('/')
            else parent / unquote(parsed.path)).resolve()
    return path if path.is_relative_to(ROOT) else None


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.path = path
        self.images, self.scripts, self.css, self.backgrounds, self.links = [], [], [], [], []
        self.loader = False
        self.portfolio = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = attrs.get('class', '').split()
        self.loader |= 'loading-area' in classes
        self.portfolio |= 'portfolio-wrap' in classes and 'data-gallery-grid' not in attrs
        if tag == 'img':
            self.images.append(attrs)
        if tag == 'script' and 'src' in attrs:
            self.scripts.append(attrs['src'])
        if tag == 'link' and 'stylesheet' in attrs.get('rel', ''):
            self.css.append(attrs['href'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])
        self.backgrounds.extend(CSS_URL.findall(attrs.get('style', '')))


def existing(urls, parent):
    return {p for url in urls if (p := local_path(url, parent)) and p.is_file()}


def relative(path):
    return path.relative_to(ROOT).as_posix()


def main():
    pages, missing, css_missing, css_seen = [], defaultdict(set), defaultdict(set), set()

    def check(url, parent, owner):
        path = local_path(url, parent)
        if path and not path.is_file():
            missing[relative(path)].add(owner)

    def check_css(path):
        if path in css_seen or not path.is_file():
            return
        css_seen.add(path)
        for url in CSS_URL.findall(path.read_text(errors='replace')):
            target = local_path(url, path.parent)
            if target and not target.is_file():
                css_missing[relative(target)].add(relative(path))
            elif target and target.suffix == '.css':
                check_css(target)

    for path in sorted(ROOT.glob('*.html')):
        parser = Page(path)
        parser.feed(path.read_text())
        image_urls = [image.get('src', '') for image in parser.images] + parser.backgrounds
        assets = existing(image_urls, path.parent)
        scripts = existing(parser.scripts, path.parent)
        styles = existing(parser.css, path.parent)
        for url in image_urls + parser.scripts + parser.css:
            check(url, path.parent, path.name)
        for style in styles:
            check_css(style)
        identical = defaultdict(list)
        for style in styles:
            identical[hashlib.sha256(style.read_bytes()).hexdigest()].append(relative(style))
        lazy = sum(image.get('loading') == 'lazy' for image in parser.images)
        pages.append(dict(page=path.name, html_bytes=path.stat().st_size,
                          image_tags=len(parser.images), lazy_images=lazy,
                          images_missing_dimensions=sum(not image.get('width') or not image.get('height') for image in parser.images),
                          image_and_inline_background_bytes=sum(asset.stat().st_size for asset in assets),
                          image_assets=[dict(path=relative(asset), bytes=asset.stat().st_size) for asset in sorted(assets)],
                          external_scripts=len(parser.scripts), script_bytes=sum(asset.stat().st_size for asset in scripts),
                          stylesheets=len(parser.css), css_bytes=sum(asset.stat().st_size for asset in styles),
                          identical_stylesheets=[sorted(group) for group in identical.values() if len(group) > 1],
                          whole_page_loader=parser.loader,
                          legacy_imagesloaded_masonry=parser.portfolio and any('imagesloaded' in url for url in parser.scripts)))

    result = dict(scope='All root HTML pages; unique local img src and inline backgrounds; CSS URLs checked separately. Not a browser waterfall or an estimate of first-viewport traffic.',
                  pages=pages,
                  missing_direct_assets=[dict(path=path, pages=sorted(owners)) for path, owners in sorted(missing.items())],
                  missing_css_assets=[dict(path=path, stylesheets=sorted(owners)) for path, owners in sorted(css_missing.items())])
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
