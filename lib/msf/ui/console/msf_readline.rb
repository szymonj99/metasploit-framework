#
# This class is responsible for handling Readline/Reline-agnostic user input.
#

class Msf::Ui::Console::MsfReadline

  # Required to check the Reline flag.
  require 'msf/core/feature_manager'
  require 'rex/ui/text/input/readline'
  require 'rex/ui/text/input/reline'

  attr_reader :input_impl

  def initialize(tab_complete_proc)
    @cached_config = {}
    @input_impl = input_impl_klass.new(tab_complete_proc)
  end

  def method_missing(sym, *args, &block)
    if @input_impl.respond_to?(sym)
      @input_impl.send(sym, *args, &block)
    else
      msg = "Method '#{sym}' not found in #{@input_impl.class}"
      elog(msg)
      raise ::NoMethodError, msg
    end
  end

  def cache_current_config
    if needs_saving_config?
      @current_config[:autocompletion] = ::Reline.autocompletion
      @current_config[:core] = ::Reline.core.dup
    end
  end

  def restore_cached_config
    if needs_restoring_config?
      ::Reline.autocompletion = @current_config[:autocompletion] if @current_config.has_key?(:autocompletion)
      ::Reline.instance_variable_set(:@core, @current_config[:core]) if @current_config.has_key?(:core)
    end
  end

  private

  attr_writer :input_impl
  attr_accessor :cached_config

  def input_impl_klass
    @input_impl ||= Msf::FeatureManager.instance.enabled?(Msf::FeatureManager::USE_RELINE) ? ::Rex::Ui::Text::Input::Reline : ::Rex::Ui::Text::Input::Readline
  end

  def needs_saving_config?
    input_impl_klass == ::Rex::Ui::Text::Input::Reline
  end

  def needs_restoring_config?
    needs_saving_config?
  end
end
