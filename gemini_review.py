# This is temporarily a backup file now
# import json
# import os
# import re
# import urllib.error
# import urllib.request

# SKIP_EXTENSIONS = {
#     ".lock",
#     ".sum",
#     ".min.js",
#     ".min.css",
#     ".png",
#     ".jpg",
#     ".jpeg",
#     ".gif",
#     ".ico",
#     ".svg",
#     ".webp",
#     ".pdf",
#     ".zip",
#     ".tar",
#     ".gz",
#     ".woff",
#     ".woff2",
#     ".ttf",
#     ".eot",
# }
# SKIP_FILENAMES = {
#     "package-lock.json",
#     "yarn.lock",
#     "go.sum",
#     "poetry.lock",
#     "Pipfile.lock",
#     "composer.lock",
#     "pnpm-lock.yaml",
# }
# MAX_TOTAL_DIFF = 300000


# def get_env(name, default=None):
#     value = os.environ.get(name, default)
#     if not value:
#         print(f"Error: Required environment variable '{name}' is missing.")
#         exit(1)
#     return value.strip()


# def should_skip(file_path):
#     basename = os.path.basename(file_path)
#     ext = os.path.splitext(file_path)[1].lower()
#     return basename in SKIP_FILENAMES or ext in SKIP_EXTENSIONS


# def parse_diff(diff):
#     """Parse unified diff into list of (new_line, old_line, prefix, content)."""
#     result = []
#     new_line = None
#     old_line = None

#     for line in diff.splitlines():
#         hunk = re.match(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
#         if hunk:
#             old_line = int(hunk.group(1))
#             new_line = int(hunk.group(2))
#             result.append((None, None, "@@", line))
#             continue
#         if new_line is None:
#             continue
#         if line.startswith("+"):
#             result.append((new_line, None, "+", line[1:]))
#             new_line += 1
#         elif line.startswith("-"):
#             result.append((None, old_line, "-", line[1:]))
#             old_line += 1
#         elif line.startswith("\\"):
#             pass
#         else:
#             content = line[1:] if line else ""
#             result.append((new_line, old_line, " ", content))
#             new_line += 1
#             old_line += 1

#     return result


# def annotate_diff(parsed_lines):
#     """Build annotated diff string with line numbers for Gemini."""
#     out = []
#     for new_line, _, prefix, content in parsed_lines:
#         if prefix == "@@":
#             out.append(content)
#         elif prefix == "+":
#             out.append(f"[L{new_line:4d}] + {content}")
#         elif prefix == "-":
#             out.append(f"[     ] - {content}")
#         else:
#             out.append(f"[L{new_line:4d}]   {content}")
#     return "\n".join(out)


# def call_gemini(api_key, model, prompt):
#     url = (
#         "https://generativelanguage.googleapis.com/v1beta/models"
#         f"/{model}:generateContent?key={api_key}"
#     )
#     payload = {
#         "contents": [{"role": "user", "parts": [{"text": prompt}]}],
#         "generationConfig": {
#             "responseMimeType": "application/json",
#         },
#     }
#     req = urllib.request.Request(
#         url,
#         data=json.dumps(payload).encode("utf-8"),
#         headers={"Content-Type": "application/json"},
#         method="POST",
#     )
#     try:
#         with urllib.request.urlopen(req) as resp:
#             data = json.loads(resp.read().decode("utf-8"))
#             candidates = data.get("candidates")
#             if not candidates:
#                 return ""
#             parts = candidates[0].get("content", {}).get("parts", [])
#             return "".join(p.get("text", "") for p in parts if "text" in p)
#     except urllib.error.HTTPError as e:
#         body = e.read().decode("utf-8")
#         print(f"Gemini API error {e.code}: {body}")
#         raise


# def post_inline_discussion(
#     api_url,
#     project_id,
#     mr_iid,
#     token,
#     diff_refs,
#     new_path,
#     old_path,
#     line_map,
#     anchor_line,
#     body,
# ):
#     url = f"{api_url}/projects/{project_id}/merge_requests/{mr_iid}/discussions"

