PICKBOX_PATH = ''

$LOAD_PATH << PICKBOX_PATH
require 'rubygems'
require 'sinatra'
require 'server_db'
require 'filefunc'

get '/:cipher_hash' do
    raise Sinatra::NotFound unless File.exists?(File.join(Dir.pwd,'files',params[:cipher_hash]))

    send_file File.join(Dir.pwd,'files',params[:cipher_hash])
end

get '/exists/:cipher_hash' do
    File.exists?(File.join(Dir.pwd,'files',params[:cipher_hash])) ? 'true' : nil
end

post '/register' do
    user = User.new
    user.username = params[:username]
    user.password = params[:password]

    user.save!
end

post '/get_dir' do
    user = User.first(:username=>params[:username])
    status 500 if user.nil?
    status 401 unless params[:password]==user.password

    return nil if user.dir_hash.nil?

    if File.exists?(File.join(Dir.pwd,'files', user.dir_hash))
        send_file File.join(Dir.pwd,'files', user.dir_hash)
    else
        nil
    end
end

post '/upload_dir' do
    Dir::mkdir('files') unless File.exists? 'files'
    user = User.first(:username=>params[:username])
    status 500 if user.nil?
    status 401 unless params[:password]==user.password

    output_path = File.join('files',params[:cipher_hash])
    output = File.new(output_path,'w')
    output.write(params[:file])
    output.flush
    output.close

    user.dir_hash = params[:cipher_hash]
    user.save!
end

post '/upload' do
    Dir::mkdir('files') unless File.exists? 'files'
    # user = User.first(:username=>params[:username])
    # status 500 if user.nil?
    # status 401 unless params[:password]==user.password

    output_path = File.join('files',params[:cipher_hash])
    output = File.new(output_path,'w')
    output.write(params[:file])
    output.flush
    output.close
end