package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCreateAndListTasks(t *testing.T) {
	// Reset state
	tasks = make(map[string]Task)
	seq = 0

	mux := http.NewServeMux()
	mux.HandleFunc("GET /tasks", listTasks)
	mux.HandleFunc("POST /tasks", createTask)

	// Create a task
	body, _ := json.Marshal(Task{Title: "Test task", Done: false})
	req := httptest.NewRequest("POST", "/tasks", bytes.NewReader(body))
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d", w.Code)
	}

	// List tasks
	req = httptest.NewRequest("GET", "/tasks", nil)
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	var result []Task
	json.NewDecoder(w.Body).Decode(&result)

	if len(result) != 1 {
		t.Fatalf("expected 1 task, got %d", len(result))
	}
	if result[0].Title != "Test task" {
		t.Fatalf("expected 'Test task', got '%s'", result[0].Title)
	}
}
