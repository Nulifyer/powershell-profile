//go:build windows

package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
	"strings"
	"sync/atomic"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	user32                  = windows.NewLazySystemDLL("user32.dll")
	procSendInput           = user32.NewProc("SendInput")
	procFindWindowW         = user32.NewProc("FindWindowW")
	procIsWindowVisible     = user32.NewProc("IsWindowVisible")
	procGetForegroundWindow = user32.NewProc("GetForegroundWindow")
	procGetWindowTextW      = user32.NewProc("GetWindowTextW")
	procMapVirtualKeyW      = user32.NewProc("MapVirtualKeyW")
	procVkKeyScanW          = user32.NewProc("VkKeyScanW")
)

const (
	inputKeyboard  = 1
	keyeventfKeyUp = 0x0002
	keyeventfUni   = 0x0004
)

type keyInput struct {
	Type      uint32
	_         uint32
	Vk        uint16
	Scan      uint16
	Flags     uint32
	Time      uint32
	ExtraInfo uintptr
	_         [8]byte
}

func vkInput(vk uint16, up bool) keyInput {
	sc, _, _ := procMapVirtualKeyW.Call(uintptr(vk), 0)
	k := keyInput{Type: inputKeyboard, Vk: vk, Scan: uint16(sc)}
	if up {
		k.Flags = keyeventfKeyUp
	}
	return k
}

func send(in []keyInput) {
	procSendInput.Call(uintptr(len(in)), uintptr(unsafe.Pointer(&in[0])), unsafe.Sizeof(in[0]))
}

var byTitle string

var (
	procEnumWindows         = user32.NewProc("EnumWindows")
	procSetForegroundWindow = user32.NewProc("SetForegroundWindow")
)

// findTitleContains returns the first visible top-level window whose title contains sub.
func findTitleContains(sub string) uintptr {
	var found uintptr
	cb := windows.NewCallback(func(h uintptr, _ uintptr) uintptr {
		t := title(h)
		// skip the console running this harness: its title contains our own command line
		if visible(h) && strings.Contains(t, sub) && !strings.Contains(t, "pbench") {
			found = h
			return 0
		}
		return 1
	})
	procEnumWindows.Call(cb, 0)
	return found
}

// forceForeground makes h the foreground window (the harness is the last input source).
func forceForeground(h uintptr) bool {
	for i := 0; i < 20; i++ {
		send([]keyInput{vkInput(0xFF, false), vkInput(0xFF, true)})
		procSetForegroundWindow.Call(h)
		if foreground() == h {
			return true
		}
		time.Sleep(20 * time.Millisecond)
	}
	return false
}

func findWindow(class string) uintptr {
	if byTitle != "" {
		t, _ := windows.UTF16PtrFromString(byTitle)
		h, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(t)))
		return h
	}
	c, _ := windows.UTF16PtrFromString(class)
	h, _, _ := procFindWindowW.Call(uintptr(unsafe.Pointer(c)), 0)
	return h
}

func visible(h uintptr) bool {
	r, _, _ := procIsWindowVisible.Call(h)
	return r != 0
}

func foreground() uintptr {
	h, _, _ := procGetForegroundWindow.Call()
	return h
}

func title(h uintptr) string {
	var b [512]uint16
	n, _, _ := procGetWindowTextW.Call(h, uintptr(unsafe.Pointer(&b[0])), 512)
	return windows.UTF16ToString(b[:n])
}

var vkByName = map[string]uint16{"ctrl": 0x11, "control": 0x11, "alt": 0x12, "shift": 0x10, "win": 0x5B, "super": 0x5B,
	"space": 0x20, "enter": 0x0D, "esc": 0x1B, "tab": 0x09, "backspace": 0x08, "bs": 0x08,
	"left": 0x25, "up": 0x26, "right": 0x27, "down": 0x28, "home": 0x24, "end": 0x23,
	"pgup": 0x21, "pgdn": 0x22, "insert": 0x2D, "ins": 0x2D, "delete": 0x2E, "del": 0x2E,
	"backtick": 0xC0, "plus": 0xBB, "minus": 0xBD, "comma": 0xBC, "period": 0xBE,
	"f1": 0x70, "f2": 0x71, "f3": 0x72, "f4": 0x73, "f5": 0x74, "f6": 0x75,
	"f7": 0x76, "f8": 0x77, "f9": 0x78, "f10": 0x79, "f11": 0x7A, "f12": 0x7B}

