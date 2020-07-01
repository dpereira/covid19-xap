include Makefile

action-download-chapeco-sms: $(CHAPECO_DATA_DIR)
	wget -c --content-disposition -nd  -r -l 1 \
	-R 'seguranca*' -A DocumentoArquivo,pdf \
	https://www.chapeco.sc.gov.br/documentos/54/documentoCategoria \
	-P $(PDF_DATA_DIR)

action-pdf-scrape:
	python scraper/scrape.py $(CHAPECO_DATA_DIR) $(CSV_DATA_DIR)/chapeco.csv
