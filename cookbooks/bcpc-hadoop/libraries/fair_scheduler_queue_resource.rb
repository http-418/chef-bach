require 'chef/resource'
class Chef
  class Resource
    # This is a Chef resource for defining Hadoop Fair Scheduler queues.
    class BcpcHadoopFairSchedulerQueue < Chef::Resource
      def initialize(name, run_context = nil)
        super
        @resource_name = :bcpc_hadoop_fair_scheduler_queue
        @provider = Chef::Provider::BcpcHadoopFairSchedulerQueue
        @action = :create
        @allowed_actions = [:create]

        @name = name

        #
        # The list of properties is defined in the Hadoop Fair
        # Scheduler documentation.  There's no XSL / XSD for
        # fair-scheduler.xml, only the documentation.
        #
        # For 2.7:
        # https://hadoop.apache.org/docs/r2.7.1/hadoop-yarn/hadoop-yarn-site/FairScheduler.html
        #
        @acl_administer_apps = nil
        @acl_submit_apps = nil
        @fair_share_preemption_timeout = 75
        @fair_share_preemption_threshold = nil
        @max_a_m_share = nil
        @max_resources = nil
        @max_running_apps = nil
        @min_resources = '256 mb,1vcores'
        @min_share_preemption_timeout = nil
        @scheduling_policy = nil
        @type = nil
        @weight = 0.5
      end

      def name(arg = nil)
        set_or_return(:name, arg, kind_of: String)
      end

      def acl_administer_apps(arg = nil)
        set_or_return(:acl_administer_apps, arg, kind_of: String)
      end

      def acl_submit_apps(arg = nil)
        set_or_return(:acl_submit_apps, arg, kind_of: String)
      end

      def fair_share_preemption_timeout(arg = nil)
        set_or_return(:fair_share_preemption_timeout, arg,
                      kind_of: [Integer, String])
      end

      def fair_share_preemption_threshold(arg = nil)
        set_or_return(:fair_share_preemption_threshold, arg,
                      kind_of: [Integer, String])
      end

      def max_a_m_share(arg = nil)
        set_or_return(:max_a_m_share, arg, kind_of: String)
      end

      def max_resources(arg = nil)
        set_or_return(:max_resources, arg, kind_of: String)
      end

      def max_running_apps(arg = nil)
        set_or_return(:max_running_apps, arg,
                      kind_of: [Integer, String])
      end

      def min_resources(arg = nil)
        set_or_return(:min_resources, arg, kind_of: String)
      end

      def min_share_preemption_timeout(arg = nil)
        set_or_return(:min_share_preemption_timeout, arg,
                      kind_of: [Integer, String])
      end

      def scheduling_policy(arg = nil)
        set_or_return(:scheduling_policy, arg, kind_of: String)
      end

      def type(arg = nil)
        set_or_return(:type, arg, kind_of: String)
      end

      def weight(arg = nil)
        set_or_return(:weight, arg,
                      kind_of: [Float, String])
      end

      def escaped_properties
        property_names =
          [
            'acl_administer_apps',
            'acl_submit_apps',
            'fair_share_preemption_timeout',
            'fair_share_preemption_threshold',
            'max_a_m_share',
            'max_resources',
            'max_running_apps',
            'min_resources',
            'min_share_preemption_timeout',
            'scheduling_policy',
            'weight'
          ]

        #
        # Rubocop hates functional programming, but this is unreadable
        # otherwise.
        #
        # rubocop:disable all
        property_names
          .map{ |name| { generate_xml_tag_name(name) =>
                         generate_xml_text(name) } }
          .reduce({}, :merge)
          .select { |_key, value| !value.nil? }
        # rubocop:enable all
      end

      private

      # Converts underscored strings to camelcase.
      # example: max_a_m_share => maxAMShare
      def generate_xml_tag_name(str = '')
        camel_case = str.to_s.split('_').map(&:capitalize).join
        camel_case[0] = camel_case[0].downcase if camel_case.length > 0
        camel_case
      end

      # Grab the named variable and encode its result for XML body text.
      # If value is nil, return nil.
      def generate_xml_text(name)
        value = instance_variable_get('@' + name.to_s)
        if value.nil?
          nil
        else
          value.to_s.encode(xml: :text)
        end
      end
    end
  end
end
