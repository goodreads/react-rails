require_relative '../javascript_context'

module React
  module Rails
    module ViewHelper

      def react_javascript(&block)
        script_contents = capture(&block)
        ::React::JavascriptContext.current.push(script_contents)
        javascript_tag script_contents
      end

      # Render a UJS-type HTML tag annotated with data attributes, which
      # are used by react_ujs to actually instantiate the React component
      # on the client.
      #
      def react_component(name, args = {}, options = {}, &block)
        options = {:tag => options} if options.is_a?(Symbol)
        block = Proc.new{concat React::Renderer.render(name, args)} if options[:prerender]

        html_options = options.reverse_merge(:data => {})
        html_options[:data].tap do |data|
          data[:react_class] = name
          data[:react_props] = React::Renderer.react_props(args) unless args.empty?
        end
        html_tag = html_options[:tag] || :div

        # remove internally used properties so they aren't rendered to DOM
        html_options.except!(:tag, :prerender)

        content_tag(html_tag, '', html_options, &block)
      end

      # At the same time as rendering a react component, initialize data
      # in one or more stores. This is to be used in views that can return
      # not-yet-rendered React Components from the server via AJAX.
      # Since the process to mount React components only runs on page load,
      # any components loaded after that must be mounted manually.
      def react_component_with_stores(component_name:, props: {}, options: {}, storeUpdateCalls: [], &block)
        javascript_for_updating_stores = ''.html_safe
        render_javascript_tag = ''.html_safe
        store_javascript_tag = ''.html_safe
        randId = "i#{rand(100000000)}"
        options[:id] ||= randId

        # If it's an XHR request, we need to generate javascript to mount
        # the component when the request is returned to the client.
        if request.xhr?
          javascript_for_rendering = <<-END
            React.render(React.createElement(eval.call(window, '#{component_name}'),
                                               #{props.to_json}),
                                               document.getElementById('#{randId}'));
          END

          if options[:prerender]
            ::React::JavascriptContext.current.push(javascript_for_rendering.html_safe)
          else
            render_javascript_tag = javascript_tag javascript_for_rendering.html_safe
          end
        end

        # Generate javascript to update stores with data provided
        storeUpdateCalls = storeUpdateCalls.is_a?(Array) ? storeUpdateCalls : [storeUpdateCalls]
        javascript_for_updating_stores = storeUpdateCalls.map do |storeUpdateCall|
          "#{storeUpdateCall}".html_safe
        end.join
        if options[:prerender]
          store_javascript_tag = react_javascript do
            javascript_for_updating_stores.html_safe
          end
        else
          store_javascript_tag = javascript_tag do
            javascript_for_updating_stores.html_safe
          end
        end

        # Return string with store and rendering JS and component itself
        "#{store_javascript_tag}\n#{render_javascript_tag}\n#{react_component(component_name, props, options, &block)}".html_safe
      end
    end
  end
end
