namespace :vite do
  desc "Build frontend assets with Vite"
  task :build do
    sh "yarn build"
  end
end

if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance([ "vite:build" ])
end
