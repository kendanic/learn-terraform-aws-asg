#!/bin/bash
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo '<html><h1>Welcome to Nginx via ASG & ALB!</h1></html>' | sudo tee /var/www/html/index.html

