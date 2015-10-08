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
      def react_component_and_stores(name, args = {}, options = {}, stores = [], &block)
        javascript_for_updating_stores = ''.html_safe
        randId = "i#{rand(100000000)}"
        options[:id] = randId
        stores.each do |store|
          javascript_for_updating_stores <<
            "ReactStores.#{store[:storeName]}.updateWith(#{store[:updateData]});".html_safe
        end
        # Whatever we pass into react_javascript must already be html_safed or
        # else it will be escaped. Wrap in async block.
        script_tag = react_javascript do
          javascript_for_rendering = <<-END
            setTimeout(function() {
              React.render(React.createElement(eval.call(window, #{name}),
                                               #{args.to_json}),
                                               document.getElementById('#{randId}'));
            });
          END
          javascript_for_updating_stores + javascript_for_rendering.html_safe
        end
        script_tag + react_component(name, args, options, &block)
      end
    end
  end
end
