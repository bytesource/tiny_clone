# mysql:
# create database tinyclone

require './postgres_tinyclone'
DataMapper.auto_migrate!
