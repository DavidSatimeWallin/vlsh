module utils

import os
import strings
import term

import cfg

const debug_mode = os.getenv('VLSHDEBUG')

pub fn ok(input string) {
	println(term.ok_message('OKY| ${input}'))
}

pub fn fail(input string) {
	println(term.fail_message('ERR| ${input}'))
}

pub fn warn(input string) {
	println(term.warn_message('WRN| ${input}'))
}

// parse_args splits a command string into tokens, respecting single and
// double quoted strings (which are kept as one token with quotes stripped).
pub fn parse_args(input string) []string {
	mut args := []string{}
	mut current := strings.new_builder(32)
	mut in_single := false
	mut in_double := false
	for ch in input {
		if ch == `'` && !in_double {
			in_single = !in_single
		} else if ch == `"` && !in_single {
			in_double = !in_double
		} else if ch == ` ` && !in_single && !in_double {
			if current.len > 0 {
				args << current.str()
				current = strings.new_builder(32)
			}
		} else {
			current.write_u8(ch)
		}
	}
	if current.len > 0 {
		args << current.str()
	}
	return args
}

// is_env_assign reports whether tok is a shell-style KEY=VALUE assignment.
// The key must be a non-empty identifier (letter or underscore, then letters,
// digits, or underscores).  Used to detect leading env-var prefixes on a
// command line, e.g. `FOO=bar cmd arg`.
pub fn is_env_assign(tok string) bool {
	eq := tok.index('=') or { return false }
	if eq == 0 { return false } // empty key
	key := tok[..eq]
	first := key[0]
	if !first.is_letter() && first != `_` { return false }
	for ch in key[1..].bytes() {
		if !ch.is_letter() && !ch.is_digit() && ch != `_` { return false }
	}
	return true
}

pub fn debug[T](input ...T) {
	style := cfg.style() or {
		fail(err.msg())

		return
	}
	if debug_mode == 'true' {
		print(
			term.bg_rgb(
				style['style_debug_bg'][0],
				style['style_debug_bg'][1],
				style['style_debug_bg'][2],
				term.rgb(
					style['style_debug_fg'][0],
					style['style_debug_fg'][1],
					style['style_debug_fg'][2],
					'debug::\t\t'
				)
			)
		)
		for i in input {
			print(
				term.bg_rgb(
					style['style_git_bg'][0],
					style['style_git_bg'][1],
					style['style_git_bg'][2],
					term.rgb(
						style['style_git_fg'][0],
						style['style_git_fg'][1],
						style['style_git_fg'][2],
						i.str()
					)
				)
			)
		}
		print('\n')
	}
}

