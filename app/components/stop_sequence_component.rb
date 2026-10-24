# frozen_string_literal: true

# The stop sequence of the latest covered day, so readers see how the route
# runs before its numbers: per direction, its stops from the first stop to the
# last, then the nature of the end where that direction's trips end and the
# other direction's first stop, where the next trip leaves. A member route
# counted with the route gets, in each direction where its stops differ, one
# sentence naming the stops it skips and the ones it serves instead. The list
# sits in a disclosure closed by default with every stop in the server response, and
# shows no sequence numbers: they run on across both directions. Between the
# heading and the disclosure goes the block the caller passes, which the route
# page fills with the route map; the component knows nothing about it.
class StopSequenceComponent < ApplicationComponent
  def initialize(stop_sequence:, ends:)
    @stop_sequence = stop_sequence
    @ends = ends
  end

  def directions = @stop_sequence.directions

  def nature(direction) = @ends.nature(direction.go_back)

  # A direction with its number of stops, as in 去程 44 站.
  def stop_count(direction) = t(".count", direction: t(".directions.#{direction.go_back}"), count: direction.stop_names.size)

  # The mark after the name of a direction's first or last stop.
  def stop_mark(text) = tag.span(text, class: "ml-2 text-label font-semibold text-teal-700")

  # The sentence of one member route's difference in a direction.
  def member_note(note)
    t(".member_note", name: note.name, route_id: note.route_id,
                      skipped: note.skipped_stops.join(t(".stop_list_separator")), added: note.added_stops.join(t(".stop_list_separator")))
  end
end
