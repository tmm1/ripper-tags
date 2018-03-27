#
# Note: This file is from devise. It was encountered in the wild and was causing
# a crash in ripper-tags. I attempted to leave only the bits that seemed to
# cause the crash.
#
# devise/lib/generators/active_record/templates/migration_existing.rb
#

class SomeClass<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def self.up
    change_table :<%= table_name %>
    # <%= table_name %>
  end

  def self.down
  end
end
