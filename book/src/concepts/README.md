# Concepts

This section introduces Switchyard's core concepts and mental model.

- Plans, Actions, and IDs: how work is represented and tracked.
- Preflight: safety checks and diffs before making changes.
- Apply: atomic mutations with durability guarantees.
- Rollback: automatic and explicit recovery paths.
- Locking: concurrency control and coordination.
- Rescue: fallback toolset and recovery-first posture.
- Cross-filesystem (EXDEV): degraded but safe behavior when rename is not atomic across filesystems.
- Audit Facts and Redaction: structured JSONL telemetry with sensitive data redaction.

Use the sidebar to dive into each topic.
