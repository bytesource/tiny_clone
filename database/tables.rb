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
# =>    primary key.
DB.create_table? :links do 
  String      :short, :primary_key => true 
  DateTime    :created_at
end

DB.create_table? :urls do 
  primary_key :id
  String      :original, :size => 255, :unique => true
  # foreign_key is integer by default, but here refers to a string.
  foreign_key :link_short, :links, :type => String, :on_delete => :cascade 
end

# Holds foreign key to :short
DB.create_table? :visits do
  primary_key :id
  inet        :ip
  String      :country, :size => 255
  DateTime    :created_at
  foreign_key :link_short, :links, :type => String, :on_delete => :cascade
end

# CREATE TABLE "links" 
# ("short" text PRIMARY KEY, "created_at" timestamp)
#  CREATE TABLE "urls" 
# ("id" serial PRIMARY KEY, "original" varchar(255) UNIQUE, 
#  "link_short" text REFERENCES "links" ON DELETE CASCADE)
# CREATE TABLE "visits" 
# ("id" serial PRIMARY KEY, "ip" inet, "country" varchar(255), 
#  "created_at" timestamp, "link_short" text REFERENCES "links" ON DELETE CASCADE)

