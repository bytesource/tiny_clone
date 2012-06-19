require_relative 'database/connection'
require_relative 'database/tables'  # for SQLite in-memory database 
require_relative 'database/associations'
require 'date'

# Timestamps
# http://sequel.rubyforge.org/rdoc-plugins/classes/Sequel/Plugins/Timestamps.html


# http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#method-i-unrestrict_primary_key
Link.unrestrict_primary_key

DB.transaction do

  key = 'youtube'
  # link = Link.create(:short => key)    # :default => created_at_function.lit
  # [{:short=>"youtube", :created_at=>2012-06-17 16:08:30 +0800}]
  link = Link.create(:short => key, :created_at => Time.now)
  puts '#####################################'
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
  
  # to_hash (2 armguments)
  # first: key
  # second: value
  p Visit.to_hash(:country, :link_short)
  # {"Island"=>"youtube", "Germany"=>nil, "Costa Rica"=>"youtube", "Denmark"=>"youtube"}

  # NOTE:
  # By default, to_hash will just have the last matching value. 
  # If you care about all matching values, use to_hash_groups:
  p Visit.to_hash_groups(:country, :link_short)
  # {"Island"=>["youtube", "youtube", "youtube"], "Germany"=>[nil], "Costa Rica"=>["youtube"], "Denmark"=>["youtube"]}

  
  puts '-------------------------------'
  


  
end

# SELECT date(created_at) as date, count(*) as count
# FROM visits
# WHERE link_short = '#{short}' and 
#       created_at between CURRENT_DATE-#{days} and CURRENT_DATE+1
# GROUP BY date(created_at)


require 'date'
# short = '785w3llv'.downcase
short     = 'youtube'
number_of_days  = 15
day       = (60 * 60 * 24) # http://www.ruby-doc.org/core-1.9.3/Time.html#method-i-2B
from_date = Time.now - (number_of_days * day)
to_date   = Time.now

  # NOTE: Using Time.now directly only works provided:
  #       -- The table column is specified as being of type Date
  #          The values for created_at are then converted to Date, even if Time.now is used
p DB[:visits].filter(:link_short => short).
              filter(:created_at => from_date .. to_date).group(:created_at).all
# SELECT * FROM `visits` WHERE ((`link_short` = 'youtube') AND 
# (`created_at` >= '2012-06-04 16:28:20.778044+0800') AND (`created_at` <= '2012-06-19 16:28:20.778047+0800')) 
# GROUP BY `created_at`

# [{ [...], :created_at=>2012-06-19 16:28:20 +0800, :link_short=>"youtube"}, 
#  { [...], :created_at=>2012-06-19 16:28:20 +0800, :link_short=>"youtube"}, 
#  [...]]







# Generating short url:
# rand(10 ** 12).to_s(36)
# => "e0xnaop"

# Before fetching 'short' from database: downcase(input)

