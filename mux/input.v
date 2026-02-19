module mux

pub enum MuxAction {
	passthrough   // forward bytes to active pane as-is
	split_v       // Ctrl+V + |  → vertical split (left/right)
	split_h       // Ctrl+V + -  → horizontal split (top/bottom)
	nav_left      // Ctrl+V + ←
	nav_right     // Ctrl+V + →
	nav_up        // Ctrl+V + ↑
	nav_down      // Ctrl+V + ↓
	resize_left   // Ctrl+V + Ctrl+←
	resize_right  // Ctrl+V + Ctrl+→
	resize_up     // Ctrl+V + Ctrl+↑
	resize_down   // Ctrl+V + Ctrl+↓
	close_pane    // auto-close when pane process exits
	quit_mux      // Ctrl+V + q
	send_prefix   // Ctrl+V + Ctrl+V  → send \x16 to pane
	cycle_pane    // Ctrl+V + o  → cycle focus to next pane
	mouse_click   // X10 mouse button-press event
	none
}

enum InputState {
	normal
	prefix_wait
}

pub struct InputHandler {
pub mut:
	state      InputState
	click_col  int   // 0-based terminal column of the last mouse click
	click_row  int   // 0-based terminal row of the last mouse click
}

// handle parses a chunk of bytes from stdin and returns the corresponding MuxAction.
// If the action is .passthrough, the caller should forward the original bytes to the active pane.
pub fn (mut h InputHandler) handle(bytes []u8) MuxAction {
	if bytes.len == 0 { return .none }

	if h.state == .normal {
		// Ctrl+V = 0x16
		if bytes[0] == 0x16 {
			h.state = .prefix_wait
			return .none
		}
		// X10 mouse event: ESC [ M b x y  (6 bytes)
		// b = button+32 (32=left press, 33=middle, 34=right, 35=release)
		// x = col+33 (1-based col + 32), y = row+33 (1-based row + 32)
		if bytes.len >= 6 && bytes[0] == 0x1b && bytes[1] == `[` && bytes[2] == `M` {
			b := bytes[3]
			// Only handle button-press events (b < 35+32? No: b is raw, b=32 is left press)
			// b values: 32=left, 33=middle, 34=right, 35=release, 64/65=wheel
			if b < 35 {
				h.click_col = int(bytes[4]) - 33
				h.click_row = int(bytes[5]) - 33
				return .mouse_click
			}
			return .none
		}
		return .passthrough
	}

	// h.state == .prefix_wait
	h.state = .normal

	if bytes.len == 0 { return .none }
	b := bytes[0]

	// Ctrl+V again → send literal \x16 to the active pane
	if b == 0x16 { return .send_prefix }

	// Single-byte commands
	match b {
		`|`  { return .split_v }
		`-`  { return .split_h }
		`o`  { return .cycle_pane }
		`q`  { return .quit_mux }
		else {}
	}

	// Arrow key sequences: ESC [ A/B/C/D  (plain arrows)
	//                  or  ESC [ 1 ; 5 A/B/C/D  (Ctrl+arrow)
	if bytes.len >= 3 && bytes[0] == 0x1b && bytes[1] == `[` {
		if bytes.len == 3 {
			match bytes[2] {
				`A` { return .nav_up }
				`B` { return .nav_down }
				`C` { return .nav_right }
				`D` { return .nav_left }
				else {}
			}
		}
		// Ctrl+Arrow: ESC [ 1 ; 5 A/B/C/D
		if bytes.len >= 6 && bytes[2] == `1` && bytes[3] == `;` && bytes[4] == `5` {
			match bytes[5] {
				`A` { return .resize_up }
				`B` { return .resize_down }
				`C` { return .resize_right }
				`D` { return .resize_left }
				else {}
			}
		}
	}

	return .passthrough
}
