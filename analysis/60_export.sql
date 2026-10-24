-- Stage 60: write the inspection CSVs and print the data of the card.
--
-- Reads the views of stages 10 to 50 and the variable inspect_dir. Writes
-- trips.csv, layovers.csv, chains.csv, profile.csv and quality.csv with a
-- fixed column order and a sort order ending in a unique key, so two runs over
-- the same files write the same bytes. These files are the only outputs that
-- carry bus_id. The last statement prints one row, card, a JSON object holding
-- everything the Markdown card shows; it is the only statement that prints.

COPY (
    SELECT bus_id, route_id, path_attribute_id, go_back, start_time, end_time, first_seq, last_seq,
           n_events, n_stops_observed, completeness, start_from_arrival, end_from_departure
    FROM trips
    ORDER BY bus_id, start_time, trip_id
) TO (getvariable('inspect_dir') || '/trips.csv') (HEADER);

COPY (
    SELECT bus_id, route_id, go_back, end_time, next_start_time, round(minutes, 1) AS minutes
    FROM layovers
    ORDER BY bus_id, end_time, trip_id
) TO (getvariable('inspect_dir') || '/layovers.csv') (HEADER);

COPY (
    SELECT chain_id, bus_id, start_time, end_time, n_trips
    FROM chains
    ORDER BY chain_id
) TO (getvariable('inspect_dir') || '/chains.csv') (HEADER);

COPY (
    SELECT go_back, band, seq, stop_name, n_trips, median, p90
    FROM load_profile
    ORDER BY go_back, band, seq, stop_name
) TO (getvariable('inspect_dir') || '/profile.csv') (HEADER);

COPY (
    SELECT metric, subject, value
    FROM quality
    ORDER BY metric, subject
) TO (getvariable('inspect_dir') || '/quality.csv') (HEADER);

