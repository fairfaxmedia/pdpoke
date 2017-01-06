require 'pager_duty/connection'
require 'thor'
require 'yaml'
require "pdpoke/version"
require "pp"

module PDPoke
  class Context
    attr_reader :account
    attr_reader :apikey
    attr_reader :email
    attr_reader :teams

    attr_accessor :api

    def initialize
      @yaml = YAML.load_file("#{ENV['HOME']}/.pdpoke.yaml")
      @apikey  = @yaml['apikey']
      @account = @yaml['account']
      @email   = @yaml['email']
      # be as non-irritating as possible with team listing
      @teams   = [ @yaml['teams'] ].flatten.sort.uniq
      @api = PagerDuty::Connection.new(account,apikey)
    end
  end

  $context = Context.new

  class CLI < Thor
    desc 'version', 'displays the pdpoke version'
    def version
      STDERR.puts "pdpoke #{VERSION}"
    end

    desc 'ping', 'check that PagerDuty API authentication is working'
    def ping
      begin
        abilities = $context.api.get('abilities')
        STDERR.puts "API access is working. Abilities are:"
        STDERR.puts abilities.abilities.sort.map{ |a| "- #{a}" }.join("\n")
      rescue Exception => e
        STDERR.puts "exception encountered: #{e.class}: #{e.message}"
      end
    end

    desc 'oncall_days', 'list days that you were on-call outside work hours within a specified period'
    method_option :minhours, desc: 'minimum hours required to constitute an on-call day', type: :numeric, default: 2
    method_option :since, desc: 'start of date range to query (ISO8601 format)', default: Date.today.prev_week.iso8601
    method_option :until, desc: 'end of date range to query (ISO8601 format)', default: Date.today.iso8601
    method_option :workstarthour, desc: 'start hour for working day', default: 9, type: :numeric
    method_option :workendhour, desc: 'start hour for working day', default: 17, type: :numeric
    method_option :timezone, desc: 'time-zone to obtain schedules for', required: false
    def oncall_days
      timezone = options[:timezone] || ENV['TZ'] || 'Australia/Sydney'
      me = get_me
      oncall_days = []
      begin
        schedule_ids = schedules_for_user(me.id)
        schedule_ids.each do |sid| 
          schedule = $context.api.get("schedules/#{sid}", :timezone => timezone, :since => options[:since], :until => options[:until]).schedule
          puts "examining schedule: #{schedule.name}"
          schedule['final_schedule']['rendered_schedule_entries'].each do |entry|
            start  = Time.parse(entry.start)
            finish = Time.parse(entry.end)
            if entry.user.id == me.id && oncall_claimable(start,finish,options)
              oncall_days += start.to_date.upto(finish.to_date).to_a.map { |d| "#{d} (#{schedule.name})" }
            end
          end
        end
        oncall_days.sort!.uniq!
        puts oncall_days.sort.uniq.map(&:to_s).map{|x| "on call on #{x}"}
      rescue Exception => e
        puts "oncall_days: #{e.class}::#{e.message}"
      end
    end

    desc 'me', 'get information on your own PagerDuty user'
    def me
      puts get_me.to_json
    end

    desc 'users', 'retrieve users in the configured team(s)'
    def users
      u = paginate_all('users',:team_ids => $context.teams)
      u.each do |user|
        puts "#{user.name} <#{user.email}>"
      end
    end

    desc 'incidents', 'retrieve incidents for the configured team(s)'
    method_option :since, desc: 'start of date range to query (ISO8601 format)', default: Date.today.prev_week.iso8601
    method_option :until, desc: 'end of date range to query (ISO8601 format)', default: Date.today.iso8601
    method_option :fieldmatch, desc: 'only return records where a specified field matches a provided regex', required: false, type: :array
    def incidents
      all_incidents = retrieve_incidents(options)
      puts all_incidents.to_json
    end

    desc 'incidents_around', 'retrieve incidents within N minutes of a time of day in the local timezone'
    method_option :since,  desc: 'start of date range to query (ISO8601 format)', default: Date.today.prev_week.iso8601
    method_option :until,  desc: 'end of date range to query (ISO8601 format)', default: Date.today.iso8601
    method_option :fieldmatch, desc: 'only return records where a specified field matches a provided regex', required: false, type: :array
    method_option :hour,   desc: 'target minute', required: true, type: :numeric
    method_option :minute, desc: 'target hour', required: true, type: :numeric
    method_option :width,  desc: 'search for incidents within N minutes of the target', default: 5, type: :numeric
    def incidents_around
      all_incidents = retrieve_incidents(options)
      all_incidents.keep_if do |incident|
        ti = incident.created_at.localtime
        tt = Time.local(ti.localtime.year,ti.localtime.mon,ti.localtime.day,options[:hour],options[:minute])
        width = options[:width] * 60
        ti.between?(tt-width,tt+width)
      end
      if all_incidents.size > 0
        puts all_incidents.to_json
      else
        STDERR.puts "no incidents found around target time"
        exit 1
      end
    end

    desc 'incident_map', 'generate a 2D map of time-binned incident occurrences'
    method_option :since, desc: 'start of date range to query (ISO8601 format)', default: Date.today.prev_week.iso8601
    method_option :until, desc: 'end of date range to query (ISO8601 format)', default: Date.today.iso8601
    method_option :fieldmatch, desc: 'only return records where a specified field matches a provided regex', required: false, type: :array
    method_option :binsize, desc: 'size of the time bins, in minutes', default: 5, type: :numeric
    def incident_map
      all_incidents = retrieve_incidents(options)
      binsize = options[:binsize]
      bins = (0..23).map { |x| Array.new(60/binsize).fill(0) }
      offset = Time.new.gmtoff
      all_incidents.each do |incident|
        incident_time = incident.created_at + offset
        bin     = (incident_time.min / binsize).truncate
        hour    = incident_time.hour
        bins[hour][bin] += 1
      end
      step_size = 255 / ([ 1, bins.flatten.sort.max ].sort[-1])
      bins.each_index do |hour|
        bins[hour].each_index do |bin|
          contents = "%03d" % ( 255 - bins[hour][bin] * step_size )
          minute = bin * options[:binsize]
          time = "#{"%02d" % hour}#{"%02d" % minute}"
          puts "#{contents} #{contents} #{contents} 255 ## #{time}/#{bins[hour][bin]}"
        end
      end
    end

  private

    def oncall_claimable(start,finish,options={})
      claimable = false
      claimable = true if start.saturday?  || start.sunday?
      claimable = true if finish.saturday? || finish.sunday?
      claimable = true if finish.hour <= options[:workstarthour]
      claimable = true if start.hour >= options[:workendhour]
      claimable &&= (finish.to_i - start.to_i) / 3600 > options[:minhours]
    end

    def schedules_for_user(userid)
      eps = paginate_all('escalation_policies', :user_ids => [ userid ])
      schedules = []
      eps.each do |policy|
        targets = policy.escalation_rules.map { |rule| rule.targets }.flatten.uniq
        targets.keep_if { |target| target.type == 'schedule_reference' }
        schedules += targets.map { |target| target.id }
      end
      schedules.sort.uniq
    end

    def get_me
      u = paginate_all('users', :query => $context.email, :limit => 1)
      u.first
    end

    def paginate_all(endpoint,options = {})
      begin
        options.delete(:limit)
        options.delete(:offset)
        options.delete(:page)
        data = $context.api.get(endpoint,options.merge(:limit => 1))
        all_items = data[endpoint]
        page = 1
        options.delete(:limit)
        while data.more == true
          page += 1
          options.merge(:page => page)
          data = $context.api.get(endpoint,options)
          all_items += data[endpoint]
        end
      rescue Exception => e
        STDERR.puts "exception encountered: #{e.class}: #{e.message}"
        exit 1
      end
      all_items
    end

    def retrieve_incidents(options={})
      begin
        data = $context.api.get('incidents',
          :team_ids => $context.teams,
          :since => options[:since], :until => options[:until],
          :limit => 100
        )
        all_incidents = data.incidents
        page = 1
        STDERR.print "retrieved #{all_incidents.size} incidents"
        while data.more == true
          page += 1
          data = $context.api.get('incidents',
            :team_ids => $context.teams,
            :since => options[:since], :until => options[:until],
            :page => page
          )
          all_incidents += data.incidents
          STDERR.print "\rretrieved #{all_incidents.size} incidents (request ##{page})"
        end
        STDERR.puts "\nall done."
      rescue Exception => e
        STDERR.puts "exception encountered: #{e.class}: #{e.message}"
        exit 1
      end
      if options[:fieldmatch]
        all_incidents.keep_if do |incident|
          match = true
          options[:fieldmatch].each do |fieldmatch|
            rulematch = true
            key,value = fieldmatch.split('~')
            positive = true
            if key.match(/\!$/)
              positive = false
              key.chop!
            end
            path = key.split('/')
            field = incident.dig(*path)
            rulematch &&= ( field && field.match(/#{value}/) )
            rulematch = !rulematch if !positive
            match &&= !!rulematch
          end
          match
        end
      end
      all_incidents
    end

  end #class

end #module
