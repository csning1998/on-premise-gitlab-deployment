package config

import (
	"fmt"
	"os"
	"strings"
)

// Config holds the environment the CI tools run with.
type Config struct {
	APIURL         string
	ProjectID      string
	MRIID          string
	GeminiToken    string
	ClaudeToken    string
	GeminiModel    string
	GeminiKey      string
	AnthropicModel string
	AnthropicKey   string
}

// Load reads environment variables. Common CI variables are required; provider
// keys are optional here and validated by each cmd binary.
func Load() Config {
	return Config{
		APIURL:         require("CI_API_V4_URL", ""),
		ProjectID:      require("CI_PROJECT_ID", ""),
		MRIID:          require("CI_MERGE_REQUEST_IID", ""),
		GeminiToken:    env("GEMINI_MR_REVIEWER", ""),
		ClaudeToken:    env("CLAUDE_MR_REVIEWER", ""),
		GeminiModel:    env("GEMINI_MODEL", defaultGeminiModel),
		GeminiKey:      env("GEMINI_API_KEY", ""),
		AnthropicModel: env("ANTHROPIC_MODEL", defaultAnthropicModel),
		AnthropicKey:   env("CLAUDE_API_KEY", ""),
	}
}

func require(name, def string) string {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		v = def
	}
	if v == "" {
		fmt.Printf("Error: Required environment variable '%s' is missing.\n", name)
		os.Exit(1)
	}
	return v
}

func env(name, def string) string {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		return def
	}
	return v
}
