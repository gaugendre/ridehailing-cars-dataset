require "json"
require "csv"
require "active_support/all"
require "awesome_print"

def filter_data(row)
  row.to_h.with_indifferent_access.each_with_object({}) do |(k, v), hh|
    next unless k.present?
    # next unless v.present?

    unless v.present?
      hh[k.strip] = nil
      next
    end

    key = k.strip.underscore.parameterize(separator: "_")
    hh[k.strip] = v.strip.tap do |vv|
      if vv.casecmp("true").zero?
        break true
      elsif vv.casecmp("false").zero?
        break false
      elsif (key == "id" || key =~ /^(.+)_id$/) && vv.to_s.to_i.to_s == vv.to_s
        break vv.to_i
      elsif key == "leather"
        break vv == "1"
      end
    end
  end
end

def json_file(filename, data)
  File.open(filename, "w") do |f|
    f.write JSON.pretty_generate(data.as_json)
  end
end

dir = File.dirname(__FILE__) + "/../dataset"

brands = CSV.open("#{dir}/brands.csv", headers: true).to_a.map { |row| filter_data(row) }
models = CSV.open("#{dir}/vehicle-models.csv", headers: true).to_a.map { |row| filter_data(row) }
models_platforms = CSV.open("#{dir}/models-platforms.csv", headers: true).to_a.map { |row| filter_data(row) }
platforms = CSV.open("#{dir}/platforms.csv", headers: true).to_a.map { |row| filter_data(row) }
variants = CSV.open("#{dir}/vehicle-variants.csv", headers: true).to_a.map { |row| filter_data(row) }

cars = variants.map do |variant|
  variant["model"] = models.find { |m| variant["modelId"] == m["id"] }

  model_platforms = models_platforms.find { |mc| variant["modelId"] == mc["modelId"] }.dup
  model_platforms.delete("modelId")

  variant["model"]["platforms"] = model_platforms.select { |_, v| v == "1" }.keys.map(&:to_i).map do |id|
    platforms.find { |cat| cat["id"] == id }
  end

  variant
end

brands.map! do |brand|
  brand["slug"] = brand["name"].parameterize
  brand
end

ride_hailing = platforms.each_with_object({}) do |platform, h|
  if h.key?(platform["ridehailingId"])
    h[platform["ridehailingId"]]["categories"] << platform
  else
    h[platform["ridehailingId"]] = {
      "id" => platform["ridehailingId"],
      "name" => platform["ridehailingName"],
      "categories" => [platform]
    }
  end
end

json_file("#{dir}/brands.json", brands)
json_file("#{dir}/cars.json", cars)
json_file("#{dir}/ride-hailing.json", ride_hailing.values)
