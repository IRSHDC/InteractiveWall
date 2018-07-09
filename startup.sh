#!/bin/bash

cd ~/dev/Tile-Server/bin
screen -d -m -S tiles-1 node www 4100
screen -d -m -S tiles-2 node www 4200
screen -d -m -S tiles-3 node www 4300

screen -d -m -S redis redis-server

cd ~/dev/Caching-Server-UBC
screen -d -m -S caching-server npm start

open -n -a "/Users/irshdc/Library/Developer/Xcode/DerivedData/MapExplorer-cebdevedrroybgdstwjueirgqasq/Build/Products/Debug/WindowExplorer.app"
