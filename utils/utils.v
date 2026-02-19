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

