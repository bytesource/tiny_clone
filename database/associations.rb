require_relative 'tables'

# ---------------------------------
# Setting Associations

# VERY IMPORTANT
# Creating an ASSOCIATION DOESN'T MODIFY THE DATABASE SCHEMA. 
# Sequel assumes your associations reflect the existing database schema.
# If not, you should modify your schema before creating the associations.

# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
# --> Database Schema

# If you want to setup a 1-1 relationship between two models,
# you have to use 
# -- many_to_one in one model, and 
# -- one_to_one in the other model. 
# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html

# The simplest way to remember is that 
# -- The model whose table stores a reference of a primary key 
#    from another table as a foreign key (the child table) 
#    uses many_to_one,
# -- The other model uses one_to_one:
class Url < Sequel::Model # Child
 # Assumes :key is :link_id, based on ASSOCIATION name of :link    # A)
 many_to_one :link, # <-- Association name 
             :key => :link_short                       # *_to_one  => singular
             
 
end


class Link < Sequel::Model # Parent
  one_to_one  :url,    :key => :link_short  # A)
  # Assumes :key is :link_id, based on CLASS NAME of Link          # A)
  one_to_many :visits, :key => :link_short  # *_to_many => plural
  
  
  def before_create
    self.created_at ||= Time.now
    super
  end
end


# A)
# PARENT table (here: Link):       Foreign key name guessed from the table's CLASS name.
# CHILD table  (here: Url, Visit): Foreign key name guessed from the table's ASSOCIATION name.

# According to these rules, the name of the foreign key should be 'link_id'.
# However, in my schema the foreign key is named 'link_short':
# foreign_key :link_short, :links, :type => String, :on_delete => :cascade
# Therefore we have to manually specify the correct name in the associations using :key

# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
# Most Common Options => :key


class Visit < Sequel::Model
 # Assumes :key is :link_id, based on ASSOCIATION name of :link    # A)
  many_to_one :link, :key => :link_short   # :link = association name. Seems to determine the setter/getter method names.


  def before_create
    self.created_at ||= Time.now
    super # ($)
  end
end

# ($)
# The one important thing to note here is the call to super inside the hook. 
# Whenever you override one of Sequel::Model's methods, you should be calling super to get the default behavior. 


# http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#method-i-unrestrict_primary_key
Link.unrestrict_primary_key
# Allow the setting of the primary key(s) when using the mass assignment methods. 
# Using this method can open up security issues, be very careful before using it.

# Artist.set(:id=>1) # Error
# Artist.unrestrict_primary_key
# Artist.set(:id=>1) # No Error





# Methods added:

# All associations:
# 0)
# Getter  
# @artist.albums    # NOTE: method name equals association name (*_to_many => plural, *_to_one => singular)
# @album.artists

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



