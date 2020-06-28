require 'csv'
require 'erb'
require 'sinatra/base'
require 'apexcharts'
require 'sinatra/reloader'

def html(filename, context={})
  erb = ERB.new(File.read(filename))
  return erb.result_with_hash(context)
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
    data = csv('elastic-stack/data/chapeco.csv')
    series = []
    charts = {}

    data.keys.each do |metric|
      s = {
        name: metric,
        data: data[metric]
      }
      series.push(s)
      charts[metric] = line_chart(
        [s],
        {
          stroke: { curve: 'smooth', width: 2},
          animations: { enabled: false },
          markers: { size: 4 }
        }
      )
    end

    return charts
  end


  get '/' do
    return html('app/src/views/index.erb', { charts: @charts})
  end

  run!
end
