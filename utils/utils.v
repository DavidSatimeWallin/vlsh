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
// Unquoted tokens that contain * or ? are glob-expanded against the filesystem;
// if no files match the pattern is passed through unchanged.
pub fn parse_args(input string) []string {
	mut args       := []string{}
	mut current    := strings.new_builder(32)
	mut in_single  := false
	mut in_double  := false
	mut has_quoted := false // any part of the current token was inside quotes
	for ch in input {
		if ch == `'` && !in_double {
			in_single  = !in_single
			has_quoted = true
		} else if ch == `"` && !in_single {
			in_double  = !in_double
			has_quoted = true
		} else if ch == ` ` && !in_single && !in_double {
			if current.len > 0 {
				args << glob_expand(current.str(), has_quoted)
				current    = strings.new_builder(32)
				has_quoted = false
			}
		} else {
			current.write_u8(ch)
		}
	}
	if current.len > 0 {
		args << glob_expand(current.str(), has_quoted)
	}
	return args
}

// glob_expand returns the filesystem matches for tok when it is unquoted and
// contains wildcard characters (* or ?).  Falls back to [tok] if quoted, no
// wildcards, or no matches found.
fn glob_expand(tok string, was_quoted bool) []string {
	if was_quoted || (!tok.contains('*') && !tok.contains('?')) {
		return [tok]
	}
	// Expand a leading ~ before handing the pattern to the OS glob.
	mut pattern := if tok == '~' {
		os.home_dir()
	} else if tok.starts_with('~/') {
		os.home_dir() + tok[1..]
	} else {
		tok
	}
	// V's os.glob cannot handle path components like ../ or ./ because its
	// internal walker skips '.' and '..' entries.  Resolve the directory part
	// to an absolute path so os.glob only sees a plain filename pattern.
	if pattern.contains('/') {
		last_sep := pattern.last_index_u8(`/`)
		dir      := pattern[..last_sep]
		file_pat := pattern[last_sep + 1..]
		real_dir := os.real_path(dir)
		if real_dir != '' && os.is_dir(real_dir) {
			pattern = '${real_dir}/${file_pat}'
		}
	}
	matches := os.glob(pattern) or { return [tok] }
	if matches.len == 0 { return [tok] }
	return matches
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

