require 'masamune/has_context'

# Separate context for test harness itself
module MasamuneExampleGroup
  include Masamune::HasContext
  extend self

  def self.included(base)
    base.before(:all) do
      self.filesystem.context = self.context = MasamuneExampleGroup.context
      Thor.send(:include, Masamune::ThorMute)
    end
  end
end