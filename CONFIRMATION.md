# Why Destructive Tools Require Confirmation

## The Problem

When an AI agent (OpenCode, Claude, etc.) is given a task, it can call MCP tools autonomously — including destructive ones like `execute_command` and `write_file` — **without pausing to check with you first**.

This means a single ambiguous instruction like _"clean up the temp files"_ could result in an `rm` command running on the remote server with zero human review.

## The Two-Layer Solution

### Layer 1 — `ToolAnnotations` (client hint)

```python
annotations=ToolAnnotations(destructiveHint=True, readOnlyHint=False)
```

This is metadata sent to the MCP client (OpenCode) in the protocol. It signals that this tool can cause irreversible changes, prompting the client to show a permission dialog before calling it.

- `readOnlyHint=True` → safe, no side effects (auto-approved by client)
- `destructiveHint=True` → dangerous, may prompt the user in the client UI

**Limitation:** This is just a hint. Not all clients act on it.

### Layer 2 — `confirmed` parameter (server-enforced gate)

```python
async def execute_command(command: str, ..., confirmed: bool = False):
    if not confirmed:
        # Returns a preview — nothing runs
        return json.dumps({"status": "AWAITING_CONFIRMATION", "command": command, ...})
    # Only executes here
```

This is enforced **inside the server**, so no client behavior can bypass it.

- First call (`confirmed=False`): returns a preview of what *would* happen. **Nothing runs.**
- The AI must show the preview to the user in chat and explicitly ask for approval.
- Second call (`confirmed=True`): only after the user says yes.

## Which Tools Are Affected

| Tool | Needs Confirmation | Reason |
|---|---|---|
| `execute_command` | Yes | Runs arbitrary shell commands on the remote server |
| `write_file` | Yes | Overwrites files on the remote server |
| `list_directory` | No | Read-only |
| `read_file` | No | Read-only |
| `get_system_info` | No | Read-only |
| `install_package` | No | Only runs `apt list`, no changes |
| `search_packages` | No | Only reads package index |

## Summary

Neither layer alone is sufficient:

- `ToolAnnotations` alone: depends on the client — unreliable
- `confirmed` alone: no client-side warning, poor UX

Together they ensure **you always see what will run and explicitly approve it** before anything destructive happens on your server.
