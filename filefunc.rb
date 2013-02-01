require 'aesfunc'

def write_file(filename, content)
    output = File.new(filename,'w')
    output.write(content)
    output.flush
    output.close  
end

def encrypt_file(filename, password)
    content = IO.read(filename)
    content_hash = Digest::SHA256.digest(content)
    file_cipher = aes256_encrypt(content_hash, content).unpack('H*')[0]
    hash_cipher = aes256_encrypt(password, content_hash).unpack('H*')[0]
    return {:file=> file_cipher, :hash=> hash_cipher}
end

def encrypt_dir_file(password)
    filename = '.dir.yaml'
    content = IO.read(filename)
    file_cipher = aes256_encrypt(password, content).unpack('H*')[0]
    cipher_hash = Digest::SHA256.digest(file_cipher)
    hash_cipher = aes256_encrypt(password, cipher_hash).unpack('H*')[0]
    return {:file=> file_cipher, :hash=> hash_cipher}   
end

def get_file_hash(path)
    Digest::SHA256.digest(IO.read(path)).to_s.unpack('H*')[0]
end

def get_encrypted_file_hash(path, password)
    aes256_encrypt(password, get_file_hash(path))
end

def build_dir_structure(root, path, dir_hash, password)
    current = Dir.new(path)
    current.each do |file|
        next if file=='.' or file=='..'
        file_path = File.join(path, file)
        if File.directory? file_path
            build_dir_structure(root, file_path,dir_hash,password)
        else
            dir_key = file_path.split(root)[1]
            dir_hash[dir_key] = {}
            encrypted = encrypt_file(file_path,password)
            dir_hash[dir_key][File.mtime(dir_key).to_i] = {:cipher_hash=>Digest::SHA256.digest(encrypted[:file]).unpack('H*')[0],:key=>encrypted[:hash]}
        end
    end
end

def update_dir(dir_path, dir_hash,password)
    dir_hash.each do |k,v|
        puts "Updating #{k}"
        latest_rev = dir_hash[k].to_a.last[0]

        if File.exists? k
            encrypted = encrypt_file(k,password)
            encrypted_cipher_hash = Digest::SHA256.digest(encrypted[:file]).unpack('H*')[0]

            params = {}
            params[:file] = encrypted[:file]
            params[:cipher_hash] = Digest::SHA256.digest(encrypted[:file]).to_s.unpack('H*')[0]

            remote_existence = RestClient.get("#{PICKBOX_SERVER_URL}/exists/" + encrypted_cipher_hash)

            if remote_existence.empty?
                # Upload local file if it hasn't been synced to remote
                dir_hash[k][File.mtime(k).to_i] = {:cipher_hash=>encrypted_cipher_hash, :key=>encrypted[:hash]}
                RestClient.post("#{PICKBOX_SERVER_URL}/upload",params)
            else
                # Update local file if remote revision is newer
                unless encrypted_cipher_hash == v[latest_rev][:key]
                    remote_file_cipher = [RestClient.get("#{PICKBOX_SERVER_URL}/#{v[latest_rev][:cipher_hash]}")].pack('H*')
                    decrypt_key = aes256_decrypt(password,[v[latest_rev][:key]].pack('H*'))
                    decrypted_file = aes256_decrypt(decrypt_key,remote_file_cipher)
                    write_file(k, decrypted_file)
                    File.utime(Time.now, Time.at(latest_rev), k)
                end
            end
        else
            # Download remote file if such file doesn't exist locally
            remote_file_cipher = [RestClient.get("#{PICKBOX_SERVER_URL}/#{v[latest_rev][:cipher_hash]}")].pack('H*')
            decrypt_key = aes256_decrypt(password,[v[latest_rev][:key]].pack('H*'))
            decrypted_file = aes256_decrypt(decrypt_key,remote_file_cipher)

            FileUtils.mkpath(k.split(k.split(File::SEPARATOR).last)[0]) if k.include? File::SEPARATOR
            write_file(k, decrypted_file)
            File.utime(Time.now, Time.at(latest_rev), k)
        end
    end

    write_file(dir_path, dir_hash.to_yaml)
end

def list_revisions(filename, dir_hash, password)
    current_hash = encrypt_file(filename, password)[:file]
    current_hash = Digest::SHA256.digest(current_hash).unpack('H*')[0]
    revs = dir_hash[filename].to_a.reverse
    indication = false
    revs.each do |rev|
        if current_hash == rev[1][:cipher_hash] and not indication
            print '     *'
            indication = true
        end
        puts "\t#{rev[1][:cipher_hash][0..7]}\t#{Time.at(rev[0])}"
    end
end

def revert(filename, revision, dir_hash, dir_path, password)
    revs = dir_hash[filename]
    timestamp = nil
    revs.each do |k,v|
        if v[:cipher_hash][0..7]==revision
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

    write_file(ARGV[1], decrypted_file)
    revs[File.mtime(filename).to_i] = {:cipher_hash=>revs[timestamp][:cipher_hash], :key=>revs[timestamp][:key]}
    write_file(dir_path, dir_hash.to_yaml)    
end