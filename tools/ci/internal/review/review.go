package review

import (
	"encoding/json"
	"fmt"
	"strings"

	"ci-tools/internal/gemini"
	"ci-tools/internal/gitlab"
)

const maxTotalDiff = 300000

const promptTemplate = `You are an expert software engineer reviewing a pull request.

Below is the annotated diff for all changed files. Each file section starts with:
    === File: <path> ===
Each line is prefixed with its line number in the new file as [L   N].
Removed lines are prefixed with [     ].

Focus on: bugs, security vulnerabilities, performance issues, architectural problems, code quality.
For infrastructure files (HCL, YAML, Dockerfile): also check resource limits, security contexts, hardcoded secrets, and misconfigurations.

Return ONLY a raw JSON array with no markdown fences or wrapper. Each element:
{
    "file": "<exact file path from the === File: ... === header>",
    "start_line": <integer, first [L N] line number of the problematic range>,
    "end_line": <integer, last [L N] line number; same as start_line for single-line issues>,
    "description": "<concise markdown explaining the issue and why it matters>",
    "suggestion": "<optional: exact replacement lines for start_line..end_line, preserving indentation; omit if no direct fix applies>"
}

If there are no significant issues across all files, return an empty array: []`

// Comment is one Gemini finding. Missing or null JSON fields decode to the zero
// value (empty string, nil pointer), so a null suggestion can never crash here.
type Comment struct {
	File        string `json:"file"`
	StartLine   *int   `json:"start_line"`
	EndLine     *int   `json:"end_line"`
	Description string `json:"description"`
	Suggestion  string `json:"suggestion"`
}

// Reviewer orchestrates a single MR review using the injected API clients.
type Reviewer struct {
	gitlab *gitlab.Client
	gemini *gemini.Client
}

func New(gl *gitlab.Client, gm *gemini.Client) *Reviewer {
	return &Reviewer{gitlab: gl, gemini: gm}
}

func (r *Reviewer) Run() error {
	mr, err := r.gitlab.FetchMR()
	if err != nil {
		return fmt.Errorf("fetch MR changes: %w", err)
	}
	if len(mr.Changes) == 0 {
		fmt.Println("No code changes detected in this MR.")
		return nil
	}
	if mr.DiffRefs.BaseSha == "" {
		return fmt.Errorf("diff_refs missing from MR data")
	}

	combined, fileMeta, skipped := buildCombinedDiff(mr.Changes)
	if len(fileMeta) == 0 {
		fmt.Println("No reviewable changes after filtering.")
		return nil
	}

	raw, err := r.gemini.Review(promptTemplate + "\n\n" + combined)
	if err != nil {
		return fmt.Errorf("gemini call failed: %w", err)
	}

	var rawComments []json.RawMessage
	if err := json.Unmarshal([]byte(raw), &rawComments); err != nil {
		return fmt.Errorf("parse Gemini JSON: %w (raw: %.200s)", err, raw)
	}
	if len(rawComments) == 0 {
		fmt.Println("LGTM -- no issues found.")
		return nil
	}

	fmt.Printf("Gemini returned %d comment(s). Posting ...\n", len(rawComments))
	posted := 0
	for _, rc := range rawComments {
		var c Comment
		if err := json.Unmarshal(rc, &c); err != nil {
			fmt.Printf("  -> skip: cannot parse comment (%v)\n", err)
			continue
		}
		if r.deliver(mr.DiffRefs, fileMeta, c) {
			posted++
		}
	}
	fmt.Printf("\nDone: %d comment(s) posted, %d file(s) skipped.\n", posted, skipped)
	return nil
}

