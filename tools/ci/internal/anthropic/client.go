package anthropic

import (
	"context"
	"fmt"
	"strings"
	"time"

	sdk "github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// Client calls the Anthropic Messages API for a fixed model.
type Client struct {
	client sdk.Client
	model  sdk.Model
}

func New(model, apiKey string) *Client {
	return &Client{
		client: sdk.NewClient(option.WithAPIKey(apiKey)),
		model:  sdk.Model(model),
	}
}

func (c *Client) Name() string { return "Anthropic" }

// Review sends the prompt and returns the concatenated text of all content blocks.
func (c *Client) Review(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	resp, err := c.client.Messages.New(ctx, sdk.MessageNewParams{
		Model:     c.model,
		MaxTokens: 8192,
		Messages: []sdk.MessageParam{
			sdk.NewUserMessage(sdk.NewTextBlock(prompt)),
		},
	})
	if err != nil {
		return "", fmt.Errorf("anthropic api: %w", err)
	}
	var sb strings.Builder
	for _, block := range resp.Content {
		if t, ok := block.AsAny().(sdk.TextBlock); ok {
			sb.WriteString(t.Text)
		}
	}
	return sb.String(), nil
}
