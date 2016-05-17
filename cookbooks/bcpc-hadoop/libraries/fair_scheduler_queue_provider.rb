class Chef
  class Provider
    #
    # This is a dummy provider.
    #
    # The actual work is done in the bcpc-hadoop yarn_schedulers
    # recipe. All the fair scheduler queue resources are passed
    # via lazy evaluator to the yarn/fair-scheduler.xml.erb
    # template.
    #
    class BcpcHadoopFairSchedulerQueue < Chef::Provider
      def load_current_resource
        name = new_resource.name

        @current_resource ||=
          Chef::Resource::BcpcHadoopFairSchedulerQueue.new(name)

        @current_resource
      end

      def action_create
        true
      end
    end
  end
end
