# First do the following:

# MYSQL
# sudo apt-get install libmysqlclient-dev
# gem install dm-mysql-adapter

# POSTGRESQL
# 1) Install postgres adapter first:
#    sudo apt-get install libpq-dev
#    NOTE: To avoid dependency issues, make sure that the Ubuntu's security repository is checked.
# 2) gem install dm-postgres-adapter

# gem install data_mapper

# TABLE CREATE cloning

require 'data_mapper'

DataMapper.setup(:default, 'mysql://root:xxx@localhost/cloning')

class User
  include DataMapper::Resource
  property :id, Serial
  has n, :books, :through => Resource
end

class Book
  include DataMapper::Resource
  property :id, Serial
  has n, :users, :through => Resource
end

DataMapper.finalize

DataMapper.auto_migrate!

# Usage

user1 = User.create
book1 = Book.create

user1.books << book1

user1.save

p user1.books.to_a

