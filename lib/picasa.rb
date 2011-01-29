# Copyright (c) 2008 Code71 Bangladesh
# http://www.code71.com/
# http://code.google.com/p/picasaonrails/
#
# Modified for Lokka plugin by nkmrshn
# http://lokka.org/
#
# - fixed to set milliseconds for gphoto:timestamp 
# - fixed to delete undefined prefix
# - modifed Picasa.post_photo to post description
# - modifed Photo.update to update image data
# - modifed 'source' in Picasa.login for Lokka plugin
#
require 'rubygems'
require 'cgi'
require 'net/https'
require 'net/http'
require 'xmlsimple'

module Picasa
  
  class PicasaSession
    attr_accessor :auth_key
    attr_accessor :user_id
  end

  class Picasa
    attr_accessor :picasa_session

    def login(email, password)
      url = "https://www.google.com/accounts/ClientLogin"
      source = "Lokka-Picasa-0.0.1" # source will be of CompanyName-ProjectName-ProjectVersion format
    
      uri = URI.parse(url)

      request = Net::HTTP.new(uri.host, uri.port)
      request.use_ssl = true
      request.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response, data = request.post(uri.path, "accountType=HOSTED_OR_GOOGLE&Email=#{email}&Passwd=#{password}&service=lh2&source=#{source}")
  
      authMatch = Regexp.compile("(Auth=)([A-Za-z0-9_\-]+)\n").match(data.to_s)
      if authMatch
        authorizationKey = authMatch[2].to_s # substring that matched the pattern ([A-Za-z0-9_\-]+)
      end
    
      unless authorizationKey.nil?
        self.picasa_session = PicasaSession.new
        self.picasa_session.auth_key = authorizationKey
        self.picasa_session.user_id = email
      end
    
      return authorizationKey
    end
    
    def album(options = {})
      
      if(options[:name] == nil)
        return nil
      end
      
      albums = self.albums(options)
      for album in albums
        if(album.name == options[:name])
          return album
        end
      end
      
      return nil
    end
    
    def albums(options = {})
      
      userId = options[:user_id] == nil ? self.picasa_session.user_id : options[:user_id]
      access = options[:access] == nil ? "public" : options[:access]
      url = "http://picasaweb.google.com/data/feed/api/user/#{userId}?kind=album&access=#{access}"
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
    
      headers = {"Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, xml_response = http.get(uri.path, headers)
      
      #xml_response = Net::HTTP.get_response(URI.parse(url)).body.to_s
      albums = create_albums_from_xml(xml_response)
    
      return albums
    end
    
    def photos(options = {})
      
      options[:user_id] = options[:user_id].nil? ? self.picasa_session.user_id : options[:user_id]
      options[:album] = options[:album].nil? ? "" : options[:album]
      
      album = Album.new
      album.picasa_session = self.picasa_session
      photos = album.photos(options)
      
      return photos
    end
    
    def create_album(options = {})
      
      title = options[:title].nil? ? "" : options[:title]
      summary = options[:summary].nil? ? "" : options[:summary]
      location = options[:location].nil? ? "" : options[:location]
      access = options[:access].nil? ? "public" : options[:access]
      commentable = options[:commentable].nil? ? "true" : options[:commentable].to_s
      keywords = options[:keywords].nil? ? "" : options[:keywords]
      mtime = sprintf("%.3f", Time.now.to_f).gsub('.','')
      
      createAlbumRequestXml = "<entry xmlns='http://www.w3.org/2005/Atom'
                    xmlns:media='http://search.yahoo.com/mrss/'
                    xmlns:gphoto='http://schemas.google.com/photos/2007'>
                      <title type='text'>#{title}</title>
                      <summary type='text'>#{summary}</summary>
                      <gphoto:location>#{location}</gphoto:location>
                      <gphoto:access>#{access}</gphoto:access>
                      <gphoto:commentingEnabled>#{commentable}</gphoto:commentingEnabled>
                      <gphoto:timestamp>#{mtime}</gphoto:timestamp>
                      <media:group>
                        <media:keywords>#{keywords}</media:keywords>
                      </media:group>
                      <category scheme='http://schemas.google.com/g/2005#kind'
                        term='http://schemas.google.com/photos/2007#album'></category>
                    </entry>"
      
      url = "http://picasaweb.google.com/data/feed/api/user/#{self.picasa_session.user_id}"

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
    
      headers = {"Content-Type" => "application/atom+xml", "Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, data = http.post(uri.path, createAlbumRequestXml, headers)
      
      album = create_album_from_xml(data)
      return album
    end
    
    def load_album(album_url)
      uri = URI.parse(album_url)
      http = Net::HTTP.new(uri.host, uri.port)
    
      headers = {"Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, album_entry_xml_response = http.get(uri.path, headers)
      
      if(response.code == "200")
        #parse the entry xml element and get the photo object
        album = self.create_album_from_xml(album_entry_xml_response)
        return album
      else
        return nil
      end
    end
    
    def load_album_with_id(album_id)
      album_url = "http://picasaweb.google.com/data/entry/api/user/#{self.picasa_session.user_id}/albumid/#{album_id}"
      
      return load_album(album_url)
    end
    
    def load_photo(photo_url)
      uri = URI.parse(photo_url)
      http = Net::HTTP.new(uri.host, uri.port)
    
      headers = {"Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, photo_entry_xml_response = http.get(uri.path, headers)
      
      if(response.code == "200")
        #parse the entry xml element and get the photo object
        photo = self.create_photo_from_xml(photo_entry_xml_response)
        return photo
      else
        return nil
      end
    end
    
    def load_photo_with_id(photo_id, album_id)
      photo_url = "http://picasaweb.google.com/data/entry/api/user/#{self.picasa_session.user_id}/albumid/#{album_id}/photoid/#{photo_id}"
      
      return load_photo(photo_url)
    end
    
    def post_photo(image_data = nil, options = {})
      summary = options[:summary] == nil ? "" : options[:summary]
      album_name = options[:album] == nil ? "" : options[:album]
      album_id = options[:album_id] == nil ? "" : options[:album_id]
      local_file_name = options[:local_file_name] == nil ? "" : options[:local_file_name]
      title = options[:title] == nil ? local_file_name : options[:title]
      description = options[:description] == nil ? "" : options[:description]
      content_type = options[:content_type] == nil ? "" : options[:content_type]
      
      if(image_data == nil)
        return nil
        # Or throw an exception in next update
      end

      unless(%w(image/bmp image/gif image/jpeg image/png).include?(content_type))
        return nil
      end
      
      if(album_id != "")
        url = "http://picasaweb.google.com/data/feed/api/user/#{self.picasa_session.user_id}/albumid/#{album_id}"
      else
        url = "http://picasaweb.google.com/data/feed/api/user/#{self.picasa_session.user_id}/album/#{album_name}"
      end

      postPhotoXml = "<entry xmlns='http://www.w3.org/2005/Atom'>
                      <title>#{title}</title>
                      <summary>#{description}</summary>
                      <category scheme='http://schemas.google.com/g/2005#kind'
                      term='http://schemas.google.com/photos/2007#photo'/>
                      </entry>"

      boundary = "PICASA"

      headers = {"Content-Type" => "multipart/related; boundary=#{boundary}", 
                 "Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      body = "" 
      body.concat("\nMedia multipart posting\n")
      body.concat("--#{boundary}\n")
      body.concat("Content-Type: application/atom+xml\n")
      body.concat("\n#{postPhotoXml}\n")
      body.concat("--#{boundary}\n")
      body.concat("Content-Type: #{content_type}\n\n")
      body.concat(image_data)
      body.concat("\n--#{boundary}--\n")

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)

      response, data = http.post(uri.path, body, headers)
      photo = create_photo_from_xml(data)
      
      return photo
    end

    def delete_photo(photo)
      url = photo.edit_url
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      
      headers = {"Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, data = http.delete(uri.path, headers)
      
      if(response.code == "200")
        return true
      else
        return false
      end
      
    end
    
    def delete_album(album)
      url = album.edit_url
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      
      headers = {"Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, data = http.delete(uri.path, headers)
      
      if(response.code == "200")
        return true
      else
        return false
      end
      
    end
    
    def create_albums_from_xml(xml_response)
      albums = []
      #response_hash = XmlSimple.xml_in(xml_response, { 'ForceArray' => false })
      #puts response_hash.inspect
    
      document = REXML::Document.new(Util.remove_undefined_prefix(xml_response))
      document.elements.each('feed/entry') do |entry|
        #parse the entry xml element and get the album object
        album = Picasa.parse_album_entry(entry)
        
        #enter session values in album object
        album.picasa_session = PicasaSession.new
        album.picasa_session.auth_key = self.picasa_session.auth_key
        album.picasa_session.user_id = self.picasa_session.user_id
      
        albums << album
      end
    
      return albums
    end
  
    def create_album_from_xml(xml_response)
      album = nil
      
      document = REXML::Document.new(xml_response)
      document.elements.each('entry') do |entry|
        #parse the entry xml element and get the album object
        album = Picasa.parse_album_entry(entry)
        
        #enter session values in album object
        album.picasa_session = PicasaSession.new
        album.picasa_session.auth_key = self.picasa_session.auth_key
        album.picasa_session.user_id = self.picasa_session.user_id
      end
    
      return album
    end
    
    def create_photo_from_xml(xml_response)
      photo = nil
      
      document = REXML::Document.new(xml_response)
      document.elements.each('entry') do |entry|
        #parse the entry xml element and get the photo object
        photo = Picasa.parse_photo_entry(entry)
        
        #enter session values in photo object
        photo.picasa_session = PicasaSession.new
        photo.picasa_session.auth_key = self.picasa_session.auth_key
        photo.picasa_session.user_id = self.picasa_session.user_id
      end
    
      return photo
    end
    
    def self.parse_album_entry(album_entry_xml)
      album_hash = XmlSimple.xml_in(album_entry_xml.to_s, { 'ForceArray' => false })
      
      album = Album.new
      album.xml = album_entry_xml.to_s
        
      album.id = album_hash["id"][1]
      album.name = album_hash["name"]
      album.user = album_hash["user"]
      album.number_of_photos = album_hash["numphotos"]
      album.number_of_comments = album_hash["commentCount"]
      album.is_commentable = album_hash["commentingEnabled"] == true ? true : false
      album.access = album_hash["access"]
            
      album.author_name = album_hash["author"]["name"]
      album.author_uri = album_hash["author"]["uri"]
      
      album.title = album_hash["group"]["title"]["content"]
      album.title_type = album_hash["group"]["title"]["type"]
      album.description = album_hash["group"]["description"]["content"]
      album.description_type = album_hash["group"]["description"]["type"]
      album.image_url = album_hash["group"]["content"]["url"]
      album.image_type = album_hash["group"]["content"]["type"]
      album.thumbnail = Thumbnail.new()
      album.thumbnail.url = album_hash["group"]["thumbnail"]["url"]
      album.thumbnail.width = album_hash["group"]["thumbnail"]["width"]
      album.thumbnail.height = album_hash["group"]["thumbnail"]["height"]
      
      # make self xml url
      links_from_hash = album_hash["link"]
      if(links_from_hash.respond_to?(:each))
        links_from_hash.each do |link|
          if(link["rel"] == "self")
            album.self_xml_url = link["href"]
          elsif(link["rel"] == "edit")
            album.edit_url = link["href"]
          end
        end
      else
        album.self_xml_url = nil
        album.edit_url = nil
      end
      
      return album
    end
    
    def self.parse_photo_entry(photo_entry_xml)
      photo_hash = XmlSimple.xml_in(photo_entry_xml.to_s, { 'ForceArray' => false })
      
      photo = Photo.new
      photo.xml = photo_entry_xml.to_s
      
      photo.id = photo_hash["id"][1]
      photo.album_id = photo_hash["albumid"]
      photo.version_number = photo_hash["version"]
      photo.is_commentable = photo_hash["commentingEnabled"]
      photo.size = photo_hash["size"]
      photo.client = photo_hash["client"]
      photo.title = photo_hash["group"]["title"]["content"]
      photo.description = photo_hash["group"]["description"]["content"]
      photo.url = photo_hash["group"]["content"]["url"]
      photo.width = photo_hash["group"]["content"]["width"]
      photo.height = photo_hash["group"]["content"]["height"]
      photo.type = photo_hash["group"]["content"]["type"]
      photo.medium = photo_hash["group"]["content"]["medium"]
      
      # make thumbnails
      photo.thumbnails = []
      thumbnails_from_hash = photo_hash["group"]["thumbnail"]
      if(thumbnails_from_hash.respond_to?(:each))
        thumbnails_from_hash.each do |thumb|
          thumbnail = Thumbnail.new
          thumbnail.url = thumb["url"]
          thumbnail.width = thumb["width"]
          thumbnail.height = thumb["height"]
            
          photo.thumbnails << thumbnail
        end
      else
          
      end
      
      # make self xml url
      links_from_hash = photo_hash["link"]
      if(links_from_hash.respond_to?(:each))
        links_from_hash.each do |link|
          if(link["rel"] == "self")
            photo.self_xml_url = link["href"]
          elsif(link["rel"] == "edit")
            photo.edit_url = link["href"]
          end
        end
      else
        photo.self_xml_url = nil
        photo.edit_url = nil
      end
      
      return photo
    end
    
  end
  
  class Album
    attr_accessor :picasa_session
    
    attr_accessor :id, :name
    attr_accessor :user
    attr_accessor :title, :title_type
    attr_accessor :description, :description_type
    attr_accessor :access
    attr_accessor :author_name, :author_uri
    attr_accessor :number_of_photos, :number_of_comments
    attr_accessor :is_commentable
    attr_accessor :image_url, :image_type
    attr_accessor :thumbnail
    attr_accessor :xml
    attr_accessor :self_xml_url, :edit_url
    
    def initialize()
      thumbnail = Thumbnail.new()
    end
    
    def photos(options = {})
      
      userId = options[:user_id].nil? ? self.user : options[:user_id]
      albumName = options[:album].nil? ? self.name : options[:album]
      albumId = options[:album_id].nil? ? self.id : options[:album_id]
      
      if(albumId != nil && albumId != "")
        url = "http://picasaweb.google.com/data/feed/api/user/#{userId}/albumid/#{albumId}?kind=photo"
      else
        url = "http://picasaweb.google.com/data/feed/api/user/#{userId}/album/#{albumName}?kind=photo"
      end
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
    
      headers = {"Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, xml_response = http.get(uri.path, headers)
      photos = self.create_photos_from_xml(xml_response)
      
      return photos
    end
    
    def create_photos_from_xml(xml_response)
      photos = []
      #response_hash = XmlSimple.xml_in(xml_response, { 'ForceArray' => false })
      #puts response_hash.inspect
    
      document = REXML::Document.new(Util.remove_undefined_prefix(xml_response))
      document.elements.each('feed/entry') do |entry|
        #parse the entry xml element and get the photo object
        photo = Picasa.parse_photo_entry(entry)
        
        #enter session values in photo object
        photo.picasa_session = PicasaSession.new
        photo.picasa_session.auth_key = self.picasa_session.auth_key
        photo.picasa_session.user_id = self.picasa_session.user_id
        
        photos << photo
      end
    
      return photos
    end
    
  end
    
  class Photo
    attr_accessor :picasa_session
    
    attr_accessor :id
    attr_accessor :title, :description
    attr_accessor :album_id
    attr_accessor :size
    attr_accessor :client
    attr_accessor :is_commentable, :number_of_comments
    attr_accessor :url, :width, :height, :type, :medium
    attr_accessor :thumbnails
    attr_accessor :xml
    attr_accessor :version_number
    attr_accessor :self_xml_url, :edit_url
    
    def initialize()
      thumbnails = []
    end
    
    def update(image_data = nil)
      mtime = sprintf("%.3f", Time.now.to_f).gsub('.','')
      updatePhotoXml = "<entry xmlns='http://www.w3.org/2005/Atom'
                    xmlns:media='http://search.yahoo.com/mrss/'
                    xmlns:gphoto='http://schemas.google.com/photos/2007'>
                      <title type='text'>#{self.title}</title>
                      <summary type='text'>#{self.description}</summary>
                      <gphoto:checksum></gphoto:checksum>
                      <gphoto:client></gphoto:client>
                      <gphoto:rotation>#{0}</gphoto:rotation>
                      <gphoto:timestamp>#{mtime}</gphoto:timestamp>
                      <gphoto:commentingEnabled>#{self.is_commentable.to_s}</gphoto:commentingEnabled>
                      <category scheme='http://schemas.google.com/g/2005#kind'
                        term='http://schemas.google.com/photos/2007#photo'></category>
                    </entry>"
      
      url = "http://picasaweb.google.com/data/"

      if image_data.nil?
        url.concat("entry")
        headers = {"Content-Type" => "application/atom+xml", "Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}
        body = updatePhotoXml
      else
        return false unless %w(image/bmp image/gif image/jpeg image/png).include?(self.type)

        boundary = "PICASA"
        url.concat("media")

        headers = {"Content-Type" => "multipart/related; boundary=#{boundary}", "Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

        body = ""
        body.concat("\nMedia multipart posting\n")
        body.concat("--#{boundary}\n")
        body.concat("Content-Type: application/atom+xml\n")
        body.concat("\n#{updatePhotoXml}\n")
        body.concat("--#{boundary}\n")
        body.concat("Content-Type: #{self.type}\n\n")
        body.concat(image_data)
        body.concat("\n--#{boundary}--\n")
      end
      url.concat("/api/user/#{self.picasa_session.user_id}/albumid/#{self.album_id}/photoid/#{self.id}/#{self.version_number}")

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)

      response, data = http.put(uri.path, body, headers)

      if(response.code == "200")
        #parse the entry xml element and get the photo object
        new_photo = Picasa.parse_photo_entry(data)
        self.version_number = new_photo.version_number
        
        return true
      else
        return false
      end
    end
    
    def move_to_album(picasa_album_id)
      mtime = sprintf("%.3f", Time.now.to_f).gsub('.','')
      updatePhotoXml = "<entry xmlns='http://www.w3.org/2005/Atom'
                    xmlns:media='http://search.yahoo.com/mrss/'
                    xmlns:gphoto='http://schemas.google.com/photos/2007'>
                      <title type='text'>#{self.title}</title>
                      <summary type='text'>#{self.description}</summary>
                      <gphoto:albumid>#{picasa_album_id}</gphoto:albumid>
                      <gphoto:checksum></gphoto:checksum>
                      <gphoto:client></gphoto:client>
                      <gphoto:rotation>#{0}</gphoto:rotation>
                      <gphoto:timestamp>#{mtime}</gphoto:timestamp>
                      <gphoto:commentingEnabled>#{self.is_commentable.to_s}</gphoto:commentingEnabled>
                      <category scheme='http://schemas.google.com/g/2005#kind'
                        term='http://schemas.google.com/photos/2007#photo'></category>
                    </entry>"
      
      url = "http://picasaweb.google.com/data/entry/api/user/#{self.picasa_session.user_id}/albumid/#{self.album_id}/photoid/#{self.id}/#{self.version_number}"

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
    
      headers = {"Content-Type" => "application/atom+xml", "Authorization" => "GoogleLogin auth=#{self.picasa_session.auth_key}"}

      response, data = http.put(uri.path, updatePhotoXml, headers)
      
      if(response.code == "200")
        #parse the entry xml element and get the photo object
        new_photo = Picasa.parse_photo_entry(data)
        self.version_number = new_photo.version_number
        self.album_id = new_photo.album_id
        
        return true
      else
        return false
      end
      
    end
    
  end
  
  class Thumbnail
    attr_accessor :url, :width, :height
  end

  class Util
    def self.remove_undefined_prefix(xml_response)
      xml_response.gsub!('gphoto:', '')
      xml_response.gsub!('media:', '')
      xml_response.gsub!('georss:', '')
      xml_response.gsub!('gml:', '')
      xml_response.gsub!('exif:', '')
      return xml_response 
    end
  end
  
end
