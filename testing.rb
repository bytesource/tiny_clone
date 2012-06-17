require_relative 'database/connection'
require_relative 'database/tables'  # for SQLite in-memory database 
require_relative 'database/associations'

# links = DB[:links]


# http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#method-i-unrestrict_primary_key
Link.unrestrict_primary_key

# Timestamps
# http://sequel.rubyforge.org/rdoc-plugins/classes/Sequel/Plugins/Timestamps.html


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


  



  
end

# p DB[:links].all # 'created at' CANNOT be nil!
# [{:short=>"hello", :created_at=>nil},
#  {:short=>"hello2", :created_at=>2012-06-13 16:18:24 +0800},
#  {:short=>"22", :created_at=>2012-06-13 16:21:48 +0800}]
# p DB[:urls].all






# Generating short url:
# rand(10 ** 12).to_s(36)
# => "e0xnaop"

