#
# This ERB file causes a ripper crash in Ruby > 2.3.
#

class SomeClass<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def self.up
    change_table :<%= table_name %>
    # <%= table_name %>
  end

  def self.down
  end
end
