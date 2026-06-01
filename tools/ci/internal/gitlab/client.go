package gitlab

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
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
		http:  &http.Client{},
	}
}

// send is the single place HTTP errors are turned into Go errors.
func (c *Client) send(method, url string, payload any) (status int, data []byte, err error) {
	var reader io.Reader
	if payload != nil {
		body, _ := json.Marshal(payload)
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("PRIVATE-TOKEN", c.token)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer func() {
		if cerr := resp.Body.Close(); cerr != nil && err == nil {
			err = cerr
		}
	}()
	data, _ = io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return resp.StatusCode, data, fmt.Errorf("gitlab %s %s -> %d: %s", method, url, resp.StatusCode, data)
	}
	return resp.StatusCode, data, nil
}

func (c *Client) FetchMR() (*MRChanges, error) {
	_, data, err := c.send(http.MethodGet, c.mrURL+"/changes", nil)
	if err != nil {
		return nil, err
	}
	var mr MRChanges
	if err := json.Unmarshal(data, &mr); err != nil {
		return nil, err
	}
	return &mr, nil
}

func (c *Client) PostDiscussion(body string, position map[string]any) (int, error) {
	status, _, err := c.send(http.MethodPost, c.mrURL+"/discussions", map[string]any{"body": body, "position": position})
	return status, err
}

func (c *Client) PostNote(body string) (int, error) {
	status, _, err := c.send(http.MethodPost, c.mrURL+"/notes", map[string]any{"body": body})
	return status, err
}
