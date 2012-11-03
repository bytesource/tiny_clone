require_relative 'database/connection'
require_relative 'database/tables'  # for SQLite in-memory database 
require_relative 'database/associations'
require 'date'
require 'pp'

# http://sequel.rubyforge.org/rdoc/files/doc/release_notes/2_2_0_txt.html
# Attempts to save an invalid Model instance will raise an error by default:
Sequel::Model.raise_on_save_failure = true  # default
# Sequel::Model.raise_on_save_failure = true  # returns nil on failure


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
  
  # table.create(...)  => creates object and inserts it into the database (INSERT INTO...)

  key = 'youtube'
  # link = Link.create(:short => key)    # :default => created_at_function.lit
  # [{:short=>"youtube", :created_at=>2012-06-17 16:08:30 +0800}]
  link = Link.create(:short => key, :created_at => Time.now)
  # INSERT INTO "links" ("short", "created_at") VALUES ('youtube', '2012-10-28 17:03:13.241424+0800')
  p DB[:links].all
  # [{:short=>"youtube", :created_at=>2012-06-17 16:06:51 +0800}]

  # #association= sets the relevant foreign key to be the same as the primary key of the other object
  link.url = Url.new(:original => 'http://www.sovonexxx.com') # Url object gets saved 1) # new Link instance
  # The above line of code leads to the execution of the following 3 SQL statements:
  # 1) Insert without foreign key
  #    INSERT INTO "urls" ("original") VALUES ('http://www.sovonexxx.com') 
  # 2) Set foreign key to NULL
  #    UPDATE "urls" SET "link_short" = NULL WHERE (("link_short" = 'youtube') AND ("id" != 1)) // I think this should be "id" != 0
  # 3) Set foreign key to the correct value from the Links table
  #    UPDATE "urls" SET "original" = 'http://www.sovonexxx.com', "link_short" = 'youtube' WHERE ("id" = 1)

  # NOTE:
  # The following are the SQL statements that where actually output using Postgres as the database: 
  # 1) Set all references to the foreign key 'youtube' to NULL
  #    UPDATE "urls" SET "link_short" = NULL WHERE (("link_short" = 'youtube') AND ("id" IS NOT NULL))
  # 2) Insert new URL row, setting both value and foreign key.
  #    INSERT INTO "urls" ("original", "link_short") VALUES ('http://www.sovonexxx.com', 'youtube') 

  # NOTE on #association=
  # -- many_to_one associations: does NOT save the current object  1)
  # -- one_to_one associations:  does save the associated object.
  #
  # http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
  # --> Method Details
  
  
  visit1 = Visit.create(:ip => '23.34.56.43', :country => 'China', :created_at => Time.now)
  visit2 = Visit.create(:ip => '23.34.56.44', :country => 'Germany', :created_at => Time.now)
  visit3 = Visit.create(:ip => '23.34.56.46', :country => 'Germany', :created_at => Time.now)
  visit4 = {:ip => '23.34.56.46', :country => 'Holland', :created_at => Time.now} # Just a hash
  [visit1, visit2, visit3, visit4].each { |v| link.add_visit(v) }
  p
  
  
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
  # p Link.filter(:url => Url[1]).all
  # [#<Link @values={:short=>"youtube", :created_at=>2012-06-16 15:35:16 +0800}>]
  puts '----------------------'
  
  # NOTE: 
  # -- :url = the ASSOCIATION NAME from Link: one_to_one :url, :key => :link_short
  # Record returned: All rows from Links where the foreign key of Url[xx] matches the primary key of Links.
  
  # NOTE: Does not seem to work with Postgres:
  p Link.filter(:url => Url[1])
  # "SELECT * FROM \"links\" WHERE (\"url\" IS NULL)"
  # Links does not have a 'url' column, so the following returns an error:
  # p Link.filter(:url => Url[1]).all
  # PG::Error: ERROR: column "url" does not exist (Sequel::DatabaseError)
  
  
  p Link.filter(:visits => Visit[1])
  #<Sequel::SQLite::Dataset: "SELECT * FROM `links` WHERE (`links`.`short` = 'youtube')">
  p Visit[1]
  #<Visit @values={:id=>1, :ip=>"23.34.56.43", :country=>"China", :created_at=>2012-06-16 15:32:17 +0800, :link_short=>"youtube"}>
  # p Link.filter(:visits => Visit[1]).all  # => error in Postgres: column "visits" does not exist
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
  # This query, obviously, does not return any record.
  
  puts "Reflection"
  # http://sequel.rubyforge.org/rdoc/files/doc/reflection_rdoc.html
  # NOTE: Should not include the primary key index, functional indexes, or partial indexes.
  p DB.indexes(:url)
  # {}
  p DB.database_type
  # :sqlite
  
  link.visits_dataset.update(:country => "Island")
  # UPDATE `visits` SET `country` = 'Island' WHERE (`visits`.`link_short` = 'youtube')
  # NOTE:
  # For more about updating (in combination with CASCASDE), see 'Updating and Deleting' below.
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
  #       :created_at=>2012-06-18 16:00:12 +0800, :link_short=>"youtube"}> 
  # associated to 
  # <Link @values={:short=>"youtube", :created_at=>2012-06-18 16:00:12 +0800}>
 
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
  
  # Other similar methods that work on a dataset (retrieved using SELECT x, y, FROM):
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
  
  puts "Alternative with a block"
  p Visit.filter(:link_short => 'youtube'){ id < 4 } # ANDed together
  # "SELECT * FROM \"visits\" WHERE ((\"link_short\" = 'youtube') AND (\"id\" < 4))"
  # NOTE:
  # As for the block, see 'Virtual Row Blocs' below for details.
  
  p Visit.filter(:id=>[1, 2]).all   # a OR b
  # "SELECT * FROM \"visits\" WHERE (\"id\" IN (1, 2))"
  # [#<Visit @values={:id=>2, ...}>, #<Visit @values={:id=>1, ...}>]
  
  # NOTE:
  # If you need to filter for different values with the same key, 
  # use two-element arrays instead.
  # This, however, does not make much sense in most cases:
  p Visit.filter([[:country, 'Germany'], [:country, 'Holland']]).all # a AND b
  # SELECT * FROM "visits" WHERE (("country" = 'Germany') AND ("country" = 'Holland'))
  
  puts "Symbols =============="
  # If you have a boolean column in the database, and you want only true values, 
  # you can just provide the column symbol to filter:

  # Artist.where(:retired)
  # SELECT * FROM artists WHERE retired
  
  puts "SQL::Expression --------------------------" 
  # Sequel has a DSL that allows easily creating SQL expressions. 
  # These SQL expressions are instances of 
  # -- subclasses of Sequel::SQL::Expression. 
  
  # Artist.filter(:name.like('Y%'))
  # SELECT * FROM artists WHERE name LIKE 'Y%'
  # => Returns a Sequel::SQL::BooleanExpression object, which is used directly in the filter.
  
  # You can use the DSL to create arbitrarily complex expressions. SQL::Expression objects support the 
  # -- & operator for AND, the 
  # -- | operator for OR, and the 
  # -- ~ operator for inversion:

  # Artist.filter(:name.like('Y%') & ({:b=>1} | ~{:c=>3}))
  # SELECT * FROM artists WHERE name LIKE 'Y%' AND (b = 1 OR c != 3)
  # You can combine these expression operators with the virtual row support:
  
  # Artist.filter{(a > 1) & ~((b(c) < 1) | d)}
  # SELECT * FROM artists WHERE a > 1 AND b(c) >= 1 AND NOT d
  
  
  puts "Virtual Row Blocs ==================================="
  # VirtualRows use METHOD_MISSING to handle almost all method calls.
  
  # http://sequel.rubyforge.org/rdoc/files/doc/virtual_rows_rdoc.html
  # If a block is passed to filter, it is treated as a virtual row block:
  # Dataset methods 'filter', 'order', and 'select' all take blocks that are referred to as virtual row blocks. 
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
  p Url.filter{ |row| row.function{} < 3} # function = count(), etc.
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

  # ds.select{|o| o.sum(:over, :args=>o.col1, :partition=>o.col2, :order=>o.col3){}}
  # ds.select{sum(:over, :args=>col1, :partition=>col2, :order=>col3){}}
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
  #    -- If there are no arguments, an SQL::Function with the name of method is used, and no arguments.
  #    -- If the first argument is :*, an SQL::Function is created with a single wildcard argument (*).
  #    -- If the first argument is :distinct, an SQL::Function is created with the keyword DISTINCT prefacing all remaining arguments.
  #    -- If the first argument is :over, the second argument, if provided, should be a hash of options to pass to SQL::Window. The options hash can also contain 
  #       :*=>true to use a wildcard argument as the function argument, or 
  #       :args=>... to specify an array of arguments to use as the function arguments.
  #       :partition=>
  #       :order=>

  # If a block is not given:
  # -- If there are arguments, an SQL::Function is returned with the name of the method used and the arguments given.
  # -- If there are no arguments and the method contains a double underscore, split on the double underscore and return an SQL::QualifiedIdentifier with the table and column.
  # -- Otherwise, create an SQL::Identifier with the name of the method.
  
  
  puts "Strings with Placeholders +++++++++++++++++++++++++++++++"
  
  pp Visit.filter("country LIKE ? AND link_short = ?", 'I%', 'youtube').all
  # "SELECT * FROM \"visits\" WHERE (country LIKE 'I%' AND link_short = 'youtube')"
  # [#<Visit @values={:id=>1, :ip=>"23.34.56.43", :country=>"Island", ...}>,
  #<Visit @values={:id=>3, :ip=>"23.34.56.46", :country=>"Island", ...}>,
  #<Visit @values={:id=>4, :ip=>"23.34.56.46", :country=>"Island", ...}>]
  
  
  # NOTE:
  # However, if you are using any untrusted input, you should definitely be using placeholders.
  short = "I am evil" 
  
  Visit.filter("id = #{short}") # Don't do this!
  Visit.filter("id = ?", short) # Do this instead
  Visit.filter(:id => short)    # Even better
  
  
  puts "Inverting"
  # NOTE: 
  # 'invert', e.g. 'filter(:id => 5).invert', can be used, but it is not very practical, 
  # as it inverts the expressions off ALL filters in a query.
  puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  p Visit.filter(:country => 'Island').exclude{ id > 5 }
  # p Visit.filter(:country => 'Island').exclude( id > 5 ) # undefined local variable or method `id' for main:Object (NameError)
  # "SELECT * FROM \"visits\" WHERE ((\"country\" = 'Island') AND (\"id\" <= 5))"
  p Visit.exclude(:id => 3)
  # "SELECT * FROM \"visits\" WHERE (\"id\" != 3)"
  p Visit.exclude(:id => [3, 5])
  # "SELECT * FROM \"visits\" WHERE (\"id\" NOT IN (3, 5))"
  
  
  puts "Removing"
  # To remove ALL existing filters, use unfiltered:
  p Visit.filter(:id=>1).filter(:country => 'Germany').unfiltered
  # "SELECT * FROM \"visits\"
  
  
  puts "Ordering ==================================="
  # NOTE:
  # Unlike filter, order REPLACES an EXISTING ORDER,
  # it does not append to an existing order:
  p Visit.order(:id).order(:country, :ip)
  # "SELECT * FROM \"visits\" ORDER BY \"country\", \"ip\""
  
  # However, you can add or prepend a column to order in the following way:
  # Add:
  p Visit.order(:country, :ip).order_append(:id)
  # "SELECT * FROM \"visits\" ORDER BY \"country\", \"ip\", \"id\""
  # Prepend:
  p Visit.order(:country, :ip).order_prepend(:id)
  # "SELECT * FROM \"visits\" ORDER BY \"id\", \"country\", \"ip\""
  p Visit.order(:country).order_prepend(:id, :link_short)
  # ORDER BY \"id\", \"link_short\", \"country\""
 
  
  puts "Reversing ====================================="
  # Just like you can invert an existing filter, 
  # you can reverse an existing order (ASC --> DESC), using reverse:
  p Visit.order(:id).reverse
  # "SELECT * FROM \"visits\" ORDER BY \"id\" DESC"
  
  # Better: using Symbol#desc
  p Visit.order(:id.desc)
  # "SELECT * FROM \"visits\" ORDER BY \"id\" DESC"
  p Visit.order(:id.asc)
  # "SELECT * FROM \"visits\" ORDER BY \"id\" ASC"
  
  puts "Removing ---------------"
  # Remove orders with unordered
  p Visit.order(:id).order(:country, :ip).unordered
  # "SELECT * FROM \"visits\""
  
  puts "\nSelected Columns ==========================="
  # Manipulating the columns selected.
  # Main method is select.
  
  # NOTE: 
  # If you are dealing with model objects, 
  # -- you'll want to include the primary key if you want to update or destroy the object. 
  # -- You'll also want to include any keys (primary or foreign) 
  #    related to associations you plan to use.

  # => If a column is not selected, and you attempt to access it, you will get nil:
  v = Visit.select(:country).first
  # SELECT "country" FROM "visits" LIMIT 1    # ip not selected
  p v[:ip]
  # => nil                                    # ip not selected
  
  # Like order, select replaces the existing selected columns:
  p Visit.select(:country).select(:ip).select(:link_short)
  # "SELECT \"link_short\" FROM \"visits\""
  
  p Visit.select(:country).select(:ip).select(:link_short).select_append(:country)
  # "SELECT \"link_short\", \"country\" FROM \"visits\""
  
  p Visit.select(:country).select(:ip).select(:link_short).select_all
  # "SELECT * FROM \"visits\""
  
  puts "\nDISTINCT"
  
  p Visit.distinct.select(:country) 
  # "SELECT DISTINCT \"country\" FROM \"visits\"">
  p Visit.select(:country).distinct
  # "SELECT DISTINCT \"country\" FROM \"visits\"">
  
  puts "\nLimit and Offset"
  # You can limit the dataset to a given number of rows using limit:
  
  p Visit.limit(3)
  # "SELECT * FROM \"visits\" LIMIT 3">
  p Visit.limit(3, 5)
  # "SELECT * FROM \"visits\" LIMIT 3 OFFSET 5">  # items 6 to 8
  p Visit.limit(3, 5).unlimited                   # reset limit 
  # "SELECT * FROM \"visits\"">
  
  
  puts "\n Grouping"
  # The SQL GROUP BY clause is used to 
  # -- COMBINE multiple ROWS 
  # -- based on the VALUES of a given GROUP OF COLUMNS.
  
  
  p Visit.group(:country)
  # "SELECT * FROM \"visits\" GROUP BY \"country\""
  p Visit.group(:country).ungrouped
  # "SELECT * FROM \"visits\""
  
  p Visit.group_and_count{ date(created_at) }
  # "SELECT date(\"created_at\"), count(*) AS \"count\" FROM \"visits\" GROUP BY date(\"created_at\")"
  # This one is equivalent (except for not using the AS clause):
  p Visit.select{ [date(created_at), count(:*){}] }.group{ date(created_at) }
  # "SELECT date(\"created_at\"), count(*) FROM \"visits\" GROUP BY date(\"created_at\")"
  # Also using the AS clause:
  p Visit.select{ [date(created_at), count(:*){}.as(:count)] }.group{ date(created_at) }
  # "SELECT date(\"created_at\"), count(*) AS \"count\" FROM \"visits\" GROUP BY date(\"created_at\")">
  
  
  puts "\nUpdating and Deleting Rows (and Testing CASCADE) ======================="
  
  Link.filter(:short => 'youtube').update(:short => 'changed')
  # UPDATE "links" SET "short" = 'changed' WHERE ("short" = 'youtube')
  # because of :on_update => cascade, the foreign keys of the associated
  # rows in the child tables get also updated.
  
  p DB[:links].filter(:short => 'changed').all.size        # => 1
  p DB[:visits].filter(:link_short => 'changed').all.size  # => 5
  p DB[:urls].filter(:link_short => 'changed').all.size    # => 1
  
  p Link.filter(:short => 'changed').delete  # delete executes code on the database
  # DELETE FROM "links" WHERE ("short" = 'changed')
  
  p DB[:links].filter(:short => 'changed').all.size        # => 0
  p DB[:visits].filter(:link_short => 'changed').all.size  # => 0
  p DB[:urls].filter(:link_short => 'changed').all.size    # => 0
  
  # Note: All associated rows from the 'urls' and 'visits' tables have been deleted due to 
  # the following CASCADE constraint on the foreign key:
  # foreign_key :link_short, :links, :type => String, :on_delete => :cascade
  
  puts "/nHaving"
  # The SQL HAVING clause is similar to the WHERE clause, 
  # except that it FILTERS the results AFTER THE GROUPING has been APPLIED,
  # instead of before. 
  
  p Visit.group_and_count{ date(created_at) }.having{ count >= 2}
  # "SELECT date(\"created_at\"), count(*) AS \"count\" FROM \"visits\" 
  # GROUP BY date(\"created_at\") 
  # HAVING (\"count\" >= 2)">

  # NOTE:
  # If you have an existing HAVING clause on your dataset, 
  # then 'filter' will ADD to the HAVING clause instead of the WHERE clause:
  p Visit.group_and_count{ date(created_at) }.having{ count >= 2}.filter { count <= 10}
  # "SELECT date(\"created_at\"), count(*) AS \"count\" FROM \"visits\" 
  # GROUP BY date(\"created_at\") 
  # HAVING ((\"count\" >= 2) AND (\"count\" <= 10))"
  
  # NOTE:
  # UNLIKE 'filter', 'where' always affects the WHERE clause:
  p Visit.group_and_count{ date(created_at) }.having{ count >= 2}.where(:name.like('I%'))
  # "SELECT date(\"created_at\"), count(*) AS \"count\" FROM \"visits\" 
  # WHERE (\"name\" LIKE 'I%') 
  # GROUP BY date(\"created_at\") 
  # HAVING (\"count\" >= 2)"
  
  # NOTE:
  # BOTH the WHERE clause and the HAVING clause are removed by 'unfiltered' in the same query:
  p Visit.group_and_count{ date(created_at) }.having{ count >= 2}.where(:name.like('I%')).unfiltered
  # "SELECT date(\"created_at\"), count(*) AS \"count\" FROM \"visits\" 
  # GROUP BY date(\"created_at\")"
  
  puts "\n Joins ============================" 
  # Different SQL JOINs
  
  # (INNER) JOIN: 
  # -- Return rows where there is at least one MATCH IN BOTH tables
  # LEFT (OUTER) JOIN: 
  # -- Return all rows from the left table, even if there are no matches in the right table
  # RIGHT (OUTER) JOIN: -- 
  # Return all rows from the right table, even if there are no matches in the left table
  # FULL (OUTER) JOIN:
  # -- Return rows when there is a match in one of the tables
  
  
  puts "MAJOR TESTING-----------------------------------------" 
  p Visit.group_and_count(:country).filter(:link_short => short)
  
end  



DB.drop_table(:urls, :visits, :links)
