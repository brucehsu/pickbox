require 'aesfunc'

def encrypt_file(filename, password)
    content = IO.read(filename)
    content_hash = Digest::SHA256.digest(content)
    file_cipher = aes256_encrypt(content_hash, content).unpack('H*')[0]
    hash_cipher = aes256_encrypt(password, content_hash).unpack('H*')[0]
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
            dir_hash[dir_key][Time.now.to_i] = {:cipher_hash=>Digest::SHA256.digest(encrypted[:file]).unpack('H*')[0],:key=>encrypted[:hash]}
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
                dir_hash[k][Time.now.to_i] = {:cipher_hash=>encrypted_cipher_hash, :key=>encrypted[:hash]}
                RestClient.post("#{PICKBOX_SERVER_URL}/upload",params)
            else
                # Check if local copy is at the latest revision
                p v[latest_rev][:key]
                unless encrypted_cipher_hash == v[latest_rev][:key]
                    remote_file_cipher = [RestClient.get("#{PICKBOX_SERVER_URL}/#{v[latest_rev][:cipher_hash]}")].pack('H*')
                    decrypt_key = aes256_decrypt(password,[v[latest_rev][:key]].pack('H*'))
                    decrypted_file = aes256_decrypt(decrypt_key,remote_file_cipher)
                    output = File.new(k,'w')
                    output.write(decrypted_file)
                    output.flush
                    output.close
                end
            end
        else
            remote_file_cipher = [RestClient.get("#{PICKBOX_SERVER_URL}/#{v[latest_rev][:cipher_hash]}")].pack('H*')
            decrypt_key = aes256_decrypt(password,[v[latest_rev][:key]].pack('H*'))
            decrypted_file = aes256_decrypt(decrypt_key,remote_file_cipher)

            FileUtils.mkpath(k.split(k.split(File::SEPARATOR).last)[0]) if k.include? File::SEPARATOR
            output = File.new(k,'w')
            output.write(decrypted_file)
            output.flush
            output.close
        end
    end

    output = File.new(dir_path,'w')
    output.write(dir_hash.to_yaml)
    output.flush
    output.close
end