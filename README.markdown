Lokka Picasa
===========

This is a [Lokka](http://lokka.org) plugin to upload image files to [Picasa Web Album](http://picasaweb.google.com/).

Installation
------------

Run these commands:

    $ cd APP_ROOT/public/plugin
    $ git clone git://github.com/nkmrshn/lokka-picasa_files.git
    $ cd ../..
    $ bundle install --path vendor/bundle --without production test
    $ bundle exec rake -f public/plugin/lokka-picasa_files/Rakefile db:migrate

Tips
----

If memcached is avaiable, it will try to cache the album photos list. If you want to change the server from 'localhost:11211', please modify PLUGIN_ROOT/lib/lokka/picasa_files.rb file.
