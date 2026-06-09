package gitlab

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Change struct {
	NewPath string `json:"new_path"`
	OldPath string `json:"old_path"`
	Diff    string `json:"diff"`
}

type DiffRefs struct {
	BaseSha  string `json:"base_sha"`
	StartSha string `json:"start_sha"`
	HeadSha  string `json:"head_sha"`
}

type MRChanges struct {
	Changes  []Change `json:"changes"`
	DiffRefs DiffRefs `json:"diff_refs"`
}

// Client talks to one merge request's GitLab API endpoints.
type Client struct {
	mrURL string
	token string
	http  *http.Client
}

func New(apiURL, projectID, mrIID, token string) *Client {
	return &Client{
		mrURL: fmt.Sprintf("%s/projects/%s/merge_requests/%s", apiURL, projectID, mrIID),
		token: token,
		http:  &http.Client{Timeout: 30 * time.Second},
	}
}

// send is the single place HTTP errors are turned into Go errors.
func (c *Client) send(method, url string, payload any) (status int, header http.Header, data []byte, err error) {
	var reader io.Reader
	if payload != nil {
		body, err := json.Marshal(payload)
		if err != nil {
			return 0, nil, nil, fmt.Errorf("marshal request body: %w", err)
		}
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		return 0, nil, nil, err
	}
	req.Header.Set("PRIVATE-TOKEN", c.token)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return 0, nil, nil, err
	}
	defer func() {
		if cerr := resp.Body.Close(); cerr != nil && err == nil {
			err = cerr
		}
	}()
	data, _ = io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return resp.StatusCode, resp.Header, data, fmt.Errorf("gitlab %s %s -> %d: %s", method, url, resp.StatusCode, data)
	}
	return resp.StatusCode, resp.Header, data, nil
}

// FetchMR fetches diff refs and the paginated diff list for the MR.
// /changes was deprecated in GitLab 15.7; /diffs is the current endpoint.
func (c *Client) FetchMR() (*MRChanges, error) {
	_, _, detailData, err := c.send(http.MethodGet, c.mrURL, nil)
	if err != nil {
		return nil, fmt.Errorf("fetch MR detail: %w", err)
	}
	var detail struct {
		DiffRefs DiffRefs `json:"diff_refs"`
	}
	if err := json.Unmarshal(detailData, &detail); err != nil {
		return nil, fmt.Errorf("parse MR detail: %w", err)
	}

	_, diffsHeader, diffsData, err := c.send(http.MethodGet, c.mrURL+"/diffs?per_page=100", nil)
	if err != nil {
		return nil, fmt.Errorf("fetch MR diffs: %w", err)
	}
	if next := diffsHeader.Get("X-Next-Page"); next != "" {
		fmt.Printf("Warning: MR has more than 100 changed files; diffs from page %s onward are not reviewed.\n", next)
	}
	var changes []Change
	if err := json.Unmarshal(diffsData, &changes); err != nil {
		return nil, fmt.Errorf("parse MR diffs: %w", err)
	}

	return &MRChanges{Changes: changes, DiffRefs: detail.DiffRefs}, nil
}

func (c *Client) PostDiscussion(body string, position map[string]any) (int, error) {
	status, _, _, err := c.send(http.MethodPost, c.mrURL+"/discussions", map[string]any{"body": body, "position": position})
	return status, err
}

func (c *Client) PostNote(body string) (int, error) {
	status, _, _, err := c.send(http.MethodPost, c.mrURL+"/notes", map[string]any{"body": body})
	return status, err
}
