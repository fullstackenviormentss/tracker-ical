require 'icalendar'
require 'pivotal-tracker'
require File.join(File.dirname(__FILE__), 'pivotal-tracker', 'story')

class TrackerIcal

  #Set the PivotalTracker token to be used for interating with the Pivotal API
  def self.token=(token)
    PivotalTracker::Client.token=token
  end
  
  #Set if PivotalTracker API should be accessed via SSL for all requests
  def self.use_ssl=(ssl=true)
    PivotalTracker::Client.use_ssl = ssl  
  end

  #Retrieves the PivotalTracker token for a given username and password, enabling further interaction with the Pivotal API
  def self.token(username,password)
    PivotalTracker::Client.token(username,password)
  end
  
  #Sets token & use_ssl in a single method call
  # configure(:token => 'jkfduisj97823974j2kl24899234', :use_ssl => true)
  def self.configure(config={})
    config = {:token => '', :use_ssl => false}.merge!(config)
    self.token=config[:token]
    self.use_ssl=config[:use_ssl]    
  end
  
  #Returns an ics formatted string of all the iterations and releases in the project
  #If a release does not have a deadline, it will not be included in the output
  def self.calendar_for_project(project_id)
    project = PivotalTracker::Project.find(project_id)
    releases = project.stories.all(:story_type => 'release')
    calendar = Icalendar::Calendar.new
    iterations = project.iterations.all
    iterations.each do |iter|
      iteration_event(project,calendar,iter)
      # Retrieve the due_on value for each milestone & stip the time component
      #Retrieve the title of the milestone & set it to the summary
      #Retrieve the goals of the milestone & set it to the description
    end
    releases.each do |release|
      release_event(project,calendar,release)
    end
    calendar.publish
    return calendar.to_ical
  end

  #Creates an ics file at the specified filepath containing the iterations and releases with deadlines for the project_id
  def self.ics_file_for_project(filepath,project_id)
    file = File.new(filepath,"w+")
    file.write(self.create_calendar_for_project_id(project_id))
    file.close
  end
  
  # <b>DEPRECATED:</b> Please use <tt>calendar_for_project</tt> instead
  def self.create_calendar_for_project_id(project_id)
    warn "[DEPRECATION] `create_calendar_for_project_id` is deprecated.  Please use `calendar_for_project` instead."
    self.calendar_for_project(project_id)
  end
  
  # <b>DEPRECATED:</b> Please use <tt>ics_file_for_project</tt> instead
  def self.create_ics_file_for_project_id(filepath,project_id)
    warn "[DEPRECATION] `create_ics_file_for_project_id` is deprecated.  Please use `ics_file_for_project` instead."
    self.ics_file_for_project(filepath,project_id)
  end

  private

  def self.release_event(project,calendar,release)
    unless release.deadline.nil?
      calendar.event do
        dtstart       Date.new(release.deadline.year,release.deadline.month,release.deadline.day)
        dtend         Date.new(release.deadline.year,release.deadline.month,release.deadline.day)
        summary       release.name
        description   release.description
      end
    end
  end
  
  def self.iteration_points(iteration)
    points = {}
    point_array = iteration.stories.collect(&:estimate).compact
    accepted_point_array = iteration.stories.select{|story|story.current_state == 'accepted'}.collect(&:estimate).compact
    points[:total] = eval point_array.join('+')
    points[:accepted] = eval accepted_point_array.join('+')
    return points
  end

  def self.iteration_event(project,calendar,iter)
    stories = []
    
    iter.stories.each do |story|
      stories.push("#{story.name} (#{story.current_state})")
    end
    
    points = self.iteration_points(iter)
    
    calendar.event do
      dtstart       Date.new(iter.start.year,iter.start.month,iter.start.day)
      dtend         Date.new(iter.finish.year,iter.finish.month,iter.finish.day)
      summary       "#{project.name}: Iteration #{iter.number} (#{points[:accepted].to_i}/#{points[:total].to_i} points)"
      description   stories.join("\n")
    end
  end

end