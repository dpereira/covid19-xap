require 'csv'
require 'erb'
require 'sinatra/base'
require 'apexcharts'
require 'sinatra/reloader'

def html(filename, context={})
  erb = ERB.new(File.read(filename))
  return erb.result_with_hash(context)
end

$legend = {
    active_series: 'Ativos',
    confirmed_series: 'Confirmados',
    death_series: 'Óbitos',
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

    @charts = self._charts
  end

  def _charts
    data = csv('app/data/chapeco.csv')
    series = {}

    data.keys.each do |metric|
      series[metric] = {
        name: $legend[metric],
        data: data[metric]
      }
    end


    charts = {}

    options = {
      stroke: { curve: 'smooth', width: 2},
      animations: { enabled: false },
      markers: { size: 4 }
    }

    charts['Totais'] = \
      line_chart(
        [
          series[:active_series],
          series[:recovered_series],
          series[:confirmed_series],
          series[:suspected_series]
        ],
        options
      )

    charts['Óbitos'] = \
      line_chart(
        [
          series[:death_series]
        ],
        options
      )

    charts['Testes Realizados'] = \
      line_chart(
        [
          series[:tests_performed_series]
        ],
        options
      )

    charts['UTI'] = \
      line_chart(
        [
          series[:suspected_in_intensive_care_series],
          series[:confirmed_in_intensive_care_series]
        ],
        options
      )

    puts 'Charts created: %s' % [charts.keys]

    return charts
  end


  get '/' do
    puts 'Called /'
    return html('app/src/views/index.erb', { charts: @charts})
  end

  run!
end
