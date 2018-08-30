FROM golang

RUN go get -u github.com/Masterminds/glide

WORKDIR $GOPATH/src/github.com/ops2go/goserver

COPY . .

RUN glide install

