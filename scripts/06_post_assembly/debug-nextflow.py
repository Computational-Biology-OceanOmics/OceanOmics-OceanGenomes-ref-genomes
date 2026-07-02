#!/usr/bin/env python3
"""
Called when a Nextflow pipeline fails in the tmux launch script.

1. Posts a failure task to Asana (immediate alert)
2. Opens a new tmux window 'debug' in the existing nf_{run} session
3. Launches Claude Code there to read the log, diagnose the failure,
   and resume the pipeline if it's a transient error

Usage:
  python3 debug-nextflow.py \
      --run PACB_260227_AMD \
      --run-dir /scratch/pawsey0964/$USER/ref-gen/runs/PACB_260227_AMD \
      --script /scratch/pawsey0964/$USER/ref-gen/configs/run_PACB_260227_AMD.sh \
      --og-ids OG1369,OG1422 \
      --samplesheet /path/to/samplesheet.csv \
      [--log-dir /scratch/pawsey0964/$USER/logs]
"""

import getpass
import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

# "claude" is resolved via PATH inside the tmux login shell (each user's own
# nvm-installed binary, sourced via their .bashrc) — no hardcoded install path.
CLAUDE_BIN        = os.environ.get("CLAUDE_BIN", "claude")
UWA_WORKSPACE_GID = "1103015454494961"
USER_REAL         = os.environ.get("USER") or getpass.getuser()
MYSCRATCH         = os.environ.get("MYSCRATCH") or f"/scratch/pawsey0964/{USER_REAL}"
LOG_DIR           = os.environ.get("HICHIFI_LOG_DIR", f"{MYSCRATCH}/logs")


def load_token():
    token = os.environ.get("ASANA_TOKEN", "")
    if not token:
        cfg = os.path.expanduser("~/asana_token.config")
        if os.path.exists(cfg):
            with open(cfg) as f:
                token = f.read().strip()
    return token


