# Sequel Google Groups
# Topic: https://groups.google.com/forum/?fromgroups#!topic/sequel-talk/WlgsyLtd9eE

require 'sequel'
require 'logger'
require 'date'


# Connection
# =============
DB = Sequel.sqlite

# DB = Sequel.connect('postgres://postgres:password@localhost/tinyclone')


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

short = 'google'
number_of_days = 10

query1 = DB[:visits].group_and_count(:created_at).
                    filter(:link_short => short).
                    filter(:created_at => (Date.today - number_of_days) .. Date.today)
                    
# #<Sequel::SQLite::Dataset: 
# "SELECT `created_at`, count(*) AS 'count' 
# FROM `visits` WHERE ((`link_short` = 'youtube') AND 
# (`created_at` >= '2012-06-05') AND (`created_at` <= '2012-06-20')) 
# GROUP BY `created_at`">

# <Sequel::Postgres::Dataset: 
# "SELECT \"created_at\", count(*) AS \"count\" 
# FROM \"visits\" 
# WHERE ((\"link_short\" = 'google') AND 
# (\"created_at\" >= '2012-06-10') AND (\"created_at\" <= '2012-06-20')) 
# GROUP BY \"created_at\"">

p query1.all
# SQLite, Postgres:
# => []


query2 = DB[:visits].group_and_count(:created_at).
                     filter(:link_short => short).
                     filter{(created_at >= (Sequel::CURRENT_DATE - number_of_days)) & 
                            (created_at <= Sequel::CURRENT_DATE)}
     
# #<Sequel::SQLite::Dataset:
# "SELECT `created_at`, count(*) AS 'count' 
# FROM `visits` 
# WHERE ((`link_short` = 'google') AND 
# (`created_at` >= (date(CURRENT_TIMESTAMP, 'localtime') - 10)) AND (`created_at` <= date(CURRENT_TIMESTAMP, 'localtime'))) 
# GROUP BY `created_at`">

#<Sequel::Postgres::Dataset: 
# "SELECT \"created_at\", count(*) AS \"count\" 
# FROM \"visits\" WHERE ((\"link_short\" = 'google') AND 
# (\"created_at\" >= (CURRENT_DATE - 10)) AND (\"created_at\" <= CURRENT_DATE)) 
# GROUP BY \"created_at\"">


p query2.all
# SQLite, Postgres:
# => []


query3 = DB[:visits].group_and_count(:created_at).
                     filter(:link_short => short).
                     filter{(created_at >= date(Sequel::CURRENT_DATE, "'-? days'".lit(number_of_days.to_i))) & 
                            (created_at <= date(Sequel::CURRENT_DATE,'+1 day'))}

# #<Sequel::SQLite::Dataset: 
# "SELECT `created_at`, count(*) AS 'count' FROM `visits` 
# WHERE ((`link_short` = 'google') AND 
# (`created_at` >= date(date(CURRENT_TIMESTAMP, 'localtime'), '-10 days')) AND 
# (`created_at` <= date(date(CURRENT_TIMESTAMP, 'localtime'), '+1 day'))) 
# GROUP BY `created_at`">


p query3.all
# => [{:created_at=>2012-06-20 16:39:11 +0800, :count=>1}]



# During Testing:
DB.drop_table(:urls, :visits, :links)




