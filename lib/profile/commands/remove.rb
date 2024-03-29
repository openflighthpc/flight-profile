require_relative '../command'
require_relative './concerns/node_utils'
require_relative '../config'
require_relative '../hunter_cli'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'

require 'logger'

require 'open3'

module Profile
  module Commands
    class Remove < Command
      include Outputs
      include Concerns::NodeUtils

      def run
        # ARGS:
        # [ names ]
        # OPTS:
        # [ force ]
        @hunter = Config.use_hunter?
        @remove_hunter_entry = @options.remove_hunter_entry || Config.remove_hunter_entry

        strings = args[0].split(',')
        names = []
        strings.each do |str|
          names.append(expand_brackets(str))
        end

        names.flatten!

        # Fetch cluster type
        cluster_type = Type.find(Config.cluster_type)
        raise "Invalid cluster type. Please run `profile configure`" unless cluster_type
        unless cluster_type.prepared?
          raise "Cluster type has not been prepared yet. Please run `profile prepare #{cluster_type.id}`."
        end

        # Check nodes exist
        check_names_exist(names)

        nodes = names.map { |n| Node.find(n) }

        # Check nodes can be removed
        check_nodes_removable(nodes)

        # Check nodes can aren't in the middle of doing something else
        check_nodes_not_busy(nodes)

        answer_collection = collect_answers(cluster_type.questions, cluster_type.answers)
        answers = answer_collection['answers']
        # Check all questions have been answered
        missing_questions = answer_collection['missing_questions']
        if missing_questions.any?
          out = <<~OUT.chomp
            The following config keys have not been set:
            #{missing_questions.join("\n")}
            Please run `profile configure`
          OUT
          raise out
        end

        hosts_term = names.length > 1 ? 'hosts' : 'host'
        printable_names = names.map { |h| "'#{h}'" }
        puts "Removing #{hosts_term} #{printable_names.join(', ')}"

        inventory = Inventory.load(Type.find(Config.cluster_type).fetch_answer("cluster_name"))
        inv_file = inventory.filepath

        env = {
          "ANSIBLE_CALLBACK_PLUGINS" => Config.ansible_callback_dir,
          "ANSIBLE_STDOUT_CALLBACK" => "log_plays_v2",
          "ANSIBLE_DISPLAY_SKIPPED_HOSTS" => "false",
          "ANSIBLE_HOST_KEY_CHECKING" => "false",
          "INVFILE" => inv_file,
          "RUN_ENV" => cluster_type.run_env,
          "HUNTER_HOSTS" => @hunter.to_s
        }.merge(answers)

        # Set up log files
        nodes.each do |node|
          ansible_log_path = File.join(
            ansible_log_dir,
            node.hostname
          )

          node.clear_logs
          log_symlink = "#{Config.log_dir}/#{node.name}-remove-#{Time.now.to_i}.log"

          FileUtils.mkdir_p(ansible_log_dir)
          FileUtils.touch(ansible_log_path)

          File.symlink(
            ansible_log_path,
            log_symlink
          )
        end

        # Group by identity to use different command for each
        nodes.group_by(&:identity).each do |identity, nodes|
          node_objs = Nodes.new(nodes)
          env = env.merge(
            {
              "NODE" => nodes.map(&:hostname).join(','),
              "ANSIBLE_LOG_FOLDER" => ansible_log_dir
            }
          ).transform_values(&:to_s)

          pid = ProcessSpawner.run(
            nodes.first.fetch_identity.commands["remove"],
            wait: @options.wait,
            env: env,
            log_files: nodes.map(&:log_filepath)
          ) do |last_exit|
            node_objs.update_all(deployment_pid: nil, exit_status: last_exit, last_action: nil)

            node_objs.destroy_all if last_exit == 0
            if last_exit == 0 && @hunter && @remove_hunter_entry
              HunterCLI.remove_node(nodes.map(&:name).join(','))
            end
          end

          node_objs.update_all(deployment_pid: pid.to_i, last_action: 'remove')
        end


        unless @options.wait
          puts "The removal process has begun. Refer to `flight profile list` "\
               "or `flight profile view` for more details"
        end

        # If `--wait` isn't included, the subprocesses are daemonised, and Ruby
        # will have no child processes to wait for, so this call ends
        # immediately. If `--wait` is included, the subprocesses aren't
        # daemonised, so the terminal holds IO until the process is finished.
        Process.waitall
      end

      private

      Nodes = Struct.new(:nodes) do
        def update_all(**kwargs)
          nodes.map { |node| node.update(**kwargs) }
        end

        def destroy_all
          nodes.each { |node| node.delete }
        end
      end

      def ansible_log_dir
        @ansible_log_dir ||= File.join(
          Config.log_dir,
          'remove'
        )
      end

      def check_names_exist(names)
        not_found = names.select { |n| !Node.find(n)&.identity }
        if not_found.any?
          out = <<~OUT.chomp
          The following nodes either do not exist or do not have an identity applied to them:
          #{not_found.join("\n")}
          OUT
          raise out
        end
      end

      def check_nodes_removable(nodes)
        not_removable = nodes.select { |node| !node.fetch_identity&.removable? }
        if not_removable.any?
          out = <<~OUT.chomp
          The following nodes have an identity that doesn't currently support the `profile remove` command:
          #{not_removable.map(&:name).join("\n")}
          OUT
          raise out
        end
      end

      def check_nodes_not_busy(nodes)
        busy = nodes.select { |node| node.status != 'complete' }
        if busy.any?
          existing_string = <<~OUT.chomp
          The following nodes are either in a failed process state
          or are currently undergoing a remove/apply process:
          #{busy.map(&:name).join("\n")}
          OUT

          if @options.force
            say_warning existing_string + "\nContinuing..."
            pids = busy.map(&:deployment_pid).compact
            pids.each { |pid| Process.kill("HUP", pid) }
          else
            raise existing_string
          end
        end
      end

      def collect_answers(questions, answers, parent_answer = nil)
        {
          'answers' => {},
          'missing_questions' => []
        }.tap do |collection|
          questions.each do |question|
            next unless parent_answer.nil? || parent_answer == question.where
            if !answers[question.id].nil?
              collection['answers'][question.env] = answers[question.id]
            else
              collection['missing_questions'] << smart_downcase(question.text.delete(':'))
            end
            # collect the answers to the child questions
            if question.questions
              child_collection = collect_answers(question.questions, answers, answers[question.id])
              collection['answers'].merge!(child_collection['answers'])
              collection['missing_questions'].concat(child_collection['missing_questions'])
            end
          end
        end
      end
    end
  end
end