SELECT to_json({
    -- The page route names the run; route_ids lists every route Id of the
    -- run, the page route first, and the sub-routes listed are theirs.
    'route': (
        SELECT {
            'route_id': any_value(route_id),
            'route_ids': getvariable('route_ids'),
            'name': any_value(route_name),
            'departure': any_value(departure),
            'destination': any_value(destination),
            'sub_routes': (
                SELECT list({'path_attribute_id': path_attribute_id, 'name': path_attribute_name} ORDER BY path_attribute_id)
                FROM routes
            )
        }
        FROM routes
        WHERE route_id = getvariable('route_id')
    ),
    'day': strftime(getvariable('day'), '%Y-%m-%d'),
    'static_day': strftime(getvariable('static_day'), '%Y-%m-%d'),
    -- Each band covers the hours from its start up to, not including, its end.
    'band_hours': {
        'morning_peak_start': getvariable('morning_peak_start_hour'),
        'daytime_start': getvariable('daytime_start_hour'),
        'evening_peak_start': getvariable('evening_peak_start_hour'),
        'evening_peak_end': getvariable('evening_peak_end_hour')
    },
    'quality': {
        -- The read window includes its start and excludes its end.
        'window': {
            'start': strftime(getvariable('window_start'), '%Y-%m-%d %H:%M'),
            'end': strftime(getvariable('window_end'), '%Y-%m-%d %H:%M')
        },
        'duty_status_end_code': getvariable('duty_status_end_code'),
        'feeds': (SELECT list({'feed': feed, 'n_read': n_read, 'n_removed': n_removed} ORDER BY feed) FROM load_counts),
        'unknown_stop_events': (SELECT count(*) FROM unknown_stop_events),
        'sequence_check': (
            SELECT list({'path_attribute_id': path_attribute_id, 'name': path_attribute_name,
                         'directions': directions, 'identical': identical} ORDER BY path_attribute_id)
            FROM sequence_check
        ),
        'completeness': (
            SELECT {'complete': count(*) FILTER (WHERE completeness = 'complete'),
                    'missing_start': count(*) FILTER (WHERE completeness = 'missing_start'),
                    'missing_end': count(*) FILTER (WHERE completeness = 'missing_end'),
                    'missing_both': count(*) FILTER (WHERE completeness = 'missing_both')}
            FROM trips
        ),
        'path_trips': (
            SELECT list({'path_attribute_id': path_attribute_id, 'name': path_attribute_name,
                         'n_trips': n_trips, 'share': share, 'n_first': n_first, 'n_last': n_last}
                        ORDER BY path_attribute_id)
            FROM path_trip_shares
            JOIN vehicle_day_ends USING (path_attribute_id)
        ),
        'last_stop_departures': (
            SELECT list({'go_back': go_back, 'stop_name': stop_name, 'complete_trips': complete_trips,
                         'with_departure': with_departure} ORDER BY go_back)
            FROM last_stop_departures
        ),
        'missing_stop_rate': (
            SELECT {'missing_stops': missing_stops, 'direction_stops': direction_stops, 'rate': rate}
            FROM missing_stop_rate
        ),
        'duty_status': (SELECT list({'duty_status': duty_status, 'n_events': n_events} ORDER BY duty_status) FROM duty_status_counts),
        'duty_status_ends': (
            SELECT {'trips_ending_duty_2': trips_ending_duty_2, 'n_trips': n_trips, 'trip_share': trip_share,
                    'final_duty_2_events': final_duty_2_events, 'duty_2_events': duty_2_events, 'event_share': event_share}
            FROM duty_status_trip_ends
        )
    },
    'trips': {
        'total': (SELECT count(*) FROM trips),
        'by_direction_band': (
            SELECT list({'go_back': go_back, 'band': band, 'n_trips': n_trips, 'n_complete': n_complete} ORDER BY go_back, band)
            FROM (
                SELECT t.go_back, b.band, count(*) AS n_trips, count(*) FILTER (WHERE t.completeness = 'complete') AS n_complete
                FROM trips t
                JOIN trip_bands b USING (trip_id)
                GROUP BY t.go_back, b.band
            )
        ),
        'start_from_arrival': (SELECT count(*) FROM trips WHERE start_from_arrival),
        'end_from_departure': (SELECT count(*) FROM trips WHERE end_from_departure),
        'split_gap_minutes': getvariable('split_gap_minutes')
    },
    'layovers': {
        'distribution': (
            SELECT list({'go_back': go_back, 'n_layovers': n_layovers, 'percentiles': percentiles,
                         'short_share': short_share, 'bin_counts': bin_counts} ORDER BY go_back NULLS FIRST)
            FROM layover_distribution
        ),
        'exclusions': (SELECT {'no_last_stop': no_last_stop, 'no_first_stop': no_first_stop, 'other_route': other_route, 'negative': negative}
                       FROM layover_exclusions),
        'bin_lower_bounds': getvariable('layover_bin_lower_bounds'),
        'percentile_levels': getvariable('percentile_levels'),
        'short_layover_minutes': getvariable('short_layover_minutes'),
        'other_route_min_stops': getvariable('other_route_min_stops')
    },
    'chains': {
        'summary': (SELECT {'n_chains': n_chains, 'n_vehicles': n_vehicles} FROM chain_summary),
        'report': (
            SELECT list({'start_time': strftime(start_time, '%Y-%m-%d %H:%M'), 'end_time': strftime(end_time, '%Y-%m-%d %H:%M'),
                         'n_trips': n_trips} ORDER BY chain_id)
            FROM chain_report
        ),
        'rest_window_minutes': getvariable('rest_window_minutes'),
        'rest_min_minutes': getvariable('rest_min_minutes'),
        'rest_credit_minutes': getvariable('rest_credit_minutes')
    },
    'profile': {
        'rows': (
            SELECT list({'go_back': go_back, 'band': band, 'seq': seq, 'stop_name': stop_name,
                         'n_trips': n_trips, 'median': median, 'p90': p90} ORDER BY go_back, band, seq, stop_name)
            FROM load_profile
        ),
        'coverage': (
            SELECT {'trips_with_count': trips_with_count, 'n_trips': n_trips, 'trip_share': trip_share,
                    'stops_with_count': stops_with_count, 'n_trip_stops': n_trip_stops, 'stop_share': stop_share}
            FROM count_coverage
        ),
        'reset': (
            SELECT list({'terminal': terminal, 'go_back': go_back, 'stop_name': stop_name, 'n_trips': n_trips,
                         'n_missing': n_missing, 'share_zero': share_zero, 'share_near_zero': share_near_zero,
                         'max_count': max_count} ORDER BY go_back, terminal)
            FROM reset_check
        ),
        'anomalies': (SELECT {'negative_counts': negative_counts, 'jumps': jumps} FROM count_anomalies),
        'reset_near_zero': getvariable('reset_near_zero'),
        'reset_record_minutes': getvariable('reset_record_minutes'),
        'jump_threshold': getvariable('jump_threshold'),
        'upper_level': getvariable('profile_upper_level')
    }
}) AS card;
