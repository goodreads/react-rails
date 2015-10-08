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

      def react_component_and_stores(name, args = {}, options = {}, stores = [], &block)
        react_store_javascript = ''.html_safe
        randId = "i#{rand(100000000)}"
        options[:id] = randId
        stores.each do |store|
          react_store_javascript <<
            "ReactStores.#{store[:storeName]}.updateWith(#{store[:updateData].to_json});".html_safe
        end
        script_tag = react_javascript do
          react_store_javascript + "setTimeout(function() { React.render(React.createElement(eval.call(window, #{name}), #{args.to_json}), document.getElementById('#{randId}')); });".html_safe
        end
        final_output = script_tag + react_component(name, args, options, &block)
        final_output
      end
    end
  end
end
