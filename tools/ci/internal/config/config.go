package config

import (
	"fmt"
	"os"
	"strings"
)

// Config holds the environment the CI tools run with.
type Config struct {
	APIURL      string
	ProjectID   string
	MRIID       string
	Token       string
	GeminiModel string
	GeminiKey   string
}

// Load reads the required environment variables, exiting if any are missing.
func Load() Config {
	return Config{
		APIURL:      require("CI_API_V4_URL", ""),
		ProjectID:   require("CI_PROJECT_ID", ""),
		MRIID:       require("CI_MERGE_REQUEST_IID", ""),
		Token:       require("GITLAB_TOKEN", ""),
		GeminiModel: require("GEMINI_MODEL", "gemini-3.5-flash"),
		GeminiKey:   require("GEMINI_API_KEY", ""),
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
