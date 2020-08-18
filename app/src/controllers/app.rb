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
    delta_active_series: 'Ativos',
    confirmed_series: 'Confirmados',
    delta_confirmed_series: 'Confirmados',
    death_series: 'Óbitos',
    delta_death_series: 'Óbitos',
    confirmed_home_isolation_series: 'Isolamento Domiciliar',
    confirmed_in_infirmary_series: 'Confirmados',
    confirmed_in_intensive_care_series: 'Confirmados',
    recovered_series: 'Recuperados',
    delta_recovered_series: 'Recuperados',
    suspected_home_isolation_series: 'Isolamento Domiciliar',
    suspected_in_infirmary_series: 'Suspeitos',
    suspected_in_intensive_care_series: 'Suspeitos',
    suspected_series: 'Suspeitos',
    delta_suspected_series: 'Suspeitos',
    tests_performed_series: 'Testes Realizados',
    tested_series: 'Testes Realizados',
    delta_tested_series: 'Testes Realizados',
    tracked_series: 'Monitorados',
    delta_tracked_series: 'Monitorados',
    positive_rate_series: 'Taxa de Positivos',
    private_icu_series: 'UTI Privada',
    public_icu_series: 'UTI Pública',
}

def delta(ary)
  d = []

  ary.each_index do |i|
    date, value = ary[i]

    if i > 0
        _, previous = ary[i - 1]
        value = value.to_i - previous.to_i
    end

    d.append([date, value])
  end

  return d
end

def rate(ary1, ary2)
  d = []

  ary1.each_index do |i|
    date, v1 = ary1[i]
    _, v2 = ary2[i]

    d.append([date, v2.to_f > 0 ? (v1.to_f / v2.to_f) : 0 ])
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
  tested_series = []
  tracked_series = []
  positive_rate_series = []

  first = true

  csv.each do |row|
    if first
      first = false
      next
    end
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

    tested = row[13]
    tested_series.push([date, tested])

    tests_performed = row[14]
    tests_performed_series.push([date, tests_performed])

    tracked = row[15]
    tracked_series.push([date, tracked])

    #positive_rate = tested.to_f > 0 ? (confirmed.to_f / tested.to_f) : 0
    #positive_rate_series.push([date, positive_rate])
  end

  return {
    active_series: active_series,
    delta_active_series: delta(active_series),
    confirmed_series: confirmed_series,
    delta_confirmed_series: delta(confirmed_series),
    death_series: death_series,
    delta_death_series: delta(death_series),
    confirmed_home_isolation_series: confirmed_home_isolation_series,
    confirmed_in_infirmary_series: confirmed_in_infirmary_series,
    confirmed_in_intensive_care_series: confirmed_in_intensive_care_series,
    recovered_series: recovered_series,
    delta_recovered_series: delta(recovered_series),
    suspected_home_isolation_series: suspected_home_isolation_series,
    suspected_in_infirmary_series: suspected_in_infirmary_series,
    suspected_in_intensive_care_series: suspected_in_intensive_care_series,
    suspected_series: suspected_series,
    delta_suspected_series: delta(suspected_series),
    tests_performed_series: tests_performed_series,
    tested_series: tested_series,
    delta_tested_series: delta(tested_series),
    tracked_series: tracked_series,
    delta_tracked_series: delta(tracked_series),
    positive_rate_series: rate(delta(confirmed_series), tests_performed_series),
  }
end

def icu_csv(filename)
  csv = CSV.read(filename)

  first = true

  private_icu_series = []
  public_icu_series = []

  csv.each do |row|
    if first
      first = false
      next
    end

    date = row[0]
    private_icu = row[1]
    public_icu = row[2]

    private_icu_series.push([date, private_icu])
    public_icu_series.push([date, public_icu])
  end

  return {
    private_icu_series: private_icu_series,
    public_icu_series: public_icu_series
  }

end

