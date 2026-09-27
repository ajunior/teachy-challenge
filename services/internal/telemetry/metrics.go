package telemetry

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/trace"
)

var duration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
	Name:    "http_server_request_duration_seconds",
	Help:    "Duração das requisições HTTP.",
	Buckets: prometheus.DefBuckets,
}, []string{"route", "method", "code"})

func init() { prometheus.MustRegister(duration) }

func MetricsHandler() http.Handler {
	return promhttp.HandlerFor(prometheus.DefaultGatherer,
		promhttp.HandlerOpts{EnableOpenMetrics: true})
}

type recorder struct {
	http.ResponseWriter
	code int
}

func (r *recorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

func Handle(mux *http.ServeMux, route string, h http.HandlerFunc) {
	measured := func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &recorder{w, http.StatusOK}
		h(rec, r)

		obs := duration.WithLabelValues(route, r.Method, strconv.Itoa(rec.code))
		secs := time.Since(start).Seconds()
		if sc := trace.SpanContextFromContext(r.Context()); sc.IsSampled() {
			obs.(prometheus.ExemplarObserver).ObserveWithExemplar(secs,
				prometheus.Labels{"trace_id": sc.TraceID().String()})
		} else {
			obs.Observe(secs)
		}
	}
	mux.Handle(route, otelhttp.NewHandler(http.HandlerFunc(measured), route))
}
