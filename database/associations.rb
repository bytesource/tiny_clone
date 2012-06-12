require 'sequel'

# ---------------------------------
# Setting Associations


# If you want to setup a 1-1 relationship between two models,
# you have to use many_to_one in one model,
# and one_to_one in the other model. 
# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html

# The simplest way to remember is that 
# -- The model whose table stores a reference of a primary key 
#    from another table as a foreign key (the child table) 
#    uses many_to_one,
# -- The other model uses one_to_one:
class Url < Sequel::Model
 # :key => :short probably not necessary.
 # :short is a well defined primary key, so there will be a link_short foreign key here
 # pointing to :short
 many_to_one :link #, :key => :short 
end

class Link < Sequel::Model
  one_to_one  :url #, :key => :short
  one_to_many :visit
end

class Visit < Sequel::Model
  many_to_one :link # , :key => :short
end