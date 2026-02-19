// vman — V module documentation pager for vlsh.
//
// Copy to ~/.vlsh/plugins/v_man.v and run `plugins reload`.
// Requires `v` in PATH to compile and internet access to fetch docs.
//
// Usage: vman <module>
//   vman os
//   vman strings
//   vman net.http

module main

import os
import net.http
import strings

const docs_base = 'https://modules.vlang.io/'

// Tags whose entire subtree is suppressed from the output.
const skip_tags = ['script', 'style', 'noscript', 'iframe', 'object']

fn decode_entities(s string) string {
	return s
		.replace('&amp;',    '&')
		.replace('&lt;',     '<')
		.replace('&gt;',     '>')
		.replace('&nbsp;',   ' ')
		.replace('&quot;',   '"')
		.replace('&#39;',    "'")
		.replace('&apos;',   "'")
		.replace('&hellip;', '...')
		.replace('&mdash;',  '—')
		.replace('&ndash;',  '–')
}

// parse_tag returns the lowercase tag name and whether it is a closing tag.
fn parse_tag(inner string) (string, bool) {
	s := inner.trim_space()
	closing := s.starts_with('/')
	src := if closing { s[1..].trim_space() } else { s }
	mut end := 0
	for end < src.len {
		b := src[end]
		if b == u8(` `) || b == u8(`\t`) || b == u8(`\n`) || b == u8(`/`) { break }
		end++
	}
	if end == 0 { return '', closing }
	return src[..end].to_lower(), closing
}

// html_to_text converts an HTML page to ANSI-formatted plain text.
fn html_to_text(html string) string {
	mut out        := strings.new_builder(html.len / 2)
	mut skip_depth := 0
	mut in_pre     := false
	mut i          := 0
	n              := html.len

	for i < n {
		// Skip <!-- ... --> comments
		if (i + 3 < n) && html[i] == u8(`<`) && html[i + 1] == u8(`!`) &&
		   html[i + 2] == u8(`-`) && html[i + 3] == u8(`-`) {
			i += 4
			for i + 2 < n {
				if html[i] == u8(`-`) && html[i + 1] == u8(`-`) && html[i + 2] == u8(`>`) {
					i += 3
					break
				}
				i++
			}
			continue
		}

		if html[i] == u8(`<`) {
			// Advance j to the matching '>', respecting quoted attribute values.
			mut j := i + 1
			for j < n && html[j] != u8(`>`) {
				if html[j] == u8(`"`) {
					j++
					for j < n && html[j] != u8(`"`) { j++ }
				} else if html[j] == u8(`'`) {
					j++
					for j < n && html[j] != u8(`'`) { j++ }
				}
				if j < n { j++ }
			}
			tag_inner := if j < n { html[i + 1..j] } else { html[i + 1..] }
			i = j + 1

			name, closing := parse_tag(tag_inner)
			if name == '' { continue }

			// Manage suppressed-subtree depth
			if name in skip_tags {
				if !closing { skip_depth++ } else if skip_depth > 0 { skip_depth-- }
				continue
			}
			if skip_depth > 0 { continue }

			if closing {
				match name {
					'h1'                              { out.write_string('\x1b[0m\n\n') }
					'h2'                              { out.write_string('\x1b[0m\n\n') }
					'h3', 'h4', 'h5', 'h6'           { out.write_string('\x1b[0m\n') }
					'pre'                             { in_pre = false; out.write_string('\x1b[0m\n') }
					'code'                            { if !in_pre { out.write_string('\x1b[0m') } }
					'strong', 'b'                     { out.write_string('\x1b[0m') }
					'em', 'i'                         { out.write_string('\x1b[0m') }
					'p', 'ul', 'ol', 'div', 'section',
					'article', 'main', 'blockquote',
					'table'                           { out.write_string('\n') }
					else                              {}
				}
			} else {
				match name {
					'h1'                  { out.write_string('\n\x1b[1m\x1b[4m') }
					'h2'                  { out.write_string('\n\x1b[1m') }
					'h3', 'h4', 'h5', 'h6' { out.write_string('\n  \x1b[1m') }
					'pre'                 { in_pre = true; out.write_string('\n\x1b[36m') }
					'code'                { if !in_pre { out.write_string('\x1b[36m') } }
					'strong', 'b'         { out.write_string('\x1b[1m') }
					'em', 'i'             { out.write_string('\x1b[3m') }
					'p'                   { out.write_string('\n') }
					'br'                  { out.write_string('\n') }
					'hr'                  { out.write_string('\n' + '─'.repeat(70) + '\n') }
					'li'                  { out.write_string('\n  • ') }
					'tr'                  { out.write_string('\n  ') }
					'td', 'th'            { out.write_string('  ') }
					else                  {}
				}
			}
		} else {
			// Text node — collect bytes up to the next '<'
			mut j := i
			for j < n && html[j] != u8(`<`) { j++ }
			raw_text := html[i..j]
			i = j
			if skip_depth > 0 { continue }

			text := decode_entities(raw_text)
			if in_pre {
				out.write_string(text)
			} else {
				// Collapse any whitespace run to a single space
				mut prev_ws := true // true → trim leading space
				for b in text.bytes() {
					ws := b == u8(` `) || b == u8(`\t`) || b == u8(`\n`) || b == u8(`\r`)
					if ws {
						if !prev_ws { out.write_u8(u8(` `)) }
						prev_ws = true
					} else {
						out.write_u8(b)
						prev_ws = false
					}
				}
			}
		}
	}

	// Collapse runs of more than two consecutive newlines to two.
	raw := out.str()
	mut clean := strings.new_builder(raw.len)
	mut nl_run := 0
	for b in raw.bytes() {
		if b == u8(`\n`) {
			nl_run++
			if nl_run <= 2 { clean.write_u8(b) }
		} else {
			nl_run = 0
			clean.write_u8(b)
		}
	}
	return clean.str().trim('\n') + '\n'
}

