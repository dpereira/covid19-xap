import csv
import datetime
import docx2txt
import os
import os.path
import PyPDF2
import re
import sys


def extract_docx_text(docx_filename):
    return docx2txt.process(docx_filename)


def extract_pdf_text(pdf_filename):
    text = ''

    with open(pdf_filename, 'rb') as f:
        reader = PyPDF2.PdfFileReader(f)

        for p in range(reader.numPages):
            page = reader.getPage(p)
            text += page.extractText()

    return text


def extract_filename_date(filename):
    date_separator_index = filename.find('_')
    date = filename[:date_separator_index]
    return datetime.datetime.strptime(date, '%d%m%Y')


def extract_docx_data(text, docx_filename):

    regex = {
        'public_icu_occupation': 'LEITOS UTI PÚBLICO\n\n(\\d+) ?%',
        'private_icu_occupation': 'LEITOS UTI PRIVADO\n\n(\\d+) ?%'
    }

    parsed_date = extract_filename_date(docx_filename)

    data = {
        'date': parsed_date.strftime('%Y-%m-%d')
    }

    data.update(extract_from_text(regex, text))

    return data


def extract_pdf_data(text, pdf_filename):
    defaults = {
        'tested': 0
    }

    regex = [
        {
            'tracked': '\n(.+)\nmonitorados',
            'tested': '\n(.+)\ntestados',
            'discarded': '\n(.+)\ndescartados',
            'confirmed': '\n(.+)\nconfirmados',
            'confirmed_in_infirmary': '\n(.+)\ninternados em',
            'confirmed_in_intensive_care': '\n(.+)\ninternados em',
            'confirmed_deaths': '\n(.+)\nóbitos',
            'confirmed_home_isolation': '\n(.+)\nisolamento',
            'confirmed_recovered': '\n(.+)\nrecuperados',
            'suspected': '\n(.+)\nsuspeitos',
            'suspected_in_infirmary': '\n(.+)\ninternados em',
            'suspected_in_intensive_care': '\n(.+)\ninternados em',
            'suspected_deaths': '\n(.+)\nÓbitos',
            'suspected_home_isolation': '\n(.+)\nisolamento'
        },
        {
            'confirmed': '\n(.+)\nconfirmados',
            'active': '\n(.+)\nativos',
            'confirmed_recovered': '\n(.+)\nrecuperados',
            'confirmed_total_deaths': '\n(.+)\nóbitos',
            'tested': '\n(.+)\ntestados'
        }
    ]

    parsed_date = extract_filename_date(pdf_filename)
    
    data = {
        'date': parsed_date.strftime('%Y-%m-%d')
    }

    for r in regex:
        data.update(extract_from_text(r, text, defaults))

    return data


def extract_from_text(regex, text, defaults={}):
    search_from = 0

    data = {}

    for name, pattern in regex.items():
        m = re.search(pattern, text[search_from:], flags = re.IGNORECASE | re.MULTILINE)

        if m:
            data[name] = convert(m.groups()[0].replace('.', ''))
            search_from += m.span()[1]
        elif name in defaults:
            data[name] = defaults[name]

    return data


def enhance_datapoint(data, prior):

    if 'active' not in data:
        try:
            data['active'] = data['confirmed'] - data['confirmed_recovered'] - data['confirmed_deaths']
        except (KeyError, TypeError, ValueError):
            data['active'] = prior['active']

    data['tests_performed'] = 0

    if prior:
        try:
            data['tests_performed'] = data['confirmed'] + data['discarded'] - (prior['confirmed'] + prior['discarded'])
        except (KeyError, TypeError, ValueError):
            data['tests_performed'] = ''

    if 'confirmed_deaths' not in data and 'confirmed_total_deaths' in data: 
        try:
            data['confirmed_deaths'] = data['confirmed_total_deaths']
        except (KeyError, TypeError, ValueError):
            data['confirmed_deaths'] = 0


def enhance(dataset):
    prior = None

    for data in dataset:
        enhance_datapoint(data, prior)
        prior = data


def convert(value):
    try:
        converted = int(value)
    except ValueError as e:
        print(f'error converting `{value}` to int: {e}')
        converted = 0

    return converted


def write_csv(data, output):
    headers = sorted(list(data[0].keys()))

    with open(output, 'w+') as f:
        writer = csv.writer(f)

        writer.writerow(headers)

        previous = {}

        for entry in data:
            filled = { h: entry.get(h, previous.get(h, '')) for h in headers }
            writer.writerow([filled[h] for h in headers])
            previous = filled


def process_pdf_files(input_directory, output_csv):
    pdf_files = sorted([f for f in os.listdir(input_directory) if f.endswith('.pdf')])

    data = []

    for pdf_file in pdf_files:
        text = extract_pdf_text(os.path.join(input_directory, pdf_file))
        data.append(extract_pdf_data(text, pdf_file))

    data = sorted(data, key=lambda d: d['date'])
    enhance(data)
    write_csv(data, output_csv)


def process_docx_files(input_directory, output_csv):
    docx_files = sorted([f for f in os.listdir(input_directory) if f.endswith('.docx')])

    data = []

    for docx_file in docx_files:
        text = extract_docx_text(os.path.join(input_directory, docx_file))
        data.append(extract_docx_data(text, docx_file))

    data = sorted(data, key=lambda d: d['date'])
    write_csv(data, output_csv)


if __name__ == '__main__':
    pdf_input = sys.argv[1]
    pdf_output = sys.argv[2]
    process_pdf_files(pdf_input, pdf_output)

    docx_input = sys.argv[3]
    docx_output = sys.argv[4]
    process_docx_files(docx_input, docx_output)
