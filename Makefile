.PHONY: \
	setup download clean clean-pdf \
	extrapolate extract update-data \
	download-brasil-io download-chapeco-sms

OS=$(shell uname -s)
CSV_DATA_DIR=data/csv/
PDF_DATA_DIR=data/pdf/
DOCX_DATA_DIR=data/docx/
CHAPECO_DATA_DIR=$(PDF_DATA_DIR)/chapeco/
ifndef PROJECT_NAME
PROJECT_NAME=$(shell basename `pwd`)
endif

%: export USER_ID:=$(shell echo -n `id -u`:`id -g`)

$(CSV_DATA_DIR):
	mkdir -p $(CSV_DATA_DIR)

$(PDF_DATA_DIR):
	mkdir -p $(PDF_DATA_DIR)

$(DOCX_DATA_DIR):
	mkdir -p $(DOCX_DATA_DIR)

$(CHAPECO_DATA_DIR): $(PDF_DATA_DIR)
	mkdir -p $(CHAPECO_DATA_DIR)

setup:
	docker-compose build

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
	docker-compose run downloader \
		wget -c --content-disposition -nd  -r -l 1 \
		-R 'seguranca*' -A DocumentoArquivo,docx \
		https://www.chapeco.sc.gov.br/documentos/67/documentoCategoria \
		-P /data/docx/chapeco/

download: download-chapeco-sms

extrapolate: ./data/caso-extra.csv

extract:
	docker-compose run scraper python scraper/scrape.py /input-data/pdf/chapeco /output-data/csv/chapeco.csv /input-data/docx/chapeco /output-data/csv/chapeco-icu.csv

./data/%-extra.csv: ./data/%.csv
	docker-compose run extrapolation python /extrapolation/extrapolate.py /data/`basename $<` /data/`basename $@` --prior 60 --after 30 --order 2

./data/%.csv: $(CSV_DATA_DIR)/%.csv.gz
	gunzip -c $< > $@

run:
	ruby config.ru
