FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /podflow-backend .

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=build /podflow-backend /usr/local/bin/podflow-backend
ENV DATABASE_PATH=/data/podflow.db
EXPOSE 8080
CMD ["podflow-backend"]
