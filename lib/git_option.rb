require 'option'
require 'i18n'

class GitOption < Option
  OPTION_NAMES = %w{
    changed_submodule_update changed_submodule_checkout
  }
  def self.option_names; OPTION_NAMES end
end
