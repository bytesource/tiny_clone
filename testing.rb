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
  link = Link.create(:short => key, :created_at => Time.now)

  link.url = Url.create(:original => 'http://www.sovonexxx.com')
  # 1) Insert without foreign key
  # INSERT INTO "urls" ("original") VALUES ('http://www.sovonexxx.com') 
  # 2) Set foreign key to NULL
  # UPDATE "urls" SET "link_short" = NULL WHERE (("link_short" = 'youtube') AND ("id" != 1))
  # 3) Set foreign key to the correct value from the Links table
  # UPDATE "urls" SET "original" = 'http://www.sovonexxx.com', "link_short" = 'youtube' WHERE ("id" = 1)

  
  visit = Visit.create(:ip => '23.34.56.43', :country => 'China', :created_at => Time.now)
  link.add_visit(visit)
  
  # visit = Visit.create(:ip => '23.34.56.43', :country => 'China', :created_at => Time.now, :link_short => key)
  
  
end

# p DB[:links].all # 'created at' CANNOT be nil!
# [{:short=>"hello", :created_at=>nil},
#  {:short=>"hello2", :created_at=>2012-06-13 16:18:24 +0800},
#  {:short=>"22", :created_at=>2012-06-13 16:21:48 +0800}]
# p DB[:urls].all






# Generating short url:
# rand(10 ** 12).to_s(36)
# => "e0xnaop"

