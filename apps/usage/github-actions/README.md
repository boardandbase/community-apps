# Run the data pump on GitHub Actions (no laptop, no jsonbin)

This runs `push_usage.py` on a free GitHub Actions cron instead of on your PC, and
stores the result as `usage.json` **in the repo itself**. The Tidbyt app reads that
file over a raw GitHub URL — so you need neither a running laptop nor jsonbin.

> **Heads-up (the one real risk):** GitHub runners use datacenter IPs, which
> Cloudflare challenges more often than a home IP. The fetch that works on your PC
> *may* be blocked on Actions. Test with **Run workflow** first (step 6). If it's
> blocked, run the pump on a home device instead (a Pi, NAS, or Home Assistant) —
> that's the most reliable route.

## What goes where

Create a **new, public** GitHub repo (e.g. `claude-usage-data`) with:

```
push_usage.py                      # copy of apps/usage/push_usage.py
.github/workflows/push-usage.yml   # copy of the file next to this README
```

Public repo → **unlimited free Actions minutes** and a readable raw URL. Your session
and keys live in encrypted **Secrets**, never in the code.

The workflow writes `usage.json` to a separate **`data`** branch, overwriting it each
run as a single force-pushed commit (so the repo doesn't fill up with commits). The
app reads:

```
https://raw.githubusercontent.com/<user>/claude-usage-data/data/usage.json
```

## One-time setup

1. **Export your session** on your PC (needs the existing `~/.claude_session` from a
   prior `python push_usage.py --login`):

   ```
   python push_usage.py --dump-state
   ```

   This writes `storage_state.json`. Keep it private — it grants access to your
   claude.ai session.

2. **Create the public repo** and add the two files above.

3. **Create a fine-grained PAT** (GitHub → Settings → Developer settings → Fine-grained
   tokens): access limited to **only this repo**, permission **Contents: Read and write**.

4. **Add three repo secrets** (repo → Settings → Secrets and variables → Actions):

   | Secret | Value |
   | --- | --- |
   | `CLAUDE_SESSION_STATE` | the full contents of `storage_state.json` |
   | `CLAUDE_USAGE_URL` | `https://claude.ai/api/organizations/<UUID>/usage` |
   | `DATA_PUSH_PAT` | the fine-grained PAT from step 3 |

5. **Point the app** — set the app's `api_url` to the raw URL above. Leave `read_key`
   empty (the repo is public).

6. **Test it** — repo → Actions → *push-usage* → **Run workflow**. Check the run log:
   - success = the fetch returned the usage JSON and `usage.json` appears on the `data`
     branch;
   - if you see a Cloudflare "checking your browser" page or a non-200 status, the
     datacenter IP was blocked → use a home runner instead (see the heads-up above).

   After that the cron takes over (every ~10 min) and the app's trend line fills in.

## Refreshing the session

The stored session eventually expires (weeks). When a run starts failing with
"session expired?", redo step 1 on your PC and update the `CLAUDE_SESSION_STATE`
secret with the new `storage_state.json`.
