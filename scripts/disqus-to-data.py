#!/usr/bin/env python3
"""Convert a Disqus XML export into data/comments.json for Hugo.

Usage: ./scripts/disqus-to-data.py <export.xml[.gz]> [output.json]
"""

import gzip
import json
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

NS = {
    "d": "http://disqus.com",
    "dsq": "http://disqus.com/disqus-internals",
}


def normalize_path(link: str) -> str:
    path = urlparse(link).path
    # Old Octopress permalinks lived under /blog/, Hugo serves them from /.
    if path.startswith("/blog/"):
        path = path[len("/blog") :]
    if not path.endswith("/"):
        path += "/"
    return path


def text(elem: ET.Element | None) -> str:
    return elem.text or "" if elem is not None else ""


def parse(source: Path) -> dict[str, list[dict[str, Any]]]:
    data = (
        gzip.decompress(source.read_bytes())
        if source.suffix == ".gz"
        else source.read_bytes()
    )
    root = ET.fromstring(data)

    threads: dict[str, str] = {}  # dsq:id -> page path
    for thread in root.findall("d:thread", NS):
        tid = thread.attrib[f"{{{NS['dsq']}}}id"]
        threads[tid] = normalize_path(text(thread.find("d:link", NS)))

    comments: dict[str, dict[str, Any]] = {}  # post dsq:id -> comment
    by_page: dict[str, list[dict[str, Any]]] = {}
    for post in root.findall("d:post", NS):
        if (
            text(post.find("d:isSpam", NS)) == "true"
            or text(post.find("d:isDeleted", NS)) == "true"
        ):
            continue
        thread_ref = post.find("d:thread", NS)
        if thread_ref is None:
            continue
        page = threads.get(thread_ref.attrib[f"{{{NS['dsq']}}}id"])
        if page is None:
            continue
        pid = post.attrib[f"{{{NS['dsq']}}}id"]
        parent_ref = post.find("d:parent", NS)
        created = text(post.find("d:createdAt", NS))
        comment = {
            "author": text(post.find("d:author/d:name", NS)) or "Anonymous",
            "date": datetime.fromisoformat(created.replace("Z", "+00:00")).strftime(
                "%d %b %Y"
            ),
            "message": text(post.find("d:message", NS)),
            "replies": [],
        }
        comments[pid] = comment
        if (
            parent_ref is not None
            and parent_ref.attrib[f"{{{NS['dsq']}}}id"] in comments
        ):
            comments[parent_ref.attrib[f"{{{NS['dsq']}}}id"]]["replies"].append(comment)
        else:
            by_page.setdefault(page, []).append(comment)
    return by_page


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("data/comments.json")
    by_page = parse(Path(sys.argv[1]))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(by_page, indent=2, ensure_ascii=False) + "\n")
    total = sum(len(v) for v in by_page.values())
    print(f"{total} top-level comments on {len(by_page)} pages -> {out}")


if __name__ == "__main__":
    main()
