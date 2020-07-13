.PHONY: \
	setup download collect clean clean-pdf \
	extrapolate extract pdf-extract update-data \
	download-brasil-io download-chapeco-sms

OS=$(shell uname -s)
CSV_DATA_DIR=data/csv/
PDF_DATA_DIR=data/pdf/
CHAPECO_DATA_DIR=$(PDF_DATA_DIR)/chapeco/
ifndef PROJECT_NAME
PROJECT_NAME=$(shell basename `pwd`)
endif

%: export USER_ID:=$(shell echo -n `id -u`:`id -g`)

$(CSV_DATA_DIR):
	mkdir -p $(CSV_DATA_DIR)

$(PDF_DATA_DIR):
	mkdir -p $(PDF_DATA_DIR)

$(CHAPECO_DATA_DIR): $(PDF_DATA_DIR)
	mkdir -p $(CHAPECO_DATA_DIR)

setup:
	pip install -r requirements.txt
	make build
	make download
	make extract
	make extrapolate

update-data: clean download extract extrapolate

clean-pdf:
	-rm -rf $(PDF_DATA_DIR)/*

clean:
	-rm -rf $(CSV_DATA_DIR)/*
	-rm -f ./data/*

download-brasil-io: $(CSV_DATA_DIR)
	docker-compose run downloader \
		curl https://data.brasil.io/dataset/covid19/boletim.csv.gz --output /$(CSV_DATA_DIR)/boletim.csv.gz
	docker-compose run downloader \
		curl https://data.brasil.io/dataset/covid19/obito_cartorio.csv.gz --output /$(CSV_DATA_DIR)/obito_cartorio.csv.gz
	docker-compose run downloader \
		curl https://data.brasil.io/dataset/covid19/caso.csv.gz --output /$(CSV_DATA_DIR)/caso.csv.gz

download-chapeco-sms: $(CHAPECO_DATA_DIR)
	docker-compose run downloader \
		wget -c --content-disposition -nd  -r -l 1 \
		-R 'seguranca*' -A DocumentoArquivo,pdf \
		https://www.chapeco.sc.gov.br/documentos/54/documentoCategoria \
		-P /data/pdf/chapeco/

download: download-brasil-io download-chapeco-sms

collect: ./data/caso.csv ./data/boletim.csv ./data/obito_cartorio.csv

extrapolate: ./data/caso-extra.csv

extract: pdf-extract

pdf-extract:
	docker-compose run scraper python scraper/scrape.py /input-data/pdf/chapeco /output-data/csv/chapeco.csv

./data/%-extra.csv: ./data/%.csv
	docker-compose run extrapolation python /extrapolation/extrapolate.py /data/`basename $<` /data/`basename $@` --prior 60 --after 30 --order 2

./data/%.csv: $(CSV_DATA_DIR)/%.csv.gz
	gunzip -c $< > $@

run:
	ruby config.ru
