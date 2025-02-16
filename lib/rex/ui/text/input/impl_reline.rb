# -*- coding: binary -*-

module Rex
module Ui
module Text

  class Input::ImplReline < Rex::Ui::Text::Input
    def initialize(tab_complete_proc = nil, **opts)
      super()
      require 'reline' unless defined?(::Reline)

      self.extend(::Reline)

      if tab_complete_proc
        ::Reline.basic_word_break_characters = ""
        @rl_saved_proc = with_error_handling(tab_complete_proc)
        ::Reline.completion_proc = @rl_saved_proc
      end

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

    def supports_readline
      true
    end

    def sysread(len = 1)
      begin
        self.fd.sysread(len)
      rescue ::Errno::EINTR
        retry
      end
    end

    def gets
      begin
        self.fd.gets
      rescue ::Errno::EINTR
        retry
      end
    end

    def pgets

      line = nil
      orig = Thread.current.priority

      begin
        Thread.current.priority = -20

        output.prompting
        line = reline_with_output(prompt, true)
      ensure
        Thread.current.priority = orig || 0
        output.prompting(false)
      end

      line
    end

    def fd
      $stdin
    end

    def intrinsic_shell?
      true
    end

    #
    # The prompt that is to be displayed.
    #
    attr_accessor :prompt
    #
    # The output handle to use when displaying the prompt.
    #
    attr_accessor :output

    def reline_with_output(prompt, add_history=false)
      input_on_entry = ::Reline::IOGate.instance_variable_get(:@input)
      output_on_entry = Reline::IOGate.instance_variable_get(:@output)

      begin
        # TODO: Currently we can't paste in non-ASCII chars. The code below fixes that but breaks out rab completion due
        # to encoding issues.
        # input_external_encoding = opts[:fd].external_encoding
        # input_internal_encoding = opts[:fd].internal_encoding
        # opts[:fd].set_encoding(::Encoding::UTF_8)
        # ::Reline.input = opts[:fd]
        # ::Reline.output = opts[:output]
        line = ::Reline.readline(prompt.to_s, add_history)
      ensure
        # opts[:fd].set_encoding(input_external_encoding, input_internal_encoding)
        ::Reline.input = input_on_entry
        ::Reline.output = output_on_entry
      end

      # Don't add duplicate lines to history
      if ::Reline::HISTORY.length > 1 && line == ::Reline::HISTORY[-2]
        ::Reline::HISTORY.pop
      end

      line.dup
    end

    private

    def with_error_handling(proc)
      proc do |*args|
        proc.call(*args)
      rescue StandardError => e
        elog("proc #{proc.inspect} has failed with args #{args}", error: e)
        []
      end
    end
  end

end
end
end
