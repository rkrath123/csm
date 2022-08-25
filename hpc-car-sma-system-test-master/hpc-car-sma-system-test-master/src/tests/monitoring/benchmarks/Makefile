rdkafka_performance_SOURCES = rdkafka_performance.c
rdkafka_performance_CFLAGS = -w -g

rdkafka_performance: $(rdkafka_performance_SOURCES)
	gcc $(rdkafka_performance_CFLAGS) $(rdkafka_performance_SOURCES) -o $@ -lrdkafka
	@echo "# $@ is ready"
	@echo "#"
	@echo "# Run producer"
	@echo "./$@ -P -t <topic> -p <partition> -s <msgsize> -b cluster-kafka-bootstrap.sma.svc.cluster.local:9092"
	@echo ""
	@echo "# or consumer"
	@echo "./$@ -C -t <topic> -p <partition>"
	@echo ""
	@echo "#"
	@echo "# More usage options:"
	@echo "./$@ -h"
