Write-Host "=== CONTENEDORES ==="
docker compose ps
Write-Host "`n=== TOPICS ==="
docker exec voltera-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
Write-Host "`n=== CONSUMER GROUPS ==="
docker exec voltera-kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
