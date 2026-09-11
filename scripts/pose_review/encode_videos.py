"""Encode complete frozen triptychs at their captured FPS; never invent missing frames."""
import argparse
import subprocess
from pathlib import Path
from revision import ensure_writable, load_capture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--ffmpeg', required=True, help='Path to the available ffmpeg executable')
    args = parser.parse_args()
    folder, manifest, captures = load_capture(args.revision)
    ensure_writable(folder)
    fps = manifest['capture_fps']
    if fps <= 0:
        raise ValueError('Capture FPS must be positive')
    jobs = []
    for name, data in captures.items():
        ids = [int(row['frame']) for row in data['frames']]
        if ids != list(range(len(ids))):
            raise ValueError(f'{name}: video encoding requires a complete sequence beginning at frame zero')
        if any(not (folder / 'frames' / name / f'{i:04d}.jpg').is_file() for i in ids):
            raise ValueError(f'{name}: render every frame first, without --selected')
        destination = folder / 'videos' / f'{name}.mp4'
        if destination.exists():
            raise ValueError(f'Video already exists: {destination}')
        jobs.append((name, len(ids), destination))
    for name, count, destination in jobs:
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([str(Path(args.ffmpeg).resolve()), '-hide_banner', '-loglevel', 'error', '-n',
                        '-framerate', str(fps), '-i', str(folder / 'frames' / name / '%04d.jpg'),
                        '-frames:v', str(count), '-c:v', 'libx264', '-threads', '2', '-crf', '18',
                        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(destination)], check=True)
        print(f'Encoded {name}: {count} frames at {fps} FPS -> {destination}')


if __name__ == '__main__':
    main()
