//go:build windows

// pbench measures shell and hotkey responsiveness on Windows.
//
// shell:  launches a shell inside a ConPTY (the same pseudo console layer that
//
//	Windows Terminal uses) and records, per run, the time to the first
//	prompt, the latency of single keystrokes, and the latency of
//	Enter -> next prompt for a trivial command.
//
// hotkey: presses a global hotkey with SendInput and records how long it takes
//
//	until a window with the given class is visible and in the foreground,
//	and how long typed characters take to change its title.
//
// All timestamps come from QueryPerformanceCounter.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"sort"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	kernel32                = windows.NewLazySystemDLL("kernel32.dll")
	procQPC                 = kernel32.NewProc("QueryPerformanceCounter")
	procQPF                 = kernel32.NewProc("QueryPerformanceFrequency")
	procCreatePseudoConsole = kernel32.NewProc("CreatePseudoConsole")
	procClosePseudoConsole  = kernel32.NewProc("ClosePseudoConsole")
	qpcFreq                 int64
)

func init() {
	procQPF.Call(uintptr(unsafe.Pointer(&qpcFreq)))
}

func qpc() int64 {
	var v int64
	procQPC.Call(uintptr(unsafe.Pointer(&v)))
	return v
}

func ms(from, to int64) float64 { return float64(to-from) * 1000.0 / float64(qpcFreq) }

type chunk struct {
	at   int64
	data []byte
}

type conpty struct {
	hpc      windows.Handle
	inW      windows.Handle
	outR     windows.Handle
	proc     windows.Handle
	pid      uint32
	chunks   chan chunk
	buf      []byte
	readDone chan struct{}
}

func startConPTY(cmdline, cwd string, cols, rows int16, env []string) (*conpty, int64, error) {
	var inR, inW, outR, outW windows.Handle
	if err := windows.CreatePipe(&inR, &inW, nil, 0); err != nil {
		return nil, 0, err
	}
	if err := windows.CreatePipe(&outR, &outW, nil, 0); err != nil {
		return nil, 0, err
	}
	var hpc windows.Handle
	size := uintptr(uint32(uint16(cols)) | uint32(uint16(rows))<<16)
	r, _, _ := procCreatePseudoConsole.Call(size, uintptr(inR), uintptr(outW), 0, uintptr(unsafe.Pointer(&hpc)))
	if r != 0 {
		return nil, 0, fmt.Errorf("CreatePseudoConsole: 0x%x", r)
	}
	windows.CloseHandle(inR)
	windows.CloseHandle(outW)

	attrs, err := windows.NewProcThreadAttributeList(1)
	if err != nil {
		return nil, 0, err
	}
	defer attrs.Delete()
	if err := attrs.Update(windows.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, unsafe.Pointer(hpc), unsafe.Sizeof(hpc)); err != nil {
		return nil, 0, err
	}
	si := &windows.StartupInfoEx{ProcThreadAttributeList: attrs.List()}
	si.Cb = uint32(unsafe.Sizeof(*si))
	si.Flags = windows.STARTF_USESTDHANDLES
	var pi windows.ProcessInformation
	cl, _ := windows.UTF16PtrFromString(cmdline)
	var cwdp *uint16
	if cwd != "" {
		cwdp, _ = windows.UTF16PtrFromString(cwd)
	}
	var envBlock *uint16
	flags := uint32(windows.EXTENDED_STARTUPINFO_PRESENT)
	if len(env) > 0 {
		var b []uint16
		for _, e := range env {
			u, _ := windows.UTF16FromString(e)
			b = append(b, u...)
		}
		b = append(b, 0)
		envBlock = &b[0]
		flags |= windows.CREATE_UNICODE_ENVIRONMENT
	}
	t0 := qpc()
	if err := windows.CreateProcess(nil, cl, nil, nil, false, flags, envBlock, cwdp, &si.StartupInfo, &pi); err != nil {
		return nil, 0, fmt.Errorf("CreateProcess: %w", err)
	}
	windows.CloseHandle(pi.Thread)
	c := &conpty{hpc: hpc, inW: inW, outR: outR, proc: pi.Process, pid: pi.ProcessId,
		chunks: make(chan chunk, 4096), readDone: make(chan struct{})}
	go c.reader()
	return c, t0, nil
}

