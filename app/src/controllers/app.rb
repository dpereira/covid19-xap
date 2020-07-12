require 'csv'
require 'erb'
require 'sinatra/base'
require 'apexcharts'
require 'sinatra/reloader'
require 'tzinfo'

def html(filename, context={})
  erb = ERB.new(File.read(filename))
  return erb.result_with_hash(context)
end

$legend = {
    active_series: 'Ativos',
    confirmed_series: 'Confirmados',
    death_series: 'Óbitos',
    delta_death_series: 'Óbitos',
    confirmed_home_isolation_series: 'Isolamento Domiciliar',
    confirmed_in_infirmary_series: 'Confirmados',
    confirmed_in_intensive_care_series: 'Confirmados',
    recovered_series: 'Recuperados',
    suspected_home_isolation_series: 'Isolamento Domiciliar',
    suspected_in_infirmary_series: 'Suspeitos',
    suspected_in_intensive_care_series: 'Suspeitos',
    suspected_series: 'Suspeitos',
    tests_performed_series: 'Testes Realizados'
}

def delta(ary)
  d = []

  ary.each_index do |i|
    date, value = ary[i]

    if i > 0
        _, previous = ary[i - 1]
        value = value.to_i - previous.to_i

      d.append([date, value])
    end
  end

  return d
end

def csv(filename)
  csv = CSV.read(filename)

  active_series = []
  confirmed_series = []
  death_series = []
  confirmed_home_isolation_series = []
  confirmed_in_infirmary_series = []
  confirmed_in_intensive_care_series = []
  recovered_series = []
  suspected_home_isolation_series = []
  suspected_in_infirmary_series = []
  suspected_in_intensive_care_series = []
  suspected_series = []
  tests_performed_series = []

  csv.each do |row|
    date = row[7]

    active = row[0]
    active_series.push([date, active])

    confirmed = row[1]
    confirmed_series.push([date, confirmed])

    deaths = row[2]
    death_series.push([date, deaths])

    confirmed_home_isolation = row[3]
    confirmed_home_isolation_series.push([date, confirmed_home_isolation])

    confirmed_in_infirmary = row[4]
    confirmed_in_infirmary_series.push([date, confirmed_in_infirmary])

    confirmed_in_intensive_care = row[5]
    confirmed_in_intensive_care_series.push([date, confirmed_in_intensive_care])

    recovered = row[6]
    recovered_series.push([date, recovered])

    suspected = row[9]
    suspected_series.push([date, suspected])

    suspected_home_isolation = row[10]
    suspected_home_isolation_series.push([date, suspected_home_isolation])

    suspected_in_infirmary = row[11]
    suspected_in_infirmary_series.push([date, suspected_in_infirmary])

    suspected_in_intensive_care = row[12]
    suspected_in_intensive_care_series.push([date, suspected_in_intensive_care])

    tests_performed = row[13]
    tests_performed_series.push([date, tests_performed])
  end

  return {
    active_series: active_series,
    confirmed_series: confirmed_series,
    death_series: death_series,
    delta_death_series: delta(death_series),
    confirmed_home_isolation_series: confirmed_home_isolation_series,
    confirmed_in_infirmary_series: confirmed_in_infirmary_series,
    confirmed_in_intensive_care_series: confirmed_in_intensive_care_series,
    recovered_series: recovered_series,
    suspected_home_isolation_series: suspected_home_isolation_series,
    suspected_in_infirmary_series: suspected_in_infirmary_series,
    suspected_in_intensive_care_series: suspected_in_intensive_care_series,
    suspected_series: suspected_series,
    tests_performed_series: tests_performed_series
  }
end


class SimpleApp < Sinatra::Application

  charts = :charts

  def initialize
    super

    @filename = 'data/csv/chapeco.csv'
    @data = csv(@filename)
    @charts = self._charts(@data)
  end

  def _charts(data, start_date=(Date.today - 30).strftime('%Y-%m-%d'), end_date=Date.today.strftime('%Y-%m-%d'))
    series = {}

    data.keys.each do |metric|
      series[metric] = {
        name: $legend[metric],
        data: data[metric].select! do |date, value| date > start_date and date < end_date end
      }
    end


    charts = {}

    options = {
      stroke: { curve: 'smooth', width: 2},
      animations: { enabled: false },
      markers: { size: 4 }
    }

    column_options = options.merge(
      {
        plotOptions: { bar: { dataLabels: { position: :top }}},
        dataLabels: { enabled: true, offsetY: -20, style: { colors: ['#000000']}}
      }
    )

    charts['Totais'] = \
      line_chart(
        [
          series[:active_series],
          series[:recovered_series],
          series[:confirmed_series],
          series[:suspected_series]
        ],
        options.merge({
           colors: ['#CC0000', '#00CC00', '#AA00AA', '#CCCC00']
        })
      )

    total_tested = series[:tests_performed_series][:data].map do |date, value| value.to_i end.sum

    charts["Testes Realizados - <i>#{total_tested}</i>"] = \
      column_chart(
        [
          series[:tests_performed_series]
        ],
        column_options
    )

   _, current_deaths = series[:death_series][:data][-1]
   charts["Óbitos - <i>#{current_deaths}</i>"] = \
      column_chart(
        [
          series[:delta_death_series]
        ],
        column_options
   )

    charts['Ocupação UTI'] = \
      column_chart(
        [
          series[:suspected_in_intensive_care_series],
          series[:confirmed_in_intensive_care_series]
        ],
        {
          colors: ['#CCCC00', '#AA00AA'],
          stacked: true,
          animations: { enabled: false },
          plotOptions: { bar: { dataLabels: { position: :center }}},
          dataLabels: { enabled: true, style: { colors: ['#000000']}}
        }
      )

    puts 'Charts created: %s' % [charts.keys]

    return charts
  end

  def _timestamp
    latest_timestamp = File.mtime(@filename)
    tz = TZInfo::Timezone.get('America/Sao_Paulo')
    return tz.strftime('%Hh%Mm%Ss %d/%m/%Y (UTC%Z)', latest_timestamp)
  end


  get '/' do
    return html(
      'app/src/views/index.erb',
      { charts: @charts, latest_timestamp: self._timestamp}
    )
  end

  get '/loaderio-9062b491158e6847ab220ae764edff3f/' do
    return 'loaderio-9062b491158e6847ab220ae764edff3f'
  end

  run!
end
