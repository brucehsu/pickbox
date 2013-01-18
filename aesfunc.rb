#src: https://gist.github.com/1077760

require "digest"
require 'rubygems'
require 'aes'

 
# def aes256_encrypt(key, data)
#   key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
#   AES.encrypt(data,key)
# end
 
# def aes256_decrypt(key, data)
#   key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
#   AES.decrypt(data,key)
# end

def aes256_encrypt(key, data)
  key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
  aes = OpenSSL::Cipher::Cipher.new('AES-256-CBC')
  aes.encrypt
  aes.key = key
  aes.update(data) + aes.final
end

def aes256_decrypt(key, data)
  key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
  aes = OpenSSL::Cipher::Cipher.new('AES-256-CBC')
  aes.decrypt
  aes.key = key
  aes.update(data) + aes.final
end