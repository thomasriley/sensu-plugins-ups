#!/usr/bin/env ruby
#  encoding: UTF-8
#   metrics-nut.rb
#
# DESCRIPTION:
#   This plugin uses polls UPS metrics from NUT and produces
#   Graphite formated output.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   nut
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Tim Smith <tim@cozy.co> Cozy Services Ltd.
#   Based on check-temperature, Copyright 2012 Wantudu SL <dsuarez@wantudu.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'

class Nut < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.ups"

  def run
    instances = `upsc -l 2>/dev/null`.split("\n")

    metrics = {}
    instances.each do |ups|
      metrics[ups.to_s] = {}
      output = `upsc #{ups} 2>/dev/null`.split("\n")
      output.each do |line|
        case line
        when /battery.voltage: (.+)/
          metrics[ups.to_s]['battery_voltage'] = Regexp.last_match(1)
        when /input.voltage: (.+)/
          metrics[ups.to_s]['input_voltage'] = Regexp.last_match(1)
        when /ups.temperature: (.+)/
          metrics[ups.to_s]['temperature'] = Regexp.last_match(1) unless Regexp.last_match(1) == '0' # 0 means it's not supported
        when /battery.charge: (.+)/
          metrics[ups.to_s]['battery_charge'] = Regexp.last_match(1)
        when /ups.load: (.+)/
          metrics[ups.to_s]['load'] = Regexp.last_match(1)
        when /ups.status: (.+)/
          metrics[ups.to_s]['on_battery'] = if Regexp.last_match(1) == 'OL'
                                              0
                                            else
                                              1
                                            end
        end
      end
    end

    timestamp = Time.now.to_i

    metrics.each do |ups, data|
      data.each do |key, value|
        output [config[:scheme], ups, key].join('.'), value, timestamp
      end
    end

    ok
  end
end
