# frozen_string_literal: true

# Where the data comes from: the three feeds and the dataset pages on
# data.gov.tw. No link to a source repository or to a raw-data release:
# neither is public yet.
class DataSourcesComponent < ApplicationComponent
  # The dataset pages, keyed by the dataset name in this component's translations.
  DATASETS = {
    bus_data: "https://data.gov.tw/dataset/128710",
    bus_seat_event: "https://data.gov.tw/dataset/175726",
    mrt_exits: "https://data.gov.tw/dataset/128428"
  }.freeze
end
