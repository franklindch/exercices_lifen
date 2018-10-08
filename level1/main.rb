require "json"

class LifenPayCalculator
  def initialize(filepath_input, filepath_output)
    @filepath_input = filepath_input
    @filepath_output = filepath_output
  end

  def calculate
    infos = parse_data(@filepath_input)
    shifts_grouped_by_worker = group_shifts_per_worker(infos)
    result = calculate_pay(infos, shifts_grouped_by_worker)
    store_data(@filepath_output, result)
  end

  private

  def parse_data(filepath_input)
    serialized_data = File.read(filepath_input)
    JSON.parse(serialized_data)
  end

  def group_shifts_per_worker(infos)
    infos['shifts'].group_by { |shift| shift['user_id'] }
  end

  def calculate_pay(infos, shifts_grouped_by_worker)
    infos['workers'].map do |worker|
      worker_id = worker['id']
      value = shifts_grouped_by_worker[worker_id].length * worker['price_per_shift']
      { 'id': worker_id, 'price': value }
    end
  end

  def store_data(filepath_output, result)
    File.open(filepath_output, 'wb') do |file|
      file.write(JSON.generate({"workers": result}))
    end
  end
end

lifen_pay_calculator = LifenPayCalculator.new('data.json', 'output.json').calculate
