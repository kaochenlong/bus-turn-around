if defined?(Rails::CodeStatistics)
  Rails::CodeStatistics.register_directory("Components", "app/components")
  Rails::CodeStatistics.register_directory("JavaScript", "app/frontend")
end
