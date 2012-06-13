DB.create_table? :urls do
  String      :original, :size => 255, :unique => true
  String      :short,    :size => 20, :primary_key => true
  DateTime    :created_at
end

DB.create_table? :visits do
  primary_key :id
  inet        :ip
  String      :country, :size => 255
  DateTime    :created_at
  foreign_key :url_short, :urls, :type => String, :on_delete => :cascade
end

class Url < Sequel::Model
 one_to_many :visit
end


class Visit < Sequel::Model
  many_to_one :url
end

