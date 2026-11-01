package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	dbPath := os.Getenv("DATABASE_PATH")
	if dbPath == "" {
		dbPath = "podflow.db"
	}
	workspaceKey := os.Getenv("WORKSPACE_KEY")
	if workspaceKey == "" {
		log.Fatal("WORKSPACE_KEY must be set")
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	store, err := NewStore(dbPath)
	if err != nil {
		log.Fatalf("open store: %v", err)
	}
	defer store.Close()

	server := NewServer(store, workspaceKey)
	log.Printf("podflow backend listening on :%s (db %s)", port, dbPath)
	if err := http.ListenAndServe(":"+port, server); err != nil {
		log.Fatal(err)
	}
}
