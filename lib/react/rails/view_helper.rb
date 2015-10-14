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
      # If passing in the need to update a store, or if an XHR request,
      # we render additional JavaScript
      def react_component(component_name:, props: {}, options: {}, store_update_calls: "", &block)
        if store_update_calls.present? && !store_update_calls.html_safe?
          raise ArgumentError
        end
        initialization_js_tags = ''.html_safe
        if store_update_calls.present? || (request && request.xhr?)
          initialization_js_tags = init_js_tags(
                                      component_name: component_name,
                                      props: props,
                                      options: options,
                                      store_update_calls: store_update_calls)
        end
        options = {:tag => options} if options.is_a?(Symbol)
        block = Proc.new{concat React::Renderer.render(component_name, props)} if options[:prerender]

        html_options = options.reverse_merge(:data => {})
        html_options[:data].tap do |data|
          data[:react_class] = component_name
          data[:react_props] = React::Renderer.react_props(props) unless props.empty?
        end
        html_tag = html_options[:tag] || :div

        # remove internally used properties so they aren't rendered to DOM
        html_options.except!(:tag, :prerender)

        initialization_js_tags + content_tag(html_tag, '', html_options, &block)
      end

      private

      #
      def init_js_tags(component_name:, props: {}, options: {}, store_update_calls: "")
        if store_update_calls.present? && !store_update_calls.html_safe?
          raise ArgumentError
        end
        js_tag_rendering_component = ''.html_safe
        js_tag_updating_store = ''.html_safe
        rand_id = "react#{rand(100000000)}"
        options[:id] ||= rand_id

        # If it's an XHR request, we need to generate javascript to mount
        # the component when the request is returned to the client.
        if request.xhr?
          js_rendering_component = <<-END
            React.render(React.createElement(eval.call(window, "#{component_name}"),
                                               #{props.to_json}),
                                               document.getElementById("#{rand_id}"));
          END

          if options[:prerender]
            ::React::JavascriptContext.current.push(js_rendering_component)
          else
            js_tag_rendering_component = javascript_tag js_rendering_component.html_safe
          end
        end

        # Generate javascript to update stores with data provided
        if options[:prerender]
          js_tag_updating_store = react_javascript do
            store_update_calls
          end
        else
          js_tag_updating_store = javascript_tag do
            store_update_calls
          end
        end

        # Return tags to update the store and render components
        js_tag_updating_store + js_tag_rendering_component
      end
    end
  end
end
