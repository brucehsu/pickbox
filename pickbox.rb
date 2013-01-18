PICKBOX_PATH = ''
PICKBOX_SERVER_URL = ''

$LOAD_PATH << PICKBOX_PATH

require 'yaml'
require 'rest-client'
require 'io/console'
require 'filefunc'
require 'pbkdf256'
require 'openssl'
require 'json'

config_path = File.join(Dir.home,'.pickbox.yaml')
dir_path = File.join(Dir.pwd,'.dir.yaml')

# Register
unless File.exists? config_path
    puts '--Register--'
    print 'Username: '
    username = STDIN.gets.strip
    print 'Password: '
    passwd = STDIN.noecho(&:gets).strip

    salt = OpenSSL::Random.random_bytes(16)
    user = PBKDF256.pbkdf2_sha256(username, salt, 1353, 16).unpack('H*')[0]

    pass = PBKDF256.pbkdf2_sha256(passwd, salt, 1353, 16).unpack('H*')[0]

    RestClient.post("#{PICKBOX_SERVER_URL}/register",{:username=>user, :password=>pass})

    passwd = aes256_encrypt(username,passwd)

    config = File.new(config_path,'w')
    config.write({:username=>username, :password=>passwd,:salt=>salt}.to_yaml)
    config.flush
    config.close
end

config = YAML::load(File.new(config_path))

username = config[:username]
username_token = PBKDF256.pbkdf2_sha256(username, config[:salt], 1353, 16).unpack('H*')[0]
password = aes256_decrypt(username,config[:password])
password_token = PBKDF256.pbkdf2_sha256(password, config[:salt], 1353, 16).unpack('H*')[0]

dir_structure = {}

# Build local directory structure if current directory isn't initialized
unless File.exists? dir_path
    build_dir_structure(Dir.pwd+File::SEPARATOR,Dir.pwd,dir_structure, password)
    output = File.new(dir_path,'w')
    output.write(dir_structure.to_yaml)
    output.flush
    output.close
end

dir_structure = YAML::load(File.new(dir_path))

if ARGV[0]=='sync'
    remote_dir = RestClient.post("#{PICKBOX_SERVER_URL}/get_dir",{:username=>username_token, :password=>password_token})
    if remote_dir.empty?
        params = {:username=>username_token, :password=>password_token}
        encrypted_dir = aes256_encrypt(password,IO.read('.dir.yaml')).unpack('H*')[0]
        params[:file] = encrypted_dir
        params[:cipher_hash] = Digest::SHA256.digest(encrypted_dir).to_s.unpack('H*')[0]
        RestClient.post("#{PICKBOX_SERVER_URL}/upload_dir",params)
    else
        decrypted_dir = aes256_decrypt(password,[remote_dir].pack('H*'))
        unless Digest::SHA256.digest(decrypted_dir).to_s.unpack('H*')[0] == get_file_hash('.dir.yaml')
            # Merge
            remote_dir_yaml = YAML::load(decrypted_dir)
            dir_structure.merge!(remote_dir_yaml)
            output = File.new(dir_path,'w')
            output.write(dir_structure.to_yaml)
            output.flush
            output.close
        end
    end
    update_dir(dir_path,dir_structure,password)  
    params = {:username=>username_token, :password=>password_token}
    encrypted_dir = aes256_encrypt(password,IO.read('.dir.yaml')).unpack('H*')[0]
    params[:file] = encrypted_dir
    params[:cipher_hash] = Digest::SHA256.digest(encrypted_dir).to_s.unpack('H*')[0]
    RestClient.post("#{PICKBOX_SERVER_URL}/upload_dir",params)
elsif ARGV[0]=='rev'
    if ARGV[1].nil?
        puts 'usage: pickbox rev [file]'
        exit 13
    end
    # list all revision
    revs = dir_structure[ARGV[1]]
    revs.each do |k,v|
        puts "\t#{v[:cipher_hash][0..7]}\t#{Time.at(k)}"
    end
elsif ARGV[0]=='revert'
    if ARGV[1].nil? and ARGV[2].nil?
        puts 'usage: pickbox revert [file] [rev]'
        exit 13
    end

    revs = dir_structure[ARGV[1]]
    timestamp = nil
    revs.each do |k,v|
        if v[:cipher_hash][0..7]==ARGV[2]
            timestamp = k
            break
        end
    end
    if timestamp.nil?
        puts 'Revision does not exist'
        exit 14
    end
    remote_file_cipher = [RestClient.get("#{PICKBOX_SERVER_URL}/#{revs[timestamp][:cipher_hash]}")].pack('H*')
    decrypt_key = aes256_decrypt(password,[revs[timestamp][:key]].pack('H*'))
    decrypted_file = aes256_decrypt(decrypt_key,remote_file_cipher)
    output = File.new(ARGV[1],'w')
    output.write(decrypted_file)
    output.flush
    output.close
end