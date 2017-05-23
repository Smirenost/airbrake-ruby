module Airbrake
  module Filters
    ##
    # Attaches thread & fiber local variables along with general thread
    # information.
    class ThreadFilter
      ##
      # @return [Integer]
      attr_reader :weight

      ##
      # @return [Array<Class>] the list of classes that can be safely converted
      #   to JSON
      SAFE_CLASSES = [
        NilClass,
        TrueClass,
        FalseClass,
        String,
        Symbol,
        Regexp,
        Numeric
      ].freeze

      def initialize
        @weight = 110
      end

      def call(notice)
        th = Thread.current
        thread_info = {}

        if (vars = thread_variables(th)).any?
          thread_info[:thread_variables] = vars
        end

        if (vars = fiber_variables(th)).any?
          thread_info[:fiber_variables] = vars
        end

        # Present in Ruby 2.3+.
        if th.respond_to?(:name) && (name = th.name)
          thread_info[:name] = name
        end

        add_thread_info(th, thread_info)

        notice[:params][:thread] = thread_info
      end

      private

      def thread_variables(th)
        th.thread_variables.map.with_object({}) do |var, h|
          h[var] = sanitize_value(th.thread_variable_get(var))
        end
      end

      def fiber_variables(th)
        th.keys.map.with_object({}) do |key, h|
          h[key] = sanitize_value(th[key])
        end
      end

      def add_thread_info(th, thread_info)
        thread_info[:self] = th.inspect
        thread_info[:group] = th.group.list.map(&:inspect)
        thread_info[:priority] = th.priority

        thread_info[:safe_level] = th.safe_level unless Airbrake::JRUBY
      end

      def sanitize_value(value)
        return value if SAFE_CLASSES.any? { |klass| value.is_a?(klass) }

        case value
        when Array
          value = value.map { |elem| sanitize_value(elem) }
        when Hash
          Hash[value.map { |k, v| [k, sanitize_value(v)] }]
        else
          value.to_s
        end
      end
    end
  end
end