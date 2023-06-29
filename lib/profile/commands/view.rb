require 'curses'

require_relative '../command'

module Profile
  module Commands
    class View < Command
      SUCCESS_STATUSES = %w[ok changed rescued]
      FAIL_STATUSES = %w[failed fatal unreachable]
      SKIP_STATUSES = %w[skipped ignored]
      ALL_STATUSES = SUCCESS_STATUSES + FAIL_STATUSES + SKIP_STATUSES

      def run
        @name = args[0]
        raise "Node '#{@name}' not found" unless node

        if @options.watch
          in_clean_window do
            loop do
              height = `tput lines`.chomp.to_i
              width = `tput cols`.chomp.to_i

              Curses.noecho
              Curses.curs_set(0)
              Curses.setpos(0, 0)

              truncated = output.lines.map do |line|
                [].tap do |out|
                  (line.length.to_f / width).ceil.times do |i|
                    out << line[0+(width*i)...width*(i+1)]
                  end
                end
              end.flatten

              Curses.addstr(truncated.last(height).join)
              Curses.refresh
              sleep 2
            end
          end
        else
          puts output
        end
      end

      def output
        log = File.read(node.log_file)
        commands = log.split(/(?=PROFILE_COMMAND)/)
        "".tap do |output|
          commands.each { |cmd| output << command_structure(cmd) + "\n" }
        end
      end

      def in_clean_window
        Curses.init_screen
        begin
          yield
        ensure
          Curses.close_screen
        end
      end

      def command_structure(command)
        header = command.split("\n").first.sub /^PROFILE_COMMAND .*: /, ''
        cmd_name = command[/(?<=PROFILE_COMMAND ).*?(?=:)/]
        <<HEREDOC
Command:
    #{cmd_name}

Running:
    #{header}

Progress:
#{new_display_task_status(command).chomp}

Status:
    #{node.status.upcase}

HEREDOC
      end

      def node
        Node.find(@name, reload: true)
      end

      def split_log_line(line)
        parts =
          line.split("\n")
            .map { |l| l.split(' - ') }
            .reject(&:empty?)
            .first


        keys = %w{time playbook task_name task_action category data}
        keys.zip(parts).to_h
      end

      def new_display_task_status(command)
        roles = []
        str = ""
        command.split("\n").each_with_index do |line, idx|
          line << "\n"
          if @options.raw
            str += line unless idx == 0
          else
            next if line.chomp.empty?
            next if line.include?("PROFILE_COMMAND")
            parts = split_log_line(line)
            if SUCCESS_STATUSES.include?(parts['category']&.downcase)
              str += "   \u2705 #{parts['task_name']}\n"
            elsif FAIL_STATUSES.include?(parts['category']&.downcase)
              str += "   \u274c #{parts['task_name']}\n"
            end
          end
        end
        str
      end

      def display_task_status(command)
        task_name, task_status, role, new_role = nil
        roles = []
        str = ""
        command.split("\n").each_with_index do |line, idx|
          line << "\n"
          if @options.raw
            str += line unless idx == 0
          else
            if line.start_with?('TASK')
              role, task_name = line[ /\[(.*?)\]/, 1 ].split(' : ')
              new_role = !roles.include?(role)
              roles << role if new_role
            elsif ALL_STATUSES.any? { |s| line.start_with?(s) }
              if !task_status || SUCCESS_STATUSES.include?(task_status)
                task_status = line.split(':')
                                  .first
              end
            elsif task_name && task_status
              str += "#{role}\n" if new_role
              if SUCCESS_STATUSES.include?(task_status)
                str += "   \u2705 #{task_name}\n"
              elsif FAIL_STATUSES.include?(task_status)
                str += "   \u274c #{task_name}\n"
              end
              task_name, task_status = nil
            end
          end
        end
        str
      end
    end
  end
end
