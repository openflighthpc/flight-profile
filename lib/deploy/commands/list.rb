require_relative '../command'
require_relative '../config'
require_relative '../table'
require_relative '../node'
module Deploy
  module Commands
    class List < Command
      def run
        t = Table.new
        t.headers('Node', 'Profile', 'Status')
        Node.all.each do |node|
          t.row( node.hostname, node.profile, node.deployment_pid )
        end
        t.emit
      end
    end
  end
end
