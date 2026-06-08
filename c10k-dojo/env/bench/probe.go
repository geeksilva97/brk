// probe — short-request HTTP load: measures throughput (req/s) and latency
// percentiles. Complements holder.go (which measures held-connection capacity).
// Together they cover the two metrics a benchmark needs without any external
// tool — just the Go toolchain you already have.
//
//	go run probe.go -addr 127.0.0.1:4000 -path / -c 50 -d 10s          # closed-loop throughput
//	go run probe.go -addr 127.0.0.1:4000 -path /io -c 200 -rate 200 -d 10s  # open-loop latency
//
// In open-loop (-rate N) a ticker emits N tokens/sec regardless of how fast the
// server replies, so a stalling server shows rising latency instead of hiding it
// (a basic guard against coordinated omission — not as rigorous as wrk2, but honest
// enough for the dojo).
package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:4000", "host:port")
	path := flag.String("path", "/", "request path")
	c := flag.Int("c", 50, "concurrent workers")
	d := flag.Duration("d", 10*time.Second, "duration")
	rate := flag.Int("rate", 0, "global requests/sec cap (0 = closed-loop, as fast as possible)")
	flag.Parse()

	url := fmt.Sprintf("http://%s%s", *addr, *path)
	client := &http.Client{
		Timeout:   10 * time.Second,
		Transport: &http.Transport{MaxIdleConns: *c * 2, MaxIdleConnsPerHost: *c * 2},
	}

	var count, errors int64
	var mu sync.Mutex
	var lat []time.Duration
	deadline := time.Now().Add(*d)
	var wg sync.WaitGroup

	do := func() {
		start := time.Now()
		resp, err := client.Get(url)
		if err != nil {
			atomic.AddInt64(&errors, 1)
			return
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		elapsed := time.Since(start)
		atomic.AddInt64(&count, 1)
		mu.Lock()
		lat = append(lat, elapsed)
		mu.Unlock()
	}

	if *rate > 0 {
		interval := time.Second / time.Duration(*rate)
		tokens := make(chan struct{}, *rate)
		go func() {
			t := time.NewTicker(interval)
			defer t.Stop()
			for time.Now().Before(deadline) {
				<-t.C
				select {
				case tokens <- struct{}{}:
				default: // server can't keep up — drop, don't throttle our own clock
				}
			}
			close(tokens)
		}()
		for i := 0; i < *c; i++ {
			wg.Add(1)
			go func() { defer wg.Done(); for range tokens { do() } }()
		}
	} else {
		for i := 0; i < *c; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for time.Now().Before(deadline) {
					do()
				}
			}()
		}
	}
	wg.Wait()

	mu.Lock()
	sort.Slice(lat, func(i, j int) bool { return lat[i] < lat[j] })
	pct := func(p float64) float64 {
		if len(lat) == 0 {
			return 0
		}
		idx := int(p * float64(len(lat)))
		if idx >= len(lat) {
			idx = len(lat) - 1
		}
		return float64(lat[idx].Microseconds()) / 1000.0
	}
	p50, p99 := pct(0.50), pct(0.99)
	mu.Unlock()

	total := atomic.LoadInt64(&count)
	reqS := float64(total) / (*d).Seconds()
	fmt.Printf("PROBE url=%s c=%d rate=%d req_s=%.0f p50_ms=%.2f p99_ms=%.2f count=%d errors=%d\n",
		url, *c, *rate, reqS, p50, p99, total, atomic.LoadInt64(&errors))
}
