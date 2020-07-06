import argparse
import csv
import datetime
import numpy
import sys

dtypes = {
    'chapeco.csv': [
        ('active', int),
        ('confirmed', int),
        ('confirmed_deaths', int),
        ('confirmed_home_isolation', int),
        ('confirmed_in_infirmary', int),
        ('confirmed_in_intensive_care', int),
        ('confirmed_recovered', int),
        ('date', 'U10'),
        ('discarded', int),
        ('suspected', int),
        ('suspected_home_isolation', int),
        ('suspected_in_infirmary', int),
        ('suspected_in_intensive_care', int),
        ('tests_performed', int),
        ('tracked', int)
    ]
}


def cities_data(data):
    sorted_data = numpy.sort(data, order='date')[::-1]

    current_city = 'chapeco'
    current_index = 0

    for i, entry in enumerate(sorted_data):
        if  current_city != entry['city']:
            yield sorted_data[current_index:i]
            current_index = i
            current_city = entry['city']


def load_data(input):
    with open(input, 'r') as df:
        dtype = dtypes.get(input.split('/')[-1])

        if dtype:
            converters = { i: lambda x: x or 0 for i in range(len(dtype))}
        else:
            converters = 0

        return numpy.loadtxt(df, dtype=dtype, delimiter=',', skiprows=1, converters=converters)


def extrapolate_city_data(city_data, field='confirmed', prior=5, after=14, order=1):
    daystamps = [
        int(datetime.datetime.strptime(day['date'], '%Y-%m-%d').timestamp() / (24 * 3600))
        for day in city_data
    ]

    print([d['date'] for d in city_data[-prior:] ])

    if len(city_data[field]) < prior:
        # not enough data
        return [], []

    print(f'Priors for {field}: {city_data[field][-prior:]}')

    fit = numpy.polyfit(daystamps[-prior:], city_data[field][-prior:], order)
    p = numpy.poly1d(fit)

    latest_date = max(daystamps)
    extra_data = [max(0, int(p(latest_date + i))) for i in range(1, after + 1)]
    utc_timestamp = lambda i: ((latest_date + i) * 24 * 3600) + 10800  # BRT +3h = UTC
    extra_days = [datetime.datetime.fromtimestamp(utc_timestamp(i)).strftime('%Y-%m-%d') for  i in range(1, after + 1)]

    return extra_days, extra_data


def extrapolate(data, prior=5, after=14, order=2, fields=['active', 'confirmed', 'confirmed_deaths', ]):
    extra = {}

    fields = [d for d in data.dtype.names if d != 'date']

    for f in fields:
        dates, values = extrapolate_city_data(data, field=f, prior=prior, after=after, order=order)
        extra[f] = values
        extra['date'] = dates

    return [
        tuple((data[-1][f] if f not in fields and f != 'date' else extra[f][i] for f in data.dtype.names ))
        for i in range(after)
    ]


def save(data, header_names, file_name):

    with open(file_name, 'w+') as f:
        writer = csv.writer(f)

        writer.writerow(header_names)
        for row in data:
            writer.writerow(row)


def parse_args():
    parser = argparse.ArgumentParser(description='Extrapolate covid-19 data')
    parser.add_argument('input')
    parser.add_argument('output')
    parser.add_argument('--prior', type=int, default=14)
    parser.add_argument('--after', type=int, default=14)
    parser.add_argument('--order', type=int, default=2)

    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()
    data = load_data(args.input)
    e = extrapolate(data, args.prior, args.after, args.order)
    print(e)
    save(e, data.dtype.names, args.output)