class Covid19Xap < Sinatra::Application

  charts = :charts

  def initialize
    super

    @filename = 'data/csv/chapeco.csv'
    @icu_filename = 'data/csv/chapeco-icu.csv'
    @data = csv(@filename)
    @icu_data = icu_csv(@icu_filename)
    @charts = self._charts(@data, @icu_data)
  end

  def _charts(data, icu_data, start_date=(Date.today - 60).strftime('%Y-%m-%d'), end_date=Date.today.strftime('%Y-%m-%d'))
    series = {}

    data.keys.each do |metric|
      series[metric] = {
        name: $legend[metric],
        data: data[metric].select do |date, value| date > start_date and date <= end_date end
      }
    end

    puts icu_data[:private_icu_series]

    icu_data.keys.each do |metric|
      series[metric] = {
        name: $legend[metric],
        data: icu_data[metric].select do |date, value| date > start_date and date <= end_date end
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

    charts['Ocupação UTI (%)'] = {
      chart: column_chart(
        [
          series[:private_icu_series],
          series[:public_icu_series]
        ],
        column_options.merge({
          colors: ['#CC0000', '#AA00AA', '#00CC00', '#CCCC00'],
          yaxis: {
            max: 100,
            labels: {
              formatter: {
                function: {
                  args: 'value',
                  body: 'return (value).toFixed(0) +\'%\''
                }
              }
            }
          },
        })
      )
    }

    charts['Totais'] = {
      chart: line_chart(
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
    }

    charts['Variação de Casos Ativos'] = {
      chart: column_chart(
        [
          series[:delta_active_series],
          #series[:delta_confirmed_series],
          #series[:delta_recovered_series],
          #series[:delta_suspected_series],
        ],
        column_options.merge({
          height: '250px',
          colors: ['#CC0000', '#AA00AA', '#00CC00', '#CCCC00'],
        })
      )
    }

    charts['Taxa de Positivos (%)'] = {
      subtitle: '<p>Percentual de testes com resultado positivo em relação ao total testado, por dia.</p><p><i>"A OMS sugere uma taxa de positivos entre 3 e 12% como um medidor geral de níveis de testagem adequados".<a target="#" href="https://ourworldindata.org/coronavirus-testing#the-positive-rate-are-countries-testing-enough-to-monitor-their-outbreak">¹</a></i></p>',
      chart: column_chart(
        [
          series[:positive_rate_series],
          #series[:delta_confirmed_series],
          #series[:tests_performed_series],
          #series[:delta_suspected_series],
        ],
        column_options.merge({
          colors: ['#CC0000', '#AA00AA', '#00CC00', '#CCCC00'],
          yaxis: {
            max: 1,
            labels: {
              formatter: {
                function: {
                  args: 'value',
                  body: 'return (value * 100).toFixed(0) +\'%\''
                }
              }
            }
          },
          dataLabels: {
            enabled: true,
            offsetY: -20,
            style: { colors: ['#000000']},
            formatter: {
              function: {
                args: 'value',
                body: 'return (value * 100).toFixed(0)'
              }
            }
          }
        })
      )
    }


    _, total_tested = data[:tested_series][-1]
    tested_per_1000 = 1000 * total_tested.to_i / 216154

    charts["Testes Realizados"] = {
      subtitle: "<b>Total</b>: <i>#{total_tested}</i> (#{tested_per_1000}/mil hab.)",
      chart: column_chart(
        [
          series[:tests_performed_series]
        ],
        column_options
      )

    }

    _, current_deaths = data[:death_series][-1]
    max_deaths = series[:delta_death_series][:data].map do |a, b| b end.max + 1
    charts["Óbitos"] = {
      subtitle: "<b>Total</b>: <i>#{current_deaths}</i>",
      chart: column_chart(
         [
           series[:delta_death_series]
         ],
         column_options.merge({ yaxis: { max: max_deaths} })
      )
    }

    charts['Leitos UTI'] = {
      chart: column_chart(
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
    }

    charts['Leitos Enfermaria'] = {
      chart: column_chart(
        [
          series[:suspected_in_infirmary_series],
          series[:confirmed_in_infirmary_series]
        ],
        {
          colors: ['#CCCC00', '#AA00AA'],
          stacked: true,
          animations: { enabled: false },
          plotOptions: { bar: { dataLabels: { position: :center }}},
          dataLabels: { enabled: true, style: { colors: ['#000000']}}
        }
      )
    }

    puts 'Charts created: %s' % [charts.keys]

    return charts
  end

  def _timestamp(format='<i>%d/%m %H:%M</i>')
    latest_timestamp = File.mtime(@filename)
    tz = TZInfo::Timezone.get('America/Sao_Paulo')
    return tz.strftime(format, latest_timestamp)
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

  get '/sitemap.xml' do
    lastmod = self._timestamp('%y-%m-%d')
    return \
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"> 
          <url>
            <loc>https://covid19-xap.herokuapp.com/</loc>
            <lastmod>#{lastmod}</lastmod>
          </url>
        </urlset>"
  end

  run!
end
