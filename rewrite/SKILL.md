---
name: rewrite
description: Re-send the complete, up-to-date version of the script/code being worked on in this conversation, ready to copy-paste. Use when the user types /rewrite.
---

# /rewrite — send the full code

The user wants the **complete, current version** of the code being worked on, so they can copy-paste it in one go.

Extra instructions from the user (may be empty): $ARGUMENTS

## What to do

1. Identify the target: the most recent script/file/code being worked on in this conversation, unless the arguments name a different one.
2. Apply every change agreed so far in the conversation, plus any change requested in the arguments.
3. Output the **entire** file in a single fenced code block with the right language tag:
   - no `...`, "rest unchanged", placeholders or omitted sections;
   - no diffs or partial snippets;
   - keep existing structure, comments and naming unless a change requires otherwise;
   - if it has a version field (e.g. a userscript `@version`), bump it.
4. After the code block, add at most 2–3 short lines: what changed since the last full version, and where to paste it if not obvious.
5. Don't write to disk unless the user asks; just send the code in the reply.
6. If it's genuinely unclear which code is meant (several candidates), ask one short question instead of guessing.
