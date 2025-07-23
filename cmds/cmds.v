module cmds

import os
import net.http

pub fn help(version string) {
	println('
vlsh - V Lang SHell v$version
---------------------------------------
Copyright (c) 2021 David Satime Wallin <david@dwall.in>
https://vlsh.ti-l.de


aliases		Shows a list of all declared aliases.
cd		Change to provided directory.
exit		Exit the shell.
help		Displays this message.
ocp		Override existing destination for cp.
version		Prints the version of vlsh.
share		Uploads a file to sprunge.us. ie. to share code.

	')
}

pub fn cd(args []string) ! {
	mut target := os.home_dir()
	if args.len > 0 {
		target = args[0]
	}
	os.chdir(target) or {
		return error('could not change directory to ${target}: ${err.msg}')
	}
}

pub fn share(args []string) !string {
	if args.len != 1 {
		return error('usage: share <file>')
	}
	if !os.exists(args[0]) {
		return error('could not find ${args[0]}')
	}
	file_content := os.read_file(args[0]) or {
		return error('could not read ${args[0]}')
	}

	mut data := map[string]string
	host := 'https://dpaste.com/api/'
	data['content'] = file_content
	resp := http.post_form(host, data) or {
		return error('could not post file: ${err.msg}')
	}

	if resp.status_code == 200 || resp.status_code == 201 {
		return resp.bytestr()
	}
	return error('status_code: ${resp.status_code}')
}
