module main

import os

// ---------------------------------------------------------------------------
// split_and_chain
// ---------------------------------------------------------------------------

fn test_split_and_chain_single_command() {
	assert split_and_chain('ls -la') == ['ls -la']
}

fn test_split_and_chain_two_commands() {
	assert split_and_chain('touch /tmp/x && echo ok') == ['touch /tmp/x', 'echo ok']
}

fn test_split_and_chain_three_commands() {
	assert split_and_chain('a && b && c') == ['a', 'b', 'c']
}

fn test_split_and_chain_no_ampersand() {
	assert split_and_chain('echo hello') == ['echo hello']
}

fn test_split_and_chain_quoted_ampersands_not_split() {
	// && inside single quotes must not be treated as a chain separator
	result := split_and_chain("echo 'foo && bar'")
	assert result == ["echo 'foo && bar'"]
}

fn test_split_and_chain_double_quoted_ampersands_not_split() {
	result := split_and_chain('echo "foo && bar"')
	assert result == ['echo "foo && bar"']
}

fn test_split_and_chain_trims_parts() {
	assert split_and_chain('  a  &&  b  ') == ['a', 'b']
}

fn test_split_and_chain_empty_string() {
	assert split_and_chain('') == []string{}
}

// ---------------------------------------------------------------------------
// venv helpers (venv_tracked / venv_track / venv_untrack)
// ---------------------------------------------------------------------------

fn test_venv_tracked_empty_when_no_registry() {
	os.unsetenv(venv_registry)
	assert venv_tracked() == []string{}
}

fn test_venv_track_adds_key() {
	os.unsetenv(venv_registry)
	venv_track('TEST_VENV_KEY')
	keys := venv_tracked()
	assert 'TEST_VENV_KEY' in keys
	os.unsetenv(venv_registry)
}

fn test_venv_track_no_duplicates() {
	os.unsetenv(venv_registry)
	venv_track('DUP_KEY')
	venv_track('DUP_KEY')
	keys := venv_tracked()
	assert keys.filter(it == 'DUP_KEY').len == 1
	os.unsetenv(venv_registry)
}

fn test_venv_untrack_removes_key() {
	os.unsetenv(venv_registry)
	venv_track('RM_KEY')
	venv_untrack('RM_KEY')
	keys := venv_tracked()
	assert 'RM_KEY' !in keys
}

fn test_venv_untrack_clears_registry_when_last_key() {
	os.unsetenv(venv_registry)
	venv_track('ONLY_KEY')
	venv_untrack('ONLY_KEY')
	assert os.getenv(venv_registry) == ''
}

fn test_venv_untrack_nonexistent_key_is_noop() {
	os.unsetenv(venv_registry)
	venv_track('A')
	venv_untrack('B') // B was never tracked
	assert 'A' in venv_tracked()
	os.unsetenv(venv_registry)
}
