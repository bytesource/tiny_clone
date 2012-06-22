require_relative 'database/connection'
require_relative 'database/tables'  # for SQLite in-memory database 
require_relative 'database/associations'
require 'date'


puts "Generating short url:"
p rand(10 ** 12).to_s(36)
# => "e0xnaop"
# NOTE:
# Before fetching 'short' from database: downcase(input)


# Playing with dates
number_of_days = 10
day       = (60 * 60 * 24) # http://www.ruby-doc.org/core-1.9.3/Time.html#method-i-2B
from_date = Time.now - (number_of_days * day)
to_date   = Time.now

# Timestamps
# http://sequel.rubyforge.org/rdoc-plugins/classes/Sequel/Plugins/Timestamps.html


puts "Tesing Sequel methods"
puts '========================='

# http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#method-i-unrestrict_primary_key
Link.unrestrict_primary_key

DB.transaction do

  key = 'youtube'
  # link = Link.create(:short => key)    # :default => created_at_function.lit
  # [{:short=>"youtube", :created_at=>2012-06-17 16:08:30 +0800}]
  link = Link.create(:short => key, :created_at => Time.now)
  p DB[:links].all
  # [{:short=>"youtube", :created_at=>2012-06-17 16:06:51 +0800}]

  # #association= sets the relevant foreign key to be the same as the primary key of the other object
  link.url = Url.new(:original => 'http://www.sovonexxx.com') # Url object gets saved 1)
  # 1) Insert without foreign key
  # INSERT INTO "urls" ("original") VALUES ('http://www.sovonexxx.com') 
  # 2) Set foreign key to NULL
  # UPDATE "urls" SET "link_short" = NULL WHERE (("link_short" = 'youtube') AND ("id" != 1))
  # 3) Set foreign key to the correct value from the Links table
  # UPDATE "urls" SET "original" = 'http://www.sovonexxx.com', "link_short" = 'youtube' WHERE ("id" = 1)

  # NOTE on #association=
  # -- many_to_one associations: does NOT save the current object  1)
  # -- one_to_one associations:  does save the associated object.
  #
  # http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
  # --> Method Details
  
  
  visit1 = Visit.create(:ip => '23.34.56.43', :country => 'China', :created_at => Time.now)
  visit2 = Visit.create(:ip => '23.34.56.44', :country => 'Germany', :created_at => Time.now)
  visit3 = Visit.create(:ip => '23.34.56.46', :country => 'Germany', :created_at => Time.now)
  [visit1, visit2, visit3].each { |v| link.add_visit(v) }
  
  visit3 = {:ip => '23.34.56.46', :country => 'Holland', :created_at => Time.now} # Just a hash
  
  link.add_visit(visit3)  # a visit object will be created from the provided hash
  
  # link.remove_visit(visit3)
  link.remove_visit(visit2)
  # UPDATE `visits` SET `ip` = '23.34.56.44', `country` = 'Germany', 
  # `created_at` = '2012-06-16 17:00:53.920172+0800', 
  # `link_short` = NULL WHERE (`id` = 2)
  puts "removed object of one_to_many association: foreign_key set to null"
  puts "many_to_many: row from join table will be removed"
  # NOTE: The add_association and remove_association methods 
  #       should be thought of as adding and removing from the association, 
  #       NOT from the database.
  # -- Use visit2.destroy to remove from the database.
  p Visit.filter(:link_short => nil).all
  # SELECT * FROM `visits` WHERE (`link_short` IS NULL)
  # Output:
  # [#<Visit @values={:id=>2, :ip=>"23.34.56.44", :country=>"Germany", 
  # :created_at=>2012-06-17 15:23:03 +0800, :link_short=>nil}>]
  puts '________________'
  
  puts "all visits as records:"
  p link.visits
  # [#<Visit @values={:id=>1, :ip=>"23.34.56.43", :country=>"China", 
  #  :created_at=>2012-06-15 16:17:03 +0800, :link_short=>"youtube"}>, 
  #  #<Visit @values={:id=>2, :ip=>"23.34.56.44", :country=>"Germany", 
  #  :created_at=>2012-06-15 16:17:03 +0800, :link_short=>"youtube"}>]
  puts "all visits as dataset:"
  p link.visits_dataset
  # #<Sequel::SQLite::Dataset: "SELECT * FROM `visits` WHERE (`visits`.`link_short` = 'youtube')">
  puts "one url:"
  p link.url
  # #<Url @values={:id=>1, :original=>"http://www.sovonexxx.com", :link_short=>"youtube"}>
  p link.url.original # "http://www.sovonexxx.com"
  
  puts 'Filtering by associations'
  p Link.filter(:short => 'youtube').all
  # [#<Link @values={:short=>"youtube", :created_at=>2012-06-15 17:00:19 +0800}>]
  p Visit.filter(:link_short => 'youtube', :ip => '23.34.56.46').all
  # [#<Visit @values={:id=>3, :ip=>"23.34.56.46", :country=>"Germany", :created_at=>2012-06-16 15:15:02 +0800,
  #  :link_short=>"youtube"}>]
  puts 'Same as:' 
  p link.visits_dataset.filter(:ip => '23.34.56.46').all 
  
  # !!!
  p Link.filter(:url => Url[1]) 
  #<Sequel::SQLite::Dataset: "SELECT * FROM `links` WHERE (`links`.`short` = 'youtube')">
  p Url[1]
  #<Url @values={:id=>1, :original=>"http://www.sovonexxx.com", :link_short=>"youtube"}>
  p Link.filter(:url => Url[1]).all
  # [#<Link @values={:short=>"youtube", :created_at=>2012-06-16 15:35:16 +0800}>]
  puts '----------------------'
  
  # NOTE: 
  # -- :url = the ASSOCIATION NAME from Link: one_to_one :url, :key => :link_short
  # Record returned: All rows from Links where the primary key matched Url[xx] foreign key.
  
  
  p Link.filter(:visits => Visit[1])
  #<Sequel::SQLite::Dataset: "SELECT * FROM `links` WHERE (`links`.`short` = 'youtube')">
  p Visit[1]
  #<Visit @values={:id=>1, :ip=>"23.34.56.43", :country=>"China", :created_at=>2012-06-16 15:32:17 +0800, :link_short=>"youtube"}>
  p Link.filter(:visits => Visit[1]).all
  # [#<Link @values={:short=>"youtube", :created_at=>2012-06-16 15:33:42 +0800}>]
  puts '---------------------------'
  
  p Visit.filter(:country => ['Germany', 'China'])
  #<Sequel::SQLite::Dataset: "SELECT * FROM `visits` WHERE (`country` IN ('Germany', 'China'))">

  p Visit.filter(:country => ['Germany', 'China']).all   # Germany OR China
  # [#<Visit @values={:id=>1, :ip=>"23.34.56.43", :country=>"China", [...]},
  #<Visit @values={:id=>2, :ip=>"23.34.56.44", :country=>"Germany", [...]},
  #<Visit @values={:id=>3, :ip=>"23.34.56.46", :country=>"Germany", [...]}>]
  puts 'one_to_many'
  p Visit.filter(:country => 'Germany').filter(:country => 'China') # A AND B 
  # #<Sequel::SQLite::Dataset: "SELECT * FROM `visits` WHERE ((`country` = 'Germany') AND (`country` = 'China'))">
  # This does not return any record in this case, obviously
  
  puts "Reflection"
  # http://sequel.rubyforge.org/rdoc/files/doc/reflection_rdoc.html
  # NOTE: Should not include the primary key index, functional indexes, or partial indexes.
  p DB.indexes(:url)
  {}
  p DB.database_type
  # :sqlite
  
  link.visits_dataset.update(:country => "Island")
  # UPDATE `visits` SET `country` = 'Island' WHERE (`visits`.`link_short` = 'youtube')
  p Visit.all
  # [#<Visit @values={:id=>1, :ip=>"23.34.56.43", :country=>"Island", 
  #  :created_at=>2012-06-17 16:25:54 +0800, :link_short=>"youtube"}>, 
  #  #<Visit @values={:id=>2, :ip=>"23.34.56.44", :country=>"Germany", 
  #  :created_at=>2012-06-17 16:25:54 +0800, :link_short=>nil}>, [...]]
  
  puts "Testing return type -------------------"
  p Visit.all.map { |row| row.class }
  # [Visit, Visit, Visit, Visit]

  
  # Callbacks
  # Re-opening class Link < Sequel::Model
  class Link
    one_to_one  :url,    :key => :link_short, :after_set => :log_url_set 
    one_to_many :visits, :key => :link_short, 
                         :after_add => :log_add_visit, # :symbol, proc or array 2)
                         :after_load => :handle_loaded_visits
    
    # :after_add 
    # called with the ASSOCIATED object
    def log_add_visit(associated_obj)  
      puts "Visit #{associated_obj.inspect} associated to #{inspect}"
    end
    
    # :after_set
    def log_url_set(url)
      puts "Url with id #{url.id} associated to link with key #{self.short}."
    end
    
    attr_reader :latest_country_count
    
    # :after_load
    # For one_to_many and many_to_many associations, 
    # both the argument to symbol callbacks and the second argument to proc callbacks 
    # will be an array of associated objects instead of a single object.
    def handle_loaded_visits(visits)
      puts "((((((((((((())))))))))))) #{visits}"
      @latest_country_count = visits.reduce(Hash.new(0)) {|hash, visit| hash[visit] += 1; hash}
    end
  end
  
  # Before callbacks are often used to check preconditions, 
  # they can return false to signal Sequel to abort the modification. 
  # If any before callback returns false, the remaining before callbacks are not called 
  # and modification is aborted.
  
  # 2)
  # Procs are called with two arguments:
  # -- receiver: first argument
  # -- associated object: second argument
  
  
  visit_new = Visit.create(:ip => '23.34.56.43', :country => 'Costa Rica', :created_at => Time.now)
  # triggers :after_add:
  link.add_visit(visit_new)
  # Visit #<Visit @values={:id=>5, :ip=>"23.34.56.43", :country=>"Costa Rica", 
  # :created_at=>2012-06-18 16:00:12 +0800, :link_short=>"youtube"}> 
  # associated to #<Link @values={:short=>"youtube", :created_at=>2012-06-18 16:00:12 +0800}>
 
  short = rand(10 ** 12).to_s(36)
  
  link_new = Link.create(:short => short, :created_at => Time.now)
  # using #new instead of #create raises error:
  # SQLite3::ConstraintException: foreign key constraint failed: 
  # INSERT INTO `urls` (`original`, `link_short`) VALUES ('http://www.google.com', 'meme')

  # triggers :after_set
  link_new.url = Url.new(:original => 'http://www.google.com') # Url object gets saved 1)
  # => Url with id 2 associated to link with key 4opc2pfz.
  
  link.add_visit(Visit.create(:ip => '23.45.23.45', :country => 'Denmark', :created_at => Time.now))
  
  puts "Lastest country count ==============="
  p link.latest_country_count # => nil (visits not loaded yet)
  
  # should trigger :after_load  
  Link.eager(:visits).all
  p link.latest_country_count # => nil ?)
  
  # ?) :after_load
  # Not called when eager loading via eager_graph, but called when eager loading via eager.
  
  p link_new.visits
  
  
  puts "QUERYING ---------------------"
  # NOTE:
  # The following retrieval methods (to_hash*) always return every row in a table.
  
  # ::map
  # ::select_map
  # ::select_order_map
  
  puts "to_hash"
  # NOTE: ::to_hash and ::to_hash_groups work on a dataset retrieved with SELECT * FROM...
  # to_hash (2 armguments)
  # first: key
  # second: value
  p Visit.to_hash(:country, :link_short)
  # {"Island"=>"youtube", "Germany"=>nil, "Costa Rica"=>"youtube", "Denmark"=>"youtube"}
  
  # If you only provide one argument to to_hash, it uses the entire hash or model object as the value:
  p Visit.to_hash(:country)
  # {"Island"=>#<Visit @values={:id=>4, :ip=>"23.34.56.46", :country=>"Island", ...},
  #  "Germany"=>#<Visit @values={:id=>2, :ip=>"23.34.56.44", :country=>"Germany", ...},
  #  ...}

  # NOTE:
  # By default, to_hash will just have the last matching value. 
  # If you care about all matching values, use to_hash_groups:
  p Visit.to_hash_groups(:country, :link_short)
  # {"Island"=>["youtube", "youtube", "youtube"], "Germany"=>[nil], "Costa Rica"=>["youtube"], "Denmark"=>["youtube"]}
  puts '-------------------------------'
 
  # With only one argument, the argument is the key, the values are the model objects:
  p Visit.to_hash_groups(:country)
  # {"Island"=>[#<Visit @values={:id=>1, :country=>"Island", ...}, #<Visit @values= ...], 
  #  "Germany"=>[#<Visit @values={:id=>2, :country=>"Germany", ...}], 
  #  "Costa Rica"=>[#<Visit @values={:id=>5, :country=>"Costa Rica", ...}], 
  #  "Denmark"=>[#<Visit @values={:id=>6, :country=>"Denmark", ...}]}
 
  puts '-------------------------------'
  # Model datasets have a to_hash method that can be called without any arguments, 
  # in which case it will use 
  # -- the primary key as the key and 
  # -- the model object as the value.
  p Link.to_hash
  # {"youtube"=>#<Link @values={:short=>"youtube", :created_at=>2012-06-20 10:59:37 +0800}>, 
  #  "24qwubu6"=>#<Link @values={:short=>"24qwubu6", :created_at=>2012-06-20 10:59:37 +0800}>}
  puts '-------------------------------'
  
  # Other similar methods that work on a dataset retrieved using SELECT x, y, FROM:
  # ::select_hash
  # ::select_hash_groups
  
  puts "MODIFYING DATASETS ----------------------------------"
  
  dataset = DB[:visits]  
  #<Sequel::SQLite::Dataset: "SELECT * FROM `visits`">

  ds2 = dataset.where(:country.like('C%')) # only countries starting with 'C'
  #<Sequel::SQLite::Dataset: "SELECT * FROM `visits` WHERE (`country` LIKE 'C%')">
  
  ds3 = ds2.order(:country).select(:created_at, :country)
  # #<Sequel::SQLite::Dataset: 
  # "SELECT `created_at`, `country` FROM `visits` WHERE (`country` LIKE 'C%') ORDER BY `country`">

  puts "Filters --------------------------------------------"
  
  p Visit.filter(:link_short => nil).all
  # SELECT * FROM `visits` WHERE (`link_short` IS NULL)
  # Output:
  # [#<Visit @values={:id=>2, :ip=>"23.34.56.44", :country=>"Germany", 
  #  :created_at=>2012-06-17 15:23:03 +0800, :link_short=>nil}>]
  
  p Visit.filter(:link_short => 'youtube', :ip => '23.34.56.46')  # a AND b
  # #<Sequel::Postgres::Dataset: 
  # "SELECT * FROM \"visits\" WHERE ((\"link_short\" = 'youtube') AND (\"ip\" = '23.34.56.46'))">

  p Visit.filter(:id=>[1, 2]).all   # a AND b
  # "SELECT * FROM \"visits\" WHERE (\"id\" IN (1, 2))"
  # [#<Visit @values={:id=>2, ...}>, #<Visit @values={:id=>1, ...}>]
  
  # NOTE:
  # If you need to filter for different values with the same key, 
  # use two-element arrays instead.
  # This, however, does not make much sense in most cases:
  p Visit.filter([[:country, 'Germany'], [:country, 'Holland']]).all # a AND b
  # SELECT * FROM "visits" WHERE (("country" = 'Germany') AND ("country" = 'Holland'))
  
  puts "Virtual Row Blocs ==================================="
  # VirtualRows use METHOD_MISSING to handle almost all method calls.
  
  # http://sequel.rubyforge.org/rdoc/files/doc/virtual_rows_rdoc.html
  # If a block is passed to filter, it is treated as a virtual row block:
  # Dataset methods filter, order, and select all take blocks that are referred to as virtual row blocks. 
  # Many other dataset methods pass the blocks they are given into one of those three methods, 
  # so there are actually many Sequel::Dataset methods that take virtual row blocks.
  
  # Evaluated in the context of an instance of Sequel::SQL::VirtualRow (via instance_eval)
  p Url.filter{ id < 3}  
  # NOTE: If there is a variable 'id' in the surrounding scope,
  #       the call to the method 'id' needs to be as follows: 
  p Url.filter{ id() < 3}
  # SELECT * FROM "urls" WHERE ("id" < 3)
  # Returns: SQL::Identifiers
  
  
  # Block called with an instance of Sequel::SQL::VirtualRow ('row' in this example):
  p Url.filter{ |row| row.id < 3}
  # "SELECT * FROM \"urls\" WHERE (\"id\" < 3)"
  # NOTE:
  # You usually use instance evaled procs UNLESS you need to 
  # call methods on the receiver of the SURROUNDING SCOPE inside the proc.
  
  p Url.filter{ urls__id < 3}
  p Url.filter{ |o| o.urls__id < 3}
  # "SELECT * FROM \"urls\" WHERE (\"urls\".\"id\" < 3)"
  # Returns: SQL::QualifiedIdentifiers
  
  puts "Calling SQL functions"
  p Url.filter{ |row| row.function(1, row.id) < 3}
  # "SELECT * FROM \"urls\" WHERE (function(1, \"id\") < 3)"
  # Returns: SQL::Functions
  
  # NOTE: 
  # If the SQL function does not accept any arguments, you need to provide an empty block to the method 
  # to distinguish it from a call that will produce an SQL::Identifier:
  p Url.filter{ |row| row.function{} < 3}
  # "SELECT * FROM \"urls\" WHERE (function() < 3)"
  
  puts "Using the wildcard * in a function call"
  # 1) make :* the sole argument to the method
  # 2) provide an empty block to the method:
  p Url.select{ count(:*){} }
  # "SELECT count(*) FROM \"urls\"
  
  puts "Using the DISTICT keyword"
  # 1) make :distinct the first argument of the method
  # 2) add all additional arguments
  # 3) provide an empty block
  p Visit.select{ count(:distinct, country){} }
  # SELECT count(DISTINCT \"country\") FROM \"visits\"
  p Visit.select{ count(:distinct, country, ip){} }
  # "SELECT count(DISTINCT \"country\", \"ip\") FROM \"visits\"
  
  puts "SQL::WindowFunctions - SQL window function calls"
  # -- make :over the first argument of the method call, 
  # -- with an optional hash as the second argument
  
  # ds.select{|o| o.rank(:over){}}
  # ds.select{rank(:over){}}
  # SELECT rank() OVER ()
  # ds.select{|o| o.count(:over, :*=>true){}}
  # ds.select{count(:over, :*=>true){}}
  # SELECT count(*) OVER ()

