module cmds

import os

pub fn ocp(args []string) ! {
	if os.exists(args[0]) {
		os.cp(args[0], args[1]) !
	} else {
		return error('"${args[0]}" does not exist')
	}
}