// deliver posts one comment, preferring an inline discussion and falling back to
// a plain note. It is self-contained, so one bad comment never aborts the run.
func (r *Reviewer) deliver(refs gitlab.DiffRefs, fileMeta map[string]fileInfo, c Comment) bool {
	file := strings.TrimSpace(c.File)
	description := strings.TrimSpace(c.Description)
	suggestion := strings.TrimSpace(c.Suggestion)

	if c.StartLine == nil {
		fmt.Println("  -> skip: missing start_line")
		return false
	}
	start := *c.StartLine
	end := start
	if c.EndLine != nil {
		end = *c.EndLine
	}
	if file == "" || description == "" {
		fmt.Println("  -> skip: missing file or description")
		return false
	}

	body := buildBody(description, suggestion, start, end)
	label := fmt.Sprintf("L%d", start)
	if start != end {
		label = fmt.Sprintf("L%d-%d", start, end)
	}

	if info, ok := fileMeta[file]; ok {
		if pos := position(refs, file, info, start, end); pos != nil {
			status, err := r.gitlab.PostDiscussion(body, pos)
			if err == nil {
				fmt.Printf("  -> Inline %s %s (HTTP %d)\n", file, label, status)
				return true
			}
			fmt.Printf("  -> inline failed, falling back to note: %v\n", err)
		}
	}

	fallback := fmt.Sprintf("### Gemini Review -- `%s` (%s)\n\n%s", file, label, body)
	status, err := r.gitlab.PostNote(fallback)
	if err != nil {
		fmt.Printf("  -> note failed: %v\n", err)
		return false
	}
	fmt.Printf("  -> Note %s %s (HTTP %d)\n", file, label, status)
	return true
}

func buildBody(description, suggestion string, start, end int) string {
	if suggestion == "" {
		return description
	}
	header := "suggestion"
	return fmt.Sprintf("%s\n\n```%s\n%s\n```", description, header, suggestion)
}

func position(refs gitlab.DiffRefs, file string, info fileInfo, start, end int) map[string]any {
	if _, ok := info.lines[end]; !ok {
		if _, ok2 := info.lines[start]; ok2 {
			end = start
		}
	}
	anchor := end
	if _, ok := info.lines[anchor]; !ok {
		anchor = start
		if _, ok2 := info.lines[anchor]; !ok2 {
			return nil
		}
	}

	lp := info.lines[anchor]
	pos := map[string]any{
		"base_sha":      refs.BaseSha,
		"start_sha":     refs.StartSha,
		"head_sha":      refs.HeadSha,
		"position_type": "text",
		"new_path":      file,
		"old_path":      info.oldPath,
	}
	if lp.newLine != nil {
		pos["new_line"] = *lp.newLine
	}
	if lp.oldLine != nil {
		pos["old_line"] = *lp.oldLine
	}
	return pos
}

// buildCombinedDiff assembles the annotated diff sent to Gemini and the per-file
// line maps used to anchor inline comments.
func buildCombinedDiff(changes []gitlab.Change) (string, map[string]fileInfo, int) {
	fileMeta := map[string]fileInfo{}
	var sections []string
	total, skipped := 0, 0

	for _, ch := range changes {
		newPath := ch.NewPath
		if newPath == "" {
			newPath = ch.OldPath
		}
		if newPath == "" {
			newPath = "unknown"
		}
		oldPath := ch.OldPath
		if oldPath == "" {
			oldPath = newPath
		}

		switch {
		case shouldSkip(newPath):
			fmt.Printf("Skip %s (lock/binary/generated)\n", newPath)
			skipped++
			continue
		case strings.TrimSpace(ch.Diff) == "":
			fmt.Printf("Skip %s (empty diff)\n", newPath)
			skipped++
			continue
		case total+len(ch.Diff) > maxTotalDiff:
			fmt.Printf("Skip %s (total diff limit reached)\n", newPath)
			skipped++
			continue
		}

		parsed := parseDiff(ch.Diff)
		lines := map[int]linePos{}
		for _, l := range parsed {
			if l.newLine != nil {
				lines[*l.newLine] = linePos{newLine: l.newLine, oldLine: l.oldLine}
			}
		}
		fileMeta[newPath] = fileInfo{oldPath: oldPath, lines: lines}
		sections = append(sections, fmt.Sprintf("=== File: %s ===\n%s", newPath, annotateDiff(parsed)))
		total += len(ch.Diff)
		fmt.Printf("Queued %s (%d chars)\n", newPath, len(ch.Diff))
	}

	fmt.Printf("\nSending %d files (%d chars) to Gemini ...\n", len(fileMeta), total)
	return strings.Join(sections, "\n\n"), fileMeta, skipped
}
