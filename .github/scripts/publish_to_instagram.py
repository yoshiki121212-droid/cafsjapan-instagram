import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

GRAPH_API = "https://graph.instagram.com/v21.0"


def http_json(url, data=None, method="GET"):
    req = urllib.request.Request(url, data=data, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"Instagram API error ({e.code}): {body}", file=sys.stderr)
        raise


def raw_url(repo, sha, folder, filename):
    encoded_folder = urllib.parse.quote(folder)
    encoded_file = urllib.parse.quote(filename)
    return f"https://raw.githubusercontent.com/{repo}/{sha}/{encoded_folder}/{encoded_file}"


def create_media_container(ig_user_id, access_token, params):
    body = urllib.parse.urlencode({**params, "access_token": access_token}).encode("utf-8")
    return http_json(f"{GRAPH_API}/{ig_user_id}/media", data=body, method="POST")


def wait_until_finished(container_id, access_token, timeout_s=60):
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        status = http_json(
            f"{GRAPH_API}/{container_id}?fields=status_code&access_token={urllib.parse.quote(access_token)}"
        )
        code = status.get("status_code")
        if code == "FINISHED":
            return
        if code == "ERROR":
            print(f"Container processing failed: {status}", file=sys.stderr)
            sys.exit(1)
        time.sleep(3)
    print(f"Timed out waiting for container {container_id} to finish processing.", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Usage: publish_to_instagram.py <folder>", file=sys.stderr)
        sys.exit(1)

    folder = sys.argv[1]
    ig_user_id = os.environ["IG_USER_ID"]
    access_token = os.environ["IG_ACCESS_TOKEN"]
    repo = os.environ["GITHUB_REPOSITORY"]
    sha = os.environ["GITHUB_SHA"]

    if not os.path.isdir(folder):
        print(f"Folder not found: {folder}", file=sys.stderr)
        sys.exit(1)

    image_files = sorted(
        f for f in os.listdir(folder)
        if f.lower().endswith((".png", ".jpg", ".jpeg"))
    )
    if not image_files:
        print(f"No image files found in {folder}", file=sys.stderr)
        sys.exit(1)
    if len(image_files) > 10:
        print("Instagram carousels support at most 10 images; trimming to the first 10.", file=sys.stderr)
        image_files = image_files[:10]

    caption = ""
    caption_path = os.path.join(folder, "caption.txt")
    if os.path.exists(caption_path):
        with open(caption_path, encoding="utf-8") as f:
            caption = f.read().strip()
    else:
        print(f"Note: no caption.txt found in {folder}; publishing without a caption.", file=sys.stderr)

    if len(image_files) == 1:
        container = create_media_container(ig_user_id, access_token, {
            "image_url": raw_url(repo, sha, folder, image_files[0]),
            "caption": caption,
        })
        creation_id = container["id"]
    else:
        child_ids = []
        for fname in image_files:
            resp = create_media_container(ig_user_id, access_token, {
                "image_url": raw_url(repo, sha, folder, fname),
                "is_carousel_item": "true",
            })
            child_ids.append(resp["id"])
            print(f"Created child container for {fname}: {resp['id']}")

        carousel = create_media_container(ig_user_id, access_token, {
            "media_type": "CAROUSEL",
            "children": ",".join(child_ids),
            "caption": caption,
        })
        creation_id = carousel["id"]

    wait_until_finished(creation_id, access_token)

    published = http_json(
        f"{GRAPH_API}/{ig_user_id}/media_publish",
        data=urllib.parse.urlencode({
            "creation_id": creation_id,
            "access_token": access_token,
        }).encode("utf-8"),
        method="POST",
    )

    print(json.dumps(published, ensure_ascii=False, indent=2))

    media_id = published.get("id")
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as sf:
            sf.write(f"## Instagram publish result\n\nFolder: {folder}\n\nImages: {len(image_files)}\n\nMedia ID: {media_id}\n\nStatus: published\n")


if __name__ == "__main__":
    main()
