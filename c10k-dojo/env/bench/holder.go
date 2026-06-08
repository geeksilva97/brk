// holder — the C10K stress client. Opens N connections and HOLDS them (idle /
// slowloris style). This is what actually kills fork/thread servers; a request-
// rate tool like wrk/oha can't show it because short requests let a thread pool
// keep up. Written in Go so the generator isn't itself GVL-bound.
//
//	go run holder.go -addr 127.0.0.1:4000 -n 10000 -hold 30s -kind http
//
// Reports peak established connections and the dominant failure reason. A run
// where the *generator* hit EADDRNOTAVAIL is the client exhausting ephemeral
// ports, not the server failing — run.sh disqualifies those.
package main

import (
	"flag"
	"fmt"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:4000", "host:port to hammer")
	n := flag.Int("n", 1000, "concurrent connections to open and hold")
	hold := flag.Duration("hold", 30*time.Second, "how long to hold each connection")
	kind := flag.String("kind", "http", "tcp | http")
	flag.Parse()

	var established, failed int64
	var mu sync.Mutex
	reasons := map[string]int{}
	var wg sync.WaitGroup

	note := func(err error) {
		atomic.AddInt64(&failed, 1)
		msg := err.Error()
		switch {
		case strings.Contains(msg, "EADDRNOTAVAIL") || strings.Contains(msg, "assign requested address"):
			msg = "client-ephemeral-exhausted" // disqualifier: not the server's fault
		case strings.Contains(msg, "connection refused"):
			msg = "refused" // accept backlog / server not listening
		case strings.Contains(msg, "reset by peer") || strings.Contains(msg, "reset"):
			msg = "reset" // server reset under the connection storm (backlog pressure)
		case strings.Contains(msg, "timeout") || strings.Contains(msg, "deadline"):
			msg = "timeout" // server wedged
		case strings.Contains(msg, "too many open files"):
			msg = "client-fd-exhausted"
		}
		mu.Lock()
		reasons[msg]++
		mu.Unlock()
	}

	start := time.Now()
	for i := 0; i < *n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			c, err := net.DialTimeout("tcp", *addr, 5*time.Second)
			if err != nil {
				note(err)
				return
			}
			defer c.Close()
			atomic.AddInt64(&established, 1)
			if *kind == "http" {
				// partial request to /hold, then trickle a header every few seconds
				// so the connection stays open without ever completing.
				fmt.Fprintf(c, "GET /hold HTTP/1.1\r\nHost: bench\r\n")
				deadline := time.Now().Add(*hold)
				for time.Now().Before(deadline) {
					time.Sleep(5 * time.Second)
					if _, err := c.Write([]byte("X-Keep: 1\r\n")); err != nil {
						return
					}
				}
			} else {
				// raw TCP: just hold the accepted connection open and idle.
				time.Sleep(*hold)
			}
		}()
		// tiny stagger to avoid a thundering SYN burst that trips the client first
		if i%500 == 499 {
			time.Sleep(20 * time.Millisecond)
		}
	}

	// Print a live peak once connections have had a moment to settle.
	time.Sleep(2 * time.Second)
	peak := atomic.LoadInt64(&established)
	wg.Wait()

	// dominant reason
	top, topN := "none", 0
	mu.Lock()
	for r, c := range reasons {
		if c > topN {
			top, topN = r, c
		}
	}
	mu.Unlock()

	fmt.Printf("HOLDER addr=%s requested=%d established=%d peak=%d failed=%d first_error=%s elapsed=%s\n",
		*addr, *n, atomic.LoadInt64(&established), peak, atomic.LoadInt64(&failed), top, time.Since(start).Round(time.Millisecond))
}