// find_pager returns the full path of less or more, or '' if neither is found.
fn find_pager() string {
	for prog in ['less', 'more'] {
		r := os.execute('which ${prog} 2>/dev/null')
		if r.exit_code == 0 {
			p := r.output.trim_space()
			if p.len > 0 { return p }
		}
	}
	return ''
}

fn vman(module_name string) {
	url := docs_base + module_name + '.html'

	eprint('Fetching ${url} … ')
	resp := http.get(url) or {
		eprintln('')
		eprintln('vman: network error: ${err}')
		exit(1)
	}
	eprintln('done')

	if resp.status_code == 404 {
		eprintln('vman: module "${module_name}" not found')
		eprintln('      Browse available modules at https://modules.vlang.io/')
		exit(1)
	}
	if resp.status_code != 200 {
		eprintln('vman: HTTP ${resp.status_code} for ${url}')
		exit(1)
	}

	header  := '\x1b[1m${module_name.to_upper()}(vlang)' +
	           '                         V Module Documentation\x1b[0m\n\n'
	footer  := '\n\x1b[2m${url}\x1b[0m\n'
	content := header + html_to_text(resp.body) + footer

	// Safe filename: dots and slashes become underscores (e.g. net.http → net_http)
	safe_name := module_name.replace('.', '_').replace('/', '_')
	tmp := os.join_path(os.temp_dir(), 'vman_${safe_name}.txt')

	pager := find_pager()
	if pager == '' {
		print(content)
		return
	}
	os.write_file(tmp, content) or {
		print(content)
		return
	}
	flags := if pager.ends_with('less') { ' -R' } else { '' }
	os.system('${pager}${flags} "${tmp}"')
	os.rm(tmp) or {}
}

fn main() {
	op := if os.args.len > 1 { os.args[1] } else { '' }
	match op {
		'capabilities' {
			println('command vman')
		}
		'run' {
			cmd := if os.args.len > 2 { os.args[2] } else { '' }
			if cmd == 'vman' {
				if os.args.len < 4 {
					eprintln('usage: vman <module>')
					eprintln('examples: vman os   vman strings   vman net.http')
					eprintln('see: https://modules.vlang.io/')
					exit(1)
				}
				vman(os.args[3])
			}
		}
		else {}
	}
}
