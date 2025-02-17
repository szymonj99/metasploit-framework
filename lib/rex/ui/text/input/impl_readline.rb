# -*- coding: binary -*-

# When Reline has been used by default for a while, we can delete this implementation.

module Rex
module Ui
module Text

  class Input::ImplReadline < Rex::Ui::Text::Input

    require_relative 'common_readline_impl' unless defined?(CommonReadlineImpl)
    include CommonReadlineImpl

    def initialize(tab_complete_proc = nil, **args)
      super()
      require 'readline' unless defined?(::Readline)

      self.extend(::Readline)

      if tab_complete_proc
        ::Readline.basic_word_break_characters = ""
        @rl_saved_proc = with_error_handling(tab_complete_proc)
        ::Readline.completion_proc = @rl_saved_proc
      end

      self.fd = args[:fd] || $stdin
      self.output = args[:output] || $stdout
    end

    def reset_tab_completion(tab_complete_proc = nil)
      ::Readline.basic_word_break_characters = "\x00"
      ::Readline.completion_proc = tab_complete_proc ? with_error_handling(tab_complete_proc) : @rl_saved_proc
    end


    #
    # Retrieve the line buffer
    #
    def line_buffer
      ::Readline.line_buffer
    end

    #
    # Stick readline into a low-priority thread so that the scheduler doesn't slow
    # down other background threads. This is important when there are many active
    # background jobs, such as when the user is running Karmetasploit
    #
    def pgets
      original_priority = Thread.current.priority

      begin
        Thread.current.priority = -20
        output.prompting
        line = readline_with_output(prompt.to_s, add_history: true)
      ensure
        Thread.current.priority = original_priority || 0
        output.prompting(false)
      end

      line
    end

    # This closely matches Readline's readline method definition.
    def readline_with_output(prompt, **args)
      input_on_entry = ::RbReadline.rl_instream
      output_on_entry = ::RbReadline.rl_outstream
      
      begin
        ::RbReadline.rl_instream = args[:fd] if args[:fd]
        ::RbReadline.rl_outstream = args[:output] if args[:output]
        line = ::RbReadline.readline(prompt)
      rescue ::StandardError => e
        ::RbReadline.rl_instream = input_on_entry
        ::RbReadline.rl_outstream = output_on_entry
        handle_signal

        raise e
      end

      add_to_history(line) if args[:add_history]
      line
    end

    def handle_signal
      ::RbReadline.rl_cleanup_after_signal
      ::RbReadline.rl_deprep_terminal
    end

    def add_to_history(line)
      return if line&.empty?

      # Don't add duplicate lines to history
      ::Readline::HISTORY << line unless line == ::Readline::HISTORY[-1]
    end

    def clear_history
      ::Readline::HISTORY.pop until ::Readline::HISTORY.empty?
    end

  end

end
end
end
