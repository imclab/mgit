#!/usr/bin/env ruby
# (c) 2010 jerome etienne
# release under MIT license

require 'optparse'
require 'open4'
require 'shellwords'	# same as escape gem. but in core, so no dependancy

class Mgit
	def initialize(dirnames)
		# copy the parameters
		@dirnames	= dirnames
		
		@verbose	= true

		@tty_all_off	= "\e[0m"
		@tty_fg_green	= "\e[32m"
		@tty_fg_red	= "\e[31m"
	end
	
	def pull
		@dirnames.each { |dirname|	pull_one(dirname)			}
	end
	
	def push
		@dirnames.each { |dirname|	push_one(dirname)			}
	end

	def status
		@dirnames.each { |dirname|	status_one(dirname)			}
	end
	
	def commit_all(message)
		@dirnames.each { |dirname|	commit_all_one(dirname, message)	}
	end

	def add_all()
		@dirnames.each { |dirname|	add_all_one(dirname)			}
	end
	
	def is_git_repo?(dirname)
		gitdir	= File.join(dirname, ".git")
		return false unless File.directory?	gitdir
		return false unless File.directory?	File.join(gitdir,"objects")
		return false unless File.directory?	File.join(gitdir,"branches")
		return false unless File.directory?	File.join(gitdir,"refs")
		return false unless File.exists?	File.join(gitdir,"config")
		return false unless File.exists?	File.join(gitdir,"HEAD")
		return true
	end
	
	private
	def clean?(dirname)
		# test if "nothing to commit" is presenty
		begin
			# build the cmdline
			cmdline	= ""
			cmdline	+= "cd #{shell_escape_word(dirname)};"
			cmdline	+= "git status | tail -1 | egrep -i '^nothing to commit'"
			# run the command line
			output	= run_cmdline(cmdline)
		rescue => e
			return false
		end

		# test if "# You branch is ahead of" is NOT present
		begin
			# build the cmdline
			cmdline	= ""
			cmdline	+= "cd #{shell_escape_word(dirname)};"
			cmdline	+= "git status | egrep -i '^# Your branch is ahead of'"
			# run the command line
			output	= run_cmdline(cmdline)
			return false
		rescue => e
		end
		# if all previous tests passed, return true
		return true
	end

	def pull_one(dirname)
		# put this sequence in the cmd above, only once
		STDOUT.write "#{dirname}: "
		STDOUT.flush
		unless is_git_repo?(dirname)
			STDOUT.puts "#{@tty_fg_red}Not a git repository#{@tty_all_off}"
			return
		end
	
		# build the cmdline
		cmdline	= ""
		cmdline	+= "cd #{shell_escape_word(dirname)};"
		cmdline	+= "git pull"
		begin
			output	= run_cmdline(cmdline)
		rescue => e
		end
		STDOUT.puts "#{output}"
	end
	
	def push_one(dirname)
		STDOUT.write "#{dirname}: "
		STDOUT.flush
		unless is_git_repo?(dirname)
			STDOUT.puts "#{@tty_fg_red}Not a git repository#{@tty_all_off}"
			return
		end
		STDOUT.puts "pushing..."

		# build the cmdline
		cmdline	= ""
		cmdline	+= "cd #{shell_escape_word(dirname)};"
		cmdline	+= "git push >/dev/tty 2>/dev/tty"
		begin
			output	= run_cmdline(cmdline)
		rescue => e
		end
		STDOUT.puts "#{output}"
	end

	def status_one(dirname)
		sepa_length	= 30 - dirname.length
		STDOUT.write	"#{dirname}" + " " * [1,sepa_length].max + ": "
		STDOUT.flush
		unless is_git_repo?(dirname)
			STDOUT.puts "#{@tty_fg_red}Not a git repository#{@tty_all_off}"
			return
		end
	
		if clean?(dirname)
			STDOUT.puts "#{@tty_fg_green}Clean#{@tty_all_off}"
		else
			STDOUT.puts "#{@tty_fg_red}Dirty#{@tty_all_off}"
		end
	end
	
	def commit_all_one(dirname, message)
		STDOUT.write "#{dirname}: "
		STDOUT.flush
		unless is_git_repo?(dirname)
			STDOUT.puts "#{@tty_fg_red}Not a git repository#{@tty_all_off}"
			return
		end
		if clean?(dirname)
			STDOUT.puts "#{@tty_fg_green}nothing to commit#{@tty_all_off}"
			return
		end
		STDOUT.puts "Commiting..."
	
		# build the cmdline
		cmdline	= ""
		cmdline	+= "cd #{shell_escape_word(dirname)};"
		cmdline	+= "git commit -a -m #{shell_escape_word(message)} >/dev/tty 2>/dev/tty"
		begin
			output	= run_cmdline(cmdline)
		rescue => e
			#puts "failed due to #{e.inspect}"
		end
		STDOUT.puts "#{output}"
	end
	
	def add_all_one(dirname)
		STDOUT.write "#{dirname}: "
		STDOUT.flush
		unless is_git_repo?(dirname)
			STDOUT.puts "#{@tty_fg_red}Not a git repository#{@tty_all_off}"
			return
		end
		if clean?(dirname)
			STDOUT.puts "#{@tty_fg_green}nothing to add#{@tty_all_off}"
			return
		end
		STDOUT.puts "adding..."
	
		# build the cmdline
		cmdline	= ""
		cmdline	+= "cd #{shell_escape_word(dirname)};"
		cmdline	+= "git add . >/dev/tty 2>/dev/tty"
		begin
			output	= run_cmdline(cmdline)
		rescue => e
			#puts "failed due to #{e.inspect}"
		end
		STDOUT.puts "#{output}"
	end
	
	# run the cmdline and return stdout if no error occurs
	# otherwise it raise an exception with the exitstatus and stderr
	def run_cmdline(cmdline)
		pid, stdin, stdout, stderr = Open4::popen4(cmdline)
		# close stdin
		stdin.close
		# wait for the cmdline to complete
		ignored, status = Process::waitpid2 pid
		# if there is a error, raise an exception
		if status.exitstatus != 0
			reason	= "code: #{status.exitstatus} error: #{stderr.read}"
			stderr.close
			raise StandardError.new(reason)
		end
		# get the output
		output= stdout.read
		# close the fd
		stdout.close
		stderr.close
		# return stdout
		return output
	end
	def shell_escape_word(word)
		return Shellwords.escape(word)		
	end
