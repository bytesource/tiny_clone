require 'sequel'


# Creating Tables 

DB.create_table :urls do
  primary_key :id
  String      :original
end


DB.create_table :links do 
  primary_key :id   # don't need this one
  String      :identifier # make this the primary key (look up how to do)
  DateTime    :created_at
end

DB.create_table :visits do
  primary_key :id
  String      :ip
  String      :country
  DateTime    :created_at
end

# ---------------------------------
# Setting Associations


# If you want to setup a 1-1 relationship between two models,
# you have to use many_to_one in one model,
# and one_to_one in the other model. 
# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html

# The simplest way to remember is that 
# -- the model whose table has the foreign key uses many_to_one,
# -- the other model uses one_to_one:
class Url
 one_to_one :link, :key => identifier
end

class Link
  many_to_one :url, :key => identifier
  one_to_many :visit
end

class Visit
  many_to_one :link
  
end