#     new_l, old_l = line_map[anchor_line]
#     position = {
#         "base_sha": diff_refs["base_sha"],
#         "start_sha": diff_refs["start_sha"],
#         "head_sha": diff_refs["head_sha"],
#         "position_type": "text",
#         "new_path": new_path,
#         "old_path": old_path,
#     }
#     if new_l is not None:
#         position["new_line"] = new_l
#     if old_l is not None:
#         position["old_line"] = old_l

#     req = urllib.request.Request(
#         url,
#         data=json.dumps({"body": body, "position": position}).encode("utf-8"),
#         headers={"Content-Type": "application/json", "PRIVATE-TOKEN": token},
#         method="POST",
#     )
#     try:
#         with urllib.request.urlopen(req) as resp:
#             return resp.status
#     except urllib.error.HTTPError as e:
#         err = e.read().decode("utf-8")
#         print(f"GitLab discussions API error {e.code}: {err}")
#         raise


# def post_mr_note(api_url, project_id, mr_iid, token, body):
#     url = f"{api_url}/projects/{project_id}/merge_requests/{mr_iid}/notes"
#     req = urllib.request.Request(
#         url,
#         data=json.dumps({"body": body}).encode("utf-8"),
#         headers={"Content-Type": "application/json", "PRIVATE-TOKEN": token},
#         method="POST",
#     )
#     try:
#         with urllib.request.urlopen(req) as resp:
#             return resp.status
#     except urllib.error.HTTPError as e:
#         err = e.read().decode("utf-8")
#         print(f"GitLab notes API error {e.code}: {err}")
#         raise


# PROMPT_TEMPLATE = """\
# You are an expert software engineer reviewing a pull request.

# Below is the annotated diff for all changed files. Each file section starts with:
#     === File: <path> ===
# Each line is prefixed with its line number in the new file as [L   N].
# Removed lines are prefixed with [     ].

# Focus on: bugs, security vulnerabilities, performance issues, architectural problems, code quality.
# For infrastructure files (HCL, YAML, Dockerfile): also check resource limits, security contexts, \
# hardcoded secrets, and misconfigurations.

# Return ONLY a raw JSON array with no markdown fences or wrapper. Each element:
# {{
#     "file": "<exact file path from the === File: ... === header>",
#     "start_line": <integer, first [L N] line number of the problematic range>,
#     "end_line": <integer, last [L N] line number; same as start_line for single-line issues>,
#     "description": "<concise markdown explaining the issue and why it matters>",
#     "suggestion": "<optional: exact replacement lines for start_line..end_line, preserving indentation; omit if no direct fix applies>"
# }}

# If there are no significant issues across all files, return an empty array: []

# {combined_diff}
# """


# gemini_key = get_env("GEMINI_API_KEY")
# gemini_model = get_env("GEMINI_MODEL", default="gemini-3.5-flash")
# gitlab_token = get_env("GITLAB_TOKEN")
# api_url = get_env("CI_API_V4_URL")
# project_id = get_env("CI_PROJECT_ID")
# mr_iid = get_env("CI_MERGE_REQUEST_IID")

# mr_changes_url = f"{api_url}/projects/{project_id}/merge_requests/{mr_iid}/changes"
# try:
#     with urllib.request.urlopen(
#         urllib.request.Request(mr_changes_url, headers={"PRIVATE-TOKEN": gitlab_token})
#     ) as resp:
#         mr_data = json.loads(resp.read().decode("utf-8"))
#         changes = mr_data.get("changes", [])
#         diff_refs = mr_data.get("diff_refs", {})
# except Exception as e:
#     print(f"Failed to fetch MR changes: {e}")
#     exit(1)

# if not changes:
#     print("No code changes detected in this MR.")
#     exit(0)

# if not diff_refs.get("base_sha"):
#     print("Error: diff_refs missing from MR data.")
#     exit(1)

# # Build combined annotated diff (single Gemini call)
# file_meta = {}  # new_path -> (old_path, line_map)
# diff_sections = []
# total_chars = 0
# skipped = 0

