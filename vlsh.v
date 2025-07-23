module main

import os
import term
import readline { Readline }

import cfg
import cmds
import exec
import utils

const version = '0.1.4'

struct Prompt {
	mut:
	git_branch string
	git_commit string
	git_prompt string
	git_repo   string
}

fn pre_prompt() string {

	mut prompt := Prompt{}

	style := cfg.style() or {
		utils.fail(err.msg())

		exit(1)
	}

	mut current_dir := term.colorize(term.bold, '$os.getwd() ')
	current_dir = current_dir.replace('$os.home_dir()', '~')

	// Verify and/or update git prompt
	prompt.update_git_info() or {
		utils.fail(err.msg())
	}

	prompt.git_prompt = term.bg_rgb(
		style['style_git_bg'][0],
		style['style_git_bg'][1],
		style['style_git_bg'][2],
		term.rgb(
			style['style_git_fg'][0],
			style['style_git_fg'][1],
			style['style_git_fg'][2],
			prompt.git_prompt
		)
	)

	return '\n$prompt.git_prompt\n$current_dir'
}

fn main() {

	if !os.exists(cfg.config_file) {
		cfg.create_default_config_file() or { panic(err.msg()) }
	}

	term.clear()
	mut r := Readline{}
	for {
		println(pre_prompt())
		cmd := r.read_line(term.rgb(255, 112, 112, '- ')) or {
			utils.fail(err.msg())
			return
		}
		main_loop(cmd.str().trim_space())
	}
}

fn main_loop(input string) {

	input_split := input.split(' ')
	cmd := input_split[0]
	mut args := []string{}
	if input_split.len > 1 {
		args << input_split[1..]
	}

	match cmd {
		'aliases' {
			aliases := cfg.aliases() or {
				utils.fail(err.msg())

				return
			}
			for alias_name, alias_cmd in aliases {
				print('${term.bold(alias_name)} : ${term.italic(alias_cmd)}\n')
			}
		}
		'cd'      {
			cmds.cd(args) or {
				utils.fail(err.msg())

				return
			}
		}
		'ocp'     { cmds.ocp(args) or { utils.fail(err.msg()) } }
		'exit'    { exit(0) }
		'help'    { cmds.help(version) }
		'version' { println('version $version') }
		'share'   {
			link := cmds.share(args) or {
				utils.fail(err.msg())

				return
			}
			println(link)
		}
		else {
			local_cfg := cfg.get() or {
				utils.fail(err.msg())

				return
			}
			mut t := exec.Task{
				cmd: exec.Cmd_object{
					cmd  : cmd,
					args : args,
					cfg  : local_cfg
				}
			}
			t.prepare_task() or {
				utils.fail(err.msg())
			}
		}
	}
}

fn (mut s Prompt) update_git_info() ! {

	// if we're still in the same git-root, don't update
	if	s.git_repo != '' && os.getwd().contains(s.git_repo) { return }

	git_folder := [os.getwd(), '.git'].join('/')
	if !os.exists(git_folder) {
		s.fully_reset()

		return
	}

	if s.git_repo == '' || !os.getwd().contains(s.git_repo) {
		// assume we're in a new but valid git repo
		s.git_repo = os.getwd()
	}

	head_file := [git_folder, 'HEAD'].join('/').trim_space()
	if !os.exists(head_file) {
		s.fully_reset()

		return
	}

	head_file_content := os.read_file(head_file) or { return err }
	head_file_content_slice := head_file_content.trim_space().split('/')

	// assume, for now, that the last word in the HEAD -file is the branch
	s.git_branch = head_file_content_slice[head_file_content_slice.len - 1]
	s.git_prompt = '$s.git_branch'

	commit_file := [git_folder, 'refs', 'heads', s.git_branch]
		.join('/')
		.trim_space()
	commit_file_content := os.read_file(commit_file) or { return err }
	s.git_commit = commit_file_content.trim_space()[0..7]
	s.git_prompt = '$s.git_prompt $s.git_commit'
}

fn (mut p Prompt) fully_reset() {
	p.git_branch = ''
	p.git_commit = ''
	p.git_prompt = ''
	p.git_repo   = ''
}
