require 'connection_pool'
require_relative 'javascript_context'

module React
  class Renderer

    class PrerenderError < RuntimeError
      def initialize(component_name, props, js_message)
        message = "Encountered error \"#{js_message}\" when prerendering #{component_name} with #{props}"
        super(message)
      end
    end

    cattr_accessor :pool

    def self.setup!(react_js, components_js, args={})
      args.assert_valid_keys(:size, :timeout)
      @@react_js = react_js
      @@components_js = components_js
      @@pool.shutdown{} if @@pool
      reset_combined_js!
      default_pool_options = {:size =>10, :timeout => 20}
      @@pool = ConnectionPool.new(default_pool_options.merge(args)) { self.new }
    end

    def self.render(component, args={})
      unless React::JavascriptContext.current.renderer
        duration = Benchmark.ms do
          React::JavascriptContext.current.renderer = @@pool.checkout
        end
        ::Rails.logger.info "[React-SSR]: @@pool.checkout took #{duration}ms" if duration > 1.0
      end
      React::JavascriptContext.current.renderer.render(component, args)
    end

    def self.reset!
      renderer = nil
      duration = Benchmark.ms do
        if renderer = React::JavascriptContext.current.renderer
          React::JavascriptContext.reset!
          renderer.reload_context!
          @@pool.checkin # the pool keeps a stack of checked-out objects per-thread
        end
      end
      ::Rails.logger.info "[React-SSR]: #{renderer}.reset! took #{duration}ms" if duration > 1.0
    end

    def self.react_props(args={})
      if args.is_a? String
        args
      else
        args.to_json
      end
    end

    def reload_context!
      duration = Benchmark.ms do
        @context = ExecJS.compile(self.class.combined_js)
      end
      ::Rails.logger.info "[React-SSR]: ExecJS compile took #{duration}ms"
    end

    def context
      reload_context! unless @context
      @context
    end

    def render(component, args={})
      react_props = React::Renderer.react_props(args)
      jscode = <<-JS
        function() {
          #{React::JavascriptContext.current.pop_all}
          return React.renderToString(React.createElement(#{component}, #{react_props}));
        }()
      JS
      output = nil
      duration = Benchmark.ms do
        output = context.eval(jscode).html_safe
      end
      ::Rails.logger.info "[React-SSR]: context.eval(jscode) took #{duration}ms"
      output
    rescue ExecJS::ProgramError => e
      raise PrerenderError.new(component, react_props, e)
    end


    private

    def self.setup_combined_js
      <<-CODE
        var global = global || this;
        var self = self || this;
        var window = window || this;

        var console = global.console || {};
        ['error', 'log', 'info', 'warn'].forEach(function (fn) {
          if (!(fn in console)) {
            console[fn] = function () {};
          }
        });

        #{@@react_js.call};
        React = global.React;
        #{@@components_js.call};
      CODE
    end

    def self.reset_combined_js!
      @@combined_js = setup_combined_js
    end

    def self.combined_js
      @@combined_js
    end

  end
end