end

if $PROGRAM_NAME == __FILE__
	# This hash will hold all of the options parsed from the command-line by OptionParser.
	cmdline_opts	= {
		:commit_msg	=> "Automatic commit"
	}
	OptionParser.new do |opts|
		# Set a banner, displayed at the top
		# of the help screen.
		opts.banner = "Usage: #{$0} [options...]\n\n"
		opts.on("-m", "--commit_msg STRING", "define the commit message. default to '#{cmdline_opts[:commit_msg]}'") do |val|
			cmdline_opts[:commit_msg]	= val
		end
		opts.on( '-h', '--help', 'Display this screen' ) do
			puts opts
			exit
		end
	end.parse!
	
	# parse ARGV
	
	commands	= [ARGV[0]]
	dirnames	= ARGV[1..-1]
	
	if commands == ["fullpush"]
		commands	= ["add", "commit", "push"]
	elsif commands == ["fullsync"]
		commands	= ["add", "commit", "pull", "push"]
	end

	# if no dirname is specified, it default to the git repository in which we are
	if dirnames.nil? or dirnames.empty?
		git_dir	= `git rev-parse --git-dir`
		dirname	= File.dirname(git_dir.strip)
		dirnames= [dirname]
	end

	# instanciate the object itself
	mgit	= Mgit.new(dirnames)

	commands.each { |command|
		if command == "status"
			mgit.status
		elsif command == "pull"
			mgit.pull
		elsif command == "push"
			mgit.push
		elsif command == "commit"
			mgit.commit_all(cmdline_opts[:commit_msg])
		elsif command == "add"
			mgit.add_all
		else
			STDERR.puts "command '#{command}' is invalid. Use --help for details"
		end
	}
	
end	
