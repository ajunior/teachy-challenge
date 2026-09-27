package main

import (
	"context"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/ajunior/teachy-challenge/services/internal/telemetry"
)

func main() {
	ctx := context.Background()
	shutdown, err := telemetry.Setup(ctx, "orders")
	if err != nil {
		slog.Error("telemetry", "err", err)
		os.Exit(1)
	}
	defer shutdown(ctx)

	errorRate, _ := strconv.ParseFloat(os.Getenv("ERROR_RATE"), 64)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.Handle("GET /metrics", telemetry.MetricsHandler())
	telemetry.Handle(mux, "GET /orders", func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(time.Duration(20+rand.IntN(200)) * time.Millisecond)
		if rand.Float64() < errorRate {
			slog.ErrorContext(r.Context(), "order failed", "reason", "simulated")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		slog.InfoContext(r.Context(), "order listed")
		w.Write([]byte(`{"orders":[{"id":1},{"id":2}]}`))
	})

	slog.Info("listening", "addr", ":8080")
	http.ListenAndServe(":8080", mux)
}
