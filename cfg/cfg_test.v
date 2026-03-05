module cfg

// ---------------------------------------------------------------------------
// extract_aliases
// ---------------------------------------------------------------------------

fn test_extract_aliases_single() {
	mut c := Cfg{}
	c.extract_aliases(['alias gs=git status'])
	assert c.aliases['gs'] == 'git status'
}

fn test_extract_aliases_multiple() {
	mut c := Cfg{}
	c.extract_aliases([
		'alias gs=git status',
		'alias gps=git push',
		'alias gpl=git pull',
	])
	assert c.aliases['gs']  == 'git status'
	assert c.aliases['gps'] == 'git push'
	assert c.aliases['gpl'] == 'git pull'
}

fn test_extract_aliases_ignores_non_alias_lines() {
	mut c := Cfg{}
	c.extract_aliases(['# paths', 'export PATH=/tmp', 'alias ll=ls -la'])
	assert c.aliases.len == 1
	assert c.aliases['ll'] == 'ls -la'
}

fn test_extract_aliases_empty_input() {
	mut c := Cfg{}
	c.extract_aliases([])
	assert c.aliases.len == 0
}

fn test_extract_aliases_skips_blank_lines() {
	mut c := Cfg{}
	c.extract_aliases(['', 'alias vim=nvim', ''])
	assert c.aliases['vim'] == 'nvim'
}

fn test_extract_aliases_skips_comments() {
	mut c := Cfg{}
	c.extract_aliases(['# alias old=legacy', 'alias vim=nvim'])
	assert c.aliases.len == 1
	assert c.aliases['vim'] == 'nvim'
}

fn test_extract_aliases_value_with_equals() {
	mut c := Cfg{}
	c.extract_aliases(['alias run=VAR=1 cmd'])
	assert c.aliases['run'] == 'VAR=1 cmd'
}

// ---------------------------------------------------------------------------
// extract_style
// ---------------------------------------------------------------------------

fn test_extract_style_parses_rgb() {
	mut c := Cfg{}
	c.extract_style(['style_git_bg=44,59,71']) or { assert false, err.msg() }
	assert c.style['style_git_bg'] == [44, 59, 71]
}

fn test_extract_style_multiple_keys() {
	mut c := Cfg{}
	c.extract_style(['style_git_bg=44,59,71', 'style_git_fg=251,255,234']) or {
		assert false, err.msg()
	}
	assert c.style['style_git_bg'] == [44, 59, 71]
	assert c.style['style_git_fg'] == [251, 255, 234]
}

fn test_extract_style_injects_defaults_for_missing_keys() {
	mut c := Cfg{}
	c.extract_style([]) or { assert false, err.msg() }
	assert 'style_git_bg'   in c.style
	assert 'style_git_fg'   in c.style
	assert 'style_debug_bg' in c.style
	assert 'style_debug_fg' in c.style
}

fn test_extract_style_existing_key_not_overwritten_by_default() {
	mut c := Cfg{}
	c.extract_style(['style_git_bg=10,20,30']) or { assert false, err.msg() }
	assert c.style['style_git_bg'] == [10, 20, 30]
}

fn test_extract_style_skips_blank_lines() {
	mut c := Cfg{}
	c.extract_style(['', 'style_git_bg=1,2,3', '']) or { assert false, err.msg() }
	assert c.style['style_git_bg'] == [1, 2, 3]
}

fn test_extract_style_skips_comments() {
	mut c := Cfg{}
	c.extract_style(['#style_git_bg=99,99,99', 'style_git_fg=1,2,3']) or { assert false, err.msg() }
	assert c.style['style_git_fg'] == [1, 2, 3]
	// The commented style should not be parsed; the default should be used instead.
	assert c.style['style_git_bg'] == [44, 59, 71]
}