// Keys that a physical keyboard sends with the extended-key flag; without it
// Windows reports the numeric-keypad versions (scan codes shared with them).
var extendedVK = map[uint16]bool{0x21: true, 0x22: true, 0x23: true, 0x24: true, 0x25: true, 0x26: true,
	0x27: true, 0x28: true, 0x2D: true, 0x2E: true}

const keyeventfExtended = 0x0001

func parseCombo(s string) []uint16 {
	var vks []uint16
	for _, p := range strings.Split(strings.ToLower(s), "+") {
		if vk, ok := vkByName[p]; ok {
			vks = append(vks, vk)
		} else if len(p) == 1 {
			vks = append(vks, uint16(strings.ToUpper(p)[0]))
		}
	}
	return vks
}

func comboInput(vk uint16, up bool) keyInput {
	k := vkInput(vk, up)
	if extendedVK[vk] {
		k.Flags |= keyeventfExtended
	}
	return k
}

func pressCombo(vks []uint16) {
	var in []keyInput
	for _, vk := range vks {
		in = append(in, comboInput(vk, false))
	}
	for i := len(vks) - 1; i >= 0; i-- {
		in = append(in, comboInput(vks[i], true))
	}
	send(in)
}

// typeKey types r with real virtual-key codes (like a physical keyboard),
// falling back to a Unicode packet for characters the layout can't produce.
func typeKey(r rune) {
	v, _, _ := procVkKeyScanW.Call(uintptr(r))
	if int16(v) == -1 {
		typeRune(r)
		return
	}
	vk := uint16(v & 0xFF)
	shift := v&0x100 != 0
	var in []keyInput
	if shift {
		in = append(in, vkInput(0x10, false))
	}
	in = append(in, vkInput(vk, false), vkInput(vk, true))
	if shift {
		in = append(in, vkInput(0x10, true))
	}
	send(in)
}

func typeRune(r rune) {
	send([]keyInput{{Type: inputKeyboard, Scan: uint16(r), Flags: keyeventfUni},
		{Type: inputKeyboard, Scan: uint16(r), Flags: keyeventfUni | keyeventfKeyUp}})
}

// spin polls cond with sub-millisecond granularity.
func spin(timeout time.Duration, cond func() bool) (int64, bool) {
	deadline := qpc() + int64(timeout.Seconds()*float64(qpcFreq))
	for {
		if cond() {
			return qpc(), true
		}
		if qpc() > deadline {
			return 0, false
		}
		windows.SleepEx(0, false)
	}
}

type hotkeyRun struct {
	Run        int       `json:"run"`
	Visible    float64   `json:"visible_ms"`
	Foreground float64   `json:"foreground_ms"`
	Type       []float64 `json:"type_ms"`
	Hide       float64   `json:"hide_ms"`
	Error      string    `json:"error,omitempty"`
}

