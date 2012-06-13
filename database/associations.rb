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

# Methods added:

# 1) 
# -- many_to_ONE
# -- one_to_ONE

# Setter
# @album.artist = Artist.create(:name=>'YJM')

# 2) 
# -- many_to_MANY
# -- one_to_MANY

# add_*, remove_*, remove_all
# @artist.add_album(@album)       # associate an object to the current object
# @artist.remove_album(@album)    # dissociate an object from the current object
# @artist.remove_all_albums       # dissociate all currently associated objects


# Getter
# @artist.albums
# @album.artists






