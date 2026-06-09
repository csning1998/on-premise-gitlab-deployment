package main

import (
	"fmt"
	"os"

	"ci-tools/internal/anthropic"
	"ci-tools/internal/config"
	"ci-tools/internal/gitlab"
	"ci-tools/internal/review"
)

func main() {
	cfg := config.Load()
	if cfg.ClaudeToken == "" {
		fmt.Fprintln(os.Stderr, "Error: Required environment variable 'CLAUDE_MR_REVIEWER' is missing.")
		os.Exit(1)
	}
	if cfg.AnthropicKey == "" {
		fmt.Fprintln(os.Stderr, "Error: Required environment variable 'CLAUDE_API_KEY' is missing.")
		os.Exit(1)
	}

	gl := gitlab.New(cfg.APIURL, cfg.ProjectID, cfg.MRIID, cfg.ClaudeToken)
	ac := anthropic.New(cfg.AnthropicModel, cfg.AnthropicKey)

	if err := review.New(gl, ac).Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
