# -*- coding: binary -*-

module Rex
module Ui
module Text
  ###
  #
  # This class implements standard input using readline against
  # standard input.  It supports tab completion.
  #
  ###
  class Input::Readline

    #
    # Initializes the readline-aware Input instance for text.
    #
    def initialize(tab_complete_proc = nil, **opts)
      create_impl(tab_complete_proc, **opts)
      load_methods
    end

    private

    attr_accessor :impl

    def create_impl(tab_complete_proc = nil, **opts)
      if opts[:use_reline]
        puts 'using reline'
        require_relative 'impl_reline' unless defined?(ImplReline)
        @impl = Rex::Ui::Text::Input::ImplReline.new(tab_complete_proc, **opts)
      else
        puts 'using readline'
        require_relative 'impl_readline' unless defined?(ImplReadline)
        @impl = Rex::Ui::Text::Input::ImplReadline.new(tab_complete_proc, **opts)
      end
    end

    def load_methods
      (@impl.public_methods - self.class.instance_methods).each do |method_name|
        define_singleton_method(method_name) do |*args, &block|
          @impl.send(method_name, *args, &block)
        end
      end
    end
  end
end
end
end
