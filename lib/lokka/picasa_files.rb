$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '..'))
require 'picasa'
require 'dalli'

module Lokka
  module PicasaFiles
    @@picasa = Picasa::Picasa.new
    @@dc = Dalli::Client.new(ENV['MEMCACHE_SERVERS'] || 'localhost:11211')

    alive = nil
    @@dc.stats.each do |k, v|
      alive = v unless v.nil?
    end
    @@dc = nil if alive.nil?

    def self.registered(app)
      app.before do
        path = request.env['PATH_INFO']

        if /^(\/admin\/(posts|pages)\/new|\/admin\/(posts|pages)\/\d*\/edit)$/ =~ path
          haml :"plugin/lokka-picasa_files/views/editor_plugin", :layout => false
        elsif /^\/admin/ =~ path
          haml :"plugin/lokka-picasa_files/views/aside", :layout => false
        end

        if @@picasa.picasa_session.nil?
          unless @@picasa.login(Option.picasa_email, Option.picasa_password).nil?
            @@picasa.picasa_session.auth_key
          end
        end
      end 

      app.get '/admin/plugins/picasa/upload_files' do
        album = Option.picasa_album.blank? ? 'Lokka' : Option.picasa_album
        @photos = @@picasa.photos(:album => album)
        begin
          @@dc.set('photos', @photos) unless @@dc.nil?
        rescue
        end
        haml :'plugin/lokka-picasa_files/views/index', :layout => :'admin/layout'
      end 

      app.get '/admin/plugins/picasa/upload_files/new' do
        @photo = Picasa::Photo.new
        haml :'plugin/lokka-picasa_files/views/new', :layout => :'admin/layout'
      end 

      app.post '/admin/plugins/picasa/upload_files' do
        album = Option.picasa_album.blank? ? 'Lokka' : Option.picasa_album

        album_names = []
        @@picasa.albums(:access => 'all').each {|a| album_names.push a.name}
        @@picasa.create_album(:title => album) unless album_names.include?(album)

        @photo = @@picasa.post_photo(
          params[:file][:tempfile].read,
          :album => album, 
          :title => params['title'],
          :description => params['description'],
          :content_type => params[:file][:type],
          :local_file_name => params[:file][:filename]
        )
        if @photo.nil?
          @photo = Picasa::Photo.new
          @photo.title = params['title']
          @photo.description = params['description']
          flash[:notice] = t.picasa_failed_to_upload
        else
          flash[:notice] = t.picasa_file_was_successfully_uploaded
          redirect '/admin/plugins/picasa/upload_files'
        end
        haml :'plugin/lokka-picasa_files/views/new', :layout => :'admin/layout'
      end

      app.get '/admin/plugins/picasa/upload_files/:photo_id/:album_id/edit' do |photo_id, album_id|
        @photo = @@picasa.load_photo_with_id(photo_id, album_id)
        haml :'plugin/lokka-picasa_files/views/edit', :layout => :'admin/layout'
      end

      app.put '/admin/plugins/picasa/upload_files/:photo_id/:album_id' do |photo_id, album_id|
        @photo = @@picasa.load_photo_with_id(photo_id, album_id)
        @photo.title = params['title']
        @photo.description = params['description']
        image_data = nil
        if params[:file]
          image_data = params[:file][:tempfile].read
          @photo.type = params[:file][:type]
        end
        if @photo.update(image_data)
          flash[:notice] = t.picasa_file_was_successfully_updated
          redirect '/admin/plugins/picasa/upload_files'
        else
          flash[:notice] = t.picasa_failed_to_update
        end
        haml :'plugin/lokka-picasa_files/views/edit', :layout => :'admin/layout'
      end

      app.delete '/admin/plugins/picasa/upload_files/:photo_id/:album_id' do |photo_id, album_id|
        photo = @@picasa.load_photo_with_id(photo_id, album_id)
        flash[:notice] = t.picasa_failed_to_delete
        unless photo.nil?
          if @@picasa.delete_photo(photo)
            flash[:notice] = t.picasa_file_was_successfully_deleted
          end
        end
        redirect '/admin/plugins/picasa/upload_files'
      end

      app.get '/admin/plugins/picasa/files' do
        begin
          @photos = @@dc.nil? ? nil : @@dc.get('photos')
          if @photos.nil?
            @photos = @@picasa.photos(:album => Option.picasa_album)
            @@dc.set('photos', @photos) unless @@dc.nil?
          end
        rescue
            @photos = @@picasa.photos(:album => Option.picasa_album)
        end
        haml :'plugin/lokka-picasa_files/views/list', :layout => false
      end

      app.get '/admin/plugins/picasa_files' do
        haml :'plugin/lokka-picasa_files/views/setting', :layout => :'admin/layout'
      end 

      app.put '/admin/plugins/picasa_files' do
        email = params['picasa_email']
        password = params['picasa_password']
        if @@picasa.login(email, password).nil?
          flash[:notice] = t.picasa_failed_to_update
        else
          flash[:notice] = t.picasa_updated
          Option.picasa_email = email
          Option.picasa_password = password
          Option.picasa_album = params['picasa_album'].blank? ? 'Lokka' : params['picasa_album']
          @@picasa.picasa_session.auth_key
        end
        redirect '/admin/plugins/picasa_files'
      end 
    end 
  end 

  module Helpers
    def file_readable_size(filesize)
      if filesize.to_f / 1024 >= 1024
        sprintf("%.1fMB", filesize.to_f / 1024 / 1024)
      elsif filesize.to_f / 1024 >= 1
        sprintf("%.fKB", filesize.to_f / 1024)
      else
        return filesize.to_s + "byte" + (filesize > 1 ? "s" : "")
      end
    end
  end
end
