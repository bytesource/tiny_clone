require 'sequel'
require_relative 'connection'
# http://stackoverflow.com/questions/3795513/ruby-require-file-doesnt-work-but-require-file-does-why
# http://geek4eva.com/2011/08/01/current-directory-removed-from-load_path-in-ruby-1-9-2/

# Creating Tables
# http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html
# ---------------------------------

# create_table    Creates table, using the column information from set_schema.
# create_table!   Drops the table if it exists and then runs create_table.
#                 Should probably not be used except in testing.
# create_table?   CREATE TABLE IF NOT EXISTS
# http://sequel.rubyforge.org/rdoc-plugins/classes/Sequel/Plugins/Schema/ClassMethods.html

# NOTE: parent table 'links' has to be the first as the following tables reference its
#       primary key.
#       Likewise, drop table links using 'cascade': drop table links cascade;
DB.create_table? :links do
  String      :short,      :primary_key => true
  DateTime    :created_at, :null => false        # 1)
end

# 1)
# NOTE: default time stamp can be added using the respective database specific function with 'lit':
#       :default => (function).lit
#       https://groups.google.com/d/topic/sequel-talk/wO9zH0Gcz6g/discussion

DB.create_table? :urls do
  primary_key :id
  String      :original, :size => 255, :unique => true, :null => false
  # foreign_key is integer by default, but here refers to a string.
  # http://sequel.rubyforge.org/rdoc/classes/Sequel/Schema/Generator.html#method-i-foreign_key
  foreign_key :link_short, :links, :type => String, :on_delete => :cascade     # 2)
end



# Holds foreign key to :short
DB.create_table? :visits do
  primary_key :id
  inet        :ip,         :null => false
  String      :country,    :size => 255
  DateTime    :created_at, :null => false
  foreign_key :link_short, :links, :type => String, :on_delete => :cascade       # 2)
end

# 2)
# :null => false does not work with associations, because when using associtations,
# the foreign key is added only after the row has been saved (using an UPDATE statement).

# CREATE TABLE "links"
# ("short" text PRIMARY KEY, "created_at" timestamp)
#  CREATE TABLE "urls"
# ("id" serial PRIMARY KEY, "original" varchar(255) UNIQUE,
#  "link_short" text REFERENCES "links" ON DELETE CASCADE)
# CREATE TABLE "visits"
# ("id" serial PRIMARY KEY, "ip" inet, "country" varchar(255),
#  "created_at" timestamp, "link_short" text REFERENCES "links" ON DELETE CASCADE)