func cmdHotkey(args []string) {
	fs := flag.NewFlagSet("hotkey", flag.ExitOnError)
	class := fs.String("class", "ProjPickWindow", "window class to wait for")
	combo := fs.String("combo", "ctrl+alt+p", "hotkey to press")
	runs := fs.Int("runs", 50, "summons")
	typed := fs.String("type", "proj", "characters typed after each summon; the window title must contain the typed query")
	gap := fs.Duration("gap", 400*time.Millisecond, "pause between runs")
	load := fs.Int("load", 0, "busy goroutines at normal priority to load the CPU")
	timeout := fs.Duration("timeout", 5*time.Second, "per-step timeout")
	out := fs.String("out", "", "JSON output path")
	fs.StringVar(&byTitle, "title", "", "find the window by exact title instead of class (e.g. Karchy)")
	focus := fs.String("focus", "", "before each summon, put the window whose title contains this in the foreground")
	high := fs.Bool("high", false, "run the harness at HIGH priority so CPU load can't delay the measurement itself")
	fs.Parse(args)
	if *high {
		windows.SetPriorityClass(windows.CurrentProcess(), windows.HIGH_PRIORITY_CLASS)
	}

	var stop atomic.Bool
	for i := 0; i < *load; i++ {
		go func() {
			runtime.LockOSThread()
			x := 0
			for !stop.Load() {
				x++
			}
		}()
	}
	defer stop.Store(true)

	vks := parseCombo(*combo)
	var results []hotkeyRun
	for i := 0; i < *runs; i++ {
		r := hotkeyRun{Run: i}
		h := findWindow(*class)
		if h != 0 && visible(h) {
			send([]keyInput{vkInput(0x1B, false), vkInput(0x1B, true)})
			spin(*timeout, func() bool { return !visible(h) })
			time.Sleep(*gap)
		}
		if *focus != "" {
			fh := findTitleContains(*focus)
			if fh == 0 || !forceForeground(fh) {
				r.Error = "could not focus " + *focus
				results = append(results, r)
				fmt.Fprintf(os.Stderr, "run %d: %s\n", i, r.Error)
				continue
			}
		}
		t0 := qpc()
		pressCombo(vks)
		tv, ok := spin(*timeout, func() bool {
			h = findWindow(*class)
			return h != 0 && visible(h)
		})
		if !ok {
			r.Error = "not visible"
			results = append(results, r)
			fmt.Fprintf(os.Stderr, "run %d: NOT VISIBLE\n", i)
			time.Sleep(*gap)
			continue
		}
		r.Visible = ms(t0, tv)
		if tf, ok := spin(*timeout, func() bool { return foreground() == h }); ok {
			r.Foreground = ms(t0, tf)
		} else {
			r.Error = "never foreground"
		}
		q := ""
		for _, ch := range *typed {
			q += string(ch)
			want := q
			tt := qpc()
			typeRune(ch)
			if te, ok := spin(*timeout, func() bool { return strings.Contains(title(h), "["+want+"]") }); ok {
				r.Type = append(r.Type, ms(tt, te))
			} else {
				r.Error = "typed query not applied"
				break
			}
		}
		th := qpc()
		send([]keyInput{vkInput(0x1B, false), vkInput(0x1B, true)})
		if te, ok := spin(*timeout, func() bool { return !visible(h) }); ok {
			r.Hide = ms(th, te)
		}
		results = append(results, r)
		fmt.Fprintf(os.Stderr, "run %d: visible=%.2fms fg=%.2fms type=%v %s\n", i, r.Visible, r.Foreground, r.Type, r.Error)
		time.Sleep(*gap)
	}
	var vis, fg, typ, hide []float64
	fails := 0
	for _, r := range results {
		if r.Error != "" {
			fails++
		}
		if r.Visible > 0 {
			vis = append(vis, r.Visible)
		}
		if r.Foreground > 0 {
			fg = append(fg, r.Foreground)
		}
		typ = append(typ, r.Type...)
		if r.Hide > 0 {
			hide = append(hide, r.Hide)
		}
	}
	writeJSON(*out, map[string]any{"kind": "hotkey", "combo": *combo, "load": *load, "failures": fails, "runs": results,
		"summary": map[string]any{"visible_ms": stats(vis), "foreground_ms": stats(fg), "type_ms": stats(typ), "hide_ms": stats(hide)}})
}

// cmdType types text into the foreground window (for screenshots/demos).
// "\r" is Enter; "{wait:500}" pauses for that many milliseconds.
func cmdType(args []string) {
	fs := flag.NewFlagSet("type", flag.ExitOnError)
	text := fs.String("text", "", "text to type")
	delay := fs.Duration("delay", 40*time.Millisecond, "pause between characters")
	focus := fs.String("focus", "", "first bring the window whose title contains this to the foreground")
	fs.Parse(args)
	if *focus != "" {
		for i := 0; i < 50; i++ {
			if h := findTitleContains(*focus); h != 0 && forceForeground(h) {
				break
			}
			time.Sleep(200 * time.Millisecond)
		}
	}
	s := strings.NewReplacer(`\r`, "\r", `\e`, "\x1b").Replace(*text)
	for len(s) > 0 {
		if strings.HasPrefix(s, "{focus}") {
			if h := findTitleContains(*focus); h != 0 {
				forceForeground(h)
				time.Sleep(300 * time.Millisecond)
			}
			s = s[len("{focus}"):]
			continue
		}
		if strings.HasPrefix(s, "{combo:") {
			end := strings.Index(s, "}")
			pressCombo(parseCombo(s[7:end]))
			s = s[end+1:]
			continue
		}
		if strings.HasPrefix(s, "{wait:") {
			end := strings.Index(s, "}")
			var n int
			fmt.Sscanf(s[6:end], "%d", &n)
			time.Sleep(time.Duration(n) * time.Millisecond)
			s = s[end+1:]
			continue
		}
		r := []rune(s)[0]
		s = s[len(string(r)):]
		if r == '\r' {
			send([]keyInput{vkInput(0x0D, false), vkInput(0x0D, true)})
		} else if r == 0x1b {
			send([]keyInput{vkInput(0x1B, false), vkInput(0x1B, true)})
		} else {
			typeKey(r)
		}
		time.Sleep(*delay)
	}
}
