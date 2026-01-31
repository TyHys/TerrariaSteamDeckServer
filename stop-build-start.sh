cd /home/deck/code_projects/TerrariaSteamDeckServer/docker
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d