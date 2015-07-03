#! /bin/sh

# Install-Script to build a OSM-Tileserver from a clean Ubuntu 14.004.2 Server Installation
# Initial Tutorial taken from: https://switch2osm.org/serving-tiles/manually-building-a-tile-server-14-04/
# Modified in several ways to be able to build a install script for easier use
# Author: dirk@blanckenhorn.de
# License of this Install Script: MIT-License, see http://opensource.org/licenses/MIT

# You must run this script with sudo.
if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you have to run this script with root privileges. Try to run 'sudo install_tileserver.sh instead."
	exit 1
fi

# Generate 8 char random string as password for the user gisuser:
for i in {0..8}; do gisuser_passwd+=$(printf "%x" $(($RANDOM%16)) ); done;

# download and install prerequisites:
apt-get install libboost-all-dev subversion git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff4-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg node-carto

# download and install postgres
apt-get install postgresql postgresql-contrib postgis postgresql-9.3-postgis-2.1

# create dbuser to run your tileserver after finished:
sudo -u postgres createuser gisuser && createdb -E UTF8 -O gisuser gis

# create same user as system user
useradd -m gisuser
echo "gisuser:$gisuser_passwd"|chpasswd

# prepare database
sudo -u postgres psql -c "\c gis"
sudo -u postgres psql -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -c "ALTER TABLE geometry_columns OWNER TO gisuser;"
sudo -u postgres psql -c "ALTER TABLE spatial_ref_sys OWNER TO gisuser;"
sudo -u postgres psql -c "\q"

# download and install osm2pgsql
mkdir ~/src
cd ~/src
git clone git://github.com/openstreetmap/osm2pgsql.git
cd osm2pgsql
./autogen.sh
./configure
make
make install

# download and install mapnik
cd ~/src
git clone git://github.com/mapnik/mapnik
cd mapnik
git branch 2.2 origin/2.2.x
git checkout 2.2

python scons/scons.py configure INPUT_PLUGINS=all OPTIMIZATION=3 SYSTEM_FONTS=/usr/share/fonts/truetype/
make
make install
ldconfig

# download and install map_tile
cd ~/src
git clone git://github.com/openstreetmap/mod_tile.git
cd mod_tile
./autogen.sh
./configure
make
make install
make install-mod_tile
ldconfig

# download and install stylesheets
mkdir -p -m777 /usr/local/share/maps/style
cd /usr/local/share/maps/style
wget https://github.com/mapbox/osm-bright/archive/master.zip
wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip
wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places_simple.zip

unzip '*.zip'
mkdir -m777 ne_10m_populated_places_simple
mv ne_10m_populated_places_simple.dbf ne_10m_populated_places_simple.prj ne_10m_populated_places_simple.README.html ne_10m_populated_places_simple.s* ne_10m_populated_places_simple.VERSION.txt ne_10m_populated_places_simple
mkdir -m777 osm-bright-master/shp
mv land-polygons-split-3857 osm-bright-master/shp/
mv simplified-land-polygons-complete-3857 osm-bright-master/shp/
mv ne_10m_populated_places_simple osm-bright-master/shp/

# build index on huge files
cd osm-bright-master/shp/land-polygons-split-3857
shapeindex land_polygons.shp
cd ../simplified-land-polygons-complete-3857/
shapeindex simplified_land_polygons.shp
cd ../


# //TODO
