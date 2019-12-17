package main

// See https://github.com/deepch/rtsp/blob/master/client.go

import (
  "bufio"
  "bytes"
  "crypto/md5"
  "encoding/hex"
  "fmt"
  "io"
  "net"
  "net/textproto"
  "net/url"
  "os"
  "strconv"
  "strings"
)

func md5hash(s string) string {
  h := md5.Sum([]byte(s))
  return hex.EncodeToString(h[:])
}

type Stream struct {
  fuBuffer []byte
  sps []byte
  pps []byte

  gotpkt bool
  timestamp uint32
}

type Client struct {
  DebugConn bool
  url *url.URL
  conn net.Conn
  rconn io.Reader
  requestUri string
  cseq uint
  streams []*Stream
  session string
  authorization string
  body io.Reader
}

type Request struct {
  Header []string
  Uri string
  Method string
}

type Response struct {
  BlockLength int
  Block []byte
  BlockNo int

  StatusCode int
  Header textproto.MIMEHeader
  ContentLength int
  Body []byte
}


func (self *Client) writeLine(line string) (err error) {
  if self.DebugConn {
    fmt.Print("> ", line)
  }
  _, err = fmt.Fprint(self.conn, line)
  return
}

func (self *Client) WriteRequest(req Request) (err error) {
  self.cseq++
  req.Header = append(req.Header, fmt.Sprintf("CSeq: %d", self.cseq))
  if err = self.writeLine(fmt.Sprintf("%s %s RTSP/1.0\r\n", req.Method, req.Uri)); err != nil {
    return
  }
  for _, v := range req.Header {
    if err = self.writeLine(fmt.Sprint(v, "\r\n")); err != nil {
      return
    }
  }
  if err = self.writeLine("\r\n"); err != nil {
    return
  }
  return
}

func (self *Client) ReadResponse() (res Response, err error) {
  var br *bufio.Reader

  defer func() {
    if br != nil {
      buf, _ := br.Peek(br.Buffered())
      self.rconn = io.MultiReader(bytes.NewReader(buf), self.rconn)
    }
    if res.StatusCode == 200 {
      if res.ContentLength > 0 {
        res.Body = make([]byte, res.ContentLength)
        if _, err = io.ReadFull(self.rconn, res.Body); err != nil {
          return
        }
      }
    } else if res.BlockLength > 0 {
      res.Block = make([]byte, res.BlockLength)
      if _, err = io.ReadFull(self.rconn, res.Block); err != nil {
        return
      }
    }
  }()

  var h [4]byte
  if _, err = io.ReadFull(self.rconn, h[:]); err != nil {
    return
  }

  if h[0] == 36 {
    // $
    res.BlockLength = int(h[2])<<8+int(h[3])
    res.BlockNo = int(h[1])
    if self.DebugConn {
      fmt.Println("block: len", res.BlockLength, "no", res.BlockNo)
    }
    return
  } else if h[0] == 82 && h[1] == 84 && h[2] == 83 && h[3] == 80 {
    // RTSP 200 OK
    self.rconn = io.MultiReader(bytes.NewReader(h[:]), self.rconn)
  } else {
    for {
      for {
        var b [1]byte
        if _, err = self.rconn.Read(b[:]); err != nil {
          return
        }
        if b[0] == 36 {
          break
        }
      }
      if self.DebugConn {
        fmt.Println("block: relocate")
      }
      if _, err = io.ReadFull(self.rconn, h[1:4]); err != nil {
        return
      }
      res.BlockLength = int(h[2])<<8+int(h[3])
      res.BlockNo = int(h[1])
      if res.BlockNo/2 < len(self.streams) {
        break
      }
    }
    if self.DebugConn {
      fmt.Println("block: len", res.BlockLength, "no", res.BlockNo)
    }
    return
  }

  br = bufio.NewReader(self.rconn)
  tp := textproto.NewReader(br)

  var line string
  if line, err = tp.ReadLine(); err != nil {
    return
  }
  if self.DebugConn {
    fmt.Println("<", line)
  }

  fline := strings.SplitN(line, " ", 3)
  if len(fline) < 2 {
    err = fmt.Errorf("malformed RTSP response line")
    return
  }

  if res.StatusCode, err = strconv.Atoi(fline[1]); err != nil {
    return
  }
  var header textproto.MIMEHeader
  if header, err = tp.ReadMIMEHeader(); err != nil {
    return
  }

  if self.DebugConn {
    fmt.Println("<", header)
  }

  if res.StatusCode != 200 && res.StatusCode != 401 {
    err = fmt.Errorf("rtsp: StatusCode=%d invalid", res.StatusCode)
    return
  }

  if res.StatusCode == 401 {
    /*
    	RTSP/1.0 401 Unauthorized
    	CSeq: 2
    	Date: Wed, May 04 2016 10:10:51 GMT
    	WWW-Authenticate: Digest realm="LIVE555 Streaming Media", nonce="c633aaf8b83127633cbe98fac1d20d87"
    */
    authval := header.Get("WWW-Authenticate")
    hdrval := strings.SplitN(authval, " ", 2)
    var realm, nonce string

    if len(hdrval) == 2 {
      for _, field := range strings.Split(hdrval[1], ",") {
        field = strings.Trim(field, ", ")
        if keyval := strings.Split(field, "="); len(keyval) == 2 {
          key := keyval[0]
          val := strings.Trim(keyval[1], `"`)
          switch key {
          case "realm":
            realm = val
          case "nonce":
            nonce = val
          }
        }
      }

      if realm != "" && nonce != "" {
        if self.url.User == nil {
          err = fmt.Errorf("rtsp: please provide username and password")
          return
        }
        var username string
        var password string
        var ok bool
        username = self.url.User.Username()
        if password, ok = self.url.User.Password(); !ok {
          err = fmt.Errorf("rtsp: please provide password")
          return
        }
        hs1 := md5hash(username+":"+realm+":"+password)
        hs2 := md5hash("DESCRIBE:"+self.requestUri)
        response := md5hash(hs1+":"+nonce+":"+hs2)
        self.authorization = fmt.Sprintf(
          `Digest username="%s", realm="%s", nonce="%s", uri="%s", response="%s"`,
          username, realm, nonce, self.requestUri, response)
      }
    }
  }

  if sess := header.Get("Session"); sess != "" && self.session == "" {
    if fields := strings.Split(sess, ";"); len(fields) > 0 {
      self.session = fields[0]
    }
  }

  res.ContentLength, _ = strconv.Atoi(header.Get("Content-Length"))

  return
}



func main() {
  var err error
  var URL *url.URL

  uri := fmt.Sprintf("%s", os.Getenv("HEALTHCHECK_URL"))

  if URL, err = url.Parse(uri); err != nil {
    os.Exit(1)
  }

  dailer := net.Dialer{}
  var conn net.Conn
  if conn, err = dailer.Dial("tcp", URL.Host); err != nil {
    os.Exit(1)
  }

  u2 := *URL
  u2.User = nil

  self := &Client{
    conn: conn,
    rconn: conn,
    url: URL,
    requestUri: u2.String(),
  }

  if err = self.WriteRequest(Request{
    Method: "OPTIONS",
    Uri: self.requestUri,
  }); err != nil {
    os.Exit(1)
  }
  var response Response
  if response, err = self.ReadResponse(); err != nil {
    os.Exit(1)
  }
  if response.StatusCode != 200 {
    os.Exit(1)
  }
  fmt.Println("Healthcheck returned OK")
  return

}

