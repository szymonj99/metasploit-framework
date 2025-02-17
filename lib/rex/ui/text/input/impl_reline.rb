# -*- coding: binary -*-

module Rex
module Ui
module Text

  class Input::ImplReline < Rex::Ui::Text::Input

    require_relative 'common_readline_impl' unless defined?(CommonReadlineImpl)
    include CommonReadlineImpl

    def initialize(tab_complete_proc = nil, **args)
      super()
      require 'reline' unless defined?(::Reline)

      self.extend(::Reline)

      if tab_complete_proc
        ::Reline.basic_word_break_characters = ""
        @rl_saved_proc = with_error_handling(tab_complete_proc)
        ::Reline.completion_proc = @rl_saved_proc
      end

      self.fd = args[:fd] || $stdin
      # puts "On initialise args output: #{args[:output].inspect}"
      self.output = args[:output] || $stdout
    end

    def reset_tab_completion(tab_complete_proc = nil)
      ::Reline.basic_word_break_characters = "\x00"
      ::Reline.completion_proc = tab_complete_proc ? with_error_handling(tab_complete_proc) : @rl_saved_proc
    end

    #
    # Retrieve the line buffer
    #
    def line_buffer
      ::Reline.line_buffer
    end

    def pgets

      line = nil
      orig = Thread.current.priority

      begin
        Thread.current.priority = -20

        output.prompting
        line = reline_with_output(prompt, add_history: true, fd: fd, output: output)
      ensure
        Thread.current.priority = orig || 0
        output.prompting(false)
      end

      line
    end

    def reline_with_output(prompt, **args)
      # These are raw IO descriptors. e.g. #<IO:<STDIN>>
      input_on_entry = ::Reline::IOGate.instance_variable_get(:@input)
      output_on_entry = Reline.core.instance_variable_get(:@output)

      begin
        # TODO: Currently we can't paste in non-ASCII chars. The code below fixes that but breaks out rab completion due
        # to encoding issues.
        # input_external_encoding = opts[:fd].external_encoding
        # input_internal_encoding = opts[:fd].internal_encoding
        # opts[:fd].set_encoding(::Encoding::UTF_8)
        # Our args can contain an fd that's either a Rex object, or a raw IO descriptor. Abstract that away.

        ::Reline.input = from_arg(args, :fd)
        ::Reline.output = from_arg(args, :output)
        line = ::Reline.readline(prompt.to_s, args[:add_history] || false)
      ensure
        # opts[:fd].set_encoding(input_external_encoding, input_internal_encoding)
        ::Reline.input = input_on_entry
        ::Reline.output = output_on_entry
      end

      # Don't add duplicate lines to history
      remove_from_history if duplicate_line?(line)

      line
    end

    def from_arg(args, sym)
      return nil unless args[sym]

      args[sym].respond_to?(:fd) ? args[sym].fd : args[sym]
    end

    def duplicate_line?(line)
      return unless line

      ::Reline::HISTORY.length > 1 && line == ::Reline::HISTORY[-1]
    end

    def remove_from_history
      ::Reline::HISTORY.pop
    end

    def clear_history
      return if ::Reline::HISTORY.empty?

      ::Reline::HISTORY.clear
    end

  end

end
end
end
