include Makefile

action-download-chapeco-sms: $(CHAPECO_DATA_DIR)
	wget -c --content-disposition -nd  -r -l 1 \
	-R 'seguranca*' -A DocumentoArquivo,pdf \
	https://www.chapeco.sc.gov.br/documentos/54/documentoCategoria \
	-P $(CHAPECO_DATA_DIR)
	wget -c --content-disposition -nd  -r -l 1 \
	-R 'seguranca*' -A DocumentoArquivo,docx \
	https://www.chapeco.sc.gov.br/documentos/67/documentoCategoria \
	-P $(CHAPECO_DOCX_DATA_DIR)

action-pdf-scrape: scraper-setup $(CSV_DATA_DIR) extract
	python scraper/scrape.py $(CHAPECO_DATA_DIR) $(CSV_DATA_DIR)/chapeco.csv $(CHAPECO_DOCX_DATA_DIR) $(CSV_DATA_DIR)/chapeco-icu.csv

scraper-setup:
	pip install -r scraper/requirements.txt
