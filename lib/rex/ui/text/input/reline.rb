# -*- coding: binary -*-

module Rex
module Ui
module Text

  ###
  #
  # This class implements standard input using Reline against
  # standard input.  It supports tab completion.
  #
  ###
  class Input::Reline < Rex::Ui::Text::Input

    #
    # Initializes the readline-aware Input instance for text.
    #
    def initialize(tab_complete_proc = nil)
      super()
      if(not Object.const_defined?('Reline'))
        require 'reline'
      end

      self.extend(::Reline)

      if tab_complete_proc
        ::Reline.basic_word_break_characters = ""
        @rl_saved_proc = with_error_handling(tab_complete_proc)
        ::Reline.completion_proc = @rl_saved_proc
      end

      @current_config = {}
    end

    #
    # Reattach the original completion proc
    #
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

    attr_accessor :prompt

    #
    # Whether or not the input medium supports readline.
    #
    def supports_readline
      true
    end

    #
    # Calls sysread on the standard input handle.
    #
    def sysread(len = 1)
      begin
        self.fd.sysread(len)
      rescue ::Errno::EINTR
        retry
      end
    end

    #
    # Read a line from stdin
    #
    def gets()
      begin
        self.fd.gets()
      rescue ::Errno::EINTR
        retry
      end
    end

    def cache_current_config
      @current_config = { autocompletion: ::Reline.autocompletion, core: ::Reline.core.dup }
    end

    def restore_saved_config
      ::Reline.instance_variable_set(:@core, @current_config[:core]) if @current_config.has_key?(:core)
      ::Reline.autocompletion = @current_config[:autocompletion] if @current_config.has_key?(:autocompletion)
    end

    #
    # Stick Reline into a low-priority thread so that the scheduler doesn't slow
    # down other background threads. This is important when there are many active
    # background jobs, such as when the user is running Karmetasploit
    #
    def pgets
      orig = Thread.current.priority

      begin
        Thread.current.priority = -20

        output.prompting

        # IRB changes propagate out of the context of IRB. We store the current state and restore it on exit.
        # TODO: Once IRB fixes this behaviour, we should be able to remove this patch.

        cache_current_config
        line = ::Reline.readline(prompt, true)
      ensure
        Thread.current.priority = orig || 0
        output.prompting(false)
      end

      line
    end

    #
    # Returns the output pipe handle
    #
    def fd
      $stdin
    end

    #
    # Indicates that this input medium as a shell builtin, no need
    # to extend.
    #
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

    private

    def duplicate_line?(line)
      ::Reline::HISTORY.length > 1 && line == ::Reline::HISTORY[-2]
    end

    def readline_with_output(prompt, add_history=false)
      self.prompt = prompt

      line = ::Reline.readline(prompt, add_history)

      # Don't add duplicate lines to history
      ::Reline::HISTORY.pop if duplicate_line?(line)

      line
    end

    private

    def with_error_handling(proc)
      proc do |*args|
        proc.call(*args)
      rescue StandardError => e
        elog("tab_complete_proc has failed with args #{args}", error: e)
        []
      end
    end

  end

end
end
end