func (c *conpty) reader() {
	defer close(c.readDone)
	b := make([]byte, 64*1024)
	for {
		var n uint32
		err := windows.ReadFile(c.outR, b, &n, nil)
		at := qpc()
		if n > 0 {
			d := make([]byte, n)
			copy(d, b[:n])
			c.chunks <- chunk{at, d}
		}
		if err != nil {
			close(c.chunks)
			return
		}
	}
}

func (c *conpty) write(s string) int64 {
	var n uint32
	t := qpc()
	windows.WriteFile(c.inW, []byte(s), &n, nil)
	return t
}

// waitFor consumes output until pred(buffer-since-mark) is true. Returns the
// QPC timestamp of the chunk that satisfied it.
func (c *conpty) waitFor(mark int, timeout time.Duration, pred func([]byte) bool) (int64, bool) {
	deadline := time.After(timeout)
	if pred(c.buf[mark:]) {
		return qpc(), true
	}
	for {
		select {
		case ch, ok := <-c.chunks:
			if !ok {
				return 0, false
			}
			c.buf = append(c.buf, ch.data...)
			if pred(c.buf[mark:]) {
				return ch.at, true
			}
		case <-deadline:
			return 0, false
		}
	}
}

// waitAny waits for the first output chunk after mark.
func (c *conpty) waitAny(mark int, timeout time.Duration) (int64, bool) {
	return c.waitFor(mark, timeout, func(b []byte) bool { return len(b) > 0 })
}

// drain swallows output until it has been quiet for `quiet`.
func (c *conpty) drain(quiet time.Duration) {
	for {
		select {
		case ch, ok := <-c.chunks:
			if !ok {
				return
			}
			c.buf = append(c.buf, ch.data...)
		case <-time.After(quiet):
			return
		}
	}
}

func (c *conpty) close() {
	procClosePseudoConsole.Call(uintptr(c.hpc))
	windows.CloseHandle(c.inW)
	select {
	case <-c.readDone:
	case <-time.After(2 * time.Second):
	}
	windows.CloseHandle(c.outR)
	windows.CloseHandle(c.proc)
}

type shellRun struct {
	Run          int       `json:"run"`
	FirstOutput  float64   `json:"first_output_ms"`
	Prompt       float64   `json:"prompt_ms"`
	FirstKeyEcho float64   `json:"first_key_echo_ms"`
	KeyEcho      []float64 `json:"key_echo_ms"`
	Enter        []float64 `json:"enter_prompt_ms"`
	Exit         float64   `json:"exit_ms"`
	SelfReported string    `json:"self_reported,omitempty"`
	Error        string    `json:"error,omitempty"`
}

func stripANSI(b []byte) string {
	var sb strings.Builder
	for i := 0; i < len(b); i++ {
		if b[i] == 0x1b {
			// CSI ... final byte, or OSC ... BEL/ST
			if i+1 < len(b) && b[i+1] == '[' {
				i += 2
				for i < len(b) && (b[i] < 0x40 || b[i] > 0x7e) {
					i++
				}
				continue
			}
			if i+1 < len(b) && b[i+1] == ']' {
				i += 2
				for i < len(b) && b[i] != 7 && !(b[i] == 0x1b && i+1 < len(b) && b[i+1] == '\\') {
					i++
				}
				continue
			}
			i++
			continue
		}
		sb.WriteByte(b[i])
	}
	return sb.String()
}

