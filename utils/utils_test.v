module utils

// ---------------------------------------------------------------------------
// parse_args
// ---------------------------------------------------------------------------

fn test_parse_args_empty_string() {
	assert parse_args('') == []string{}
}

fn test_parse_args_single_word() {
	assert parse_args('hello') == ['hello']
}

fn test_parse_args_multiple_words() {
	assert parse_args('echo hello world') == ['echo', 'hello', 'world']
}

fn test_parse_args_leading_trailing_spaces() {
	assert parse_args('  ls  ') == ['ls']
}

fn test_parse_args_multiple_internal_spaces() {
	// consecutive spaces produce a single token boundary
	assert parse_args('echo  hello') == ['echo', 'hello']
}

fn test_parse_args_single_quoted_token() {
	result := parse_args("echo 'hello world'")
	assert result == ['echo', 'hello world']
}

fn test_parse_args_double_quoted_token() {
	result := parse_args('echo "hello world"')
	assert result == ['echo', 'hello world']
}

fn test_parse_args_single_quotes_suppress_double() {
	// double-quote inside single-quoted string is literal
	result := parse_args("echo '\"stay\"'")
	assert result == ['echo', '"stay"']
}

fn test_parse_args_double_quotes_suppress_single() {
	// single-quote inside double-quoted string is literal
	result := parse_args('echo "it\'s fine"')
	assert result == ['echo', "it's fine"]
}

fn test_parse_args_quoted_value_with_equals() {
	result := parse_args('aliases add name="git status"')
	assert result == ['aliases', 'add', 'name=git status']
}

fn test_parse_args_multiple_quoted_args() {
	result := parse_args('"foo bar" "baz qux"')
	assert result == ['foo bar', 'baz qux']
}

fn test_parse_args_empty_quoted_string() {
	result := parse_args('echo ""')
	// empty quoted token is discarded (current.len == 0 after closing quote)
	assert result == ['echo']
}

fn test_parse_args_only_spaces() {
	assert parse_args('   ') == []string{}
}

fn test_parse_args_pipe_character_is_not_special() {
	// parse_args is a tokenizer; pipe handling is exec's responsibility
	result := parse_args('cat file | wc')
	assert result == ['cat', 'file', '|', 'wc']
}

fn test_parse_args_env_assign_stays_one_token() {
	// KEY=VALUE must remain a single token so is_env_assign can detect it
	result := parse_args('FOO=bar cmd')
	assert result == ['FOO=bar', 'cmd']
}

// ---------------------------------------------------------------------------
// is_env_assign
// ---------------------------------------------------------------------------

fn test_is_env_assign_simple() {
	assert is_env_assign('FOO=bar') == true
}

fn test_is_env_assign_with_underscore_key() {
	assert is_env_assign('MY_VAR=value') == true
}

fn test_is_env_assign_key_starting_with_underscore() {
	assert is_env_assign('_VAR=value') == true
}

fn test_is_env_assign_empty_value() {
	assert is_env_assign('FOO=') == true
}

fn test_is_env_assign_empty_key_is_false() {
	assert is_env_assign('=value') == false
}

fn test_is_env_assign_no_equals_is_false() {
	assert is_env_assign('FOO') == false
}

fn test_is_env_assign_key_with_digit_start_is_false() {
	assert is_env_assign('1FOO=bar') == false
}

fn test_is_env_assign_key_with_hyphen_is_false() {
	assert is_env_assign('MY-VAR=value') == false
}

fn test_is_env_assign_key_with_dot_is_false() {
	assert is_env_assign('my.var=value') == false
}

fn test_is_env_assign_numeric_key_is_false() {
	assert is_env_assign('123=value') == false
}

fn test_is_env_assign_lowercase_key() {
	assert is_env_assign('path=value') == true
}

fn test_is_env_assign_key_with_digits_after_first() {
	assert is_env_assign('VAR2=value') == true
}
