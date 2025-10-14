# FROM golang:1.24-alpine as build
# WORKDIR /go/src

# COPY go.mod go.sum ./

# RUN go mod download

# COPY apps/pkg ./apps/pkg
# COPY apps/workload ./apps/workload

# WORKDIR /go/src/apps/workload
# RUN CGO_ENABLED=0 GOOS=linux go build -o app main.go

# FROM alpine:latest
# COPY --from=build /go/src/apps/workload/app /
# ENTRYPOINT ["/app"]

FROM golang:1.24-alpine as build
WORKDIR /go/src

# Set custom cache locations for consistent paths
ENV GOCACHE=/go-cache
ENV GOMODCACHE=/gomod-cache

# Copy dependency files first for better layer caching
COPY go.mod go.sum ./

# Download dependencies with cache mount
RUN --mount=type=cache,target=/gomod-cache \
    go mod download

# Copy source code
COPY apps/pkg ./apps/pkg
COPY apps/workload ./apps/workload

WORKDIR /go/src/apps/workload

# Build with both GOMODCACHE and GOCACHE mounts
RUN --mount=type=cache,target=/gomod-cache \
    --mount=type=cache,target=/go-cache \
    CGO_ENABLED=0 GOOS=linux go build -o app main.go

FROM alpine:latest
COPY --from=build /go/src/apps/workload/app /
ENTRYPOINT ["/app"]