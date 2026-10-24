module RoutePage
  # The depot inspection scores of config/depot_inspections.yml, as in the
  # turnaround-facilities spec: per term, the report and its announcement
  # page, the items copied, and per depot the two columns the appendix prints,
  # or that the depot is not in the appendix. The route pages use the newest
  # term. A configuration that does not hold together fails loudly and names
  # the term or the depot, because a wrong score is a wrong statement about an
  # operator.
  module DepotInspections
    # The configuration does not hold together; the message says where.
    class InvalidConfiguration < StandardError; end

    TERM_NAME = /\A(\d+)-(\d+)\z/
    TERM_KEYS = %i[title page_url].freeze
    DEPOT_KEYS = %i[provider station printed_as inspected_on printed_page].freeze

    Item = Data.define(:name, :weight)
    # One item's two columns, as the appendix prints them.
    Score = Data.define(:item, :columns)
    # A depot's inspection: the operator and station as the appendix prints
    # them, the inspection date as printed, the appendix page and the scores
    # in the order of the term's items.
    Inspection = Data.define(:term, :printed_as, :inspected_on, :printed_page, :scores)
    # One term, such as 115-1 (year 115, period 1): the report's title and
    # announcement page, the items, the inspections keyed by [operator,
    # station] and the [operator, station] pairs not in the appendix.
    Term = Data.define(:name, :year, :period, :title, :page_url, :items, :inspections, :not_in_appendix) do
      # :scored with the inspection, :not_in_appendix or :unchecked, for the
      # operator and station exactly as GetProvider.gz names them.
      def status_of(provider, station)
        key = [ provider, station ]
        if (inspection = inspections[key]) then [ :scored, inspection ]
        elsif not_in_appendix.include?(key) then [ :not_in_appendix, nil ]
        else [ :unchecked, nil ]
        end
      end
    end

    # The newest term of config/depot_inspections.yml for the current environment.
    def self.current = @current ||= newest(Rails.application.config_for(:depot_inspections).fetch(:terms, {}))

    # The newest term of `terms`, the terms section of the configuration.
    def self.newest(terms)
      raise InvalidConfiguration, "config/depot_inspections.yml 沒有任何 term" if terms.blank?

      name, config = terms.max_by { |key, _| term_order(key) }
      term(name.to_s, config)
    end

    def self.term_order(name)
      match = TERM_NAME.match(name.to_s) or raise InvalidConfiguration, "term #{name} 不是「年-期」的寫法，例如 115-1"

      match.captures.map(&:to_i)
    end

    def self.term(name, config)
      missing = TERM_KEYS.reject { config[it].present? }
      raise InvalidConfiguration, "term #{name} 缺 #{missing.join('、')}" if missing.any?

      items = Array(config[:items]).map { Item.new(name: it.fetch(:name).to_s, weight: it.fetch(:weight)) }
      raise InvalidConfiguration, "term #{name} 沒有 items" if items.empty?

      inspections = inspections(name, Array(config[:depots]), items)
      not_in_appendix = Array(config[:not_in_appendix]).map { required_pair(name, it, "not_in_appendix") }
      both = inspections.keys & not_in_appendix
      raise InvalidConfiguration, "term #{name} 的 #{both.map { it.join(' ') }.join('、')} 同時在 depots 與 not_in_appendix" if both.any?

      year, period = term_order(name)
      Term.new(name:, year:, period:, title: config[:title], page_url: config[:page_url], items:, inspections:, not_in_appendix:)
    end

    def self.inspections(name, depots, items)
      depots.each_with_object({}) do |depot, inspections|
        key = required_pair(name, depot, "depots")
        raise InvalidConfiguration, "term #{name} 的調度站 #{key.join(' ')} 列了兩次" if inspections.key?(key)

        inspections[key] = inspection(name, key.join(" "), depot, items)
      end
    end

    def self.inspection(name, depot_name, depot, items)
      missing = DEPOT_KEYS.reject { depot[it].present? }
      raise InvalidConfiguration, "term #{name} 的調度站 #{depot_name} 缺 #{missing.join('、')}" if missing.any?

      Inspection.new(term: name, printed_as: depot[:printed_as], inspected_on: depot[:inspected_on].to_s,
                     printed_page: depot[:printed_page], scores: scores(name, depot_name, depot[:scores].to_h, items))
    end

    # One score per item, in the order of the items; the scores name exactly the items.
    def self.scores(name, depot_name, scores, items)
      given = scores.keys.map(&:to_s)
      names = items.map(&:name)
      unless given.sort == names.sort
        raise InvalidConfiguration, "term #{name} 的調度站 #{depot_name} 的 scores 跟 items 不同：" \
                                    "缺 #{(names - given).join('、').presence || '無'}，多 #{(given - names).join('、').presence || '無'}"
      end

      items.map do |item|
        columns = scores.fetch(item.name.to_sym)
        unless columns.is_a?(Array) && columns.size == 2 && columns.all?(Integer)
          raise InvalidConfiguration, "term #{name} 的調度站 #{depot_name} 的 #{item.name} 不是兩個整數：#{columns.inspect}"
        end

        Score.new(item: item.name, columns:)
      end
    end

    # The [operator, station] of an entry of `list`, both present.
    def self.required_pair(name, entry, list)
      pair = entry.values_at(:provider, :station)
      raise InvalidConfiguration, "term #{name} 的 #{list} 有一筆缺 provider 或 station：#{entry.inspect}" unless pair.all?(&:present?)

      pair
    end

    private_class_method :term_order, :term, :inspections, :inspection, :scores, :required_pair
  end
end
