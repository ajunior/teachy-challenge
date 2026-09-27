FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG SVC
RUN CGO_ENABLED=0 go build -o /app ./cmd/${SVC}

FROM gcr.io/distroless/static:nonroot
COPY --from=build /app /app
USER 65532:65532
ENTRYPOINT ["/app"]
