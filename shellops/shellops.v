module shellops

import os
import strings

// ChainPart represents one command in a &&/||/; chain together with the
// operator that precedes it (empty string for the first command).
pub struct ChainPart {
pub:
	cmd    string
	pre_op string // '', '&&', '||', ';'
}

// split_commands splits an input string on &&, ||, and ; operators while
// respecting single and double quotes.  A lone | is left in the buffer
// (it is a pipe, handled later by walk_pipes).
pub fn split_commands(input string) []ChainPart {
	mut parts     := []ChainPart{}
	mut current   := strings.new_builder(64)
	mut in_single := false
	mut in_double := false
	mut cur_op    := ''
	mut i         := 0
	for i < input.len {
		ch := input[i]
		if ch == `'` && !in_double {
			in_single = !in_single
			current.write_u8(ch)
		} else if ch == `"` && !in_single {
			in_double = !in_double
			current.write_u8(ch)
		} else if !in_single && !in_double {
			if ch == `&` && i + 1 < input.len && input[i + 1] == `&` {
				s := current.str().trim_space()
				if s != '' { parts << ChainPart{ cmd: s, pre_op: cur_op } }
				current = strings.new_builder(64)
				cur_op = '&&'
				i += 2
				continue
			} else if ch == `|` && i + 1 < input.len && input[i + 1] == `|` {
				s := current.str().trim_space()
				if s != '' { parts << ChainPart{ cmd: s, pre_op: cur_op } }
				current = strings.new_builder(64)
				cur_op = '||'
				i += 2
				continue
			} else if ch == `;` {
				s := current.str().trim_space()
				if s != '' { parts << ChainPart{ cmd: s, pre_op: cur_op } }
				current = strings.new_builder(64)
				cur_op = ';'
				i++
				continue
			} else {
				current.write_u8(ch)
			}
		} else {
			current.write_u8(ch)
		}
		i++
	}
	s := current.str().trim_space()
	if s != '' { parts << ChainPart{ cmd: s, pre_op: cur_op } }
	return parts
}

// builtin_redirect strips > and >> redirection tokens from a built-in
// command's argument list, returning (cleanArgs, targetFile, appendMode).
pub fn builtin_redirect(args []string) ([]string, string, bool) {
	mut out     := []string{}
	mut rfile   := ''
	mut rappend := false
	mut skip    := false
	for i, tok in args {
		if skip { skip = false; continue }
		if tok == '>>' {
			rappend = true
			if i + 1 < args.len {
				rfile = if args[i + 1].starts_with('~/') {
					os.home_dir() + args[i + 1][1..]
				} else if args[i + 1] == '~' {
					os.home_dir()
				} else {
					args[i + 1]
				}
				skip = true
			}
		} else if tok == '>' {
			rappend = false
			if i + 1 < args.len {
				rfile = if args[i + 1].starts_with('~/') {
					os.home_dir() + args[i + 1][1..]
				} else if args[i + 1] == '~' {
					os.home_dir()
				} else {
					args[i + 1]
				}
				skip = true
			}
		} else {
			out << tok
		}
	}
	return out, rfile, rappend
}

// write_redirect writes content to a file (truncate or append mode).
pub fn write_redirect(path string, content string, append_mode bool) ! {
	flag := if append_mode { 'a' } else { 'w' }
	mut f := os.open_file(path, flag) or {
		return error('cannot open ${path}: ${err.msg()}')
	}
	f.write_string(content) or {}
	f.close()
}

