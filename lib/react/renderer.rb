require 'connection_pool'
require_relative 'javascript_context'

module React
  class Renderer

    class PrerenderError < RuntimeError
      def initialize(component_name, props, js_message)
        message = ["Encountered error \"#{js_message}\" when prerendering #{component_name} with #{props}",
                    js_message.backtrace.join("\n")].join("\n")
        super(message)
      end
    end

    cattr_accessor :pool

    def self.setup!(react_js, components_js, replay_console, args={})
      args.assert_valid_keys(:size, :timeout)
      @@react_js = react_js
      @@components_js = components_js
      @@replay_console = replay_console
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
      end
      React::JavascriptContext.current.renderer.render(component, args)
    end

    def self.reset!
      renderer = nil
      duration = Benchmark.ms do
        if renderer = React::JavascriptContext.current.renderer
          React::JavascriptContext.reset!
          Thread.new do
            if ::Rails.env.development?
              self.reset_combined_js!
              self.write_combined_js_to_file_for_debugging
            end
            duration = Benchmark.ms do
              renderer.reload_context!
            end
            ::Rails.logger.info "[React-SSR]: reloading javascript context took #{duration}ms"
            @@pool.checkin # the pool keeps a stack of checked-out objects per-thread
          end
        end
      end
    end

    def self.react_props(args={})
      if args.is_a? String
        args
      else
        args.to_json
      end
    end

    def reload_context!
      @context = ExecJS.compile(self.class.combined_js)
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
          var result = React.renderToString(React.createElement(#{component}, #{react_props}));
          #{@@replay_console ? React::Console.replay_as_script_js : ''}
          return result;
        }()
      JS
      output = nil
      duration = Benchmark.ms do
        output = context.eval(jscode).html_safe
      end
      ::Rails.logger.info "[React-SSR]: rendering #{component} took #{duration}ms"
      output
    rescue ExecJS::ProgramError => e
      raise PrerenderError.new(component, react_props, e)
    end


    private

    def self.setup_combined_js
      <<-JS
        var global = global || this;
        var self = self || this;
        var window = window || this;
        #{React::Console.polyfill_js}
        #{@@react_js.call};
        React = global.React;
        #{@@components_js.call};
      JS
    end

    def self.reset_combined_js!
      @@combined_js = setup_combined_js
    end

    def self.write_combined_js_to_file_for_debugging
      File.open(::Rails.root.join('tmp', 'ssr-react.js'), 'w') do |file|
        file.write @@combined_js
      end
    end

    def self.combined_js
      @@combined_js
    end

  end
end
