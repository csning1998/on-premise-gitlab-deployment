package main

import (
	"fmt"
	"os"

	"ci-tools/internal/config"
	"ci-tools/internal/gemini"
	"ci-tools/internal/gitlab"
	"ci-tools/internal/review"
)

func main() {
	cfg := config.Load()

	gl := gitlab.New(cfg.APIURL, cfg.ProjectID, cfg.MRIID, cfg.Token)
	gm := gemini.New(cfg.GeminiModel, cfg.GeminiKey)

	if err := review.New(gl, gm).Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
