require 'xcodeproj'

project_path = 'aikata.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first

group = project.main_group.find_subpath(File.join('aikata'), true)

files_to_add = [
  'Color+Extensions.swift',
  'Date+Extensions.swift',
  'FlowLayout.swift',
  'PostConfirmationView.swift',
  'RegionSelectionView.swift',
  'ReportView.swift'
]

files_to_add.each do |file_name|
  file_path = File.join('aikata', file_name)
  next unless File.exist?(file_path)
  
  # Check if file is already in the project
  unless group.files.find { |f| f.path == file_name }
    puts "Adding #{file_name} to project..."
    file_ref = group.new_file(file_name)
    target.add_file_references([file_ref])
  else
    puts "#{file_name} is already in the project."
  end
end

project.save
puts "Project saved."