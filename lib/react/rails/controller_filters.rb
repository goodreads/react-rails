module React
  module Rails
    module ControllerFilters
      extend ::ActiveSupport::Concern

      included do
        around_action :with_resetting_react_javascript_context
      end

      def with_resetting_react_javascript_context
        begin
          yield
        ensure
          ::React::Renderer.reset!
        end
      end

    end
  end
end
