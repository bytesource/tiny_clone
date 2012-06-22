# Sequel Google Groups
# Topic: https://groups.google.com/forum/?fromgroups#!topic/sequel-talk/WlgsyLtd9eE

require 'sequel'
require 'logger'
require 'date'


# Connection
# =============
# DB = Sequel.sqlite

DB = Sequel.connect('postgres://postgres:blablabla@localhost/tinyclone')


# Schema
# =============
DB.create_table? :links do
  String      :short,      :primary_key => true, :size => 15
  DateTime    :created_at, :null => false    
end

DB.create_table? :urls do
  primary_key :id
  String      :original, :size => 255, :unique => true, :null => false
  foreign_key :link_short, :links, :type => String, :on_delete => :cascade
end

DB.create_table? :visits do
  primary_key :id
  inet        :ip,         :null => false
  String      :country,    :size => 255
  DateTime    :created_at, :null => false
  foreign_key :link_short, :links, :type => String, :on_delete => :cascade
end


# Associations
# =============
class Url < Sequel::Model
 many_to_one :link, :key => :link_short  
end


class Link < Sequel::Model 
  one_to_one  :url,    :key => :link_short 
  one_to_many :visits, :key => :link_short 
end


class Visit < Sequel::Model
  many_to_one :link, :key => :link_short  
end


Link.unrestrict_primary_key


# Inserting data
# =============
link1 = Link.create(:short => 'example', :created_at => Time.now)
link1.url = Url.new(:original => 'http://www.example.com')

link2 = Link.create(:short => 'google', :created_at => Time.now)
link2.url = Url.new(:original => 'http://www.google.com')


visit1 = Visit.create(:ip => '23.34.56.43', :country => 'China', :created_at => Time.now)
visit2 = Visit.create(:ip => '23.34.56.44', :country => 'Germany', :created_at => Time.now)
visit3 = Visit.create(:ip => '23.34.56.46', :country => 'Germany', :created_at => Time.now)

link1.add_visit(visit1)
link1.add_visit(visit2)
link2.add_visit(visit3)


# Querying
# =============

short = 'example'
number_of_days = 10

main_query1 = DB[:visits].group_and_count{ date(created_at) }.filter(:link_short => short)
main_query2 = DB[:visits].group_and_count{ created_at.cast(Date) }.filter(:link_short => short)

# LONG VERSION OF THE ABOVE QUERY:
main_query_test = DB[:visits].select{ [date(created_at), count(:*){}] }.
                              filter(:link_short => short).group{ date(created_at) }

query1 = main_query1.filter(:created_at => (Date.today - number_of_days) .. (Date.today + 1))
query2 = main_query2.filter(:created_at => (Date.today - number_of_days) .. (Date.today + 1))

query_test = main_query_test.filter(:created_at => (Date.today - number_of_days) .. (Date.today + 1))


p query1
p query1.all
p query2
p query2.all

puts "Test query: --------------------------------"
p query_test
p query_test.all
# SELECT date(`created_at`), count(*) 
# FROM `visits` 
# WHERE ((`link_short` = 'example') AND 
#        (`created_at` >= '2012-06-12') AND (`created_at` <= '2012-06-23')) 
# GROUP BY date(`created_at`)

# => [{:date=>#<Date: 2012-06-22 (4912201/2,0,2299161)>, :count=>2}]


# SQLite

# #<Sequel::SQLite::Dataset: 
# "SELECT date(`created_at`), count(*) AS 'count' 
# FROM `visits` WHERE ((`link_short` = 'example') AND 
# (`created_at` >= '2012-06-11') AND (`created_at` <= '2012-06-22')) 
# GROUP BY date(`created_at`)">


# => [{:"date(`created_at`)"=>nil, :count=>2}]

# #<Sequel::SQLite::Dataset: 
# "SELECT CAST(`created_at` AS date), count(*) AS 'count' 
# FROM `visits` WHERE ((`link_short` = 'example') AND 
# (`created_at` >= '2012-06-11') AND (`created_at` <= '2012-06-22')) 
# GROUP BY CAST(`created_at` AS date)">

# =  [{:"CAST(`created_at` AS date)"=>2012, :count=>2}]


# Postgres

# #<Sequel::Postgres::Dataset: 
# "SELECT date(\"created_at\"), count(*) AS \"count\" 
# FROM \"visits\" WHERE ((\"link_short\" = 'example') AND 
# (\"created_at\" >= '2012-06-11') AND (\"created_at\" <= '2012-06-22')) 
# GROUP BY date(\"created_at\")">

# => [{:date=>#<Date: 2012-06-21 (4912199/2,0,2299161)>, :count=>2}]


# #<Sequel::Postgres::Dataset: 
# "SELECT CAST(\"created_at\" AS date), count(*) AS \"count\" 
# FROM \"visits\" WHERE ((\"link_short\" = 'example') AND 
# (\"created_at\" >= '2012-06-11') AND (\"created_at\" <= '2012-06-22')) 
# GROUP BY CAST(\"created_at\" AS date)">

# => [{:created_at=>#<Date: 2012-06-21 (4912199/2,0,2299161)>, :count=>2}]


if DB.database_type == :postgres
  query3 = main_query2.filter{(created_at >= (Sequel::CURRENT_DATE - number_of_days)) & 
                         (created_at <= (Sequel::CURRENT_DATE + 1))}
else
  query3 = main_query1.filter{(created_at >= date(Sequel::CURRENT_DATE, "'-? days'".lit(number_of_days.to_i))) & 
                         (created_at <= date(Sequel::CURRENT_DATE,'+1 day'))}
end



# During Testing:
DB.drop_table(:urls, :visits, :links)
