FROM golang:1.12 as build-stage
WORKDIR /go/src/devflowapp
COPY devflowapp.go .
COPY services/ ./services/

# RUN go get -d -v ./...
RUN go get github.com/go-sql-driver/mysql
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -a -installsuffix cgo devflowapp.go
RUN ls /go/src/devflowapp/devflowapp

FROM scratch as production-stage
WORKDIR /
COPY --from=build-stage /go/src/devflowapp/devflowapp /bin/devflowapp
CMD ["/bin/devflowapp"]
