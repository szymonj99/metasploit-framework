# -*- coding: binary -*-

# When Reline has been used by default for a while, we can delete this implementation.

module Rex
module Ui
module Text

  class Input::ImplReadline < Rex::Ui::Text::Input
    def initialize(tab_complete_proc = nil, **args)
      super()
      require 'readline' unless defined?(::Readline)

      self.extend(::Readline)

      if tab_complete_proc
        ::Readline.basic_word_break_characters = ""
        @rl_saved_proc = with_error_handling(tab_complete_proc)
        ::Readline.completion_proc = @rl_saved_proc
      end
    end

    def reset_tab_completion(tab_complete_proc = nil)
      ::Readline.basic_word_break_characters = "\x00"
      ::Readline.completion_proc = tab_complete_proc ? with_error_handling(tab_complete_proc) : @rl_saved_proc
    end


    #
    # Retrieve the line buffer
    #
    def line_buffer
      defined?(::RbReadline) ? ::RbReadline.rl_line_buffer : ::Readline.line_buffer
    end

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

    #
    # Stick readline into a low-priority thread so that the scheduler doesn't slow
    # down other background threads. This is important when there are many active
    # background jobs, such as when the user is running Karmetasploit
    #
    def pgets

      line = nil
      orig = Thread.current.priority

      begin
        Thread.current.priority = -20

        output.prompting
        line = readline_with_output(prompt, true)
        ::Readline::HISTORY.pop if (line and line.empty?)
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

    def readline_with_output(prompt, add_history=false)
      # rb-readlines's Readline.readline hardcodes the input and output to
      # $stdin and $stdout, which means setting `Readline.input` or
      # `Readline.output` has no effect when running `Readline.readline` with
      # rb-readline, so need to reimplement
      # []`Readline.readline`](https://github.com/luislavena/rb-readline/blob/ce4908dae45dbcae90a6e42e3710b8c3a1f2cd64/lib/readline.rb#L36-L58)
      # for rb-readline to support setting input and output.  Output needs to
      # be set so that colorization works for the prompt on Windows.

      input_on_entry = ::RbReadline.rl_instream
      output_on_entry = ::RbReadline.rl_outstream

      begin
        # ::RbReadline.rl_instream = opts[:fd]
        # ::RbReadline.rl_outstream = opts[:output]
        line = ::RbReadline.readline(prompt.to_s)
      rescue ::StandardError => e
        ::RbReadline.rl_instream = input_on_entry
        ::RbReadline.rl_outstream = output_on_entry
        ::RbReadline.rl_cleanup_after_signal
        ::RbReadline.rl_deprep_terminal

        raise e
      end

      if add_history && line && !line.start_with?(' ')
        # Don't add duplicate lines to history
        if ::Readline::HISTORY.empty? || line.strip != ::Readline::HISTORY[-1]
          ::RbReadline.add_history(line.strip)
        end
      end

      line
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