def asana_post(path, data, token):
    url  = f"https://app.asana.com/api/1.0{path}"
    body = json.dumps({"data": data}).encode()
    req  = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def get_me(token):
    req = urllib.request.Request(
        "https://app.asana.com/api/1.0/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["data"]


def post_failure_task(run_name, run_dir, tmux_session, token):
    """Create an Asana task alerting that Nextflow failed."""
    me = get_me(token)
    log_path = f"{run_dir}/.nextflow.log"
    notes = (
        f"Run: {run_name}\n"
        f"Nextflow pipeline FAILED at {datetime.now().strftime('%Y-%m-%d %H:%M AWST')}\n\n"
        f"A Claude Code debug agent has been launched automatically.\n"
        f"Attach to the tmux session to watch or intervene:\n"
        f"  tmux attach -t {tmux_session}\n"
        f"  (switch to the 'debug' window)\n\n"
        f"Nextflow log: {log_path}\n"
        f"Run directory: {run_dir}"
    )
    result = asana_post("/tasks", {
        "name":      f"Nextflow FAILED: {run_name} — debug agent running",
        "notes":     notes,
        "assignee":  me["gid"],
        "workspace": UWA_WORKSPACE_GID,
    }, token)
    return result["data"]["gid"]


def launch_debug_agent(run_name, run_dir, script_path, og_ids, samplesheet, assembly_mode="hifi_only"):
    """Open a new tmux window and launch Claude Code to debug the failure."""
    tmux_session = f"nf_{run_name}"
    log_path     = f"{run_dir}/.nextflow.log"

    # Write the prompt to a file so we can pass complex multi-line context
    prompt = f"""The Nextflow {assembly_mode} assembly pipeline for run '{run_name}' just failed on the Pawsey HPC cluster (setonix-07).

Your job:
1. Read the Nextflow log at: {log_path}
   - Focus on the tail of the file — look for ERROR, FAILED, Exception lines
   - Also check for per-process error logs (Nextflow prints paths like work/xx/yy/.command.err)
2. Read any referenced .command.err or .command.log files to get the full error
3. Diagnose the root cause. Common causes on Pawsey:
   - SLURM job preemption or walltime exceeded → safe to resume
   - Node failure / lost connection → safe to resume
   - Out of memory (OOM) → may need config change before resume
   - Missing input file → data issue, do NOT resume automatically
   - Container/singularity error → may need intervention
   - Pipeline bug / unexpected output format → do NOT resume automatically
4. If any code changes are needed to fix the issue (pipeline scripts, config files, Python scripts):
   - Make the change
   - Lint the modified file BEFORE applying it:
       uv run ruff check <file>        # preferred — full lint
       python3 -m py_compile <file>    # fallback — syntax only
   - Fix any lint errors before proceeding
   - Only apply the change if it passes cleanly
5. If the error is TRANSIENT (preemption, timeout, node failure):
   - Resume by running: bash {script_path}
   - This will re-run Nextflow with -resume from the same run directory
6. If the error requires intervention:
   - Clearly explain what is broken and what needs to be done
   - Do NOT run the resume script
7. If the root cause is ambiguous or you need a deeper investigation, use /codex:rescue to
   delegate the diagnosis — it can do a more thorough multi-step analysis.
8. Print a clear summary of: what failed, why, and what action you took

Samples in this run: {', '.join(og_ids)}
Samplesheet: {samplesheet}
Run directory: {run_dir}
"""

    prompt_file = f"{run_dir}/debug_prompt.txt"
    Path(run_dir).mkdir(parents=True, exist_ok=True)
    with open(prompt_file, "w") as f:
        f.write(prompt)

    # Create new tmux window 'debug' in the existing session
    subprocess.run(
        ["tmux", "new-window", "-t", tmux_session, "-n", "debug"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )

    # Launch Claude Code in that window
    # --allowedTools lets Claude use tools without prompting for each one
    claude_cmd = (
        f'cd {run_dir} && '
        f'{CLAUDE_BIN} --allowedTools "Read,Grep,Glob,Bash,Edit,Agent" '
        f'"$(cat {prompt_file})"'
    )
    result = subprocess.run(
        ["tmux", "send-keys", "-t", f"{tmux_session}:debug", claude_cmd, "Enter"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        print(f"WARNING: failed to launch debug agent in tmux: {result.stderr.decode().strip()}")
        return False

    print(f"Debug agent launched in tmux session '{tmux_session}' window 'debug'")
    print(f"Attach with: tmux attach -t {tmux_session}")
    return True


def main():
    global LOG_DIR

    args = sys.argv[1:]

    run_name    = args[args.index("--run")         + 1] if "--run"         in args else None
    run_dir     = args[args.index("--run-dir")     + 1] if "--run-dir"     in args else None
    script_path = args[args.index("--script")      + 1] if "--script"      in args else None
    og_ids_arg  = args[args.index("--og-ids")      + 1] if "--og-ids"      in args else ""
    samplesheet = args[args.index("--samplesheet") + 1] if "--samplesheet" in args else ""

    if not run_name or not run_dir or not script_path:
        print("Usage: debug-nextflow.py --run RUN --run-dir DIR --script SCRIPT "
              "[--og-ids IDs] [--samplesheet PATH] [--log-dir DIR] [--assembly-mode hifi_only|hifi_hic]")
        sys.exit(1)

    if "--log-dir" in args:
        LOG_DIR = args[args.index("--log-dir") + 1]
    assembly_mode = args[args.index("--assembly-mode") + 1] if "--assembly-mode" in args else "hifi_only"

    og_ids = [x.strip() for x in og_ids_arg.split(",") if x.strip()]
    os.makedirs(LOG_DIR, exist_ok=True)

    token = load_token()

    # 1. Post Asana failure task
    tmux_session = f"nf_{run_name}"
    if token:
        try:
            gid = post_failure_task(run_name, run_dir, tmux_session, token)
            print(f"Asana failure task created: {gid}")
        except Exception as e:
            print(f"WARNING: could not post Asana failure task: {e}")
    else:
        print("WARNING: no Asana token — skipping failure notification")

    # 2. Launch Claude Code debug agent
    launch_debug_agent(run_name, run_dir, script_path, og_ids, samplesheet, assembly_mode)


if __name__ == "__main__":
    main()
