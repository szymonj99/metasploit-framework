module Rex
module Ui
module Text
  module Input::CommonReadlineImpl
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

    def intrinsic_shell?
      true
    end

    attr_accessor :fd

    #
    # The prompt that is to be displayed.
    #
    attr_accessor :prompt
    #
    # The output handle to use when displaying the prompt.
    #
    attr_accessor :output

    private

    def with_error_handling(proc)
      proc do |*args|
        proc.call(*args)
      rescue ::StandardError => e
        elog("proc #{proc.inspect} has failed with args #{args}", error: e)
        []
      end
    end
  end
end
end
end
