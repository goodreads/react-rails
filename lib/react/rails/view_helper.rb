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
      # This forked version supports an additional option, :store_init_js
      #
      # options[:store_init_js]
      #  A string of html_safe javascript that will be included both in
      #  a server-side render and in the browser. It should initialize any
      #  stores upon which this component depends.
      def react_component(name, props={}, options={}, &block)
        options = {:tag => options} if options.is_a?(Symbol)
        store_init_js = options.delete(:store_init_js)
        if store_init_js.present? && !store_init_js.html_safe?
          raise ArgumentError("options[:store_init_js] must be marked html_safe")
        end
        initialization_js_tags = ''.html_safe
        if store_init_js.present? || (request && request.xhr?)
          initialization_js_tags = init_js_tags(
                                      name: name,
                                      props: props,
                                      options: options,
                                      store_init_js: store_init_js)
        end
        block = Proc.new{concat React::Renderer.render(name, props)} if options[:prerender]

        html_options = options.reverse_merge(:data => {})
        html_options[:data].tap do |data|
          data[:react_class] = name
          data[:react_props] = React::Renderer.react_props(props) unless props.empty?
        end
        html_tag = html_options[:tag] || :div

        # remove internally used properties so they aren't rendered to DOM
        html_options.except!(:tag, :prerender, :store_init_js)

        initialization_js_tags + content_tag(html_tag, '', html_options, &block)
      end

      private

      def init_js_tags(name:, props:, options:, store_init_js:)
        js_tag_rendering_component = ''.html_safe
        js_tag_updating_store = ''.html_safe
        rand_id = "react#{rand(100000000)}"
        options[:id] ||= rand_id

        # If it's an XHR request, we need to generate javascript to mount
        # the component when the request is returned to the client.
        if request.xhr?
          js_rendering_component = <<-END
            React.render(React.createElement(eval.call(window, "#{name}"),
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
            store_init_js
          end
        else
          js_tag_updating_store = javascript_tag do
            store_init_js
          end
        end

        # Return tags to update the store and render components
        js_tag_updating_store + js_tag_rendering_component
      end
    end
  end
end