ds.select{|o| o.sum(:over, :args=>o.col1, :partition=>o.col2, :order=>o.col3){}}
ds.select{sum(:over, :args=>col1, :partition=>col2, :order=>col3){}}
# SELECT sum(col1) OVER (PARTITION BY col2 ORDER BY col3)
  
  puts "Math operators"
  # ds.select{|o| o.-(1, o.a).as(b)}
  # ds.select{self.-(1, a).as(b)}
  # SELECT (1 - a) AS b
  
  puts "Boolean operators"
  
 # ds.where{|o| o.&({:a=>:b}, :c)}
 # ds.where{self.&({:a=>:b}, :c)}
 # WHERE ((a = b) AND c)
 
 # The ~ method is defined to do inversion:

 # ds.where{|o| o.~({:a=>1, :b=>2})}
 # ds.where{self.~({:a=>1, :b=>2})}
 # WHERE ((a != 1) OR (b != 2))
  
  
  puts 'Inequality Operators'
  # ds.where{|o| o.>(1, :c)}
  # ds.where{self.>(1, :c)}
  # WHERE (1 > c)
  
  puts "Literal Strings"
  # The backtick operator can be used inside an instance-evaled virtual row block to 
  # create a literal string:

  # ds.where{a > `some SQL`}
  # WHERE (a > some SQL)"
 
 
  puts "Returning multiple values from 'select' or 'order'"
  # Return a single array
  p Url.select{ [original, link_short]}
  # "SELECT \"original\", \"link_short\" FROM \"urls\"
  
  # ds.select{[column1, sum(column2).as(sum)]}
  # SELECT column1, sum(column2) AS sum
  
  puts "Alternative Description of the VirtualRow method call rules"
  # 1) If a block is given:
  #    -- The block is currently not called. This may change in a future version.
  #    -- If there are no arguments, an SQL::Function with the name of method used, and no arguments.
  #    -- If the first argument is :*, an SQL::Function is created with a single wildcard argument (*).
  #    -- If the first argument is :distinct, an SQL::Function is created with the keyword DISTINCT prefacing all remaining arguments.
  #    -- If the first argument is :over, the second argument if provided should be a hash of options to pass to SQL::Window. The options hash can also contain :*=>true to use a wildcard argument as the function argument, or :args=>... to specify an array of arguments to use as the function arguments.

  # If a block is not given:
  # -- If there are arguments, an SQL::Function is returned with the name of the method used and the arguments given.
  # -- If there are no arguments and the method contains a double underscore, split on the double underscore and return an SQL::QualifiedIdentifier with the table and column.
  # -- Otherwise, create an SQL::Identifier with the name of the method.
  
  
  
  
  
  
  
end  



DB.drop_table(:urls, :visits, :links)