func cmdShell(args []string) {
	fs := flag.NewFlagSet("shell", flag.ExitOnError)
	cmdline := fs.String("cmd", `"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo`, "shell command line")
	cwd := fs.String("cwd", "", "working directory")
	runs := fs.Int("runs", 10, "number of launches")
	marker := fs.String("marker", "\uf105", "text that marks a rendered prompt (after ANSI stripping)")
	keys := fs.Int("keys", 10, "keystroke echo samples per run")
	enters := fs.Int("enters", 10, "enter->prompt samples per run")
	command := fs.String("command", "cd .", "command typed for enter->prompt samples")
	timeout := fs.Duration("timeout", 60*time.Second, "per-step timeout")
	out := fs.String("out", "", "JSON output path")
	transcript := fs.String("transcript", "", "write raw output of the first run here")
	settle := fs.Duration("settle", 300*time.Millisecond, "pause between runs")
	var expects multiFlag
	fs.Var(&expects, "expect", "TEXT=>KEYS: before the prompt, wait for TEXT and send KEYS (\\r Enter, \\e Esc, \\d Down, ' ' Space); repeatable")
	think := fs.Duration("think", 0, "pause after the prompt before the first command (a human reading the prompt)")
	fs.Parse(args)

	markerHit := func(b []byte) bool { return strings.Contains(stripANSI(b), *marker) }
	var results []shellRun
	for i := 0; i < *runs; i++ {
		r := shellRun{Run: i}
		c, t0, err := startConPTY(*cmdline, *cwd, 120, 40, nil)
		if err != nil {
			r.Error = err.Error()
			results = append(results, r)
			continue
		}
		func() {
			defer c.close()
			if i == 0 && *transcript != "" {
				defer func() { c.drain(200 * time.Millisecond); os.WriteFile(*transcript, c.buf, 0o644) }()
			}
			if t, ok := c.waitAny(0, *timeout); ok {
				r.FirstOutput = ms(t0, t)
			}
			for _, ex := range expects {
				parts := strings.SplitN(ex, "=>", 2)
				if _, ok := c.waitFor(0, *timeout, func(b []byte) bool { return strings.Contains(stripANSI(b), parts[0]) }); !ok {
					r.Error = "expected text not seen: " + parts[0]
					return
				}
				time.Sleep(150 * time.Millisecond)
				keys := strings.NewReplacer(`\r`, "\r", `\e`, "\x1b", `\d`, "\x1b[B").Replace(parts[1])
				c.write(keys)
			}
			t, ok := c.waitFor(0, *timeout, markerHit)
			if !ok {
				r.Error = "prompt not seen"
				return
			}
			r.Prompt = ms(t0, t)
			// First keystroke right after the prompt is drawn: this is what a
			// user typing immediately experiences.
			mark := len(c.buf)
			tw := c.write("x")
			if te, ok := c.waitAny(mark, *timeout); ok {
				r.FirstKeyEcho = ms(tw, te)
			}
			c.drain(150 * time.Millisecond)
			c.write("\x15") // Ctrl+U clears the line
			c.drain(150 * time.Millisecond)
			for k := 0; k < *keys; k++ {
				mark := len(c.buf)
				tw := c.write(string(rune('a' + k%26)))
				te, ok := c.waitAny(mark, *timeout)
				if !ok {
					r.Error = "key echo timeout"
					return
				}
				r.KeyEcho = append(r.KeyEcho, ms(tw, te))
				c.drain(60 * time.Millisecond)
			}
			c.write("\x15")
			c.drain(150 * time.Millisecond)
			if *think > 0 {
				time.Sleep(*think)
				c.drain(50 * time.Millisecond)
			}
			for k := 0; k < *enters; k++ {
				mark := len(c.buf)
				tw := c.write(*command + "\r")
				te, ok := c.waitFor(mark, *timeout, func(b []byte) bool {
					s := stripANSI(b)
					// the marker must appear after the echoed command line
					idx := strings.LastIndex(s, *command)
					if idx < 0 {
						return false
					}
					return strings.Contains(s[idx+len(*command):], *marker)
				})
				if !ok {
					r.Error = "enter->prompt timeout"
					return
				}
				r.Enter = append(r.Enter, ms(tw, te))
				c.drain(80 * time.Millisecond)
			}
			s := stripANSI(c.buf)
			if idx := strings.Index(s, "Ready in "); idx >= 0 {
				end := strings.Index(s[idx:], "ms)")
				if end > 0 {
					r.SelfReported = s[idx : idx+end+3]
				}
			} else if idx := strings.Index(s, "Profile loaded in "); idx >= 0 {
				end := strings.Index(s[idx:], "ms")
				if end > 0 {
					r.SelfReported = s[idx : idx+end+2]
				}
			}
			tx := c.write("exit\r")
			ev, _ := windows.WaitForSingleObject(c.proc, 10000)
			if ev == windows.WAIT_OBJECT_0 {
				r.Exit = ms(tx, qpc())
			} else {
				windows.TerminateProcess(c.proc, 1)
			}
		}()
		results = append(results, r)
		fmt.Fprintf(os.Stderr, "run %d: prompt=%.1fms first_key=%.1fms key_p50=%.1fms enter_p50=%.1fms %s %s\n",
			i, r.Prompt, r.FirstKeyEcho, pct(r.KeyEcho, 50), pct(r.Enter, 50), r.SelfReported, r.Error)
		time.Sleep(*settle)
	}
	writeJSON(*out, map[string]any{"kind": "shell", "cmd": *cmdline, "runs": results, "summary": summarize(results)})
}

