#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   disk-capacity-metrics
#
# DESCRIPTION:
#   This plugin uses df to collect disk capacity metrics
#   disk-metrics.rb looks at /proc/stat which doesnt hold capacity metricss.
#   could have intetrated this into disk-metrics.rb, but thought I'd leave it up to
#   whomever implements the checks.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'

#
# Disk Capacity
#
class DiskCapacity < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: Socket.gethostname.to_s

  option :total,
         description: 'Include grand total (df --total option)',
         short: '-t',
         long: '--total',
         boolean: true,
         default: false

  # Unused ?
  #
  def convert_integers(values)
    values.each_with_index do |value, index|
      begin
        converted = Integer(value)
        values[index] = converted
      rescue ArgumentError # rubocop:disable HandleExceptions
      end
    end
    values
  end

  # Main function
  #
  def run
    # Get capacity metrics from DF as they don't appear in /proc
    `df -PT #{config[:total] ? '--total' : ''}`.split("\n").drop(1).each do |line|
      begin
        fs, _type, blocks, used, avail, capacity, _mnt = line.split

        timestamp = Time.now.to_i
        if fs =~ /\/dev/ || (config[:total] && fs == 'total')
          fs = fs.gsub('/dev/', '')
          metrics = {
            disk: {
              "#{fs}.blocks" => blocks,
              "#{fs}.used" => used,
              "#{fs}.avail" => avail,
              "#{fs}.capacity" => capacity.delete('%')
            }
          }
          metrics.each do |parent, children|
            children.each do |child, value|
              output [config[:scheme], parent, child].join('.'), value, timestamp
            end
          end
        end
      rescue
        unknown "malformed line from df: #{line}"
      end
    end

    # Get inode capacity metrics
    `df -Pi #{config[:total] ? '--total' : ''}`.split("\n").drop(1).each do |line|
      begin
        fs, _inodes, used, avail, capacity, _mnt = line.split

        timestamp = Time.now.to_i
        if fs =~ /\/dev/ || (config[:total] && fs == 'total')
          fs = fs.gsub('/dev/', '')
          metrics = {
            disk: {
              "#{fs}.iused" => used,
              "#{fs}.iavail" => avail,
              "#{fs}.icapacity" => capacity.delete('%')
            }
          }
          metrics.each do |parent, children|
            children.each do |child, value|
              output [config[:scheme], parent, child].join('.'), value, timestamp
            end
          end
        end
      rescue
        unknown "malformed line from df: #{line}"
      end
    end
    ok
  end
end
