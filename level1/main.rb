require 'json'
require 'date'

class LifenPayCalculator
  def initialize(filepath_input, filepath_output)
    @filepath_input = filepath_input
    @filepath_output = filepath_output
  end

  def calculate
    shifts_grouped_by_worker = group_shifts_per_worker(parse_data)
    smart_hash = calculate_pay(parse_data, shifts_grouped_by_worker)
    workers_key = transform(smart_hash, shifts_grouped_by_worker)
    commission_key = calculate_commission_key(workers_key, interim_workers(parse_data))
    store_data(workers_key, commission_key, @filepath_output)
  end

  private

  def parse_data
    serialized_data = File.read(@filepath_input)
    JSON.parse(serialized_data)
  end

  def interim_workers(infos)
    infos['shifts'].select { |shift| shift['user_id'] == 5 }.length
  end

  def group_shifts_per_worker(infos)
    infos['shifts'].select { |shift| !shift['user_id'].nil? }
      .group_by { |shift| shift['user_id'] }
  end

  def calculate_pay(infos, shifts_grouped_by_worker)
    infos['workers'].map do |worker|
      worker_id = worker['id']
      worker_status = worker['status']
      shifts_by_worker = shifts_grouped_by_worker[worker_id]
      weekend_shifts = count_weekend_shifts(shifts_by_worker)
      {
        'id': worker_id,
        'weekend_day': weekend_shifts,
        'week_day': (shifts_by_worker.length - weekend_shifts),
        'status': worker_status
      }
    end
  end

  def count_weekend_shifts(shifts_by_worker)
    shifts_by_worker.select { |shift_by_worker| Date.parse(shift_by_worker['start_date']).wday == 0 || Date.parse(shift_by_worker['start_date']).wday == 6 }.length
  end

  def transform(smart_hash, shifts_grouped_by_worker)
    smart_hash.map do |worker_details|
      {
        'id': worker_details[:id],
        'price': calculate_price(worker_details, shifts_grouped_by_worker)
      }
    end
  end

  def calculate_commission_key(workers_key, number_of_interim_workers)
    {
      "pdg_fee": calculate_pdg_fee(workers_key, number_of_interim_workers),
      "interim_shifts": number_of_interim_workers
    }
  end

  def calculate_pdg_fee(workers_key, number_of_interim_workers)
    (0.05 * (workers_key.map { |worker_result| worker_result[:price] }.reduce(0, :+))) + 80 * number_of_interim_workers
  end

  def calculate_price(worker_details, shifts_grouped_by_worker)
    return 480 * ((shifts_grouped_by_worker[worker_details[:id]]).length + 1) unless worker_details[:status] != 'interim'
    worker_details[:status] == 'medic' ? medic_price(worker_details) : intern_price(worker_details)
  end

  def medic_price(worker_details)
    270 * (worker_details[:weekend_day] * 2 + worker_details[:week_day])
  end

  def intern_price(worker_details)
    126 * (worker_details[:weekend_day] * 2 + worker_details[:week_day])
  end

  def store_data(workers_key, commission_key, filepath_output)
    File.open(filepath_output, 'wb') do |file|
      file.write(JSON.generate({"workers": workers_key, "commission": commission_key}))
    end
  end
end

LifenPayCalculator.new('../level4/data.json', '../level4/output.json').calculate
