#!/usr/bin/env python3
"""Shows a GitHub Actions run as a progress bar, redrawn until it finishes.

    python3 scripts/watch_run.py            # the latest Release run
    python3 scripts/watch_run.py 123456789  # a run by id
    python3 scripts/watch_run.py --once     # print once and leave

Every job counts the same in the bar, and a job's share fills as its steps finish, so the
percentage is a measure of steps and not of time. Exits 0 only if the run succeeded.
"""

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone

BAR_WIDTH = 32
POLL_SECONDS = 10
ICONS = {"success": "✓", "skipped": "-", "cancelled": "!", "failure": "✗", "timed_out": "✗"}
DONE_STEP = ("success", "skipped", "failure", "cancelled", "timed_out", "neutral")


def gh_json(*args):
    return json.loads(subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True).stdout)


def latest_release_run():
    runs = gh_json("run", "list", "--workflow", "release.yml", "--limit", "1",
                   "--json", "databaseId")
    if not runs:
        sys.exit("No Release runs yet.")
    return str(runs[0]["databaseId"])


def fetch(run_id):
    return gh_json("run", "view", run_id, "--json",
                   "status,conclusion,displayTitle,headBranch,createdAt,updatedAt,url,jobs")


def seconds_between(start, end=None):
    if not start or start.startswith("0001"):
        return 0
    begin = datetime.fromisoformat(start.replace("Z", "+00:00"))
    stop = datetime.fromisoformat(end.replace("Z", "+00:00")) if end else datetime.now(timezone.utc)
    return max(0, int((stop - begin).total_seconds()))


def clock(seconds):
    return f"{seconds // 60}:{seconds % 60:02d}"


def job_fraction(job):
    if job["status"] == "completed":
        return 1.0
    steps = job.get("steps") or []
    if not steps:
        return 0.0
    return sum(s["conclusion"] in DONE_STEP for s in steps) / len(steps)


def job_line(job, name_width):
    name = job["name"].ljust(name_width)
    if job["status"] == "completed":
        icon = ICONS.get(job["conclusion"], "?")
        if job["conclusion"] == "skipped":
            return f"  {icon} {name}  skipped"
        return f"  {icon} {name}  {clock(seconds_between(job['startedAt'], job['completedAt']))}"
    if job["status"] != "in_progress":
        return f"  · {name}  waiting"
    current = next((s["name"] for s in job.get("steps") or []
                    if s["status"] == "in_progress"), "")
    return f"  ▶ {name}  {clock(seconds_between(job['startedAt']))}  {current}"


def render(run):
    jobs = run["jobs"]
    finished = run["status"] == "completed"
    share = 1.0 if finished else (sum(map(job_fraction, jobs)) / len(jobs) if jobs else 0.0)
    filled = round(share * BAR_WIDTH)
    bar = "█" * filled + "░" * (BAR_WIDTH - filled)
    elapsed = seconds_between(run["createdAt"], run["updatedAt"] if finished else None)
    state = run["conclusion"] if finished else run["status"].replace("_", " ")
    name_width = max((len(j["name"]) for j in jobs), default=0)
    return [
        f"{run['displayTitle']} on {run['headBranch']}",
        f"[{bar}] {share * 100:3.0f}%  {clock(elapsed)}  {state}",
        *(job_line(j, name_width) for j in jobs),
    ]


def main():
    parser = argparse.ArgumentParser(description="Progress bar for a GitHub Actions run")
    parser.add_argument("run_id", nargs="?", help="run id (default: the latest Release run)")
    parser.add_argument("--once", action="store_true", help="print once and leave")
    args = parser.parse_args()

    run_id = args.run_id or latest_release_run()
    redraw = sys.stdout.isatty()
    drawn = 0
    last = None
    while True:
        try:
            run = fetch(run_id)
        except subprocess.CalledProcessError:
            # A dropped connection shouldn't end the watch: the run goes on without us.
            time.sleep(POLL_SECONDS)
            continue
        lines = render(run)
        if redraw:
            width = shutil.get_terminal_size().columns
            # A wrapped line would throw off the count of lines to go back over.
            lines = [line[:width - 1] for line in lines]
            if drawn:
                print(f"\x1b[{drawn}A\x1b[J", end="")
            print("\n".join(lines), flush=True)
            drawn = len(lines)
        elif lines[1:] != last:
            print("\n".join(lines), end="\n\n", flush=True)
            last = lines[1:]
        if args.once or run["status"] == "completed":
            break
        time.sleep(POLL_SECONDS)

    print(run["url"])
    if args.once:
        return 0
    return 0 if run["conclusion"] == "success" else 1


if __name__ == "__main__":
    sys.exit(main())
