package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
)

type Task struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Done  bool   `json:"done"`
}

var (
	tasks = make(map[string]Task)
	mu    sync.RWMutex
	seq   int
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /tasks", listTasks)
	mux.HandleFunc("POST /tasks", createTask)

	log.Println("Server starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}

func listTasks(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()

	result := make([]Task, 0, len(tasks))
	for _, t := range tasks {
		result = append(result, t)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func createTask(w http.ResponseWriter, r *http.Request) {
	var t Task
	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	mu.Lock()
	seq++
	t.ID = fmt.Sprintf("task-%d", seq)
	tasks[t.ID] = t
	mu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(t)
}