# for change in changes:
#     new_path = change.get("new_path") or change.get("old_path", "unknown")
#     old_path = change.get("old_path") or new_path
#     diff = change.get("diff", "")

#     if should_skip(new_path):
#         print(f"Skip {new_path} (lock/binary/generated)")
#         skipped += 1
#         continue

#     if not diff.strip():
#         print(f"Skip {new_path} (empty diff)")
#         skipped += 1
#         continue

#     if total_chars + len(diff) > MAX_TOTAL_DIFF:
#         print(f"Skip {new_path} (total diff limit reached)")
#         skipped += 1
#         continue

#     parsed = parse_diff(diff)
#     line_map = {nl: (nl, ol) for nl, ol, _, _ in parsed if nl is not None}
#     file_meta[new_path] = (old_path, line_map)

#     annotated = annotate_diff(parsed)
#     diff_sections.append(f"=== File: {new_path} ===\n{annotated}")
#     total_chars += len(diff)
#     print(f"Queued {new_path} ({len(diff)} chars)")

# if not diff_sections:
#     print("No reviewable changes after filtering.")
#     exit(0)

# combined_diff = "\n\n".join(diff_sections)
# print(f"\nSending {len(file_meta)} files ({total_chars} chars) to Gemini ...")

# try:
#     raw = call_gemini(gemini_key, gemini_model, PROMPT_TEMPLATE.format(combined_diff=combined_diff))
# except Exception as e:
#     print(f"Gemini call failed: {e}")
#     exit(1)

# try:
#     comments = json.loads(raw)
#     if not isinstance(comments, list):
#         raise ValueError("not a list")
# except Exception as e:
#     print(f"Failed to parse Gemini JSON ({e}), raw: {raw[:200]}")
#     exit(1)

# if not comments:
#     print("LGTM -- no issues found.")
#     exit(0)

# print(f"Gemini returned {len(comments)} comment(s). Posting ...")

# posted = 0
# for item in comments:
#     file_path = item.get("file", "").strip()
#     try:
#         start_line = int(item.get("start_line"))
#         end_line = int(item.get("end_line") or start_line)
#     except (TypeError, ValueError):
#         print(
#             f"  -> Skipping comment with invalid line numbers: {item.get('start_line')}, {item.get('end_line')}"
#         )
#         continue
#     description = item.get("description", "").strip()
#     suggestion = item.get("suggestion", "").strip()

#     if not file_path or not description:
#         continue

#     offset = max(0, end_line - start_line)
#     if suggestion:
#         sug_header = f"suggestion:-{offset}" if offset > 0 else "suggestion"
#         body = f"{description}\n\n```{sug_header}\n{suggestion}\n```"
#     else:
#         body = description

#     range_label = (
#         f"L{start_line}-{end_line}" if start_line != end_line else f"L{start_line}"
#     )

#     if file_path in file_meta:
#         old_path, line_map = file_meta[file_path]

#         if end_line not in line_map and start_line in line_map:
#             end_line = start_line
#         anchor = (
#             end_line
#             if end_line in line_map
#             else (start_line if start_line in line_map else None)
#         )

#         if anchor:
#             try:
#                 status = post_inline_discussion(
#                     api_url,
#                     project_id,
#                     mr_iid,
#                     gitlab_token,
#                     diff_refs,
#                     file_path,
#                     old_path,
#                     line_map,
#                     anchor,
#                     body,
#                 )
#                 print(f"  -> Inline {file_path} {range_label} (HTTP {status})")
#                 posted += 1
#                 continue
#             except Exception as e:
#                 print(f"  -> Inline failed ({e}), falling back to note")

#     label = f"`{file_path}` ({range_label})" if file_path else range_label
#     fallback_body = f"### Gemini Review -- {label}\n\n{body}"
#     try:
#         status = post_mr_note(api_url, project_id, mr_iid, gitlab_token, fallback_body)
#         print(f"  -> Note for {label} (HTTP {status})")
#         posted += 1
#     except Exception:
#         print(f"  -> Failed to post note for {label}")

# print(f"\nDone: {posted} comment(s) posted, {skipped} file(s) skipped.")
