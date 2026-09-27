package main

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"os"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

	"github.com/ajunior/teachy-challenge/services/internal/telemetry"
)

func main() {
	ctx := context.Background()
	shutdown, err := telemetry.Setup(ctx, "api")
	if err != nil {
		slog.Error("telemetry", "err", err)
		os.Exit(1)
	}
	defer shutdown(ctx)

	ordersURL := os.Getenv("ORDERS_URL") // http://orders:8080
	client := &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.Handle("GET /metrics", telemetry.MetricsHandler())
	telemetry.Handle(mux, "GET /orders", func(w http.ResponseWriter, r *http.Request) {
		req, _ := http.NewRequestWithContext(r.Context(), http.MethodGet, ordersURL+"/orders", nil)
		resp, err := client.Do(req)
		if err != nil {
			slog.ErrorContext(r.Context(), "orders unreachable", "err", err)
			http.Error(w, "bad gateway", http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		slog.InfoContext(r.Context(), "orders called", "status", resp.StatusCode)
		w.WriteHeader(resp.StatusCode)
		io.Copy(w, resp.Body)
	})

	slog.Info("listening", "addr", ":8080")
	http.ListenAndServe(":8080", mux)
}
