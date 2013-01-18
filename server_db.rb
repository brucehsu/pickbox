require 'data_mapper'
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/server.db")

class User
    include DataMapper::Resource

    property :id, Serial
    property :username, String, :unique => true
    property :password, String
    property :dir_hash, String
    property :db_hash, String
end

DataMapper.auto_upgrade!
DataMapper.finalize