type multiFlag []string

func (m *multiFlag) String() string     { return strings.Join(*m, ",") }
func (m *multiFlag) Set(v string) error { *m = append(*m, v); return nil }

// cmdServe serves a directory over HTTP (offline VM tests of downloads).
func cmdServe(args []string) {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	dir := fs.String("dir", ".", "directory")
	addr := fs.String("addr", "127.0.0.1:8099", "listen address")
	dur := fs.Duration("for", 10*time.Minute, "exit after")
	fs.Parse(args)
	go func() { time.Sleep(*dur); os.Exit(0) }()
	http.ListenAndServe(*addr, http.FileServer(http.Dir(*dir)))
}

func pct(v []float64, p float64) float64 {
	if len(v) == 0 {
		return 0
	}
	s := append([]float64(nil), v...)
	sort.Float64s(s)
	idx := int(float64(len(s)-1) * p / 100.0)
	return s[idx]
}

func stats(v []float64) map[string]float64 {
	if len(v) == 0 {
		return nil
	}
	s := append([]float64(nil), v...)
	sort.Float64s(s)
	sum := 0.0
	for _, x := range s {
		sum += x
	}
	return map[string]float64{"n": float64(len(s)), "min": s[0], "p50": pct(s, 50), "p90": pct(s, 90),
		"p99": pct(s, 99), "max": s[len(s)-1], "mean": sum / float64(len(s))}
}

func summarize(rs []shellRun) map[string]any {
	var prompt, first, keys, enter []float64
	for _, r := range rs {
		if r.Prompt > 0 {
			prompt = append(prompt, r.Prompt)
		}
		if r.FirstKeyEcho > 0 {
			first = append(first, r.FirstKeyEcho)
		}
		keys = append(keys, r.KeyEcho...)
		enter = append(enter, r.Enter...)
	}
	return map[string]any{"prompt_ms": stats(prompt), "first_key_echo_ms": stats(first),
		"key_echo_ms": stats(keys), "enter_prompt_ms": stats(enter)}
}

func writeJSON(path string, v any) {
	b, _ := json.MarshalIndent(v, "", "  ")
	if path == "" {
		os.Stdout.Write(b)
		return
	}
	os.WriteFile(path, b, 0o644)
}

// cmdBurn saturates N threads at normal priority for a while (a separate
// process, so the measuring harness is scheduled by the OS like any app).
func cmdBurn(args []string) {
	fs := flag.NewFlagSet("burn", flag.ExitOnError)
	threads := fs.Int("threads", 8, "busy threads")
	dur := fs.Duration("for", 60*time.Second, "duration")
	fs.Parse(args)
	runtime.GOMAXPROCS(*threads)
	deadline := time.Now().Add(*dur)
	done := make(chan struct{})
	for i := 0; i < *threads; i++ {
		go func() {
			x := 0
			for time.Now().Before(deadline) {
				for j := 0; j < 1000000; j++ {
					x += j
				}
			}
			_ = x
			done <- struct{}{}
		}()
	}
	for i := 0; i < *threads; i++ {
		<-done
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: pbench shell|hotkey [flags]")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "shell":
		cmdShell(os.Args[2:])
	case "hotkey":
		cmdHotkey(os.Args[2:])
	case "burn":
		cmdBurn(os.Args[2:])
	case "type":
		cmdType(os.Args[2:])
	case "serve":
		cmdServe(os.Args[2:])
	default:
		fmt.Fprintln(os.Stderr, "unknown command", os.Args[1])
		os.Exit(2)
	}
	_ = syscall.Getpid
}
